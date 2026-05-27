# Phase 0 — 关键 Bug 修复 & 通知页对接

> 目标：修复阻塞性运行时崩溃，将通知页从占位状态升级为可用页面
> 涉及文件：5 个
> 预估工作量：小

---

## 子任务总览

| # | 子任务 | 类型 | 依赖 | 状态 |
|---|-------|------|------|------|
| 0.1 | 修复 ProfileState `late` 变量初始化崩溃 | Bug 修复 | 无 | ✅ 已完成 |
| 0.2 | 为 ProfileState 补充当前登录用户信息获取 | Bug 修复 | 0.1 | ✅ 已完成 |
| 0.3 | 创建 NotificationState 状态管理类 | 新增 | 无 | ✅ 已完成 |
| 0.4 | 注册 NotificationState 到全局 Provider | 新增 | 0.3 | ✅ 已完成 |
| 0.5 | 重写 NotificationPage 对接真实数据 | 重构 | 0.4 | ✅ 已完成 |
| 0.6 | 实现通知筛选按钮交互 | 新增 | 0.5 | ✅ 已完成 |

---

## 子任务 0.1 — 修复 ProfileState `late` 变量初始化崩溃

**状态：✅ 已完成**

### 问题描述

`state/profile.state.dart` 中声明了两个 `late` 变量但从未初始化：

```dart
late String userId;           // 第 17 行
late UserModel _userModel;    // 第 19 行
```

当以下代码被调用时，会触发 `LateInitializationError`：
- `isMyProfile` getter（第 49 行）读取 `userId`
- `followUser()`（第 105 行）读取 `_userModel`、`_profileUserModel`

### 根本原因

`userId` 和 `_userModel` 只在 `_getloggedInUserProfile()` 中赋值，但该方法从未被任何代码调用。`_init()` 只调用了 `_getProfileUser(profileId)`，这只设置了 `_profileUserModel`。

### 修复方案

将 `late` 声明改为可空类型并提供安全默认值：

**文件：`client/lib/state/profile.state.dart`**

1. 将 `late String userId;` 改为 `String? userId;`
2. 将 `late UserModel _userModel;` 改为 `UserModel? _userModel;`
3. 将 getter `userModel => _userModel;` 保持不变（返回可空类型）
4. 将 `isMyProfile` getter 改为安全的 null 比较：

   ```dart
   bool get isMyProfile => userId != null && profileId == userId;
   ```

5. 修复 `followUser()` 中对 `_userModel` 和 `_profileUserModel` 的访问，添加 null 检查：

   ```dart
   if (_userModel == null || _profileUserModel == null) return;
   ```

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/state/profile.state.dart` | 修改 5 处 |

### 验证方式

- 打开他人主页 → 不崩溃
- 访问 `isMyProfile` → 不崩溃（返回 false）
- 调用 `followUser()` → 不崩溃（但因 userId 为 null 直接 return，功能暂不可用，将在 0.2 中完善）

---

**状态：✅ 已完成**

### 问题描述

修复 0.1 后，`followUser()` 因 `userId` 为 null 而直接 return，关注功能仍不可用。需要在 ProfileState 初始化时获取当前登录用户的 ID。

### 实现方案

**文件：`client/lib/state/profile.state.dart`**

1. 在 `_init()` 方法中，先调用 `_getloggedInUserProfile()` 获取当前登录用户信息：

   ```dart
   Future<void> _init() async {
     await _getloggedInUserProfile(profileId);  // 先拿当前用户
     await _getProfileUser(profileId);           // 再拿目标用户资料
   }
   ```

   注意：`_getloggedInUserProfile` 当前接受 `userIdStr` 参数，需要改为从 `AuthState` 的 SharedPreferences 中恢复，或直接调用 `/user/me` 接口。

2. 修改 `_getloggedInUserProfile` 使其不依赖外部参数，改为调用 `authService.getCurrentUser()` 或从本地缓存读取当前用户 ID。

3. 在 `_init` 完成后，`userId` 将被正确赋值，`isMyProfile` 和 `followUser()` 均可正常工作。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/state/profile.state.dart` | 修改 `_init()` 和 `_getloggedInUserProfile()` |

### 验证方式

- 打开自己的主页 → `isMyProfile` 返回 true，显示编辑按钮
- 打开他人主页 → `isMyProfile` 返回 false，关注按钮可点击
- 点击关注按钮 → API 调用成功，UI 更新

---

## 子任务 0.3 — 创建 NotificationState 状态管理类

**状态：✅ 已完成**

### 问题描述

当前通知页没有独立的状态管理类，直接消费 `SearchState.userlist` 作为假数据。需要创建专用的 `NotificationState` 来管理通知列表、筛选、已读状态。

### 实现方案

**新建文件：`client/lib/state/notification.state.dart`**

```dart
class NotificationState extends AppStates {
  // 通知列表
  List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;

  // 筛选类型（null = 全部）
  int? _filterType;  // 1=点赞, 2=回复, 3=关注, 4=提及, 5=转发, 6=引用
  int? get filterType => _filterType;

  // 未读数
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  // 分页
  int _currentPage = 1;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  // 加载通知列表
  Future<void> loadNotifications({bool refresh = false}) { ... }

  // 加载更多（分页）
  Future<void> loadMore() { ... }

  // 设置筛选类型
  Future<void> setFilter(int? type) { ... }

  // 获取未读数
  Future<void> fetchUnreadCount() { ... }

  // 标记已读
  Future<void> markAsRead(List<String> ids) { ... }

  // 标记全部已读
  Future<void> markAllAsRead() { ... }
}
```

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/state/notification.state.dart` | **新建** |

### 验证方式

- NotificationState 可被正常实例化
- `loadNotifications()` 调用 NotificationService 并正确解析响应
- `setFilter()` 清空列表后重新加载

---

## 子任务 0.4 — 注册 NotificationState 到全局 Provider

**状态：✅ 已完成**

### 问题描述

NotificationState 需要在应用启动时注册到 MultiProvider 中，以便 UI 可以通过 `context.watch<NotificationState>()` 消费。

### 实现方案

**文件：`client/lib/main.dart`**

在 `MultiProvider` 的 `providers` 列表中添加：

```dart
ChangeNotifierProvider<NotificationState>(create: (_) => NotificationState()),
```

同时需要导入：

```dart
import 'package:threads/state/notification.state.dart';
```

**文件：`client/lib/pages/home.dart`**

在 `_HomePageState` 的 `initState` 中添加通知初始化：

```dart
void initNotifications() {
  var state = Provider.of<NotificationState>(context, listen: false);
  state.loadNotifications();
  state.fetchUnreadCount();
}
```

在 `initState` 的 `addPostFrameCallback` 中调用 `initNotifications()`。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/main.dart` | 添加 Provider 注册 + import |
| `client/lib/pages/home.dart` | 添加通知初始化调用 + import |

### 验证方式

- 应用启动不报错
- NotificationState 可在任意页面通过 `Provider.of<NotificationState>(context)` 访问
- 进入通知页时数据已预加载

---

## 子任务 0.5 — 重写 NotificationPage 对接真实数据

**状态：✅ 已完成**

### 问题描述

当前 `NotificationPage` 存在以下问题：
1. 消费 `SearchState` 而非 `NotificationState`
2. 列表固定 200px 高度，无法滚动
3. 使用 `UserTilePage`（用户列表组件）渲染，不匹配通知数据结构
4. 无加载状态、无空状态

### 实现方案

**文件：`client/lib/pages/notification/notification.dart`**

完全重写 `NotificationPage`：

1. 将 `Provider.of<SearchState>` 替换为 `Provider.of<NotificationState>`
2. 移除固定 200px 高度限制，改为 `Expanded` + `ListView.builder`
3. 为每种通知类型（点赞/回复/关注/提及/转发/引用）设计对应的列表项 Widget
4. 添加下拉刷新（`RefreshIndicator`）
5. 添加上拉加载更多（分页）
6. 添加加载中状态（CircularProgressIndicator）
7. 添加空状态展示
8. 点击通知项时标记为已读（更新已读状态）

**通知列表项设计**：

| 通知类型 | 图标 | 展示内容 |
|---------|------|---------|
| 点赞 (1) | ❤️ | "{用户名} 赞了你的帖子" |
| 回复 (2) | 💬 | "{用户名} 回复了你：{摘要}" |
| 关注 (3) | 👤 | "{用户名} 关注了你" |
| 提及 (4) | @ | "{用户名} 在帖子中提及了你" |
| 转发 (5) | 🔄 | "{用户名} 转发了你的帖子" |
| 引用 (6) | ❝ | "{用户名} 引用了你的帖子" |

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/pages/notification/notification.dart` | **重写** |

### 验证方式

- 通知页展示真实 API 数据
- 下拉刷新正常
- 上拉加载更多分页正常
- 未读通知有视觉区分
- 空状态有友好提示

---

## 子任务 0.6 — 实现通知筛选按钮交互

**状态：✅ 已完成**

### 问题描述

当前通知页顶部有 4 个筛选按钮（全部/回复/提及/验证），但点击无效果（`onTap` 被注释掉）。

### 实现方案

**文件：`client/lib/pages/notification/notification.dart`**

1. 将筛选按钮改为可交互状态：

   ```dart
   Widget filterButton(String text, int? type, NotificationState state) {
     final isActive = state.filterType == type;
     return GestureDetector(
       onTap: () => state.setFilter(type),
       child: Container(
         // 根据 isActive 改变背景色
         decoration: BoxDecoration(
           color: isActive ? Colors.white : Colors.black,
           // ...
         ),
         child: Text(
           text,
           style: TextStyle(
             color: isActive ? Colors.black : Colors.white,
           ),
         ),
       ),
     );
   }
   ```

2. 筛选按钮映射：
   - "全部" → `type: null`
   - "回复" → `type: 2`
   - "提及" → `type: 4`
   - "验证" → `type: 3`（关注）或可改为其他类型

3. 点击后 `NotificationState.setFilter()` 会清空列表并重新请求 API。

### 涉及文件

| 文件 | 改动 |
|------|------|
| `client/lib/pages/notification/notification.dart` | 修改筛选按钮逻辑 |

### 验证方式

- 点击筛选按钮后，按钮高亮切换
- 列表刷新为对应类型的通知
- "全部"按钮恢复所有通知

---

## 执行顺序与依赖关系

```
0.1 ProfileState late 修复 ──→ 0.2 补充用户信息获取
                                    │
                                    ↓
                              （关注功能可用）

0.3 创建 NotificationState ──→ 0.4 注册到 Provider ──→ 0.5 重写通知页 ──→ 0.6 筛选按钮
```

0.1-0.2 与 0.3-0.6 之间无依赖，可并行开发。

---

## 完成标准

- [ ] 打开他人主页不崩溃
- [ ] 关注/取关按钮功能正常
- [ ] 通知页展示真实 API 数据
- [ ] 通知筛选按钮可用
- [ ] 通知分页加载正常
- [ ] 无新增 lint warning
