# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'TVRemote' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for TVRemote
 pod 'AWSS3'
  pod 'Google-Mobile-Ads-SDK'
  pod 'Toast-Swift'
  pod 'SDWebImage', '~> 5.0'
  pod 'SDWebImageSwiftUI'
  pod 'lottie-ios'
  pod 'ConnectSDK/Core'
  pod 'google-cast-sdk'
  pod 'SwiftProtobuf'
  pod 'Starscream'
  pod 'ShimmerSwift'
  pod 'MarqueeLabel'
  
  # Firebase
  pod 'FirebaseAnalytics'
  pod 'FirebaseCrashlytics'
  pod 'FirebasePerformance'
  
  post_install do |installer|
     installer.generated_projects.each do |project|
       project.targets.each do |target|
         target.build_configurations.each do |config|
           config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
           config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
           config.build_settings['CLANG_WARN_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'NO'
         end
       end
     end

     # Fix ConnectSDK CTReachability header issue if needed
     reachability_path = File.join(installer.sandbox.root, 'ConnectSDK/core/Frameworks/asi-http-request/External/Reachability/CTReachability.m')
     if File.exist?(reachability_path)
       text = File.read(reachability_path)
       if text.include?('#import <netinet6/in6.h>')
         File.chmod(0644, reachability_path)
         File.write(reachability_path, text.gsub('#import <netinet6/in6.h>', '// #import <netinet6/in6.h>'))
       end
     end
   end
end
