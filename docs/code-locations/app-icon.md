# 代码定位 — 应用图标运行时切换

> 最后更新：2026-06-16

## 功能概述

设置页新增「应用图标」入口，进入后展示 25 个预打包候选图标（5×5 网格），用户点击即调用原生层 `setAlternateIconName` 切换桌面图标。**仅 iOS 完整支持**（`CFBundleAlternateIcons` 机制），Android 上 UI 显示「仅 iOS 可用」提示。

## 平台支持矩阵

| 平台 | 支持 | 机制 |
|---|---|---|
| iOS 14+ | ✅ 完整 | `UIApplication.setAlternateIconName` + 预打包 `CFBundleAlternateIcons` |
| Android | ❌ | 无运行时 API；UI 走 `MissingPluginException` 降级路径 |
| iPad | n/a | `TARGETED_DEVICE_FAMILY = 1` 已排除 iPad |

## 25 个预打包 alternate

| 槽位 | alternate 名 | 源文件 | iOS asset catalog 位置 |
|---|---|---|---|
| 1 | `AppIcon-1` | `assets/logos/logo_01.JPG` | `client/ios/Runner/Assets.xcassets/AppIcon-1.appiconset/Icon-1.png` |
| 2 | `AppIcon-2` | `assets/logos/logo_02.JPG` | `…/AppIcon-2.appiconset/Icon-2.png` |
| … | … | … | … |
| 25 | `AppIcon-25` | `assets/logos/logo_25.JPG` | `…/AppIcon-25.appiconset/Icon-25.png` |

主图标（primary `AppIcon`）固定为 `logo_01`（与 alternate 1 视觉一致）。

## Flutter 端

| 文件 | 角色 |
|---|---|
| `client/lib/services/app_icon_service.dart` | `MethodChannel("com.yt.threads/app_icon")` 封装，提供 `supportsAlternateIcons()` / `getAlternateIconName()` / `setAlternateIconName(String?)` 三个静态方法。捕获 `MissingPluginException` + `PlatformException` 走降级。 |
| `client/lib/state/app_icon_state.dart` | `ChangeNotifier`：当前选中 `id`（0=primary，1..25=alternate），持久化到 SharedPreferences（key `app_icon_selected_id`），构造时调用 `load()` 同步 SharedPreferences + 异步校正 iOS 端实际状态。 |
| `client/lib/pages/settings/app_icon_page.dart` | 5×5 GridView 选图页。`_IconTile` 显示缩略图（`Image.asset('assets/logos/logo_NN.JPG')`），选中态加 accent 边框 + 对勾标记。底部固定一行 `appIconChangeHint` 提示文案。 |
| `client/lib/main.dart:26-27, 97-101` | 注册 import + `ChangeNotifierProvider<AppIconState>(lazy: false)`，位置在 `MediaPreferences` 之后。 |
| `client/lib/common/settings.dart:19-20, 296-310` | 注册 import + 在「About」行后插入新 `_buildMenuRow`（icon: `CupertinoIcons.app_badge`，跳转 `AppIconPage`）。 |
| `client/lib/l10n/app_en.arb:656-658` | 3 个 key：`appIcon` / `appIconChangeHint` / `appIconNotSupportedAndroid` |
| `client/lib/l10n/app_zh.arb:656-658` | 中文版本 |
| `client/lib/l10n/generated/app_localizations*.dart` | `flutter gen-l10n` 自动重生成 |

## iOS 原生层

| 文件 | 改动 |
|---|---|
| `client/ios/Runner/Assets.xcassets/AppIcon-N.appiconset/` (× 25) | 25 个新目录，每个含 `Contents.json`（1024×1024 通用图标）+ `Icon-N.png`（从 `logo_NN.JPG` 用 `sips` 转 PNG）。 |
| `client/ios/Runner/Info.plist:19-110` | 新增 `CFBundleIcons` 字典（**仅**含 `CFBundleAlternateIcons`，25 个 entry；不写 `CFBundlePrimaryIcon`，避免与 `ASSETCATALOG_COMPILER_APPICON_NAME` 冲突；iPad 不需要 `CFBundleIcons~ipad`）。 |
| `client/ios/Runner.xcodeproj/project.pbxproj` | Runner 的 Debug / Release / Profile 三个 build config 字典里都加了 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "AppIcon-1 AppIcon-2 ... AppIcon-25";`（紧邻 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;` 之后）。**这一项是 actool 必填**：缺了它 `setAlternateIconName` 静默成功但图标不变。 |
| `client/ios/Runner/AppDelegate.swift` | 在 `application(_:didFinishLaunchingWithOptions:)` 注册 `FlutterMethodChannel("com.yt.threads/app_icon")`。Scene-aware 取 root view controller（先 `window?.rootViewController as? FlutterViewController`，再 fallback 到 `UIApplication.shared.connectedScenes`）。三个 method handler：`supportsAlternateIcons` / `getAlternateIconName` / `setAlternateIconName`。 |

## Android 端

**完全不动**。`MainActivity.kt` / `AndroidManifest.xml` 不修改。Flutter 端 `AppIconService` 通过 `try/catch MissingPluginException` 自动判为「不支持」，UI 显示 `appIconNotSupportedAndroid` 文案。

## 关键约束 / 限制

1. **iOS 切换有延迟**：iOS 不在 app 运行时立即应用新图标，必须等 app 切到后台由系统重绘。SpringBoard 会自动在 home screen 显示「轻点查看新图标」覆盖层。
2. **包体积影响**：25 × 1024×1024 PNG ≈ 8–15 MB（取决于 sips 输出）。iOS 不再二次压缩 PNG。
3. **App Store 审核**：`CFBundleAlternateIcons` 改变图标可能在 iOS 17+ 触发更严格的审核。图标必须是项目自有内容，**不**允许从相册上传任意图片。
4. **状态恢复**：app 重启时 `AppIconState` 读 SharedPreferences 后还会问原生层校正（用户在系统设置里手动改过也能感知到），保证 UI 与 OS 一致。
5. **必须重启 build 缓存**：升级 Xcode 或修改 Info.plist 后建议 `flutter clean` + `cd ios && pod install` 一次。
