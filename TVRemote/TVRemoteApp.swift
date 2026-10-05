//
//  TVRemoteApp.swift
//  TVRemote
//
//  Created by Kushang kaklotar on 01/10/26.
//

import SwiftUI
import FirebaseCore
import FirebasePerformance
import FirebaseCrashlytics

@main
struct TVRemoteApp: App {
    @StateObject private var remoteVM = TR_RemoteViewModel.shared
    @StateObject private var deviceManager = DeviceConnectionManager.shared
    @StateObject private var connectivityVM = TR_DeviceConnectivityViewModel.shared
    @StateObject private var webServer = TR_CastingServerManager.shared
    @StateObject private var mirroringwebserver = TR_MirroringServerManager.shared
    
    let adCountViewModel = TR_AdCountViewModel.sharedd
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasInBackground = false
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    
    init() {
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Crashlytics.crashlytics().log("TV Remote App Launched")
        Performance.sharedInstance().isInstrumentationEnabled = true
        Performance.sharedInstance().isDataCollectionEnabled = true
        FirebaseConfiguration.shared.setLoggerLevel(FirebaseLoggerLevel.min)
        
        TR_NetworkPermissionManager.shared.startMonitoring()
        _ = DeviceConnectionManager.shared
        _ = TR_RemoteViewModel.shared
        _ = TR_DeviceConnectivityViewModel.shared
        _ = TR_CastingServerManager.shared
        _ = TR_MirroringServerManager.shared
        _ = BroadcastNotificationCenter.shared
        _ = TR_AirPlayManager.shared
        _ = TR_TVStreamingViewModel.shared
        
        TR_TVStreamingViewModel.shared.startDiscovery()
        TR_RemoteViewModel.shared.configureDiscoveryIfNeeded()
        TR_RemoteViewModel.shared.startDiscovery()
        DeviceConnectionManager.shared.startScanning()
        
        UIApplication.enableGlobalButtonHaptics()
        AdOrientationManager.shared.startMonitoring()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .buttonStyle(AppHapticButtonStyle())
                .environmentObject(remoteVM)
                .environmentObject(deviceManager)
                .environmentObject(connectivityVM)
                .environmentObject(adCountViewModel)
                .preferredColorScheme(.light)
        }
    }
}
