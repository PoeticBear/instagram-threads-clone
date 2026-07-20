# 截屏 Bug 反馈（Bug Feedback）— 代码定位

> 本文档汇总 iOS 客户端「内部测试：截屏 → Bug 反馈」功能涉及的所有源代码位置：UI、服务层、模型、原生桥接、入口集成、隔离机制。
> 后续若收到「定位 Bug 反馈 / 截屏上报」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep`。
>
> **当前状态**：截屏 → 表单 → 提交链路已打通；上报端为 **stub（写本地沙盒 + log）**，云端接入方式待定 —— 见 [§7 云端接入点](#7-云端接入点待实现)。

---

## 0. 模块概览（数据流）

```
用户按 [电源 + 音量上] 截屏
        │  iOS 系统通知
        ▼
AppDelegate.userDidTakeScreenshotNotification
        │  MethodChannel「com.yt.threads/screenshot」(native → flutter)
        ▼
ScreenshotDetectorService._handleScreenshot
   ├─ 防抖：表单已开 / 5s 窗口内 → 忽略
   └─ 记 lastTriggeredAt → 回调 onScreenshot
        ▼
main.dart _showBugFeedbackSheet
   ├─ markSheetShowing(true)
   └─ BugFeedbackSheet.show(ctx, triggerTime)
        ▼
BugFeedbackSheet
   ├─ 打开时轮询相册，取 createDateTime ≥ triggerTime 的图（本次截屏）
   ├─ 用户填描述
   └─ 提交 → BugReportService.submit
                 ├─ _collectMeta（版本/机型/系统）
                 ├─ 组装 BugReport
                 └─ _writeStub  ← 【云端接入点】当前写本地沙盒 + log
```

**隔离**：整条链路仅在 Debug / TestFlight 构建生效，App Store 正式包物理剔除 —— 见 [§6](#6-隔离机制debug--testflight--app-store)。

---

## 1. UI 层

### 1.1 `BugFeedbackSheet`（反馈表单）

- **路径**：`client/lib/pages/bug_feedback/bug_feedback_sheet.dart`
- **核心组件**：
  - `class BugFeedbackSheet extends StatefulWidget`（`bug_feedback_sheet.dart:18`）
  - `_BugFeedbackSheetState`
- **关键能力模块**：

| 模块 | 方法 / 字段 | 行号 |
| --- | --- | --- |
| 构造 + 触发时刻 | `triggerTime`（本次截屏时刻，用于相册判定） | `bug_feedback_sheet.dart:24` |
| 弹出入口 | `static Future<void> show(BuildContext, {DateTime? triggerTime})` | `bug_feedback_sheet.dart:27` |
| 状态字段 | `_loadingShot` / `_shotFailed` / `_screenshotPath` / `_submitting` / `_toast` | `bug_feedback_sheet.dart:37-41` |
| 打开即取图 | `_loadLatestScreenshot` | `bug_feedback_sheet.dart:67` |
| 轮询取「本次」截图 | `_waitForFreshScreenshot`（threshold = triggerTime − 3s，最多等 4s） | `bug_feedback_sheet.dart:92` |
| 取相册最新一张 | `_getLatestImageAsset`（photo_manager） | `bug_feedback_sheet.dart:119` |
| 提交 | `_submit`（校验非空 → 取 userId → 调 `BugReportService.submit`） | `bug_feedback_sheet.dart:129` |
| Build | `build`（drag handle / 标题 / 截图预览 320·contain / 描述框 / 提交按钮） | `bug_feedback_sheet.dart:163` |

> **取图时机**：iOS 截屏通知早于截图写入相册，故表单一打开立即取会拿到旧图。修复方式是把触发时刻透传进来，轮询直到相册最新一张 `createDateTime ≥ 触发时刻`。

---

## 2. 服务层

### 2.1 `ScreenshotDetectorService`（截屏事件分发）

- **路径**：`client/lib/services/screenshot_detector_service.dart`
- **职责**：接收原生截屏事件 → 防抖 → 触发回调。单例。

| 成员 | 行号 | 说明 |
| --- | --- | --- |
| `instance` | `screenshot_detector_service.dart:15` | 单例 |
| `onScreenshot` | `:22` | 回调（main.dart 挂为弹表单） |
| `lastTriggeredAt` | `:33` | 最近触发时刻，透传给表单做相册判定 |
| `_debounceWindow = 5s` | `:36` | 连截防抖窗口 |
| `start()` | `:39` | 注册 `setMethodCallHandler` |
| `_handleScreenshot()` | `:48` | 防抖逻辑（表单开着 / 5s 内 → 忽略） |
| `markSheetShowing(bool)` | `:60` | 表单开 / 关时标记，抑制重复弹窗 |

### 2.2 `BugReportService`（上报，**当前 stub**）

- **路径**：`client/lib/services/bug_report_service.dart`
- **职责**：组装工单 → 上报。单例。

| 成员 | 行号 | 说明 |
| --- | --- | --- |
| `instance` | `bug_report_service.dart:18` | 单例 |
| `submit({description, screenshotPath, userId, currentRoute})` | `:29` | 入口，返回 `Future<bool>` |
| `_collectMeta()` | `:57` | 采集 app 版本 / 构建号 / 机型 / 系统版本 |
| `_writeStub(report)` | `:86` | ⭐ **云端接入点** —— 当前写本地沙盒 + log |

### 2.3 `FeedbackGate`（隔离判定）

- **路径**：`client/lib/services/feedback_gate.dart`
- **职责**：双保险判定当前构建是否启用反馈功能。

| 成员 | 行号 | 说明 |
| --- | --- | --- |
| `const feedbackCompileEnabled` | `feedback_gate.dart:11` | 编译期总开关（`bool.fromEnvironment('FEEDBACK_ENABLED')`） |
| `instance` | `:21` | 单例 |
| `preload()` | `:30` | 异步预取 sandboxReceipt 状态 |
| `isReady()` | `:45` | Debug 短路；Release 要求 flag + receipt |

---

## 3. 数据模型

### 3.1 `BugReport`

- **路径**：`client/lib/model/bug_report.dart`
- **核心**：`class BugReport`（`bug_report.dart:8`）
- **字段**：`description` / `screenshotPath` / `appVersion` / `buildNumber` / `deviceModel` / `osVersion` / `currentRoute` / `userId` / `createdAt`
- **序列化**：`toJson()`（`bug_report.dart:35`）—— stub 落盘 JSON 直接用此结构

---

## 4. 原生桥接（iOS / AppDelegate）

均在 `client/ios/Runner/AppDelegate.swift` 的 `application(_:didFinishLaunchingWithOptions:)` 内，与既有 `app_icon` / `network_permission` channel 并列。

### 4.1 `ScreenshotChannel`（截屏事件）

- **channel**：`com.yt.threads/screenshot`
- **位置**：`AppDelegate.swift:88-107`
- **方向**：**native → flutter**（与另两条 channel 反向）
- **实现**：`NotificationCenter` 观察 `UIApplication.userDidTakeScreenshotNotification` → `channel.invokeMethod("onScreenshotTaken")`

### 4.2 `BuildConfigChannel`（构建渠道判定）

- **channel**：`com.yt.threads/build_config`
- **位置**：`AppDelegate.swift:109-130`
- **方法**：`isTestFlightBuild` → 读 `Bundle.main.appStoreReceiptURL.lastPathComponent == "sandboxReceipt"`

---

## 5. 入口集成（main.dart）

- **路径**：`client/lib/main.dart`
- **挂载点**：`_MyAppState.initState`

| 内容 | 行号 | 说明 |
| --- | --- | --- |
| gate（tree-shake 关键） | `main.dart:117` | `if (kDebugMode \|\| feedbackCompileEnabled) { _wireupBugFeedback(); }` |
| `_wireupBugFeedback()` | `:229` | 异步 `FeedbackGate.isReady()` 通过 → 挂 detector |
| `_showBugFeedbackSheet()` | `:236` | `markSheetShowing(true)` → `BugFeedbackSheet.show(ctx, triggerTime)` → 完成时复位 |

---

## 6. 隔离机制（Debug / TestFlight / App Store）

| 构建 | 行为 | 判定路径 |
| --- | --- | --- |
| Debug（`flutter run`） | ✅ 启用 | `kDebugMode` 短路 |
| TestFlight | ✅ 启用 | `FEEDBACK_ENABLED=true` + `sandboxReceipt` |
| App Store 正式包 | ❌ 物理不存在 | `FEEDBACK_ENABLED` 默认 false → main.dart if 块被 AOT tree-shake → 反馈模块整组无引用一并剔除 |

**发版脚本配置**：
- `client/scripts/release.sh`（TestFlight）：`flutter build ipa --release --dart-define=FEEDBACK_ENABLED=true`
- `client/scripts/appstore-release.sh`（App Store）：不带 define（默认 false）

> 第二道保险 `sandboxReceipt` 的意义：防止 appstore-release.sh 误带 define 时线上包误触发。

---

## 7. 云端接入（GitHub private repo）✅

已接入专用 GitHub private repo `PoeticBear/app-bug-reports`（private）。

**投递路径**：`BugReportService.submit` → `_deliver`
- token 已配置（`GitHubBugClient.isConfigured`）→ `_deliverToGitHub`：
  ① `GitHubBugClient.uploadScreenshot` —— Contents API 推 base64 → 返回 raw URL
  ② `GitHubBugClient.createIssue` —— 建 Issue，body 用 markdown 引用 raw URL，label `from-app`
- 未配置 / 投递失败 → `_writeStub`（本地沙盒 + log）兜底

| 文件 | 职责 |
| --- | --- |
| `client/lib/services/github_bug_client.dart` | GitHub API 封装（推图 + 建 Issue），token / repo 走 dart-define |
| `client/lib/services/bug_report_service.dart` | `_deliver` 分流（GitHub 主 / stub 兜底） |

**token 注入**：fine-grained PAT（仅本 repo 的 Contents + Issues 读写），`--dart-define=BUG_GITHUB_TOKEN` 从环境变量读（**不进 git**），由 `release.sh` 在 TestFlight 发版时注入；App Store 包不注入（`FEEDBACK_ENABLED=false`，模块被 tree-shake）。

**调用方零改动**：`BugFeedbackSheet._submit` 与 `BugReport` 契约不变，`submit()` 返回 `Future<bool>`。

---

## 8. 相关依赖（pubspec.yaml）

| 依赖 | 用途 |
| --- | --- |
| `photo_manager: ^3.0.0` | 取相册最新一张截图 |
| `device_info_plus: ^9.1.2` | 采集机型（`utsname.machine`）/ 系统版本 |
| `package_info_plus: ^9.0.1` | 采集 app 版本 / 构建号 |
| `path_provider`（既有）| stub 落盘目录 |

---

## 9. 国际化 key（`app_en.arb` / `app_zh.arb`）

`bugReportTitle` / `bugReportScreenshot` / `bugReportScreenshotLoading` / `bugReportScreenshotFailed` / `bugReportDescriptionHint` / `bugReportDescriptionRequired` / `bugReportSubmit` / `bugReportSubmitting` / `bugReportSubmitted` / `bugReportSubmitFailed` / `bugReportDismiss`

生成文件：`client/lib/l10n/generated/app_localizations*.dart`（`flutter gen-l10n`）。
