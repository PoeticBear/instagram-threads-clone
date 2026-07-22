## ADDED Requirements

### Requirement: 引用区「不可用」文案必须本地化

当被引用帖加载失败或本身不存在、引用卡回退到「不可用」占位时，系统 SHALL 通过 `AppLocalizations` 渲染提示文案，禁止出现硬编码的英文字面量。中文 locale 下 SHALL 显示一句面向用户的友好中文提示。

#### Scenario: 中文环境下被引用帖不存在

- **WHEN** 设备 locale 为中文，且引用帖补抓返回业务错误（如 code=101100 Post Not Found）或被引用帖数据本就缺失
- **THEN** 引用区显示中文友好提示语（来自 `app_zh.arb` 的 `quotedPostUnavailable`），不显示英文 `This post is unavailable`

#### Scenario: 英文环境下被引用帖不存在

- **WHEN** 设备 locale 为英文，且引用帖补抓失败或被引用帖缺失
- **THEN** 引用区显示 `app_en.arb` 中 `quotedPostUnavailable` 对应的英文文案

#### Scenario: 引用帖加载中

- **WHEN** 引用帖正在后台补抓（`_isFetchingQuote == true`）
- **THEN** 引用区显示加载态（spinner），不显示「不可用」文案

### Requirement: 引用帖后台预取失败不得触发全局错误提示

引用卡为了补全媒体而发起的「被引用帖详情」预取，属于后台、非用户主动触发的请求。该预取失败时，系统 SHALL NOT 弹出全局错误 SnackBar（`NetworkErrorNotifier`），因为引用卡本身已用占位文案向用户表达了失败。

#### Scenario: 被引用帖不存在且预取返回业务错误

- **WHEN** `QuoteCard` 触发 `fetchQuotePostDetail`，后端返回业务错误 code=101100（Post Not Found）
- **THEN** 页面底部 SHALL NOT 出现「服务暂时不可用：[code=101100] ...」Snack​Bar；引用卡回退显示本地化的「不可用」文案

#### Scenario: 预取失败仍需可排障

- **WHEN** 引用帖预取失败（任意错误类型）
- **THEN** 系统 SHALL 仍通过 `ApiLogger` 记录该错误（含 url / statusCode / message），仅抑制用户可见的 SnackBar

### Requirement: 其它错误链路保持原有提示行为

`silent`（静默错误提示）为按调用按需打开的开关，默认关闭。所有非引用帖预取的调用方 SHALL 保持原有「失败即弹全局提示」的行为，不受本变更影响。

#### Scenario: 用户在帖子详情页打开已删除帖

- **WHEN** 用户主动从 `PostDetailPage` 打开一篇已被删除的帖子，`getPostDetail`（`post_detail_page.dart` 调用方，未打开 `silent`）返回 code=101100
- **THEN** 系统 SHALL 照常弹出全局错误提示（与变更前行为一致）

#### Scenario: 点赞 / 转发 / 收藏等交互失败

- **WHEN** 用户触发的点赞、转发、收藏等操作请求失败
- **THEN** 系统 SHALL 照常通过 `NetworkErrorNotifier.showApiError` 弹出提示，不受 `silent` 开关影响
