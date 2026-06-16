# UserAvatarWithFollow（带头像关注加号的复用组件）— 代码定位

> 本文档汇总 iOS 客户端可复用组件 `UserAvatarWithFollow` 的所有源代码位置，含组件本体、显示判定、PostModel 字段扩展、PostState 乐观更新逻辑、FeedPostWidget 集成点，以及未来可复用的模块清单。
>
> 后续若收到「在 X 页面加关注按钮 / 把某个 UserCard 改成带头像加号 / 修改关注后 UI 反馈」类需求，先查阅本文档；未覆盖到的细节再执行 `Glob` / `Grep` 检索。
>
> 最后更新：2026-06-16

---

## 1. 核心组件

### 1.1 组件入口

- **路径**：`client/lib/widget/user_avatar_with_follow.dart`
- **类**：
  - `class UserAvatarWithFollow extends StatefulWidget`（新文件）
  - `class _UserAvatarWithFollowState extends State<UserAvatarWithFollow>`（新文件）
- **设计目标**：在 Feed / 搜索结果 / 关注列表 / 用户卡片等任意模块中复用同一组件，统一关注加号的展示与交互。**组件自身不持有业务状态**——`isFollowing` 由调用方传入，`onFollow` 由调用方注入。

### 1.2 构造参数

| 字段 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `avatarUrl` | `String` | ✓ | — | 头像 URL；空串走 `Icons.person` 占位 |
| `size` | `double` | ✗ | `35` | 头像直径 |
| `userId` | `int?` | ✗ | `null` | 作者 userId；`null` 时不显示加号 |
| `currentUserId` | `int?` | ✗ | `null` | 当前登录 userId；等于 `userId` 时不显示加号 |
| `isFollowing` | `bool?` | ✗ | `null` | `true` → 不显示；`null`/`false` → 显示 |
| `onAvatarTap` | `VoidCallback?` | ✗ | `null` | 点击头像回调 |
| `onFollow` | `Future<void> Function()?` | ✗ | `null` | 点击加号回调；组件 `await` 后失败时加号是否消失由调用方控制 |
| `userName` | `String?` | ✗ | `null` | 用户显示名，用于无障碍朗读 |

### 1.3 内部状态

| 字段 | 说明 |
| --- | --- |
| `bool _isLoading` | 防止用户在网络请求未返回时重复点击；`_isLoading=true` 时加号 `Opacity: 0.6` 并关闭 `onTap` |

### 1.4 关键方法

| 方法 | 作用 |
| --- | --- |
| `bool get _shouldShowFollow` | 三道闸门 + `isFollowing` 判定（详见 §2） |
| `Future<void> _handleFollowTap()` | 调 `onFollow` 回调；管理 `_isLoading`；`mounted` 守卫；`catch` 内不弹 toast（错误处理交由 PostState / 上层 UI） |

---

## 2. 显示判定（三道闸门）

`UserAvatarWithFollow` 内私有 getter `_shouldShowFollow`（`user_avatar_with_follow.dart`），**仅当全部满足时**渲染加号：

```dart
bool get _shouldShowFollow =>
    widget.userId != null &&                 // 闸门 1: 作者 ID 已知
    widget.currentUserId != null &&          // 闸门 2: 当前用户 ID 已知
    widget.userId != widget.currentUserId && // 闸门 3: 不是自己
    widget.isFollowing != true;              // 闸门 4: null/false 都视为「未关注」
```

> ⚠️ 当前 API `/post/feed` 不返回 `is_following` 字段，PostModel.isFollowing 始终为 null（首次进入 Feed 时全部显示加号）；关注成功后由 PostState 乐观更新为 true。

---

## 3. PostModel 字段扩展

**文件**：`client/lib/model/post.module.dart`

| 修改点 | 行号 | 内容 |
| --- | --- | --- |
| 字段声明 | `post.module.dart:106` | `bool? isFollowing;`（含「本地字段、API 不返回」注释） |
| 构造器 | `post.module.dart:153` | `this.isFollowing,` |
| `fromJson` | `post.module.dart:236` | `isFollowing: _parseBool(map['isFollowing'] ?? map['is_following']),` |
| `toJson` | `post.module.dart:288` | `'is_following': isFollowing,` |
| `copyWith` 参数 | `post.module.dart:332` | `bool? isFollowing,` |
| `copyWith` 赋值 | `post.module.dart:374` | `isFollowing: isFollowing ?? this.isFollowing,` |

---

## 4. PostState 扩展

**文件**：`client/lib/state/post.state.dart`

### 4.1 FollowService 注入

| 修改点 | 行号 | 内容 |
| --- | --- | --- |
| 导入 | `post.state.dart:8` | `import 'package:threads/services/follow_service.dart';` |
| lazy 字段 | `post.state.dart:81` | `FollowService? _followService;` |
| lazy getter | `post.state.dart:93-96` | `FollowService get followService { ... }`（仿 `postService` / `uploadService` 模式） |

### 4.2 Follow / Unfollow 方法

| 方法 | 行号 | 行为 |
| --- | --- | --- |
| `Future<void> followPostAuthor(String postId, int userId)` | `post.state.dart:637-646` | ① `_setFollowing(postId, true)`；② `await followService.followUser(userId)`；③ 失败回滚 + `rethrow` |
| `Future<void> unfollowPostAuthor(String postId, int userId)` | `post.state.dart:649-658` | 同上，方向相反 |
| `void _setFollowing(String postId, bool value)` | `post.state.dart:660-666` | 在 `_feedlist` 按 `key` 或 `postId` 查找，`copyWith(isFollowing: value)` + `notifyListeners()` |

**为什么放在 PostState 而不是新建 FollowState**：
- Feed 列表只订阅 `PostState`，组件复用最经济；
- 与 `likePost / unlikePost / savePost / unsavePost` 同模式同文件，认知成本最低；
- 未来 SearchState / ProfileState 需 toggle 时可复刻相同结构。

### 4.3 不需要修改的复用

| 已存在 | 路径 | 说明 |
| --- | --- | --- |
| `FollowService.followUser(int userId)` | `services/follow_service.dart:18-24` | `POST /follow/{userId}` |
| `FollowService.unfollowUser(int userId)` | `services/follow_service.dart:26-32` | `DELETE /follow/{userId}` |

---

## 5. FeedPostWidget 集成点

**文件**：`client/lib/widget/feedpost.dart`

| 修改点 | 行号 | 内容 |
| --- | --- | --- |
| 导入 | `feedpost.dart:20` | `import 'package:threads/widget/user_avatar_with_follow.dart';` |
| 派生 `currentUserId` | `feedpost.dart:132-135` | `int.tryParse(Provider.of<AuthState>(context, listen: false).userId)`（在 `build` 顶部派生区，紧跟 `quotePost` 后） |
| 替换头部头像 | `feedpost.dart:184-203` | 用 `UserAvatarWithFollow(...)` 替换原 `GestureDetector(onTap: _navigateToProfile, child: avatar(profilePic, 35))` |
| `onFollow` 实现 | `feedpost.dart:192-202` | `Provider.of<PostState>(context, listen: false).followPostAuthor(widget.postModel.id, authorId)` + `try/catch`（空 catch——回滚由 PostState 负责） |
| `_isOwnPost` 逻辑 | `feedpost.dart:1221-1223` | **未改动**（组件内部已自行判断） |
| 引用卡头像 | `feedpost.dart:728-762` | **未集成**——首版不改动（详见 §8.1） |

---

## 6. 国际化键

| 文件 | 行号 | 键 | 文案 |
| --- | --- | --- | --- |
| `client/lib/l10n/app_zh.arb` | `app_zh.arb:161` | `followUser` | `关注 {username}`（ICU 占位符） |
| `client/lib/l10n/app_en.arb` | `app_en.arb:161` | `followUser` | `Follow {username}` |

**用法**：`AppLocalizations.of(context)!.followUser(userName ?? '')`，组件内部 `Semantics` 已封装。

---

## 7. 复用点（待开发）

未来可在以下模块中以**相同 API** 接入 `UserAvatarWithFollow`：

| 候选位置 | 当前头像代码 | 替换方案 |
| --- | --- | --- |
| `client/lib/pages/search/search.dart` 搜索结果用户行 | `SearchPostTile` / `UserTilePage` 中的 `CachedNetworkImage`（约 `search.dart:286/362`） | 包一层 `UserAvatarWithFollow(userId, currentUserId, isFollowing, onFollow: SearchState.toggleFollow)` |
| `client/lib/pages/follow/follow_list_page.dart` 关注/粉丝列表 | `UserTilePage` / 自定义 `UserCard`（约 `follow_list_page.dart:166/171/225/230`） | 同上，onFollow 走 `FollowListState` 或 `PostState.toggle` |
| `client/lib/widget/user_card.dart` 56×56 推荐用户卡 | `user_card.dart:38-65` | 替换为 `UserAvatarWithFollow(size: 56, ...)`；移除卡片右侧独立"关注/已关注"按钮（避免重复） |
| 评论 / 回复中的作者头像 | `client/lib/widget/reply_bottom_sheet.dart`（未确认） | 同上 |
| 引用卡片作者头像 | `client/lib/widget/feedpost.dart:728-762` | 详见 §8.1 |

---

## 8. 风险与边界

### 8.1 引用卡作者头像暂不集成

`feedpost.dart:728-762` 的引用卡片（quote card）头像**首版不集成加号**。理由：
- 引用作者往往不是帖子作者，加号 UI 与「我是不是这条帖子的发布者」判断混在一起，UX 易混淆；
- 引用卡作者 userId 与帖子作者 userId 不同时，follow 谁的产品语义需后端确认（可能只允许 follow 一级作者）。

二期方案：把 `userId` 传引用卡作者而非帖子作者；并增加 `quotedUser?.isFollowing` 字段。

### 8.2 加号 vs 头像点击冲突

- 组件 `Stack` 顶层 `Positioned` 单独包 `GestureDetector` + `HitTestBehavior.opaque`，仅响应加号圆内的点击；
- 底层头像 `GestureDetector` 仅响应 Stack 范围内「加号之外」的区域；
- 实测 0.36× 比例下两区域无重叠。

### 8.3 列表快速滚动复用

- `UserAvatarWithFollow` 是 Stateful，每张卡 new 一个 State，`_isLoading` 互不干扰；
- PostModel 是 `isFollowing` 的真理来源——Feed 拉新数据时 `fromJson` 重新填充即覆盖乐观更新，无须额外处理；
- 复用 widget 时 Flutter 仅复用 Element 不复用 State（`createState` 会再走一次），无需手动 reset `_isLoading`。

### 8.4 跨 State 同步

- SearchState / ProfileState 持有的同一作者 PostModel **不接收** PostState 的乐观更新（MVP 已知问题）；
- 二期方案：`PostState` 维护 `Map<int, bool> _followingOverride`（按 userId 索引），所有 PostModel 在 `copyWith` 前查此 map。

### 8.5 `onFollow` 异步期间重复点击

- 组件内部 `_isLoading` 标志位 + `Opacity(0.6)` 视觉降权；
- `_handleFollowTap` 入口判断 `if (_isLoading) return`（双道闸门）。

### 8.6 PostState 失败的错误反馈

- 当前 FeedPostWidget 中 `onFollow` 用 `try/catch (_) {}` 空 catch，依赖 PostState 自动回滚；
- 若未来需要给用户提示，可在此处加 `ScaffoldMessenger.of(context).showSnackBar(...)`（注意 `context.mounted` 检查）。

---

## 9. 验收要点

- [ ] Feed 头部头像右下方出现蓝底白 `+` 加号
- [ ] 当前用户自己的帖子不显示加号
- [ ] 点击加号 → 加号消失（PostModel.isFollowing 乐观更新为 true）
- [ ] 模拟接口失败（临时改 FollowService 抛错）→ 加号回滚重新显示
- [ ] `docs/code-locations/user-avatar-with-follow.md` 可被新开发者快速参考
- [ ] `CLAUDE.md` 「现有清单」末尾出现本条引用
