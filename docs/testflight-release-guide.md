# TestFlight 发布指南

## 项目现状评估

| 项目 | 状态 | 说明 |
|------|------|------|
| Xcode 工程 | ✅ 已有 | Team ID: `B3885SFCQJ`, Bundle ID: `com.sihangpeng.threads` |
| 自动签名 | ✅ 已配置 | CODE_SIGN_STYLE = Automatic |
| App Icon | ✅ 已有 | 1024x1024 |
| 隐私权限声明 | ⚠️ 部分有问题 | 相机/相册/麦克风已声明，但通讯录描述是法语(复制粘贴错误) |
| API 地址 | ❌ 阻塞 | 硬编码为 `http://192.168.1.27:8005/` (局域网IP + 明文HTTP) |
| HTTPS | ❌ 阻塞 | 未使用 HTTPS，会被 Apple ATS 拦截 |
| Entitlements | ⚠️ 空文件 | 声明了推送但未配置 `aps-environment` |
| Firebase 推送 | ⚠️ 配置文件在但代码未接入 | `GoogleService-Info.plist` 存在，但 pubspec 没有 `firebase_messaging` |
| Debug 残留 | ❌ 需清理 | `NSBonjourServices`、`NSLocalNetworkUsageDescription` 是调试专用 |
| 部署目标不一致 | ⚠️ | Podfile 写 14.0，pbxproj 写 13.0 |
| CI/CD / Fastlane | ❌ 无 | 无自动化构建发布流程 |

---

## 第一步：解决阻塞问题（必须）

### 1. 替换 API 地址为生产环境 HTTPS 地址

当前 `client/lib/network/api_config.dart` 中：

```dart
static const String baseUrl = 'http://192.168.1.27:8005/';  // 局域网IP，无法在真机使用
```

需要替换为你的生产服务器地址，例如：

```dart
static const String baseUrl = 'https://your-server.com/api/';
```

> 如果后端暂时没有 HTTPS，需要在 `Info.plist` 中添加 ATS 例外（仅限开发测试阶段，上架需要 HTTPS）。

### 2. 清理 Debug 专用配置

从 `Info.plist` 中移除：

- `NSBonjourServices` (`_dart.debugger`)
- `NSLocalNetworkUsageDescription`

### 3. 修复通讯录权限描述

`NSContactsUsageDescription` 当前内容是法语，需改为中文或英文。

### 4. 统一部署目标

将 Podfile 和 project.pbxproj 统一为 iOS 14.0（推荐）。

---

## 第二步：Apple 开发者账号准备

1. 确认已加入 **Apple Developer Program**（年费 $99）
2. 在 [App Store Connect](https://appstoreconnect.apple.com) 中：
   - 创建新 App，Bundle ID 选择 `com.sihangpeng.threads`
   - 填写 App 名称、描述、类别、截图等元数据

---

## 第三步：构建 Release Archive

```bash
cd client

# 1. 获取依赖
flutter pub get

# 2. 安装 CocoaPods
cd ios && pod install && cd ..

# 3. 构建 Release Archive
flutter build ipa \
  --export-method app-store \
  --build-number 1
```

或者手动通过 Xcode：

```bash
# 打开 workspace
open ios/Runner.xcworkspace
# Product → Archive → Distribute App → TestFlight
```

---

## 第四步：上传到 TestFlight

### 方式 A：通过 Xcode

- Window → Organizer → 选择 Archive → Distribute App → TestFlight & App Store → Upload

### 方式 B：通过命令行

```bash
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/threads.ipa \
  --apiKey <YOUR_API_KEY> \
  --apiIssuer <YOUR_ISSUER_ID>
```

### 方式 C：通过 Transporter App（推荐，最简单）

- 从 App Store 下载 Transporter
- 拖入 `.ipa` 文件上传

---

## 第五步：TestFlight 测试

1. 上传成功后，在 App Store Connect 的 TestFlight 标签页查看构建版本
2. Apple 处理通常需要 5-30 分钟
3. 添加内部/外部测试员
4. 通过 TestFlight App 安装测试

---

## 可选：后续优化（推荐但非必须）

| 优化项 | 说明 |
|--------|------|
| 配置 Fastlane | 自动化构建+上传，一条命令完成 |
| 接入 firebase_messaging | 已有 `GoogleService-Info.plist`，加上推送功能 |
| 创建 ExportOptions.plist | 用于 CI/CD 自动化导出 |
| 设置 GitHub Actions | 自动在 CI 中构建并上传 TestFlight |
| API 地址环境隔离 | 用 `--dart-define` 或 flavor 区分开发/生产环境 |

---

## 最快路径总结

如果只是想尽快跑通 TestFlight 内部测试：

1. **解决 API 地址**（指向一个公网可达的服务器）
2. **清理 debug 配置**
3. **`flutter build ipa`**
4. **用 Transporter 上传**
