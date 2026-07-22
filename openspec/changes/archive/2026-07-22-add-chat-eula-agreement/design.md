## Context

App 含「消息 / 聊天」功能（`client/lib/pages/message/`，17 个文件，单聊 + 群聊），年龄分级已勾选「消息和聊天」。为满足 App Store 对聊天类功能的合规审核，需在用户进入聊天 / 私信前要求同意「聊天使用协议」。

参考依据：`handoff-chat-eula-agreement.md`（源项目「拜老爷 iOS」SwiftUI 版的同功能 handoff，描述了「统一导航入口 + 拦截 + 暂存目标 + 同意后续跑」模式）。

**当前现状（探查已确认）：**

- 聊天 / 私信的**外部入口只有 1 个**：`client/lib/pages/feed/feed.dart:135-137`（Feed 顶部 `Iconsax.message` 图标）→ `Navigator.push(MessagePage())`。
- `MessagePage`（`client/lib/pages/message/message_page.dart`）是整个聊天子树的根：其下 `ChatDetailPage` / `MessageSearchPage` / 群聊相关页 / 建群加群页**均为子树内部 `Navigator.push`**，无外部直达。
- **无**「Profile 发私信」入口（grep 无命中）；`client/lib/services/deep_link_service.dart:81` 深链**仅跳 `ProfilePage`**，不进聊天；**无**推送直达聊天路径。
- 项目已依赖 `shared_preferences ^2.0.20`、`url_launcher ^6.1.10`；**未引入** `webview_flutter`。
- 已有隐私政策 URL `https://www.ttlocker.top/privacy`（`fastlane/metadata/*/privacy_url.txt`），但那是**隐私政策**，非聊天 EULA——协议 URL 仍待法务 / 产品提供。
- 现有引导流 `client/lib/auth/onboard/`（`privacy.dart` 是 Public/Private profile 选择，非协议同意）——参考用，不复用。

**约束：** 仅 iOS；不写 Android；同意状态默认仅本地存储。

## Goals / Non-Goals

**Goals:**

- 用户首次进入聊天 / 私信前必须同意「聊天使用协议」，不同意不进入、不落库。
- 同意后持久化，**下次不再弹**；协议改版可通过 bump 版本号强制重新同意。
- 覆盖当前全部聊天 / 私信入口（现实中只有 `MessagePage` 一扇门），且**为将来新增入口预留可复用的闸门**，避免漏拦。
- 中英文案、加载 / 失败兜底到位。

**Non-Goals:**

- 不做服务端同意记录 / 合规审计（除非后续明确要求，见 Open Questions）。
- 不做协议多语言切换（单一 URL）。
- 不做「仅发送消息时才拦」的细粒度变体（粒度定为「进入即拦」，见 D1）。
- 不照搬 handoff 的 `ChatNavigationCoordinator` 协调器模式（见 D2）。
- 不改 `fix-appstore-rejection` 的任何内容（两 change 独立）。

## Decisions

**D1. 拦截粒度 =「进入聊天即拦」，闸门点 = `MessagePage`。**
- 备选：(a) 只拦 `ChatDetailPage`（能看列表）；(c) 只拦「发送」动作（能看能读）。
- 选 `MessagePage` 的理由：本项目聊天 / 私信**只有 `MessagePage` 一个外部入口**，守它即守全部子树，实现最干净、漏拦风险最低；同时贴合 handoff §1「进入会话列表即拦」的字面要求。
- 不选 (c)：handoff §5.2 提到的「发送才拦」体验更轻，但产品未明确要求，且会让「未同意却能浏览他人消息」的合规语义模糊。若后续产品改主意，闸门逻辑可下沉到 `MessageState.sendMessage`（见 D3 的可演进性）。

**D2. 不采用 handoff 的「导航协调器」模式，改为「目标页自带闸门」。**
- handoff 的 `ChatNavigationCoordinator`（`Destination` 枚举 + `pendingDestination` + `executeNavigation` + 逐一改入口）是为解决「入口分散、易漏拦」而生。源项目入口有：群列表 / 建群 / 加群 / 搜索 / 进群 / 私信列表 / 单个私信 / 深链 / 推送……
- **本项目不存在该问题**——只有 `MessagePage` 一扇门。照搬协调器 = 增加维护面、引入新的漏点、违背 KISS。
- 改为：闸门逻辑内建于 `MessagePage.initState`，所有入口零改动。用一个轻量 `ChatEulaConsent` helper 封装「是否需同意 + 落库 + 版本判断」，将来新增入口（如 Profile 发私信、深链直达）只需复用同一 helper，天然收敛。

**D3. 闸门状态机（极简）：**
```
MessagePage.initState (addPostFrameCallback)
        │
        ▼
  ChatEulaConsent.needsAgreement?
        │                    │
       是                   否
        ▼                    ▼
  弹全屏 EULA            loadConversations()（正常）
  （暂不加载列表）
        │
   ┌────┴─────┐
  同意       不同意/关闭
   │           │
   ▼           ▼
 persist(agreed + version)   Navigator.pop（回 Feed）
 关闭弹窗                     不落库
 loadConversations()
```
- 演进点：若将来粒度改「发送才拦」，把 `needsAgreement` 检查从 `MessagePage` 移到 `MessageState.sendMessage` / `sendGroupChatMessage` 即可，`ChatEulaConsent` helper 不变。

**D4. 协议内容展示：原生渲染要点 + `url_launcher` 链接完整条款（最终方案，零新增依赖）。**
- 弹窗用 `showDialog` 原生渲染协议**要点摘要**（`Text`，可滚动）+「查看完整条款」链接，点击用已有 `url_launcher ^6.1.10` 打开 `kChatEulaUrl`。
- 选此方案的理由（**最小化**）：(i) **零新增依赖**（不加 `webview_flutter`）；(ii) **不被法务阻塞**——要点文案原生内置可立即上线，专属 EULA URL 到位后只改 `kChatEulaUrl` 一处常量；(iii) 同意动作始终在 App 内模态完成，链接仅为「可读全文」，不破坏「必须同意才能继续」。
- 否决 `webview_flutter`：新增依赖 + 远程加载需联网与失败兜底，对本需求过重。
- 否决「纯 `url_launcher` 展示协议」：会跳出 App，破坏同意模态。
- `kChatEulaUrl` 初版占位用现有隐私政策 URL `https://www.ttlocker.top/privacy`，待法务给专属 EULA URL 后替换（改一处常量，不阻塞上线）。

> **[修订 2026-07-22]** 协议内容改为**内置完整 EULA 全文**（以 `ref-eula.md` 6 大条款为准，适配 App 显示名「Tweet」，中英双语结构化 key），不再依赖外链。理由：(i) 文案须以法务提供的**完整 EULA**为准，原「4 条要点摘要」不足以覆盖合规要点；(ii) 全文内置后**彻底摆脱对「专属 EULA URL 待法务」的依赖**——离线可读、审核更稳、不再被法务排期阻塞；(iii) 移除 `kChatEulaUrl` 常量与 `url_launcher` 调用，「查看完整条款」入口一并移除。结构化拆 key（`chatEulaIntro` + `chatEulaLastUpdated` + `chatEulaSection{1..6}Title/Body`）便于按条款排版（小标题加粗、正文可滚动）。

**D5. 持久化用 `shared_preferences`，单 key 策略 + 版本号。**
- 字段：`chat_eula_agreed`（bool）+ `chat_eula_version`（String）。
- 常量：`kCurrentChatEulaVersion`（首版取 `'2026-07-21'`）。
- 判断：`needsAgreement = !agreed || agreedVersion != kCurrentChatEulaVersion`。
- 封装成 `client/lib/common/chat_eula_consent.dart`（纯静态 helper，读 prefs 异步；无需 Provider——两个布尔值不值得单例）。
- 不复用 `auth/onboard/privacy.dart`（那是 profile 可见性选择，语义不同）。

**D6. 弹窗交互细节（对齐 handoff §6 易错点）：**
- 「不同意」/ 关闭：**绝不**写 `agreed = true`，否则下次不弹（handoff 明确警告）。
- 「同意并继续」：先 persist 再关闭弹窗，再 `loadConversations()`；无需「延迟 0.3s 续跑目标」（handoff 的延迟是为 SwiftUI sheet 关闭动画与 present 冲突；Flutter 里 `setState` 切换本地 `_agreed` 即可重渲染，无此问题）。
- 弹窗为**全屏**（非半屏 sheet），协议内容可滚动，底部固定双按钮，避免误触关闭。

> **[修订 2026-07-22]** 弹窗形态从**全屏 `AlertDialog`（`showDialog`）改为底部 sheet（`showModalBottomSheet`）**。理由：底部 sheet 是本项目成熟模式（`showModalBottomSheet` 在 message / feed / compose 等模块多处在用），更贴合 iOS 交互习惯，也与「新消息」等同模块 sheet 视觉一致。关闭语义采用**策略 X（锁死）**：`isDismissible: false` + `enableDrag: false`，用户**只能**点「同意并继续」或「不同意」二选一，禁止下拉与点遮罩关闭——原 D6「避免误触关闭」的目标，在 sheet 形态下改由「禁用手势」达成，避免「手滑关闭」与「必须同意否则退出」之间的语义歧义。「不同意」/ 关闭仍 `Navigator.pop` 回 Feed 且不落库（不变）；「同意并继续」仍先 `markAgreed` 再 `loadConversations()`。

## Risks / Trade-offs

- **[协议 URL 未定]** → 不阻塞：`kChatEulaUrl` 初版用现有隐私政策 URL 占位，要点文案原生内置可立即验收；专属 EULA URL 到位后改一处常量。
- **[将来新增入口漏拦]** → `ChatEulaConsent` helper 可复用；spec「覆盖所有入口」约束将来新增聊天入口必须过闸门。当前无深链 / 推送直达聊天，无即时风险。
- **[版本号忘记 bump]** → 协议改版但忘了改 `kCurrentChatEulaVersion` → 老用户不会被强制重新同意。文档约束 + code review 把关。

## Migration Plan

- 客户端无数据迁移；老用户首次升级后进入 `MessagePage` 会弹一次协议（符合预期）。
- 上线顺序：法务提供协议 URL / 文案 → 客户端实现 → 真机验收（首次弹 / 同意后免弹 / 不同意回 Feed / 改版本号强制重弹）→ 可与 `fix-appstore-rejection` 同批或分批提审。
- 回滚：回退客户端构建即可（本地 prefs 的 `agreed` 残留无副作用——回滚后不再弹，与「已同意」语义一致）。

## Open Questions

- ~~协议 URL + 内容形态~~ → **已定（D4）**：原生要点 + `url_launcher` 链接，零新增依赖。专属 EULA URL 待法务提供后替换 `kChatEulaUrl` 常量（不阻塞上线）。
- **群聊与私信是否共用一份协议**？—— 假设共用（单一 URL）；若需区分，给弹窗加 `url` 参数即可。
- **是否需要服务端记录同意状态**（合规审计）？—— 默认仅本地（与 handoff 一致）；若合规要求，再加 `POST` 上报。
- **拦截粒度是否改为「发送才拦」**？—— 默认「进入即拦」（D1）；待产品确认。
- **本次 EULA 是苹果新一轮驳回要求，还是主动加固**？—— 影响是否与 `fix-appstore-rejection` 同批提审；本 change 按「独立交付」设计，两种情况都兼容。
