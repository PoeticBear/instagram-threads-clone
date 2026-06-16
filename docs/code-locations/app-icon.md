# 代码定位 — 应用图标运行时切换

> 最后更新：2026-06-16（设置页内嵌水平选择条迁移）

## 功能概述

设置页（`SettingsPage`）顶部内嵌水平滑动的应用图标选择条，展示 25 个预打包候选图标，用户点击任一缩略图即调用原生层 `setAlternateIconName` 切换桌面图标。**仅 iOS 完整支持**（`CFBundleAlternateIcons` 机制）。

> 自 2026-06-16 起，原独立的 `AppIconPage` 已被删除，相关逻辑迁移至设置页内的水平条。详细设计见 [`docs/code-locations/settings-page.md`](settings-page.md) §1.4 / §1.5。

## 平台支持矩阵

| 平台 | 支持 | 机制 |
|---|---|---|
| iOS 14+ | ✅ 完整 | `UIApplication.setAlternateIconName` + 预打包 `CFBundleAlternateIcons` |
| Android | ❌ | 不在目标平台（见 `CLAUDE.md`）；保留 `platformSupported` 防御性分支，UI 显示「仅 iOS 可用」提示 |

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
| `client/lib/widget/app_icon_tile.dart` | 公开 widget `AppIconTile`：56×56 缩略图（`Image.asset('assets/logos/logo_NN.JPG')`），选中态加 accent 边框 + 18×18 对勾标记，外包 `Semantics` 支持 VoiceOver。设置页水平条 `itemBuilder` 使用。 |
| `client/lib/common/settings.dart:79-163` | 设置页顶部内嵌的 `Consumer<AppIconState>` 区块：区块标题「应用图标」+ 水平 `ListView.separated`（25 个 `AppIconTile`）+ `appIconChangeHint` + 仅 `selectedId == 0` 时显示的 `appIconPrimaryHint`。点击直接调 `AppIconState.setIcon(id)`，无导航。 |
| `client/lib/main.dart:28, 104-107` | 注册 import + `ChangeNotifierProvider<AppIconState>(lazy: false)`。 |
| `client/lib/l10n/app_en.arb:672-675` | 4 个 key：`appIcon` / `appIconChangeHint` / `appIconNotSupportedAndroid` / `appIconPrimaryHint` |
| `client/lib/l10n/app_zh.arb:672-675` | 中文版本 |
| `client/lib/l10n/generated/app_localizations*.dart` | `flutter gen-l10n` 自动重生成 |

## iOS 原生层

| 文件 | 改动 |
|---|---|
| `client/ios/Runner/Assets.xcassets/AppIcon-N.appiconset/` (× 25) | 25 个新目录，每个含 `Contents.json`（1024×1024 通用图标）+ `Icon-N.png`（从 `logo_NN.JPG` 用 `sips` 转 PNG）。 |
| `client/ios/Runner/Info.plist:19-110` | 新增 `CFBundleIcons` 字典（**仅**含 `CFBundleAlternateIcons`，25 个 entry；不写 `CFBundlePrimaryIcon`，避免与 `ASSETCATALOG_COMPILER_APPICON_NAME` 冲突；iPad 不需要 `CFBundleIcons~ipad`）。 |
| `client/ios/Runner.xcodeproj/project.pbxproj` | Runner 的 Debug / Release / Profile 三个 build config 字典里都加了 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "AppIcon-1 AppIcon-2 ... AppIcon-25";`（紧邻 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;` 之后）。**这一项是 actool 必填**：缺了它 `setAlternateIconName` 静默成功但图标不变。 |
| `client/ios/Runner/AppDelegate.swift` | 在 `application(_:didFinishLaunchingWithOptions:)` 注册 `FlutterMethodChannel("com.yt.threads/app_icon")`。Scene-aware 取 root view controller（先 `window?.rootViewController as? FlutterViewController`，再 fallback 到 `UIApplication.shared.connectedScenes`）。三个 method handler：`supportsAlternateIcons` / `getAlternateIconName` / `setAlternateIconName`。 |

## 关键约束 / 限制

1. **iOS 切换有延迟**：iOS 不在 app 运行时立即应用新图标，必须等 app 切到后台由系统重绘。SpringBoard 会自动在 home screen 显示「轻点查看新图标」覆盖层。
2. **包体积影响**：25 × 1024×1024 PNG ≈ 8–15 MB（取决于 sips 输出）。iOS 不再二次压缩 PNG。
3. **App Store 审核**：`CFBundleAlternateIcons` 改变图标可能在 iOS 17+ 触发更严格的审核。图标必须是项目自有内容，**不**允许从相册上传任意图片。
4. **状态恢复**：app 重启时 `AppIconState` 读 SharedPreferences 后还会问原生层校正（用户在系统设置里手动改过也能感知到），保证 UI 与 OS 一致。
5. **必须重启 build 缓存**：升级 Xcode 或修改 Info.plist 后建议 `flutter clean` + `cd ios && pod install` 一次。
6. **Primary 图标发现性**：当 `selectedId == 0`（使用 primary 默认图标），设置页水平条无任何 tile 高亮，需通过 `appIconPrimaryHint` 文本提示用户当前状态。
