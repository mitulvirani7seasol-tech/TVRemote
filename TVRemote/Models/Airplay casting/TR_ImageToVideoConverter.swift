//
//  TR_ImageToVideoConverter.swift
//  KaiRemote
//
//  Created by Parthiv Akbari on 04/06/26.
//

import Foundation
import UIKit
import AVFoundation
import Photos

class TR_ImageToVideoConverter {
    
    static func createMusicVideo(artwork: UIImage, audioURL: URL, completion: @escaping (Swift.Result<URL, Error>) -> Void) {
        let tempImageURL = saveImageToTemp(image: artwork)
        convertImageToVideo(imageURL: tempImageURL, completion: completion)
    }
    
    static func createMusicVideoWithAudio(
        artwork: UIImage,
        audioURL: URL,
        duration: Double,
        completion: @escaping (Swift.Result<URL, Error>) -> Void
    ) {
        let tempImageURL = saveImageToTemp(image: artwork)
        convertImageToVideo(imageURL: tempImageURL) { result in
            switch result {
            case .success(let videoURL):
                mergeVideoWithAudio(videoURL: videoURL, audioURL: audioURL, completion: completion)
            case .failure:
                completion(.success(audioURL))
            }
        }
    }
    
    static func mergeVideoWithAudio(
        videoURL: URL,
        audioURL: URL,
        completion: @escaping (Swift.Result<URL, Error>) -> Void
    ) {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        
        Task {
            do {
                let audioDuration = try await audioAsset.load(.duration)
                let videoDuration = try await videoAsset.load(.duration)
                
                guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
                      let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
                    DispatchQueue.main.async {
                        completion(.success(audioURL))
                    }
                    return
                }
                
                guard let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                      let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    DispatchQueue.main.async {
                        completion(.success(audioURL))
                    }
                    return
                }
                
                // Insert audio track full length
                let audioTimeRange = CMTimeRange(start: .zero, duration: audioDuration)
                try compAudioTrack.insertTimeRange(audioTimeRange, of: audioTrack, at: .zero)
                
                // Loop poster video track to match audio duration
                var currentTime = CMTime.zero
                let vDur = CMTimeGetSeconds(videoDuration) > 0 ? videoDuration : CMTime(seconds: 5, preferredTimescale: 600)
                while currentTime < audioDuration {
                    let remaining = audioDuration - currentTime
                    let chunkDuration = CMTimeMinimum(vDur, remaining)
                    let videoTimeRange = CMTimeRange(start: .zero, duration: chunkDuration)
                    try compVideoTrack.insertTimeRange(videoTimeRange, of: videoTrack, at: currentTime)
                    currentTime = currentTime + chunkDuration
                }
                
                let smExportDestinationURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("music_cast_\(UUID().uuidString).mp4")
                try? FileManager.default.removeItem(at: smExportDestinationURL)
                
                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                    DispatchQueue.main.async {
                        completion(.success(audioURL))
                    }
                    return
                }
                
                exportSession.outputURL = smExportDestinationURL
                exportSession.outputFileType = .mp4
                exportSession.shouldOptimizeForNetworkUse = true
                
                await exportSession.export()
                
                DispatchQueue.main.async {
                    if exportSession.status == .completed {
                        completion(.success(smExportDestinationURL))
                    } else {
                        print("⚠️ Merge export fallback: \(exportSession.error?.localizedDescription ?? "unknown")")
                        completion(.success(audioURL))
                    }
                }
            } catch {
                print("⚠️ Merge error fallback: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.success(audioURL))
                }
            }
        }
    }
    
    static func convertImageToVideo(imageURL: URL, completion: @escaping (Swift.Result<URL, Error>) -> Void) {
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let smOutputVideoURL = documentsPath.appendingPathComponent("converted_video_\(UUID().uuidString).mp4")
        
        if FileManager.default.fileExists(atPath: smOutputVideoURL.path) {
            try? FileManager.default.removeItem(at: smOutputVideoURL)
        }
        
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            completion(.failure(TR_VideoConversionError.imageLoadFailed))
            return
        }
        
        let isLandscape = image.size.width >= image.size.height
        let videoSize = isLandscape ? CGSize(width: 1920, height: 1080) : CGSize(width: 1080, height: 1920)
        let fps: Int32 = 30
        let videoDuration: Double = 10
        
        guard let smAssetWriterRef = try? AVAssetWriter(outputURL: smOutputVideoURL, fileType: .mp4) else {
            completion(.failure(TR_VideoConversionError.assetWriterCreationFailed))
            return
        }
        
        let smVideoEncoderConfig: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6000000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: smVideoEncoderConfig)
        assetWriterInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: videoSize.width,
            kCVPixelBufferHeightKey as String: videoSize.height
        ]
        
        let smAdaptorInput = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        if smAssetWriterRef.canAdd(assetWriterInput) {
            smAssetWriterRef.add(assetWriterInput)
        } else {
            completion(.failure(TR_VideoConversionError.cannotAddInput))
            return
        }
        
        smAssetWriterRef.startWriting()
        smAssetWriterRef.startSession(atSourceTime: .zero)
        
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        let totalFrames = Int(videoDuration * Double(fps))
        
        var smFrameStepCount = 0
        
        assetWriterInput.requestMediaDataWhenReady(on: DispatchQueue.global(qos: .userInitiated)) {
            while assetWriterInput.isReadyForMoreMediaData && smFrameStepCount < totalFrames {
                
                let presentationTime = CMTime(value: CMTimeValue(smFrameStepCount), timescale: CMTimeScale(fps))
                
                if let pixelBuffer = self.createPixelBuffer(from: image, size: videoSize, pixelBufferPool: smAdaptorInput.pixelBufferPool) {
                    
                    if !smAdaptorInput.append(pixelBuffer, withPresentationTime: presentationTime) {
                        print("Failed to append pixel buffer at frame \(smFrameStepCount)")
                        break
                    }
                    
                    smFrameStepCount += 1
                } else {
                    print("Failed to create pixel buffer at frame \(smFrameStepCount)")
                    break
                }
            }
            
            assetWriterInput.markAsFinished()
            smAssetWriterRef.finishWriting {
                DispatchQueue.main.async {
                    if smAssetWriterRef.status == .completed {
                        completion(.success(smOutputVideoURL))
                    } else {
                        completion(.failure(smAssetWriterRef.error ?? TR_VideoConversionError.unknown))
                    }
                }
            }
        }
    }
    
    static func convertImagesToVideo(
        images: [UIImage],
        imageDuration: Double = 11.0,
        completion: @escaping (Swift.Result<URL, Error>) -> Void
    ) {
        
        guard !images.isEmpty else {
            completion(.failure(TR_VideoConversionError.imageLoadFailed))
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let smOutputVideoURL = documentsPath.appendingPathComponent("video_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: smOutputVideoURL)
        
        let videoSize = CGSize(width: 1080, height: 1920)
        let fps: Int32 = 30
        let framesPerImage = Int(imageDuration * Double(fps))
        
        guard let smAssetWriterInstance = try? AVAssetWriter(outputURL: smOutputVideoURL, fileType: .mp4) else {
            completion(.failure(TR_VideoConversionError.assetWriterCreationFailed))
            return
        }
        
        let smVideoEncoderConfig: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let smVideoAssetInput = AVAssetWriterInput(mediaType: .video, outputSettings: smVideoEncoderConfig)
        smVideoAssetInput.expectsMediaDataInRealTime = false
        
        let smPixelAdaptorRef = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: smVideoAssetInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: videoSize.width,
                kCVPixelBufferHeightKey as String: videoSize.height
            ]
        )
        
        guard smAssetWriterInstance.canAdd(smVideoAssetInput) else {
            completion(.failure(TR_VideoConversionError.cannotAddInput))
            return
        }
        
        smAssetWriterInstance.add(smVideoAssetInput)
        smAssetWriterInstance.startWriting()
        smAssetWriterInstance.startSession(atSourceTime: .zero)
        var frameIndex: Int64 = 0
        var imageIndex = 0
        var imageFrameIndex = 0
        
        smVideoAssetInput.requestMediaDataWhenReady(on: DispatchQueue.global(qos: .userInitiated)) {
            
            while smVideoAssetInput.isReadyForMoreMediaData {
                
                if imageIndex >= images.count {
                    smVideoAssetInput.markAsFinished()
                    smAssetWriterInstance.finishWriting {
                        DispatchQueue.main.async {
                            smAssetWriterInstance.status == .completed
                            ? completion(.success(smOutputVideoURL))
                            : completion(.failure(smAssetWriterInstance.error ?? TR_VideoConversionError.unknown))
                        }
                    }
                    return
                }
                
                let image = images[imageIndex]
                
                guard let pixelBuffer = createPixelBuffer(
                    from: image,
                    size: videoSize,
                    pool: smPixelAdaptorRef.pixelBufferPool
                ) else {
                    completion(.failure(TR_VideoConversionError.unknown))
                    return
                }
                
                let smFrameTimeStamp = CMTime(value: frameIndex, timescale: fps)
                
                // ✅ Append ONE frame only
                if smPixelAdaptorRef.append(pixelBuffer, withPresentationTime: smFrameTimeStamp) {
                    frameIndex += 1
                    imageFrameIndex += 1
                } else {
                    return
                }
                
                // ✅ Move to next image AFTER 4 seconds worth of frames
                if imageFrameIndex >= framesPerImage {
                    imageFrameIndex = 0
                    imageIndex += 1
                }
            }
        }
        
    }
    
    static func saveImageToTemp(image: UIImage) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            try? imageData.write(to: tempURL)
        }
        
        return tempURL
    }
    
    private static func createPixelBuffer(
        from image: UIImage,
        size: CGSize,
        pool: CVPixelBufferPool?
    ) -> CVPixelBuffer? {
        
        guard let pool = pool else { return nil }
        
        var smCreatedBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &smCreatedBuffer)
        guard let pixelBuffer = smCreatedBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let smBitmapContext = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        
        smBitmapContext.clear(CGRect(origin: .zero, size: size))
        
        let rect = AVMakeRect(
            aspectRatio: image.size,
            insideRect: CGRect(origin: .zero, size: size)
        )
        
        if let cgImage = image.cgImage {
            smBitmapContext.draw(cgImage, in: rect)
        }
        
        return pixelBuffer
    }
    
    private static func createPixelBuffer(from image: UIImage, size: CGSize, pixelBufferPool: CVPixelBufferPool?) -> CVPixelBuffer? {
        
        var pixelBuffer: CVPixelBuffer?
        
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let smAllocatedBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(smAllocatedBuffer, [])
        
        let smBitmapContext = CGContext(
            data: CVPixelBufferGetBaseAddress(smAllocatedBuffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(smAllocatedBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let cgContext = smBitmapContext else {
            CVPixelBufferUnlockBaseAddress(smAllocatedBuffer, [])
            return nil
        }
        
        cgContext.clear(CGRect(origin: .zero, size: size))
        
        let imageSize = image.size
        let smScaleWidthRatio = size.width / imageSize.width
        let smScaleHeightRatio = size.height / imageSize.height
        let smFittedScale = min(smScaleWidthRatio, smScaleHeightRatio)
        
        let scaledSize = CGSize(width: imageSize.width * smFittedScale, height: imageSize.height * smFittedScale)
        let drawRect = CGRect(
            x: (size.width - scaledSize.width) / 2,
            y: (size.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        if let cgImage = image.cgImage {
            cgContext.draw(cgImage, in: drawRect)
        }
        
        CVPixelBufferUnlockBaseAddress(smAllocatedBuffer, [])
        
        return smAllocatedBuffer
    }
}

// Error enum
enum TR_VideoConversionError: Error {
    case imageLoadFailed
    case assetWriterCreationFailed
    case cannotAddInput
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .imageLoadFailed:
            return "Failed to load image"
        case .assetWriterCreationFailed:
            return "Failed to create asset writer"
        case .cannotAddInput:
            return "Cannot add input to asset writer"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}
