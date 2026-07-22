## ADDED Requirements

### Requirement: 进入聊天/私信前的协议拦截

App SHALL 在用户进入聊天 / 私信根页面（`MessagePage`）前检查是否需要同意「聊天使用协议」；若需要，SHALL 在加载会话列表前弹出协议弹窗，阻止用户在未同意时看到会话内容。

#### Scenario: 未同意时进入会话列表被拦截

- **WHEN** 用户点击 Feed 顶部消息图标，`MessagePage` 即将展示
- **AND** 用户尚未同意当前版本的聊天使用协议
- **THEN** 弹出「聊天使用协议」弹窗，且会话列表**不加载**、不可见

#### Scenario: 已同意时直接进入

- **WHEN** 用户已同意当前版本的聊天使用协议
- **THEN** `MessagePage` 直接加载并展示会话列表，不弹窗

### Requirement: 协议弹窗内容展示

协议弹窗 SHALL 以**底部 sheet** 形态展示完整「最终用户许可协议」全文（接受条款、用户生成内容、内容监管与执行、隐私保护、责任限制、协议变更六大部分），顶部为协议标题与最后更新日期，协议全文可滚动；底部为「不同意」与「同意并继续」两个按钮，按钮固定可见。协议全文 SHALL 通过 `AppLocalizations` 国际化（中英双语），MUST NOT 硬编码。

#### Scenario: 弹窗展示完整协议全文

- **WHEN** 协议弹窗显示
- **THEN** 用户可滚动查看完整协议六大部分，底部「不同意」「同意并继续」按钮始终可见

### Requirement: 同意并继续

用户点击「同意并继续」SHALL 持久化同意状态与协议版本、关闭弹窗，并继续加载用户原本要进入的会话列表。

#### Scenario: 同意后进入会话列表

- **WHEN** 用户在协议弹窗点击「同意并继续」
- **THEN** 关闭弹窗、本地持久化「已同意 + 当前协议版本」、加载并展示会话列表

### Requirement: 不同意不落库

用户点击「不同意」或关闭弹窗 SHALL 返回上一页（Feed），且 MUST NOT 持久化同意状态，使下次进入仍会弹窗。

#### Scenario: 不同意返回且不记录

- **WHEN** 用户点击「不同意」或关闭协议弹窗
- **THEN** 弹窗关闭、`Navigator` 返回 Feed，会话列表不加载
- **AND** 同意状态保持「未同意」，下次进入 `MessagePage` 仍弹出协议

### Requirement: 弹窗不可手势绕过

协议弹窗（底部 sheet）SHALL 禁用下拉拖拽与点击遮罩关闭（`enableDrag: false` + `isDismissible: false`），使用户只能通过「同意并继续」或「不同意」按钮退出弹窗，避免误操作或手势绕过协议确认。

#### Scenario: 下拉与点遮罩无法关闭

- **WHEN** 用户在协议 sheet 上下拉或点击 sheet 外遮罩
- **THEN** sheet 不关闭，用户必须点击「同意并继续」或「不同意」按钮

### Requirement: 同意状态持久化与免重复弹窗

App SHALL 将同意状态持久化到本地存储（`shared_preferences`），已同意的用户再次进入 `MessagePage` 时 SHALL NOT 再次弹窗。

#### Scenario: 已同意用户重复进入不弹窗

- **WHEN** 用户曾点击「同意并继续」并持久化后，再次进入 `MessagePage`
- **THEN** 不弹出协议弹窗，直接加载会话列表

### Requirement: 协议版本控制

App SHALL 记录用户同意时的协议版本；当 App 内置的当前协议版本（`kCurrentChatEulaVersion`）与用户已同意版本不一致时，SHALL 视为「需重新同意」并再次弹窗。

#### Scenario: 协议改版后强制重新同意

- **WHEN** App 升级且 `kCurrentChatEulaVersion` 变更为新版本
- **AND** 用户本地记录的同意版本与当前版本不一致
- **THEN** 用户进入 `MessagePage` 时再次弹出协议弹窗，须重新同意才能进入

#### Scenario: 同意后记录当前版本

- **WHEN** 用户点击「同意并继续」
- **THEN** 本地持久化的协议版本被更新为 `kCurrentChatEulaVersion`

### Requirement: 覆盖所有聊天/私信入口

App SHALL 确保所有进入聊天 / 私信的入口在未同意协议时都被拦截。当前已知入口为 `MessagePage`（经 Feed 顶部消息图标进入）；将来新增的入口（如从用户主页发私信、深链 / 推送直达聊天）SHALL 复用同一协议闸门，MUST NOT 存在绕过闸门直达聊天的路径。

#### Scenario: 当前唯一入口被闸门保护

- **WHEN** 用户经 Feed 顶部消息图标进入聊天
- **AND** 未同意协议
- **THEN** 被闸门拦截并弹出协议弹窗

#### Scenario: 未来新增入口同样受保护

- **WHEN** 将来新增任何直达聊天 / 私信的入口（发私信按钮、深链、推送等）
- **THEN** 该入口 MUST 经同一协议闸门，未同意时不进入聊天内容

### Requirement: 协议全文离线内置

协议全文 SHALL 内置于 App（经 `AppLocalizations` 国际化文案），用户无需联网或跳转外部链接即可在弹窗内阅读完整协议；MUST NOT 依赖外部 URL 才能展示协议正文。

#### Scenario: 离线可读完整协议

- **WHEN** 协议弹窗显示（无论网络状态）
- **THEN** 用户可在弹窗内阅读完整协议全文，无需跳转外部页面

### Requirement: 国际化文案

协议弹窗的所有可见文案（标题、按钮、加载 / 失败提示等）SHALL 通过 `AppLocalizations` 国际化，MUST NOT 硬编码中英文字符串，并提供中文与英文译文。

#### Scenario: 文案随系统语言切换

- **WHEN** 用户系统语言为中文或英文
- **THEN** 协议弹窗标题、按钮、提示文案相应显示对应语言
