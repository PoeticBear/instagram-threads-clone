# Implementation Tasks — add-chat-eula-agreement

> 实现顺序按依赖排列。①持久化层 → ②弹窗 UI → ③闸门接线 → ④文案，串行为主。
> 最小化方案：原生渲染协议要点 + `url_launcher` 链接完整条款，**零新增依赖**、**不被法务阻塞**（`kChatEulaUrl` 先用隐私政策 URL 占位）。
>
> **进度：V1 §1–§5.1 客户端代码完成；V2 §6.1–6.5 迭代完成（2026-07-22：全文 EULA + 底部 sheet）。`flutter analyze` 改动文件零问题。**
> 未完成项均为**非代码**：V1 设备回归(5.2)、真机录屏(5.4)；V2 设备回归(6.6)。5.3（法务 URL）因全文内置已不再适用。

## 1. 持久化层（co-located 于 `chat_eula_dialog.dart`）

- [x] 1.1 在 `chat_eula_dialog.dart` 内置 `ChatEulaConsent` 静态 helper：常量 `kCurrentChatEulaVersion = '2026-07-21'`、`kChatEulaUrl = 'https://www.ttlocker.top/privacy'`（占位）、prefs key `chat_eula_agreed`(bool) / `chat_eula_version`(String)
- [x] 1.2 提供 `bool get needsAgreement`（`!agreed || agreedVersion != kCurrentChatEulaVersion`）、`void markAgreed()`（写 `agreed=true` + 当前版本）；prefs 经 GetIt 同步取（`getIt<SharedPreferences>()`），无需 Future
- [x] 1.3 确认 `shared_preferences ^2.0.20`、`url_launcher ^6.1.10` 均已在 `pubspec.yaml`（**零新增依赖**）

## 2. 协议弹窗 UI（`client/lib/pages/message/chat_eula_dialog.dart`）

- [x] 2.1 新建 `ChatEulaDialog`（`showDialog<bool>`）：标题「聊天使用协议」→ `SingleChildScrollView` 原生协议要点（`Text`，`chatEulaBody`）+「查看完整条款」链接（`url_launcher` 打开 `kChatEulaUrl`）→ 底部「不同意」/「同意并继续」双按钮
- [x] 2.2 对外接口：用 `showDialog<bool>` 返回值（true=同意 / false·null=不同意）替代双回调闭包，更贴合 Flutter 习惯、避免嵌套 pop 顺序问题（D2 已记录该偏离 handoff 契约）

## 3. `MessagePage` 闸门接线

- [x] 3.1 `message_page.dart` 的 `initState` `addPostFrameCallback` 改为先调 `_maybeShowEulaThenLoad()`：`ChatEulaConsent.needsAgreement` 为真则弹 `ChatEulaDialog`（`barrierDismissible: false`），暂不 `loadConversations()`
- [x] 3.2 同意（`agreed == true`）→ `ChatEulaConsent.markAgreed()` + `loadConversations()`
- [x] 3.3 不同意 / 关闭（`!agreed`）→ `Navigator.of(context).pop()` 退回 Feed，MUST NOT 调 `markAgreed`、MUST NOT 加载会话列表；`mounted` 守卫已加

## 4. 国际化文案

- [x] 4.1 在 `app_en.arb` / `app_zh.arb` 新增 key：`chatEulaTitle`、`chatEulaBody`（含换行的协议要点）、`chatEulaViewFullTerms`、`chatEulaAgree`、`chatEulaDisagree`
- [x] 4.2 补齐中文 + 英文译文；`flutter gen-l10n` 重新生成（5 key 双语均已落地）；弹窗内无硬编码字符串

## 5. 验证 & 提审前置

- [x] 5.1 `flutter analyze` 改动文件（`chat_eula_dialog.dart` / `message_page.dart` / `l10n/`）零问题
- [ ] 5.2 iOS 真机回归：① 未同意进入被拦 / ② 同意后进列表且再进不弹 / ③ 不同意回 Feed 且下次仍弹 / ④ 改 `kCurrentChatEulaVersion` 后老同意失效强制重弹 / ⑤「查看完整条款」链接可打开（待人工）
- [x] 5.3 ~~专属 EULA URL 到位后替换 `kChatEulaUrl` 常量~~ → **不再适用**：V2 改为协议全文内置（见 §6.3），已移除 `kChatEulaUrl` 与外链依赖
- [ ] 5.4 **[提审前置]** 真机录屏：进入聊天 → 弹协议 → 同意 → 进入会话列表全流程，交付提审同事附入 App Store Connect 审核备注（待人工）

## 6. V2 迭代（2026-07-22）— 全文 EULA + 底部 sheet

> 需求：① 文案以 `ref-eula.md` 完整 EULA 为准（适配 Tweet、中英双语）；② 弹窗改底部 sheet；③ 必须同意否则退出页面（保持）。详见 design.md D4 / D6 修订。

- [x] 6.1 文案：以 `ref-eula.md` 6 大条款为准，适配 App 显示名「Tweet」，结构化拆 key（`chatEulaIntro` + `chatEulaLastUpdated` + `chatEulaSection{1..6}Title/Body` + `chatEulaTitle/Agree/Disagree`），中英双语写入 `app_en.arb` / `app_zh.arb`；移除旧 `chatEulaBody`（4 条摘要）与 `chatEulaViewFullTerms`（外链入口）
- [x] 6.2 `flutter gen-l10n` 重新生成（17 个 `chatEula*` key 双语落地）
- [x] 6.3 `chat_eula_dialog.dart`：`ChatEulaDialog` 从 `AlertDialog` 重写为**底部 sheet widget**（顶部标题 + 更新日期 / 滚动条款全文 / 底部「同意并继续」主按钮 + 「不同意」次按钮）；移除 `url_launcher` 外链逻辑与 `kChatEulaUrl` 常量（全文内置不再需要）
- [x] 6.4 `message_page.dart`：`showDialog` → `showModalBottomSheet`（`isScrollControlled: true` + `isDismissible: false` + `enableDrag: false`，策略 X：只能点按钮）；拦截逻辑（不同意退回 Feed / 不落库）不变
- [x] 6.5 `flutter analyze` 改动文件（`chat_eula_dialog.dart` / `message_page.dart` / `l10n/`）零问题
- [ ] 6.6 iOS 真机回归：① 未同意弹底部 sheet（不可下拉 / 点遮罩关闭）② 同意后进列表且再进不弹 ③ 不同意回 Feed 且下次仍弹 ④ 改 `kCurrentChatEulaVersion` 后强制重弹 ⑤ 中英文案随系统语言切换正确（待人工）
