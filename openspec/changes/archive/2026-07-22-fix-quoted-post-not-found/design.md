## 背景：两个现象为什么连在一起

```
信息流帖子引用了一篇已不存在的帖子
   │  QuoteCard._maybeFetchQuotePost()
   ▼
postState.fetchQuotePostDetail(id) ─► postService.getPostDetail ─► apiClient.get('post/detail/{id}')
   │
   ▼
后端业务错误 { code: 101100, msg: "Post Not Found" }
   │
   ▼
api_client._handleResponse 抛 ServerException(code=101100)
   │
   ├──► ❗ _sendOnce 的 catch 里先弹 NetworkErrorNotifier.showServerError   ← 现象②
   │     (api_client.dart:271-273，对所有 ServerException 都弹)
   │
   └──► rethrow → fetchQuotePostDetail 接住、吞掉、返回 null
            │
            ▼
      QuoteCard 走「情况 3」，渲染硬编码 'This post is unavailable'           ← 现象①
      (quote_card.dart:280)
```

关键事实：**全局 SnackBar 在 `api_client` 拦截器里就弹了，比 `fetchQuotePostDetail` 把异常吞掉还早**。所以光在 state 层 catch 拦不住提示——这正是「卡片已显示不可用、底部还弹一次」的根因。

## 决策 1：文案本地化（无争议）

- 在 `app_en.arb` / `app_zh.arb` 新增 `quotedPostUnavailable`。
- 英文保留 `This post is unavailable`（或等价友好措辞）。
- 中文给一句友好提示，候选：「这条帖子已无法显示」/「原帖已被删除或不可用」。
- `quote_card.dart:280` 改为 `AppLocalizations.of(context)!.quotedPostUnavailable`。`_buildQuoteCard` 已有 `BuildContext`，无障碍。

## 决策 2：压住冗余提示 —— 采用「按调用静默」开关

候选方案对比：

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | 给请求链路加 `silent` 开关，**只**在引用帖补抓这条链路打开 | 精准命中「这类情况」，其它调用零影响 |
| B | 在 `NetworkErrorNotifier` 按 code=101100 全局拉黑 | 改动最小，但太宽——见下方「为什么不全局拉黑」 |
| C | 只在 `fetchQuotePostDetail` 里 catch | ❌ 行不通，提示在 catch 之前已弹 |

### 为什么不全局拉黑 code=101100（否定方案 B）

`getPostDetail` 有**两个**调用方：

- 引用卡后台补抓（`post.state.dart:688`）← 本次要静默
- 帖子详情页（`post_detail_page.dart:66`）← 用户**主动**点开一篇被删帖，此时弹「Post Not Found」是合理的操作反馈，应保留

全局按 code 拉黑会误伤详情页。因此必须「按调用按需打开」——这正是 `silent` 开关的价值。

### `silent` 的作用边界

`fetchQuotePostDetail` 失败时，无论根因是 101100、真·500 还是网络抖动，卡片的用户可见兜底都是同一句「不可用」。因此这条预取链路上的**所有错误类型都不弹 SnackBar**，行为一致、不误导。

实现上 `silent` 只作用于 `on ApiException → ServerException` 分支（即本次现象②的源头）；`SocketException` / `ClientException` / `TimeoutException` 分支**不在**本次改动范围内——它们走的是 `showNetworkError`，且引用帖预取失败时这些分支同样会让卡片落到「不可用」兜底，但为控制改动面、避免影响全局网络错误提示策略，本次不一并静默。（如后续发现这些分支在预取场景也频繁扰民，再单独评估。）

`ApiLogger.logError` 与 `silent` **互相独立**：静默只压 SnackBar，日志照打，排障信息不丢。

## 风险与回滚

- 风险点：`silent` 开关透传链路较长（service → apiClient.get → _request → _sendOnce），任一节点漏传会导致静默失效（最坏退化为「提示照弹」，即现状，不会更糟）。
- 回滚：把 `fetchQuotePostDetail` 里的 `silent: true` 去掉即可全量还原；文案本地化为独立改动，可单独保留。
