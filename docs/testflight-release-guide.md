# iOS 发布到 TestFlight — 纯 CLI 方式

> 使用 `flutter build ipa` + `xcodebuild -exportArchive` 命令行完成 Archive + Upload 到 TestFlight。
> 无需 API Key，依赖 Xcode 已登录的 Apple ID session。

## 前提条件

- Xcode 已登录 Apple ID 账号（Xcode > Settings > Accounts）
- 项目已配置正确的 Signing & Capabilities（Automatic Signing）
- Flutter 环境已安装

## 项目签名信息

| 项目 | 值 |
|------|------|
| Team ID | `B3885SFCQJ` |
| Bundle ID | `com.yt.threads` |
| Scheme | `Runner` |
| Workspace | `client/ios/Runner.xcworkspace` |

---

## 一键发布命令

### 1. 构建 Archive

```bash
cd client

flutter build ipa --release
```

构建产物位于 `build/ios/archive/Runner.xcarchive`。

### 2. 创建 UploadOptions.plist

```bash
cat > build/ios/upload/UploadOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>B3885SFCQJ</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
EOF
```

### 3. 导出并上传到 TestFlight

```bash
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/upload \
  -exportOptionsPlist build/ios/upload/UploadOptions.plist \
  -allowProvisioningUpdates
```

看到 `** EXPORT SUCCEEDED **` 即表示上传成功，App Store Connect 会自动开始处理。

---

## 完整一键脚本

可以将以上步骤合并为一个脚本，在项目根目录执行：

```bash
#!/bin/bash
set -e

cd client

echo "==> Step 1: flutter build ipa"
flutter build ipa --release

echo "==> Step 2: create UploadOptions.plist"
mkdir -p build/ios/upload
cat > build/ios/upload/UploadOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>B3885SFCQJ</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
EOF

echo "==> Step 3: export & upload to TestFlight"
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/upload \
  -exportOptionsPlist build/ios/upload/UploadOptions.plist \
  -allowProvisioningUpdates

echo "==> Done! Upload succeeded."
```

---

## 仅导出 IPA（不上传）

如果只需要导出 IPA 文件（例如通过 Transporter 手动上传）：

```bash
cat > build/ios/export/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>B3885SFCQJ</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/export \
  -exportOptionsPlist build/ios/export/ExportOptions.plist \
  -allowProvisioningUpdates
```

导出的 IPA 在 `build/ios/export/` 目录下。

---

## 关键参数说明

| 参数 | 说明 |
|------|------|
| `method: app-store-connect` | 直接上传到 App Store Connect（含 TestFlight） |
| `method: app-store` | 仅导出 IPA，不自动上传 |
| `destination: upload` | 配合 `app-store-connect` 使用，触发上传 |
| `teamID` | Apple Developer Team ID |
| `signingStyle: automatic` | 由 Xcode 自动管理签名 |

## 注意事项

- `method` 必须使用 `app-store-connect`（不是 `app-store`），这样才能直接上传而不仅是导出 IPA
- `destination` 设为 `upload` 表示直接上传到 App Store Connect
- 上传后通常需要等待 5-15 分钟，App Store Connect 处理完成后即可在 TestFlight 中看到新版本
- 此方式依赖 Xcode 已登录的 Apple ID session，无需单独配置 API Key
- 如果遇到签名问题，确认 Xcode > Settings > Accounts 中 Apple ID 状态正常
