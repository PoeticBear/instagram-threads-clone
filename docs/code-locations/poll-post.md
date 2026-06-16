# 投票帖子（Poll Post）— 代码定位

> 本文档汇总 iOS 客户端「投票帖子」这一帖子类型（创建 / 渲染 / 投票 / 结果展示 / 草稿 / API 契约）的所有源代码位置。
> 「投票帖子」是一种**特殊帖子类型**：帖子的内容可以附带 2–4 个投票选项，用户可以对其中一个选项投票，结果以百分比进度条形式回显。
> 后续若收到「定位投票帖子 / 投票卡片 / 创建投票 / 投票交互」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。

---

## 1. 完整数据流（先看这张图）

```
[发帖]
  ComposePost 工具栏「投票」按钮 → _togglePollEditor → _buildPollEditor
  → 输入 2-4 个选项 → _getValidPollOptions 校验 → createPost(pollOptions: [...])
  → 后端在 post/poll_options 字段写入选项 → 同时返回 poll_id / poll_options / poll_total_votes / poll_expire_time

[加载 / 解析]
  PostService.getPostDetail / getFeed 等 → Post.fromJson 把 poll_id 等字段组装成 PollData
  → PostModel.pollData
  → Feed 流 / 详情页渲染时通过 Consumer<PostState> 拿到 pollData → PollWidget

[投票]
  PollWidget._handleVote(optionId) → _isVoting 防抖闸
  → PostState.voteOnPoll(postId, optionId) [乐观更新 _feedlist + _userPosts]
  → PostService.votePoll(postId, optionId) [POST /post/poll/{post_id}/vote]
  → 成功：保留乐观态；失败：回滚 PollData + SnackBar 提示

[结果展示]
  PollWidget build 根据 PollData.hasVoted / isExpired / 本地过期判定
  → 结果态：百分比进度条 + 「你已投票」边框高亮
  → 投票中：可点击的选项列表（Material + InkWell + 防抖 spinner）

[草稿]
  草稿服务在创建投票帖时落库 DraftModel.pollOptions
  → 恢复时 ComposePost._restoreDraft 把 pollOptions 重新填回 _pollControllers
```

---

## 2. 核心组件（UI 层）

### 2.1 投票卡片 `PollWidget`（核心展示 + 投票交互）

- **路径**：`client/lib/widget/poll_widget.dart`
- **行数**：362
- **核心类**：
  - `class PollWidget extends StatefulWidget`（`poll_widget.dart:13`）
  - `class _PollWidgetState`（`poll_widget.dart:34`）— 持有 `_isVoting`（防抖）+ `_countdownTimer`（30s 倒计时）
  - `class _BuildVotingOption extends StatefulWidget`（`poll_widget.dart:292`）— 单个投票中状态的选项
- **构造参数**：
  | 字段 | 行号 | 说明 |
  | --- | --- | --- |
  | `required String postId` | `poll_widget.dart:14` | 帖子 ID（投票时传给 state） |
  | `required PollData pollData` | `poll_widget.dart:15` | 投票数据 |
  | `VoidCallback? onCardTap` | `poll_widget.dart:20` | 结果态（已投 / 已过期）下整卡可点跳详情；投票中时不触发 |
  | `EdgeInsetsGeometry padding` | `poll_widget.dart:16` | 默认 `EdgeInsets.only(left: 55, right: 10, top: 8)`（FeedPostWidget 传入） |

### 2.2 关键状态与计算

| 名称 | 行号 | 用途 |
| --- | --- | --- |
| `bool _isVoting` | `poll_widget.dart:36` | 投票进行中标记；防抖 + 展示 spinner |
| `Timer? _countdownTimer` | `poll_widget.dart:39` | 每 30s 触发 `setState(() {})` 更新「剩余 N 分钟」 |
| `_formatRemainingTime(l10n)` | `poll_widget.dart:62-71` | `expireTime` → 「投票已结束 / 剩余 N 小时 / 剩余 N 分钟」 |
| `_handleVote(optionId)` | `poll_widget.dart:75-96` | 第一道闸：`if (_isVoting) return;`；调 `PostState.voteOnPoll`；失败弹 `voteFailed` SnackBar |
| `_computePercentages(options, totalVotes)` | `poll_widget.dart:100-115` | 最大余数法计算百分比，保证累加 = 100% |
| `isExpiredLocally` | `poll_widget.dart:122-123` | 客户端兜底过期判定（应对服务端时钟偏差 / 缓存延迟） |
| `showResults` | `poll_widget.dart:124-125` | `hasVoted \|\| isExpired \|\| isExpiredLocally` |

### 2.3 结果态渲染 `_buildResultOption`

- **行号**：`poll_widget.dart:163-259`
- **关键细节**：
  - 已投票选项：`Border.all(color: textPrimary, width: 1.5)` 加粗边框 + `Icons.check_circle` + `FontWeight.w600`
  - 未投票选项：`Border.all(color: border, width: 1)` + `Icons.circle_outlined` + `FontWeight.normal`
  - 进度条：`FractionallySizedBox(widthFactor: percentage / 100)` + `appColors.surfaceSecondary`
  - 整卡可点：`GestureDetector(onTap: widget.onCardTap)` + `Semantics(container: true, label: ...)`（无障碍朗读「选项 X, 60%, 你已投票」）

### 2.4 投票中选项 `_BuildVotingOption`

- **行号**：`poll_widget.dart:344-413`
- **关键细节**：
  - 用 `Material` + `InkWell` 取代 `GestureDetector`，提供水波纹视觉反馈（`poll_widget.dart:371-376`）
  - `_isVoting=true` 时 `opacity: 0.5` + 左侧图标替换为 `CircularProgressIndicator` + `onTap: null`（第二道闸，物理上拒绝 tap）

### 2.5 底部文案 `_buildFooter`

- **行号**：`poll_widget.dart:285-313`
- **签名**：`Widget _buildFooter(BuildContext, bool showResults, {required bool isEnded})`
- **组合**：`pollVotesCount(totalVotes)` · `pollYouVoted` · `_formatRemainingTime()`
- **已结束抑制**：当 `isEnded == true` 时不追加 `_formatRemainingTime()`（避免与顶部 banner 重复显示 `pollEnded`）
- **结果态 + 有 `onCardTap`**：footer 也包 `GestureDetector` 跳详情。

### 2.6 "已结束"状态 Banner `_buildEndedBanner`

- **行号**：`poll_widget.dart:321-341`
- **触发条件**：`build()` 中 `if (isEnded) _buildEndedBanner(context)`（`poll_widget.dart:138`）
- **设计**：沿用项目 `scheduled_posts_page.dart:80-99` 的 status banner 惯例
  - `CupertinoIcons.clock`（size 14, `textMuted`）+ `SizedBox(width: 6)` + `Text(pollEnded, textMuted, size 12, w500)`
- **不**用 `Icons.lock*`（项目中专用于隐私 / 密码场景）
- **无背景、无边框**：保持低调但有辨识度

### 2.7 已结束视觉强化（`_buildResultOption` 内）

当 `isEnded == true` 时（与"已投未过期"区分）：

| 维度 | 已投未过期 | 已结束（含已投 + 未投） |
| --- | --- | --- |
| 边框 | `textPrimary / width 1.5`（已投）或 `border / 1`（未投） | `divider / 1`（所有选项） |
| 字体粗细 | `FontWeight.w600`（已投）或 `normal`（未投） | `FontWeight.normal`（全部） |
| 整体压暗 | 无 | `Opacity(opacity: 0.6)` 包外层 |
| 图标形状 | `check_circle` / `circle_outlined`（保留） | `check_circle` / `circle_outlined`（保留，便于仍区分"我投了哪个"） |
| Semantics | `"X, 60%, 你已投票"` | 末尾追加 `, 投票已结束` |
| 点击行为 | `onCardTap` 跳详情（保留） | `onCardTap` 跳详情（保留，Opacity 不影响 hit test） |

样式 token 抽离：`borderColor` / `borderWidth` / `textWeight`（`poll_widget.dart:181-186`）。

---

## 3. 投票帖子编辑器（创建流程）

### 3.1 状态字段（ComposePost）

| 字段 | 位置 | 说明 |
| --- | --- | --- |
| `bool _showPollEditor` | `client/lib/pages/composePost/post.dart:58` | 投票编辑器显隐 |
| `List<TextEditingController> _pollControllers` | `client/lib/pages/composePost/post.dart:59` | 每个选项一个 controller |
| `static const int _maxPollOptions = 4` | `client/lib/pages/composePost/post.dart:69` | 最多 4 个选项 |
| `static const int _minPollOptions = 2` | `client/lib/pages/composePost/post.dart:70` | 最少 2 个选项 |

### 3.2 生命周期 / 行为

| 方法 | 行号 | 行为 |
| --- | --- | --- |
| `_initPollControllers()` | `post.dart:90-99` | 初始化 2 个空 controller |
| `_clearContent()` | `post.dart:219-231` | 提交后清空 controller 并隐藏编辑器 |
| `_togglePollEditor()` | `post.dart:261-270` | **开启投票时清空所有媒体**（互斥） |
| `_addPollOption()` | `post.dart:272-278` | `_pollControllers.length < 4` 时追加 |
| `_removePollOption(index)` | `post.dart:280-287` | `> 2` 时移除并 dispose controller |
| `_getValidPollOptions()` | `post.dart:289-296` | 收集非空选项；`>= 2` 才返回（否则返回 `null`） |

### 3.3 媒体 ↔ 投票 互斥逻辑（关键约束）

| 入口 | 行号 | 行为 |
| --- | --- | --- |
| `_addMedia(item)` | `post.dart:241-253` | 添加媒体时若已开投票 → **关闭投票并清空 controller** |
| `_togglePollEditor()` | `post.dart:261-270` | 开启投票时 **清空所有媒体** |
| `_hasContent` 计算 | `post.dart:112-114` | 「有内容 / 有媒体 / 有投票」三选一即可提交 |

### 3.4 工具栏按钮（投票触发入口）

- **路径**：`post.dart:1585-1601`（`_buildBottomToolbar` 内）
- **逻辑**：
  - 已有媒体草稿 → 投票按钮 `onTap: null`（disabled）
  - 开启投票 → 投票按钮 `appColors.accent`（高亮），其他工具按钮变 `divider`（disabled）
  - 投票按钮文案：`AppLocalizations.removePoll`（开启时变为移除投票的入口）

### 3.5 编辑器 UI `_buildPollEditor`

- **路径**：`client/lib/pages/composePost/post.dart:1458-1533`
- **结构**：
  - 循环渲染每个选项的 `TextField`（`poll_widget.dart` 提示文案 `optionLabel(i + 1)`）
  - 选项数 `> 2` 时右侧 `IconButton(Icons.close)` 移除
  - 选项数 `< 4` 时下方「+ Add option」入口
  - 底部居中 `removePoll` 按钮（destructive 颜色）

### 3.6 提交

- **新建帖子**：`post.dart:635-660` `_submit()` 调 `PostService.createPost`，传入 `pollOptions: _getValidPollOptions()`
- **编辑帖子**：`post.dart:749-797` `_updatePost()` 不包含投票（编辑模式只允许改文本 / 敏感标记）

### 3.7 草稿恢复

- **路径**：`post.dart:525-540`（`_restoreDraft`）
- **逻辑**：从 `DraftModel.pollOptions` 恢复 → 设 `_showPollEditor = true` → 按选项数填充 `_pollControllers`，不足 2 个则补齐空 controller。

---

## 4. 投票帖子渲染（消费流程）

### 4.1 FeedPostWidget 内

- **路径**：`client/lib/widget/feedpost.dart`
- **关键行**：
  | 行号 | 行为 |
  | --- | --- |
  | `feedpost.dart:128` | `final hasPoll = widget.postModel.pollData != null;` |
  | `feedpost.dart:246-253` | `if (hasPoll) PollWidget(postId, pollData, onCardTap: () => _navigateToPostDetail(...))` |
  | `feedpost.dart:259-264` | **互斥**：有投票时 **不渲染媒体**（`if (!hasPoll && hasMedia)`） |
- **互斥约束**：帖子一旦带投票，就不显示媒体画廊；服务端 `post_options` 与 `media_urls` 也不应同时出现。

### 4.2 PostDetailPage 内

- **路径**：`client/lib/pages/post/post_detail_page.dart`
- **关键行**：
  - `post_detail_page.dart:15` — `import 'package:threads/widget/poll_widget.dart';`
  - `post_detail_page.dart:88` — `pollData: apiPost.pollData`（首屏用 API 返回值）
  - `post_detail_page.dart:264-284` — `if (post.pollData != null)` → 用 `Consumer<PostState>` 拿到 `feedlist` 中的最新 `pollData`（投票后即时刷新）→ `PollWidget(padding: EdgeInsets.zero)`
  - `post_detail_page.dart:285` — 同样互斥：`hasMedia && post.pollData == null`

### 4.3 PostModel 字段

- **路径**：`client/lib/model/post.module.dart`
- **`PollData? pollData`** — `post.module.dart:106` / `post.module.dart:152`（构造） / `post.module.dart:328`（`copyWith`） / `post.module.dart:369`（`copyWith` 实现）

---

## 5. 状态层（Provider）

### 5.1 `PostState.voteOnPoll`（核心：乐观更新 + 回滚）

- **路径**：`client/lib/state/post.state.dart:361-421`
- **流程**：
  | 步骤 | 行号 | 说明 |
  | --- | --- | --- |
  | 1. 解析 postId | `post.state.dart:363-367` | 非数字直接 `return false`（不发起网络请求） |
  | 2. 找 _feedlist 中的帖子 | `post.state.dart:369-372` | `indexWhere` 按 `postId` / `key` 匹配；不存在直接放弃 |
  | 3. 局部辅助 `buildUpdated(votedOptionId, deltaVotes)` | `post.state.dart:377-389` | 构造新的 PollData（被选项 +1 票、totalVotes +1、userVotedOptionId = optionId） |
  | 4. 乐观更新 _feedlist | `post.state.dart:392-394` | `post.copyWith(pollData: buildUpdated(...))` |
  | 5. 乐观同步 _userPosts | `post.state.dart:397-405` | 仅 poll 才同步到用户主页 Threads Tab |
  | 6. notifyListeners | `post.state.dart:406` | 触发 UI 立刻从「投票中」切到「结果态」 |
  | 7. 调 API | `post.state.dart:409-411` | `postService.votePoll(pid, optionId)` |
  | 8. 失败回滚 | `post.state.dart:412-420` | `_feedlist` / `_userPosts` 都回滚到 `oldPollData` + `notifyListeners` |

### 5.2 `PostState` 中其他投票相关方法

| 方法 | 位置 | 说明 |
| --- | --- | --- |
| `_feedlist` 索引时的 `pollData` 透传 | `post.state.dart:234` | `pollData: post.pollData` |
| `getDataFromDatabase` → 解析 `apiPost.pollData` | `post.state.dart:115` | 拉取本地数据库时填充 |
| `createPost(pollOptions: ...)` | `post.state.dart:152, 203` | 提交时透传给 service |

### 5.3 数据模型（`PollData` / `PollOption`）

> ⚠️ 这两个类**没有**放在 `model/post.module.dart`，而是定义在 `services/post_service.dart` 里（项目历史遗留）。

| 类 | 位置 | 字段 |
| --- | --- | --- |
| `PollData` | `client/lib/services/post_service.dart:944-977` | `pollId` / `options` / `totalVotes` / `expireTime` / `userVotedOptionId`；派生 `hasVoted`（`userVotedOptionId != null`）/ `isExpired`（`DateTime.now().isAfter(expireTime!)`）；`copyWith` |
| `PollOption` | `client/lib/services/post_service.dart:979-997` | `id` / `optionText`（同时兼容 `option_text` / `optionText`） / `votesCount`（同时兼容 `votes_count` / `votesCount`）；`fromJson` |

### 5.4 Post.fromJson 中的投票解析

- **路径**：`client/lib/services/post_service.dart:837-851`
- **字段映射**（来自 openapi_docs/post.json:633-637）：
  | OpenAPI 字段 | PollData 字段 |
  | --- | --- |
  | `poll_id` | `pollId` |
  | `poll_options` (`PollOptionResponse[]`) | `options` |
  | `poll_total_votes` | `totalVotes` |
  | `poll_expire_time` | `expireTime` |
  | `poll_user_voted_option_id` | `userVotedOptionId` |
  | `is_expired` | `isExpired`（`PollData` 内派生，不在此处赋值） |

---

## 6. 服务层（API）

### 6.1 `PostService.votePoll`

- **路径**：`client/lib/services/post_service.dart:405-407`
- **请求**：`POST post/poll/{post_id}/vote`，body `{ "option_id": <int> }`
- **返回**：`Future<void>`（调用方靠 `PostState.voteOnPoll` 维护状态）

### 6.2 `PostService.getPollResults`

- **路径**：`client/lib/services/post_service.dart:679-703`
- **请求**：`GET post/poll/{post_id}`
- **返回**：`Future<PollData?>`
- **说明**：返回 `null` 当响应中无 `poll_id` 或 `poll_options` 为空；其他情况按 `poll_id` / `poll_options` / `poll_total_votes` / `poll_expire_time` / `poll_user_voted_option_id` 构造。
- ⚠️ **当前业务上未直接调用此方法**——`PollWidget` 直接消费 `PostModel.pollData`（由帖子详情 / Feed 流一次性带回）。

### 6.3 `PostService.createPost`

- **路径**：`client/lib/services/post_service.dart:25-79`
- **投票相关**：`pollOptions` 参数 → body `poll_options` 字段（`post_service.dart:29, 54-56`）

---

## 7. 服务端 API 契约（来自 `openapi_docs/post.json`）

| 接口 | Method | Path | 行号 |
| --- | --- | --- | --- |
| 投票 | POST | `/post/poll/{post_id}/vote` | `post.json:247-258` |
| 获取投票结果 | GET | `/post/poll/{post_id}` | `post.json:236-245` |

### 7.1 投票请求 / 响应

```jsonc
// request
{ "option_id": 1 }

// response: PollResultResponse?
{
  "poll_id": 12,
  "post_id": 456,
  "options": [
    { "id": 1, "option_text": "A", "votes_count": 10, "display_order": 1 },
    { "id": 2, "option_text": "B", "votes_count": 5,  "display_order": 2 }
  ],
  "total_votes": 15,
  "expire_time": "2025-01-02T12:00:00Z",
  "is_expired": false,
  "user_voted_option_id": 1
}
```

### 7.2 帖子响应中嵌入的投票字段（`PostResponse`）

- `poll_id` / `poll_options` / `poll_total_votes` / `poll_expire_time` / `poll_user_voted_option_id` — 见 `post.json:633-637`
- 字段命名带 `poll_` 前缀是为了与选项字段 `options` 区分。

### 7.3 服务端约束

- 每个用户对同一投票**只能投一次**（来自接口描述）
- 投票**过期后不能再投**
- 投票过期时间固定为发帖后 **24 小时**（`post.json:636` 注释「投票过期时间（24小时后）」）

### 7.4 草稿相关

- 草稿请求中也支持 `poll_options`（`post.json:30, 70`）— 与帖子请求保持一致。

---

## 8. 草稿模型（持久化）

### 8.1 `DraftModel.pollOptions`

- **路径**：`client/lib/model/draft.module.dart`
- **字段**：`final List<String>? pollOptions` — `draft.module.dart:9`
- **构造 / fromJson / toJson / copyWith**：`draft.module.dart:22, 109, 127, 142, 155`

### 8.2 `DraftState` 透传

- **路径**：`client/lib/state/draft.state.dart:35-45`
- 保存草稿时 `pollOptions: pollOptions` 一并存入。

### 8.3 ComposePost 恢复

- **路径**：`post.dart:525-540`
- **逻辑**：`draft.pollOptions != null` → 设 `_showPollEditor = true` → 重建 `_pollControllers`；长度不足 2 时补空 controller。

---

## 9. 通知设置（用户偏好）

| 字段 | 位置 |
| --- | --- |
| `int notifyPolls` | `client/lib/services/user_service.dart:268, 297, 323, 349` |
| 拷贝 / copyWith | `user_service.dart:374, 398` |
| SettingsState 解析 | `client/lib/state/settings.state.dart:73-74` |
| i18n | `AppLocalizations.notifyPolls` — `app_localizations_en.dart:293` / `app_localizations_zh.dart:284`（en: "Polls" / zh: "投票"） |
| 通知设置页 | `client/lib/common/settings/notification_settings.dart` |

---

## 10. 关联子组件 / 入口

| 名称 | 路径 | 用途 |
| --- | --- | --- |
| `PollWidget` | `client/lib/widget/poll_widget.dart` | 投票卡片本体 |
| `FeedPostWidget` | `client/lib/pages/feed/feed.dart`（Feed 流入口） + `client/lib/widget/feedpost.dart`（本体） | 在帖子卡内嵌入 `PollWidget` |
| `PostDetailPage` | `client/lib/pages/post/post_detail_page.dart` | 帖子详情，详情页内嵌 `PollWidget` |
| `ComposePost` | `client/lib/pages/composePost/post.dart` | 创建 / 编辑帖子入口（仅新建支持投票） |
| `PostModel` | `client/lib/model/post.module.dart` | `pollData` 字段 |
| `DraftModel` | `client/lib/model/draft.module.dart` | `pollOptions` 字段 |
| `PostState` / `DraftState` | `client/lib/state/post.state.dart` / `draft.state.dart` | 投票状态管理 + 草稿持久化 |
| `PostService` | `client/lib/services/post_service.dart` | API 客户端（`votePoll` / `getPollResults` / `createPost`） |

---

## 11. 国际化文案

| Key | en | zh | 位置 |
| --- | --- | --- | --- |
| `removePoll` | Remove poll | 移除投票 | `app_localizations.dart:207` |
| `pollEnded` | Poll ended | 投票已结束 | `app_localizations.dart:219` |
| `pollRemainingHours(int)` | N hours left | 剩余 N 小时 | `app_localizations.dart:225` |
| `pollRemainingMinutes(int)` | N minutes left | 剩余 N 分钟 | `app_localizations.dart:231` |
| `pollVotesCount(int)` | N votes | N 票 | `app_localizations.dart:237` |
| `pollYouVoted` | You voted | 你已投票 | `app_localizations.dart:243` |
| `voteFailed`（由 SnackBar 用） | Vote failed | 投票失败 | `app_localizations.dart` 派生 |
| `addOption` | Add option | 添加选项 | `post.dart:1516` |
| `optionLabel(int)` | Option N | 选项 N | `post.dart:1478` |
| `notifyPolls` | Polls | 投票 | `app_localizations.dart` 派生（设置） |

---

## 12. 主题颜色（仅投票卡片用到的字段）

| 色值 | 用途 |
| --- | --- |
| `appColors.surface` | 选项底色 |
| `appColors.surfaceSecondary` | 百分比进度条填充 |
| `appColors.border` | 未投票选项边框（投票中） |
| `appColors.divider` | **已结束**状态下所有选项边框（统一弱化） |
| `appColors.textPrimary` | 已投票选项边框（投票中）+ 文本 |
| `appColors.textMuted` | 未投票 icon + 百分比 + footer 文本 + 已结束 banner 文本/图标 |
| `appColors.destructive` | 编辑器中「移除投票」按钮 |

---

## 13. 快速检索指引

| 需求 | 检索关键词 | 关键位置 |
| --- | --- | --- |
| 修改投票卡片样式 | `_buildResultOption` / `_BuildVotingOption` | `poll_widget.dart:167-281` / `poll_widget.dart:344-413` |
| 修改已结束视觉强化 | `_buildEndedBanner` / `Opacity(0.6)` / `isEnded` token | `poll_widget.dart:181-186, 265-267, 321-341` |
| 修改投票逻辑（防抖 / 失败处理） | `_handleVote` / `_isVoting` | `poll_widget.dart:75-96` |
| 修改乐观更新策略 | `voteOnPoll` | `post.state.dart:361-421` |
| 修改过期判定（增加客户端兜底） | `isExpiredLocally` / `isEnded` | `poll_widget.dart:122-126` |
| 修改百分比算法 | `_computePercentages` | `poll_widget.dart:100-115` |
| 修改倒计时刷新频率 | `Timer.periodic(Duration(seconds: 30))` | `poll_widget.dart:46-50` |
| 修改投票编辑器（增/删选项） | `_togglePollEditor` / `_addPollOption` / `_removePollOption` | `post.dart:261-287` |
| 修改投票编辑器 UI | `_buildPollEditor` | `post.dart:1458-1533` |
| 修改媒体 ↔ 投票互斥 | `_addMedia` / `_togglePollEditor` | `post.dart:241-270` |
| 修改媒体与投票同时限制（详情页） | `hasMedia && post.pollData == null` | `post_detail_page.dart:285` |
| 修改提交时透传字段 | `pollOptions: _getValidPollOptions()` | `post.dart:659` / `post.dart:749-753` |
| 修改草稿恢复 | `_restoreDraft` 的 `pollOptions` 分支 | `post.dart:525-540` |
| 修改投票 API 路径 | `'post/poll/$postId/vote'` / `'post/poll/$postId'` | `post_service.dart:406` / `post_service.dart:681` |
| 修改投票响应字段解析 | `Post.fromJson` 中的 `pollData` 构造 | `post_service.dart:837-851` |
| 修改过期文案 / 通知文案 | `pollEnded` / `pollRemainingHours` / `notifyPolls` | `app_en.arb` / `app_zh.arb` |
| 关闭投票通知 | `notifyPolls: 0` | `user_service.dart:323` / `settings.state.dart:73-74` |

---

## 14. 已知的特殊场景 / 边界

| 场景 | 行为 | 代码位置 |
| --- | --- | --- |
| 用户重复投票同一选项 | 第一道闸：`_isVoting` 防抖；第二道闸：`onTap: null`（物理拒绝） | `poll_widget.dart:76, 375` |
| 投票接口失败 | 状态回滚到 `oldPollData` + SnackBar `voteFailed` | `post.state.dart:412-420` / `poll_widget.dart:87-95` |
| 服务端 `is_expired` 不准（时钟偏差） | 客户端 `isExpiredLocally` 兜底 | `poll_widget.dart:122-123` |
| 投票帖 + 媒体 | 服务端契约不应同时出现；前端 `hasPoll` 判定后跳过媒体 | `feedpost.dart:259-264` / `post_detail_page.dart:285` |
| 编辑投票帖 | 编辑模式 `_isEditing` 时底部工具栏只显示提交按钮（投票 / 媒体 / 草稿全 disable） | `post.dart:1537-1554` |
| 投票帖内发起回复 | `_replyType` / 回复权限仍按帖子自身设置；不影响投票 | `post.dart:802-998`（位置 / 定时 / 回复权限段） |
| `_feedlist` / `_userPosts` 双向同步 | 投票成功后两边都乐观更新；失败时两边都回滚 | `post.state.dart:392-420` |
| `_userPosts` 中无该帖 | `indexWhere` 返回 -1，仅 `_feedlist` 生效 | `post.state.dart:397-399` |
| `postId` 非数字 | `int.tryParse` 返回 null → 直接 `return false`，不发起请求 | `post.state.dart:363-367` |
| `expireTime` 为 null | footer 不显示剩余时间文案（`_formatRemainingTime` 返回 `''`） | `poll_widget.dart:63-71, 297-299` |
| **已结束的视觉强化** | 顶部 banner（`CupertinoIcons.clock` + `pollEnded`）+ 整体 `Opacity(0.6)` + 边框统一 `divider` + 字体回退 `normal` + Semantics 末尾追加"投票已结束" + footer 抑制重复 `pollEnded` | `poll_widget.dart:138, 181-186, 265-267, 297-299, 321-341` |

---

_最后更新：2026-06-16 — 由 Claude 自动化梳理（基于代码静态分析 + openapi_docs 交叉对账）。新增「已结束视觉强化」方案：顶部 banner + 整体 opacity 0.6 + 边框统一 divider + footer 抑制重复文案。_
