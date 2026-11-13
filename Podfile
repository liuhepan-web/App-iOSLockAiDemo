source 'https://cdn.cocoapods.org/'
source 'https://github.com/tuya/tuya-pod-specs.git'

platform :ios, '14.0'

target 'LockDemo' do
  use_modular_headers!

  # 必须使用当前 AppKey 对应工程在涂鸦 IoT 平台下载的 ios_core_sdk 包。
  # 解压后放到 ./TuyaSDK/ios_core_sdk（目录内应包含 ThingSmartCryption.podspec）。
  pod 'ThingSmartCryption', :path => './TuyaSDK/ios_core_sdk'

  # ThingSmartHomeKit 由 AppIOSBase 的 podspec 依赖带出（ ~> 7.11.0），无需重复声明
  pod 'ThingSmartBusinessExtensionKit', '~> 7.11.0'
  pod 'ThingSmartLockKit', '7.11.0.3'
  # 5.2.1.4 的二进制缺 ThingModuleServices-umbrella.h，编译报 umbrella header not found，固定到正常版本
  pod 'ThingModuleServices', '4.76.6'

  # 基础能力库（注册 / 登录 / 家庭 / 设备列表 / 个人中心），git 引用，升级改 :tag。
  # 远程 0.2.0 = da32aec：ThingSmartHomeKit/BusinessExtensionKit ~> 7.11.0（HomeKit 由本 podspec 声明）
  pod 'AppIOSBase', :git => 'https://github.com/liuhepan-web/AppIOSBase.git', :tag => '0.2.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'NO'
    end
  end
end
