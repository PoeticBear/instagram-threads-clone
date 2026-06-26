# 引用帖（Quote Post）— 代码定位

> 本文档汇总 iOS 客户端「引用帖」全链路涉及的源代码位置，覆盖**发布端**（用户引用别人帖子发出去）和**展示端**（Feed 卡片 / 详情页渲染被引用的原帖）。
> 后续若收到「定位引用帖 / quote / 引用转发」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 0. 关键结论（先读这段）

1. **引用帖不走 `ComposePost` 发帖页**，而是走一个独立的轻量底部弹窗 `_showQuoteSheet`（`feedpost.dart:1412`）。`ComposePost` 的构造参数里**没有任何** quote / quotedPost / quotePostId 入参。
2. **引用发布 = 普通发帖接口 `POST post/create`**，只是在请求体里多带一个 `quote_post_id` 字段。
3. **引用帖 ≠ 纯转发**，两者是**两个不同接口**：

   | 操作 | 接口 | 关键参数 | 触发 |
   | --- | --- | --- | --- |
   | 引用帖（带新文字 + 原帖） | `POST post/create` | `quote_post_id` | `_showRepostSheet` → 「引用」选项 |
   | 纯转发（无新文字） | `POST post/repost/{id}` | `repost_type: 1` | `_showRepostSheet` → 「转发」选项 |

4. 这两个操作在同一张 `_showRepostSheet` 里是**互斥选项**，由 `isReposted` 标记决定显示「转发」还是「撤销转发」。

---

## 1. 发布端（用户引用别人帖子发出去）

> 全部集中在 `client/lib/widget/feedpost.dart`，**不经过** `pages/composePost/post.dart`。

### 1.1 触发入口 `_showRepostSheet`

- **路径**：`client/lib/widget/feedpost.dart`
- **行号**：`1358-1408`
- **职责**：转发操作栏图标（`Iconsax.repeat`，build 内 `402-414`）点击后弹出的底部菜单，三个互斥选项：
  | 选项 | 文案 key | 行号 | 行为 |
  | --- | --- | --- | --- |
  | 纯转发 | `l10n.repost` | `1377-1383` | `postState.repost(postId)`（仅在 `!isReposted` 时显示） |
  | **引用** | `l10n.quote` | `1386-1392` | **`_showQuoteSheet(context)`** —— 引用帖入口 |
  | 撤销转发 | `l10n.undoRepost` | `1395-1402` | `postState.unrepost(postId)`（仅在 `isReposted` 时显示） |

### 1.2 引用发布弹窗 `_showQuoteSheet`

- **路径**：`client/lib/widget/feedpost.dart`
- **行号**：`1412-1535`
- **职责**：引用帖的「发帖页」替代品——一个 `isScrollControlled` 的底部弹窗，内含被引原帖预览 + 引言输入框 + 发布按钮。
- **结构**：

  | 模块 | 行号 | 说明 |
  | --- | --- | --- |
  | 标题 + 关闭 | `1434-1446` | `l10n.quoteRepost` |
  | 被引原帖预览 | `1449-1472` | 显示 `widget.postModel.user?.displayName` + `bio`（最多 3 行）—— 纯文字预览，无媒体 |
  | 引言输入框 | `1474-1495` | `TextField`，`maxLines: 3`，placeholder = `l10n.quotePlaceholder`，`autofocus: true` |
  | **发布按钮 `onPressed`** | `1507-1526` | 见下文 |

- **发布逻辑（`1507-1526`）**：
  1. 关闭弹窗（`1508`）。
  2. 取 `PostState` + `AuthState`（`1509-1510`）。
  3. 用当前用户信息 + 输入文字 `controller.text` 组装一个**最小 `PostModel`**（`1511-1521`）：仅含 `user / bio / createdAt / key`，无媒体、无投票。
  4. **`await state.createPost(postModel, quoteRepostId: int.tryParse(widget.postModel.id))`（`1522-1525`）** —— 把被引帖的 id 作为 `quoteRepostId` 透传给状态层。

> 注：帖子详情页 `client/lib/pages/post/post_detail_page.dart` **没有引用入口**，只展示 `repostsCount`；长按菜单 / 分享 sheet（`_showShareSheet`）也**没有**引用入口。引用的唯一入口是 Feed 卡片转发按钮。

---

## 2. 状态层（Provider）

### 2.1 `PostState.createPost`（发布引用帖的状态入口）

- **路径**：`client/lib/state/post.state.dart`
- **行号**：`231-370`（签名 `int? quoteRepostId` 在 `249`）
- **职责**：发帖统一入口，引用帖也走这里。
- **关键行**：
  - `'quoteRepostId': quoteRepostId`（`329`）—— 写入本地 payload 日志。
  - `postService.createPost(..., quoteRepostId: quoteRepostId)`（`350`）—— 透传给服务层。
  - 成功后 `_apiPostToModel(post)` 转 `PostModel`（`354-366`）—— **注释 `359` 明确：必须复用 `_apiPostToModel`，否则漏掉 `quoteRepostId` / `quotePost` 导致引用区不显示**。
  - 非定时帖 `insert(0)` 到 `_feedlist` 头部 → `notifyListeners()`。

### 2.2 `PostState.fetchQuotePostDetail`（补抓被引用帖详情）

- **路径**：`client/lib/state/post.state.dart`
- **行号**：`686-702`
- **职责**：调 `postService.getPostDetail(quotePostId)` → `_apiPostToModel`。用于 Feed 列表 API 未返回嵌套 `quote_post`（或嵌套版缺媒体）时，由卡片补抓完整数据。

### 2.3 `PostState._apiPostToModel`（API→UI 转换器）

- **路径**：`client/lib/state/post.state.dart`
- **行号**：`172-217`
- **职责**：保留全部 quote / repost 字段：`quoteRepostId`（`199`）、`quoteContent`（`204`）、`quotePost`（`205-207`，递归 `_apiPostToModel`）、`isRepost`（`208`）、`repostParentId`（`209`）、`quotesCount`（`213`）。

### 2.4 `PostState.repost`（纯转发，对比用）

- **路径**：`client/lib/state/post.state.dart`
- **行号**：`710-720`
- **职责**：纯转发的乐观更新状态方法（与引用帖无关）。`_updatePostRepostStatus(postId, true)` → `postService.repost(...)`，失败不回滚。`_updatePostRepostStatus` 在 `728-740`。

---

## 3. 服务层（API）

### 3.1 `PostService.createPost` —— 引用帖走的接口

- **路径**：`client/lib/services/post_service.dart`
- **行号**：`22-95`
- **接口**：`POST post/create`
- **关键参数**：`int? quoteRepostId`（`39`）→ `if (quoteRepostId != null) body['quote_post_id'] = quoteRepostId;`（`76`）—— **请求体字段名是 `quote_post_id`**。
- **响应**：`Post.fromJson(response['data'])`（`91`）。
- 其余字段：`content / media_urls / media_types / poll_options / reply_type / reply_to_post_id / reply_to_user_id / location / latitude / longitude / topic_ids / community_id / scheduled_publish_time / mentioned_user_ids`。

### 3.2 `PostService.repost` —— 纯转发接口（对比）

- **路径**：`client/lib/services/post_service.dart`
- **行号**：`335-344`
- **接口**：`POST post/repost/{postId}`
- **请求体**：`'repost_type': 1`（`338`，硬编码）；签名虽支持 `String? content`（`339`），但调用方（`PostState.repost`）从不传 content。

### 3.3 `PostService.getUserReposts`（个人中心 Reposts Tab）

- **路径**：`client/lib/services/post_service.dart`
- **行号**：`252-291`
- **接口**：`GET post/user/{user_id}/reposts`
- 靠 `_extractOriginalPostJson`（`294-323`）从候选 key（`original_post / post / source_post / quote_post / parent_post` 等）里抽原帖 JSON。

---

## 4. 数据模型

### 4.1 UI 层 `PostModel`

- **路径**：`client/lib/model/post.module.dart`
- **字段声明**（`155-176` 区段）：

  | 字段 | 行号 | 含义 |
  | --- | --- | --- |
  | `int? quoteRepostId` | `160` | 被引用帖的 id（对应 API `quote_repost_id` / `quote_post_id`） |
  | `String? quoteContent` | `168` | 引用帖的引言文字 |
  | `PostModel? quotePost` | `169` | 被引用的原帖完整对象（递归） |
  | `bool? isRepost` | `170` | 当前帖是否为纯转发 |
  | `int? repostParentId` | `171` | 转发父帖 id |
  | `int? quotesCount` | `174` | 被引用次数 |
  | 配套统计 | `141 / 145` | `repostsCount` / `isReposted` |

- **解析 / 序列化**：
  - `fromJson`（`248-336`）：`249-253` 递归解析 `quote_post` / `quotePost`；`322-325` `quoteRepostId` 兼容 `quote_repost_id` / `quoteRepostId` / `quote_post_id` / `quotePostId` 任一；`329-335` 其余 quote 字段。
  - `toJson`（`434-444`）、`copyWith`（`485-543`）均含这些字段。

### 4.2 API 层 `Post`

- **路径**：`client/lib/services/post_service.dart`（文件尾部）
- **字段声明**（`899-926`）：`quoteRepostId`（`899`）、`quoteContent`（`905`）、`quotePost`（`906`）、`isRepost`（`907`）、`repostParentId`（`908`）、`quotesCount`（`911`）。
- **`Post.fromJson` 递归解析**（`1078-1126`）：
  - `1078-1082`：`quote_post` / `quotePost` → `Post.fromJson(...)` 递归。
  - `1112-1115`：`quoteRepostId` 兼容 `quote_repost_id` / `quoteRepostId` / `quote_post_id` / `quotePostId`。
  - `1120-1126`：`quoteContent` / `quotePost` / `isRepost` / `repostParentId` / `quotesCount`。

---

## 5. 展示端（Feed 卡片渲染被引用帖）

> 全部集中在 `client/lib/widget/feedpost.dart`。

### 5.1 三种形态的渲染分支（build）

- **路径**：`client/lib/widget/feedpost.dart`
- **行号**：`211-330`
- **逻辑**：
  - `hasQuoteId = widget.postModel.quoteRepostId != null`（`214`）。
  - **引用帖卡片插入**：`if (hasQuoteId)` → `_buildQuoteCard(...)`（`317-325`），padding `left:40, right:10`。这是「引用帖（带新文字 + 原帖）」的渲染分支。
  - 普通帖子的正文 / 媒体：`_buildPostContent`（`234-238`）、`_buildMediaGallery`（`312-316`）。
  - **纯转发（无新文字）**：build 里**没有针对 `isRepost` 的独立渲染分支**——纯转发只靠 `isReposted` 标记（`408` 图标变色）+ Reposts Tab 列表展示，Feed 卡片**不内联**渲染被转发原帖。即 Feed 卡片只区分「有 `quoteRepostId`（渲染引用卡）」vs「无（普通帖）」两种形态。

### 5.2 被引用帖数据补抓 `_maybeFetchQuotePost` + `_effectiveQuotePost`

- **路径**：`client/lib/widget/feedpost.dart`
- **`_maybeFetchQuotePost`（`169-203`）**：在 `initState`（`101`）调用。补抓条件：
  - `quoteRepostId`（`qid`，`171`）有值（`178`）；
  - 未在 fetching 中（`179`）；
  - `quotePost` 与 `_fetchedQuotePost` 任意一个来源都**没有媒体**（`181-184`）—— 后端 Feed API 当前只回填最小版 `quote_post`、缺 `media_list`，故几乎每次都要补抓。
  - 调 `postState.fetchQuotePostDetail(qid)`（`188`），成功写入 `_fetchedQuotePost`（`192`）。
- **`_effectiveQuotePost` getter（`90-98`）**：选有效的被引用帖数据，优先级：有 media 的 `_fetchedQuotePost` → 有 media 的 `quotePost` → `_fetchedQuotePost` → `quotePost`。注释强调不能让空 `_fetchedQuotePost` 盖住 `post.quotePost`。

### 5.3 引用卡主体 `_buildQuoteCard`

- **路径**：`client/lib/widget/feedpost.dart`
- **行号**：`971-1073`（情况 1：有完整数据）、`1076+`（情况 2：`_isFetchingQuote` 加载态）
- **结构**：

  | 模块 | 行号 | 说明 |
  | --- | --- | --- |
  | 作者信息行 | `1011-1038` | `AppCircleAvatar`(20) + `displayName`（空则回退 `userName`），点击跳被引用户 Profile |
  | 正文 | `1040-1052` | `Text.rich(_buildMentionTextSpan(...))`，最多 4 行 |
  | 首图 / 首段视频 | `1056-1068` | 单 tile，固定 `height:150`，视频走 `_buildQuoteVideoPoster`，图片走 `_buildQuoteImage` |
  | 整卡点击 | `999` | `_navigateToQuotedPostDetail` → `PostDetailPage` |

- 内含调试 `print`（`989-996`），用于排查后端是否回填 `media_list`。

### 5.4 引用卡媒体渲染

| 方法 | 行号 | 职责 |
| --- | --- | --- |
| `_buildQuoteImage(AppColors, MediaItemModel)` | `1119-1149` | 首图：`thumbUrl ?? url` 作源，`CachedNetworkImage` + 占位 / 错误 fallback（`broken_image`） |
| `_buildQuoteVideoPoster(AppColors, MediaItemModel)` | `1152-1200+` | 首段视频：有缩略图→poster + 播放按钮 + 时长；无缩略图→深色占位 + 大播放图标；无 URL→`videocam_off`。**真正播放靠点击跳详情页**（注释 `1151`） |

### 5.5 引用卡跳转

| 方法 | 行号 | 跳转目标 |
| --- | --- | --- |
| `_navigateToQuotedPostDetail` | `1287-1295` | `PostDetailPage(postId: quotePost.id, postModel: quotePost)` |
| `_navigateToQuotedUserProfile` | `1299-1307` | 被引用帖作者的 `ProfilePage` |

---

## 6. 国际化文案

- **主语言文件**：`client/lib/l10n/app_en.arb`、`client/lib/l10n/app_zh.arb`
- **生成代码**：`client/lib/l10n/generated/app_localizations*.dart`
- **引用帖相关 key**：
  - `quote` —— `_showRepostSheet` 里的「引用」选项标签（`feedpost.dart:1387`）
  - `quoteRepost` —— `_showQuoteSheet` 标题（`1438`）
  - `quotePlaceholder` —— 引言输入框 placeholder（`1480`）
  - `repost` / `undoRepost` —— 同 sheet 内的转发 / 撤销转发（`1378` / `1396`）
  - `post` —— 引用发布按钮文案（`1527`）

---

## 7. 快速检索指引

| 需求 | 检索关键词 | 关键文件 / 位置 |
| --- | --- | --- |
| 改引用发布的入口 / 选项顺序 | `_showRepostSheet` / `l10n.quote` | `client/lib/widget/feedpost.dart:1358` |
| 改引用发布弹窗 UI（预览 / 输入框 / 按钮） | `_showQuoteSheet` | `client/lib/widget/feedpost.dart:1412` |
| 改引用发布提交逻辑（组装 PostModel / quoteRepostId） | `_showQuoteSheet` 的 `onPressed` | `feedpost.dart:1507-1526` |
| 改引用帖用的接口字段 | `quote_post_id` / `quoteRepostId` | `post_service.dart:76` + `post.state.dart:350` |
| 改 Feed 卡片里引用卡的渲染 | `_buildQuoteCard` / `_effectiveQuotePost` | `feedpost.dart:971` / `90` |
| 改被引用帖媒体补抓逻辑 | `_maybeFetchQuotePost` / `fetchQuotePostDetail` | `feedpost.dart:169` + `post.state.dart:686` |
| 改引用卡跳转（点卡片 / 点作者） | `_navigateToQuotedPostDetail` / `_navigateToQuotedUserProfile` | `feedpost.dart:1287` / `1299` |
| 区分「引用帖 vs 纯转发」 | `quoteRepostId`（引用）/ `repost_type:1`（转发） | `post_service.dart:76` vs `338` |
| 改 PostModel 引用字段 | `quoteRepostId` / `quoteContent` / `quotePost` | `client/lib/model/post.module.dart:160-174` |
| 加 / 改引用相关文案 | `quote` / `quoteRepost` / `quotePlaceholder` | `client/lib/l10n/app_zh.arb` + `app_en.arb` |

---

## 8. 引用帖完整生命周期（数据流）

1. **触发**：用户点 Feed 卡片转发按钮（`Iconsax.repeat`，`feedpost.dart:402-414`）→ `_showRepostSheet`（`1358`）。
2. **进入引用**：选「引用」→ `_showQuoteSheet`（`1412`）弹出，内联显示被引原帖预览（纯文字）+ 3 行引言输入框。
3. **发布**：点发布（`1507`）→ 组装最小 `PostModel` → `PostState.createPost(postModel, quoteRepostId: 被引帖id)`（`1522`）。
4. **网络**：`PostService.createPost` 发 `POST post/create`，请求体带 `quote_post_id`（`post_service.dart:76`）。
5. **本地回写**：成功后 `_apiPostToModel` 转换（必须复用，否则漏 `quotePost`）→ `insert(0)` 进 `_feedlist` → `notifyListeners()`（`post.state.dart:354-366`）。
6. **渲染**：Feed 卡片 build 时若 `quoteRepostId != null` → 渲染 `_buildQuoteCard`（`feedpost.dart:317`）。
7. **补抓**：若列表 API 未返回嵌套 `quote_post` 的媒体 → `_maybeFetchQuotePost`（`169`）调 `/post/detail/{id}` 拉完整数据再 `setState`。

---

_最后更新：2026-06-26 — 由 Claude 自动化梳理（基于代码静态分析 + 行号校准）。_
