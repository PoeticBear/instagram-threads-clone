## Why

App 含「消息 / 聊天」功能（年龄分级已勾选「消息和聊天」），为满足 App Store 对聊天类功能的合规审核要求，需在用户进入聊天 / 私信前，强制展示并要求同意「聊天使用协议（EULA / Terms）」。当前 App **无任何进入聊天前的协议同意步骤**——`MessagePage`（会话列表）被 Feed 顶部消息图标直接 push，未做任何拦截。

本 change 与 `fix-appstore-rejection`（处理 Apple 登录按钮 + 删除账号 + 年龄分级）**相互独立**：删除账号那批可先单独过审发版，本 change 作为聊天合规的补充，独立交付、独立提审，互不阻塞。

## What Changes

- **① 新增「最终用户许可协议」同意弹窗（底部 sheet）**
  - 用户首次进入 `MessagePage`（会话列表）前，弹出底部 sheet 展示**完整 EULA 全文**（以 `ref-eula.md` 6 大条款为准，适配 App 显示名「Tweet」，中英双语内置渲染，无需外链）。
  - 必须点击「同意并继续」才能进入；点「不同意」则 `Navigator.pop` 回 Feed，**不落库**（下次仍弹）；sheet 禁用下拉与点遮罩关闭，用户只能二选一。

- **② `MessagePage` 自带协议闸门（拦截点）**
  - 在 `MessagePage.initState` 检查是否需同意；需同意则弹窗、**暂不加载**会话列表，同意后再 `loadConversations()`。
  - 选 `MessagePage` 作为闸门是因为本项目聊天 / 私信**只有这一个外部入口**（Feed → `MessagePage`），守住这扇门即守住整个子树（`ChatDetailPage` / 群聊 / 搜索均为子树内部跳转）。详见 `design.md` D2。
  - **不采用** handoff 文档的「统一导航协调器（`ChatNavigationCoordinator`）」模式——该模式为「入口分散、易漏拦」而生，本项目不存在该问题，照搬属过度设计。

- **③ 同意状态持久化（`shared_preferences`）+ 协议版本控制**
  - 落库 `chat_eula_agreed`（bool）+ `chat_eula_version`（String）。
  - 协议改版时 bump `kCurrentChatEulaVersion` 常量，老用户会被强制重新同意（handoff §7 增强，成本几乎为零，本次一并补齐）。

- **④ 国际化文案**
  - 新增「聊天使用协议」标题、「同意并继续」、「不同意」、加载 / 加载失败提示等 key，中英双语。

## Capabilities

### New Capabilities

- `chat-eula-agreement`: 用户进入聊天 / 私信前的「聊天使用协议」拦截——`MessagePage` 闸门、协议弹窗、同意状态持久化与版本控制、不同意不落库。

### Modified Capabilities

（无——本仓库尚未定义该能力。）

## Impact

- **代码改动**：
  - `client/lib/pages/message/message_page.dart`（`initState` 增加闸门检查；同意后再 `loadConversations()`）
  - 新增 `client/lib/pages/message/chat_eula_dialog.dart`（协议弹窗 UI + 同文件内置 `ChatEulaConsent` 静态 helper：标题 + 原生要点 + 完整条款链接 + 双按钮）
  - 国际化文案源（新增 key，中英双语，`flutter gen-l10n`）
- **依赖**：**零新增**——原生渲染协议要点 + 复用已有 `url_launcher ^6.1.10`（声明于 `pubspec.yaml:48`，当前休眠未用）打开完整条款链接；`shared_preferences` 已有。
- **API**：无新增接口。同意状态**仅本地存储**（与 handoff 源项目一致）；如合规后续要求服务端审计，再扩展（Open Question）。
- **平台**：仅 iOS（项目策略，不写 Android 适配）。
- **风险**：
  - 完整条款链接 `kChatEulaUrl` 初版用现有隐私政策 URL 占位，专属 EULA URL 待法务提供后替换（改一处常量，**不阻塞上线**）。
  - 拦截收敛：本项目当前聊天仅 `MessagePage` 一个外部入口，但**将来若新增**「Profile 发私信」、深链 / 推送直达聊天等入口，必须同样过闸门（见 spec「覆盖所有入口」）。
- **非目标**：不做服务端同意记录、不做协议的多语言版本切换（URL 单一）、不做「仅发送时才拦」的细粒度（粒度定为「进入即拦」，见 D1）。
