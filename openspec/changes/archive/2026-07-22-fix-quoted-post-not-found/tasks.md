# Tasks — fix-quoted-post-not-found

> 实现顺序：先做底层开关（api_client → service → state），再做文案（arb + 生成），最后接到卡片。每步可独立编译。

## 1. API 层：增加 `silent` 静默开关

- [x] 1.1 `client/lib/network/api_client.dart`
  - `get/post/put/patch/delete` 各加可选参数 `{bool silent = false}`，透传给 `_request`。
  - `_request(method, path, { ..., bool isRetry = false, bool silent = false})` 透传给 `_sendOnce`。
  - `_sendOnce` 增加 `bool silent = false`；在 `on ApiException catch (e)` 分支中，把 `if (e is ServerException) NetworkErrorNotifier.showServerError(e);` 改为 `if (e is ServerException && !silent) NetworkErrorNotifier.showServerError(e);`。
  - **注意**：`_request` 的 401→refresh→重试路径（约 130 行）若再次调用 `_request`/`_sendOnce` 重试，需把 `silent` 一并透传，避免重试请求丢静默语义。
  - `ApiLogger.logError` 保持原样（静默只压 SnackBar，不压日志）。

## 2. Service 层：`getPostDetail` 透传 silent

- [x] 2.1 `client/lib/services/post_service.dart`
  - `getPostDetail(String postId, {bool silent = false})`，把 `silent` 透传给 `_apiClient.get('post/detail/$postId', silent: silent)`。
  - 默认 `false`，确保详情页等其它调用方零行为变化。

## 3. State 层：引用帖预取打开静默

- [x] 3.1 `client/lib/state/post.state.dart`
  - `fetchQuotePostDetail` 内 `postService.getPostDetail(quotePostId.toString(), silent: true)`。
  - 其余（catch、`developer.log`、返回 null）保持不变。

## 4. 文案本地化

- [x] 4.1 `client/lib/l10n/app_en.arb`：新增 `"quotedPostUnavailable": "This post is unavailable"`。
- [x] 4.2 `client/lib/l10n/app_zh.arb`：新增 `"quotedPostUnavailable": "这条帖子已无法显示"`。
- [x] 4.3 在 `client/` 下运行 `flutter gen-l10n`，确认 `lib/l10n/generated/app_localizations.dart` / `_en.dart` / `_zh.dart` 三个文件均已生成 `quotedPostUnavailable` getter。

## 5. 卡片接入本地化文案

- [x] 5.1 `client/lib/widget/quote_card.dart`
  - `quote_card.dart:280` 处 `Text('This post is unavailable', ...)` 改为 `Text(AppLocalizations.of(context)!.quotedPostUnavailable, ...)`。
  - 确认 `AppLocalizations` 已 import；`_buildQuoteCard` 已持有 `BuildContext`，无需额外传参。

## 6. 验证

> 6.1–6.4 为运行期人工 QA 场景，依赖真机/模拟器 + 「信息流中引用了已删帖」的测试数据，需在设备上确认。代码层已按 spec 实现（静默开关默认 false，仅引用帖预取链路打开），并已通过静态分析（见 6.5）。

- [ ] 6.1 中文环境：构造/找到一条引用了已删帖的信息流条目 → 引用区显示中文友好提示，底部**不**弹 `[code=101100]` SnackBar。
- [ ] 6.2 英文环境：同上 → 引用区显示英文 `quotedPostUnavailable`，底部不弹 SnackBar。
- [ ] 6.3 回归：帖子详情页主动打开已删帖 → 全局提示**照常**弹出（确认 `silent` 默认 false 生效）。
- [ ] 6.4 回归：点赞 / 转发 / 收藏等交互失败 → 全局提示照常弹出。
- [x] 6.5 `flutter analyze` 无新增告警。（仅余 `_refreshToken` unused_field 一条历史告警，位于 api_client.dart:14，非本次改动引入。）
