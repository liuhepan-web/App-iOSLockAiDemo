# LockDemo iOS

基于涂鸦智能生活 App SDK（ThingSmartHomeKit 7.11.0.1）+ ThingSmartLockKit 7.11.0.3 的原生 iOS 门锁示例，功能对齐同目录外的 Android `LockDemo` 工程。界面为中文，使用 UIKit 纯代码布局。

## 环境要求

- Xcode 15 及以上，iOS 14.0+（涂鸦 7.11 起 SDK 最低支持 iOS 14）
- CocoaPods
- XcodeGen（仅在修改 `project.yml` 后需要）
- 涂鸦 IoT 平台上与工程 Bundle ID 一致的 iOS App（默认 `com.lock.set`）

## 首次运行

1. 填写 App 凭证：复制 `LockDemo/App/LocalSecrets.example.plist` 为 `LockDemo/App/LocalSecrets.plist`，填入 IoT 平台同一 App 的 `AppKey` / `AppSecret`。该文件已被 `.gitignore` 忽略，**不要提交**。
2. 准备 App 专属安全 SDK：从涂鸦 IoT 平台下载当前 AppKey 对应的 `ios_core_sdk`，解压并覆盖 `./TuyaSDK/ios_core_sdk`（目录内应包含 `ThingSmartCryption.podspec`）。**不能使用其他 App 的 ThingSmartCryption，也不要将其提交到仓库。**
3. 安装依赖：

   ```bash
   cd /Users/fire/5d12eecf
   LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 pod install --no-repo-update
   open LockDemo.xcworkspace
   ```

4. 在真机上运行。SDK 的 Pod 未提供 arm64 模拟器切片，Apple Silicon Mac 无法直接运行模拟器。

如果修改了 `project.yml`，先执行 `xcodegen generate`，再重新 `pod install`（XcodeGen 会重写工程，需要恢复 CocoaPods 集成）。

## 功能

- 账号：手机号 / 邮箱自动识别国家码，登录、注册、验证码、退出登录。
- 家庭：创建家庭、家庭列表与切换、家庭详情。
- 配网：EZ / AP / QR / BLE 四种方式，展示配网进度与失败原因。
- 设备：设备列表、在线状态、按品类路由门锁面板、移除设备。
- Wi-Fi 门锁面板：动态密码、7 位数字临时密码（24 小时）、成员管理、密码 SN 绑定、开锁记录、远程开锁。
- 视频 / 拍照门锁面板：P2P 预览、对讲、面板成员、远程开锁、强制关锁、重新拍照、开锁记录。
- 视频 / 拍照临时密码：
  - 在线密码 4-15 位，24 小时有效；视频锁使用云端硬件 SN。
  - 视频锁离线密码由云端生成，7 天有效、可多次使用。
  - 拍照锁离线密码通过在线密码列表管理。
  - 列表展示名称、编号 / SN、有效期与状态，支持删除。
- BLE 门锁面板：连接 / 解锁 / 上锁 / 同步、在线与离线密码、自定义密码、成员管理（Pro 邀请、标准当前成员）。

## 目录

- `LockDemo/App/`：Swift 界面、路由、模型与主题。
- `LockDemo/Support/`：Objective-C 服务层，所有涂鸦 SDK 调用集中于此：
  - `LockSDKSupport`：SDK 启动、登录、家庭、设备、配网
  - `LockBaseService`：Wi-Fi / 视频 / 拍照门锁通用能力与临时密码
  - `LockVideoService`：视频预览、对讲、远程开锁、成员密码
  - `LockBLEService`：BLE 连接、开锁、密码与成员
- `project.yml`：XcodeGen 工程定义。

## 实现说明

- 视频 / 拍照在线临时密码的周期参数使用与 Android FastJSON 一致的字符串：
  `[{"allDay":true,"effectiveTime":0,"invalidTime":0,"workingDay":127}]`。
- 拍照锁在线密码时间传毫秒，视频锁与离线密码传秒；离线密码 `pwdType` 为 `"0"`（多次使用）。
- 视频密码创建 / 删除使用 `symbolic=NO`、`dpTunnel=2`，与 Android `ThingVideoManager` 一致。
- 视频在线密码的 SN 通过设备 schema 中的 `unlock_temporary` / `temporary_password_creat` 解析 dpId，读取失败时回退 `69`。
- 列表接口直接返回云端原始结构，服务层做了递归字典收集与秒/毫秒归一化。

## 安全约束

- 不提交 `LocalSecrets.plist`、`ios_core_sdk` 或任何签名密码。
- 只使用为当前 AppKey 与 Bundle ID 生成的 `ThingSmartCryption`。
- 如凭证或安全 SDK 泄漏，请在涂鸦 IoT 平台重新生成并替换。

## 已验证 / 未验证

- 已验证：真机 target 与 x86_64 模拟器 target 均编译通过。
- 未验证：由于缺少真实 AppKey、门锁设备与可运行的模拟器环境，登录、配网、P2P 预览、蓝牙开锁等运行时流程需要在真机上联调。
