//
//  PhotoThumbnailCell.swift
//  TV Remote
//

import SwiftUI
import Photos

struct PhotoThumbnailCell: View {
    let asset: PHAsset?
    let isVideo: Bool
    let cellHeight: CGFloat
    var previewImage: UIImage? = nil
    
    @State private var thumbnailImage: UIImage?
    @State private var requestID: PHImageRequestID?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = thumbnailImage ?? previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else {
                // Placeholder shimmer / soft gradient
                LinearGradient(
                    colors: [Color(hex: "E5E7EB"), Color(hex: "D1D5DB")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            }
            
            // Video Duration & Play Badge if video
            if isVideo {
                HStack(spacing: 3) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(formatDuration(asset?.duration ?? 0))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.65))
                .clipShape(Capsule())
                .padding(6)
            }
        }
        .frame(height: cellHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipped()
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .onAppear {
            loadImage()
        }
        .onDisappear {
            cancelImageRequest()
        }
    }
    
    private func loadImage() {
        guard let asset = asset else { return }
        guard thumbnailImage == nil else { return }
        
        let smCellThumbnailDimensions = CGSize(width: 320, height: 380)
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        
        requestID = PhotoGalleryManager.shared.cachingImageManager.requestImage(
            for: asset,
            targetSize: smCellThumbnailDimensions,
            contentMode: .aspectFill,
            options: options
        ) { [self] image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.thumbnailImage = image
                }
            }
        }
    }
    
    private func cancelImageRequest() {
        if let id = requestID {
            PhotoGalleryManager.shared.cachingImageManager.cancelImageRequest(id)
            requestID = nil
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 && !duration.isNaN && !duration.isInfinite else { return "00:00" }
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

