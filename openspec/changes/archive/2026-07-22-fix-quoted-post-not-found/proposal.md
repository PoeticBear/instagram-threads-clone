## Why

信息流里，当一条帖子引用了「已被删除 / 不存在」的帖子时，会出现两个连带问题，且都源自同一条「引用帖补抓失败」链路：

1. 引用区硬编码显示英文 `This post is unavailable`，中文模式下的用户看到的是未翻译的英文。
2. 页面底部还会再弹一次全局 SnackBar「服务暂时不可用：[code=101100] Post Not Found」——卡片本身已经表达了「不可用」，这条全局提示纯属冗余噪音。

两者要一并修掉，让引用区的失败展示对中文用户友好，同时消除重复打扰。

## What Changes

- 引用区「不可用」文案改为走 `AppLocalizations`，新增中英文双语文案，中文为一句友好的提示语。
- 给 API 请求链路增加一个「静默错误提示」开关（`silent`），在「引用帖补抓」这条**后台预取**链路上打开；命中失败时跳过全局 SnackBar，但保留 `ApiLogger` 日志（排障不丢）。
- 其它所有调用方（含帖子详情页用户主动打开已删帖）**不受影响**，错误提示照常弹出。

## Capabilities

### New Capabilities

- `quote-card-error-display`: 引用卡在「被引用帖不可用」时的展示与错误传播契约 —— 文案本地化 + 后台预取失败不弹全局提示。

### Modified Capabilities

（无 —— `openspec/specs/` 当前为空，本变更新增首个能力。）

## Impact

- `client/lib/widget/quote_card.dart`：`_buildQuoteCard` 情况 3 的文案改用本地化字符串。
- `client/lib/network/api_client.dart`：`get/post/put/patch/delete` → `_request` → `_sendOnce` 透传 `silent` 开关；`on ApiException` 命中 `ServerException` 时按开关决定是否调用 `NetworkErrorNotifier.showServerError`。其余网络/超时分支**不在**本次静默范围（见 design）。
- `client/lib/services/post_service.dart`：`getPostDetail` 透传 `silent`，默认 `false`。
- `client/lib/state/post.state.dart`：`fetchQuotePostDetail` 以 `silent: true` 调用 `getPostDetail`。
- `client/lib/l10n/app_en.arb` / `app_zh.arb`：新增 `quotedPostUnavailable` 文案；运行 `flutter gen-l10n` 重新生成 `generated/` 三件套。

非目标（明确不做）：
- 不做「全局按 code 黑名单屏蔽」(详见 design)。
- 不改帖子详情页 `post_detail_page.dart:66` 的提示行为。
