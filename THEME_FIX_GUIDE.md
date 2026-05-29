# 主题外观适配 — 页面清单与修复规范

## 第一部分：页面清单与适配状态

> 状态说明：✅ 已适配 | ❌ 未适配 | ⚠️ 部分适配

---

### 1. 认证模块（Auth）

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ❌ | `lib/auth/onboard/follow.dart` | 注册引导 — 关注 Instagram 好友 |
| ❌ | `lib/auth/onboard/privacy.dart` | 注册引导 — 隐私设置选择 |
| ❌ | `lib/auth/onboard/thread.dart` | 注册引导 — Threads 工作原理说明 |
| ❌ | `lib/auth/signup/account.dart` | 切换账号页 |
| ❌ | `lib/auth/signup/email.dart` | 邮箱+密码注册表单 |
| ❌ | `lib/auth/signup/name.dart` | 用户名+密码登录页 |
| ❌ | `lib/auth/signup/register.dart` | 注册信息填写页 |
| ❌ | `lib/auth/signup/signup.dart` | 注册流程中的个人资料定制页 |

---

### 2. 首页 / 信息流模块

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ✅ | `lib/pages/home.dart` | 主框架 — 底部导航栏 + Tab 容器 |
| ✅ | `lib/pages/feed/feed.dart` | 信息流 Tab 页 |
| ✅ | `lib/common/splash.dart` | 启动页 / 登录路由 |

---

### 3. 搜索模块

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ✅ | `lib/pages/search/search.dart` | 搜索页（用户/话题/帖子 Tab） |

---

### 4. 通知 / 活动模块

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ✅ | `lib/pages/notification/notification.dart` | 通知列表页 + 筛选栏 |

---

### 5. 消息模块

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ✅ | `lib/pages/message/message_page.dart` | 消息收件箱 Tab 页 |
| ❌ | `lib/pages/message/chat_detail_page.dart` | 一对一聊天详情页 |
| ❌ | `lib/pages/message/chat_bubble.dart` | 聊天气泡组件 |
| ❌ | `lib/pages/message/message_list_tile.dart` | 会话列表项组件 |
| ❌ | `lib/pages/message/reaction_picker.dart` | 表情回应选择器 |
| ❌ | `lib/pages/message/create_group_page.dart` | 创建群聊页 |
| ❌ | `lib/pages/message/group_chat_detail_page.dart` | 群聊详情/设置页 |
| ❌ | `lib/pages/message/group_members_page.dart` | 群成员列表页 |
| ❌ | `lib/pages/message/join_requests_page.dart` | 入群申请审批页 |

---

### 6. 个人资料模块

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ✅ | `lib/pages/profile/myprofile.dart` | 我的资料 Tab 页 |
| ❌ | `lib/pages/profile/profile.dart` | 他人资料页 |
| ❌ | `lib/pages/profile/edit.dart` | 编辑资料页 |

---

### 7. 帖子模块

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ❌ | `lib/pages/composePost/post.dart` | 发帖/编辑帖页面 |
| ❌ | `lib/pages/composePost/widget/composeBottomIconWidget.dart` | 发帖底部工具栏图标 |
| ❌ | `lib/pages/post/post_detail_page.dart` | 帖子详情 + 回复列表页 |
| ❌ | `lib/pages/post/reply_review_page.dart` | 回复审核页（待审回复列表） |
| ❌ | `lib/pages/post/guest_reply_review_page.dart` | 访客回复审核页 |
| ❌ | `lib/pages/post/saved_posts_page.dart` | 收藏帖子列表页 |
| ❌ | `lib/pages/post/scheduled_posts_page.dart` | 定时帖子列表页 |

---

### 8. 社区模块

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ❌ | `lib/pages/community/community_list_page.dart` | 社区浏览/列表页 |
| ❌ | `lib/pages/community/community_detail_page.dart` | 社区详情页（帖子/成员 Tab） |
| ❌ | `lib/pages/community/community_members_page.dart` | 社区成员列表页 |

---

### 9. 话题模块

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ❌ | `lib/pages/topic/topic_detail_page.dart` | 话题详情页（帖子列表） |

---

### 10. 设置子页面

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ⚠️ | `lib/common/settings.dart` | 设置主页（大部分已适配，图标颜色未适配） |
| ❌ | `lib/common/settings/notification_settings.dart` | 通知设置页 |
| ❌ | `lib/common/settings/privacy_settings.dart` | 隐私设置页 |
| ❌ | `lib/common/settings/hidden_words_page.dart` | 隐藏词汇设置页 |
| ❌ | `lib/common/settings/collections_page.dart` | 收藏集管理页 |
| ❌ | `lib/common/settings/links_page.dart` | 社交链接管理页 |
| ❌ | `lib/common/settings/relation_control_page.dart` | 屏蔽/限制/静音管理页 |

---

### 11. 通用组件

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ✅ | `lib/widget/feedpost.dart` | 信息流帖子卡片 |
| ✅ | `lib/widget/list.dart` | 用户列表项 |
| ✅ | `lib/widget/topic_tile.dart` | 话题标签项 |
| ✅ | `lib/widget/search_post_tile.dart` | 搜索帖子项 |
| ✅ | `lib/widget/poll_widget.dart` | 投票组件 |
| ❌ | `lib/widget/reply_bottom_sheet.dart` | 回复底部弹窗 |
| ❌ | `lib/widget/edit_history_sheet.dart` | 编辑历史底部弹窗 |
| ❌ | `lib/widget/draft_list_sheet.dart` | 草稿列表底部弹窗 |

---

### 12. 相机模块

| 状态 | 文件路径 | 说明 |
|------|----------|------|
| ❌ | `lib/pages/camera/camera.dart` | 相机拍摄页（可考虑保持深色） |

---

### 汇总统计

| 模块 | 总文件数 | 已适配 | 未适配 |
|------|----------|--------|--------|
| 认证模块 | 8 | 0 | 8 |
| 首页/信息流 | 3 | 3 | 0 |
| 搜索模块 | 1 | 1 | 0 |
| 通知模块 | 1 | 1 | 0 |
| 消息模块 | 8 | 1 | 7 |
| 个人资料 | 3 | 1 | 2 |
| 帖子模块 | 7 | 0 | 7 |
| 社区模块 | 3 | 0 | 3 |
| 话题模块 | 1 | 0 | 1 |
| 设置子页面 | 7 | 0 | 7 |
| 通用组件 | 8 | 5 | 3 |
| 相机模块 | 1 | 0 | 1 |
| **合计** | **51** | **12** | **39** |

---

## 第二部分：主题适配修复执行规范

### 2.1 核心原则

1. **每个文件独立完成**：一次处理一个文件，处理完确认无编译错误后再进入下一个。
2. **最小改动原则**：只替换颜色相关代码，不重构逻辑、不改变布局、不修改功能。
3. **深色模式零回归**：所有替换必须保证深色模式下的视觉效果与改动前完全一致。

### 2.2 标准操作步骤

对每个文件执行以下 4 步：

**Step 1 — 添加 import**

在文件顶部添加：
```dart
import 'package:threads/theme/app_colors.dart';
```

**Step 2 — 在 build() 方法开头获取 appColors**

在 `Widget build(BuildContext context)` 方法的第一行添加：
```dart
final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
```

- 对于 `StatelessWidget`，放在 `build()` 方法内。
- 对于 `StatefulWidget`，同样放在 `build()` 方法内（不要放在 `initState` 中，因为 context 不可用）。
- 如果一个文件中有多个独立的 `build()` 方法（如私有 widget 类），每个 `build()` 中都要独立获取。
- 如果 build 方法中已经存在 `appColors` 变量，则跳过此步。

**Step 3 — 按颜色映射表逐一替换**

使用下表的映射关系替换所有硬编码颜色：

| 原始值 | 替换为 | 语义说明 |
|--------|--------|----------|
| `Colors.black`（作为背景色） | `appColors.background` | 页面/容器主背景 |
| `Colors.white`（作为文字色） | `appColors.textPrimary` | 主要文字 |
| `Colors.grey` | `appColors.textSecondary` | 次要文字 |
| `Colors.grey[400]` ~ `Colors.grey[600]` | `appColors.textSecondary` | 次要文字/图标 |
| `Colors.grey[700]` ~ `Colors.grey[900]` | `appColors.surface` | 深色表面/占位背景 |
| `Colors.grey[500]` | `appColors.textMuted` | 弱化文字（时间戳等） |
| `Colors.blue` | `appColors.accent` | 强调色（CTA/关注） |
| `Colors.red` | `appColors.destructive` | 破坏性操作/错误 |
| `Colors.green` | `appColors.repost` | 转发/成功状态 |
| `Color(0xff1a1a1a)` | `appColors.surface` | 卡片/输入框/弹窗背景 |
| `Color(0xff222222)` | `appColors.surfaceSecondary` | 次级表面 |
| `Color(0xff333333)` / `Color.fromARGB(255, 46, 46, 46)` | `appColors.divider` | 分割线 |
| `Color(0xff444444)` | `appColors.dividerSecondary` | 次级分割线 |
| `Color(0xff555555)` | `appColors.textHint` | 提示文字 |
| `Color(0xff888888)` | `appColors.textMuted` | 弱化文字 |
| `Color.fromARGB(255, 22, 22, 22)` ~ `Color.fromARGB(255, 25, 25, 25)` | `appColors.surface` | 输入框/编辑区背景 |
| `Color.fromARGB(255, 28, 28, 30)` | `appColors.surfaceSecondary` | iOS 风格弹窗背景 |
| `Color.fromARGB(255, 29, 29, 29)` ~ `Color.fromARGB(255, 30, 30, 30)` | `appColors.surfaceTertiary` | 工具栏/编辑区背景 |
| `Color.fromARGB(255, 69, 69, 69)` | `appColors.dividerSecondary` | 列表分割线 |
| `Color.fromARGB(255, 78, 78, 78)` | `appColors.textHint` | 时间戳 |
| `Color.fromARGB(255, 112, 112, 112)` | `appColors.textHint` | 提示文字 |

**Step 4 — 处理特殊模式**

以下特殊模式需要额外注意：

| 模式 | 处理方式 |
|------|----------|
| `CupertinoThemeData(brightness: Brightness.dark)` | 替换为：`CupertinoThemeData(brightness: Theme.of(context).brightness)` |
| `keyboardAppearance: Brightness.dark` | 替换为：`keyboardAppearance: Theme.of(context).brightness` |
| `Colors.transparent` | **保持不变**，透明色不受主题影响 |
| `Colors.white.withOpacity(0.3)` 等半透明 | 根据语义替换为 `appColors.xxx.withOpacity(...)` |
| `Colors.black` 作为 SnackBar 背景等局部用途 | 根据语义替换为 `appColors.background` 或 `appColors.surface` |

### 2.3 不需要替换的情况

以下情况 **不需要** 替换：

1. **`Colors.transparent`** — 透明色与主题无关。
2. **`Colors.white`/`Colors.black` 作为图片占位/错误占位** — 这些通常不影响主题观感，可以保留。但如果占位区域较大（如大图 loading），建议替换。
3. **`Colors.black` 用于遮罩层（Overlay）** — 如 `showGeneralDialog` 的 barrier color，属于全局遮罩，可保留。
4. **动画/过渡中的颜色** — 如果是短暂的过渡动画效果，可保留。
5. **相机页面** — 相机预览通常保持深色，可暂不处理。

### 2.4 推荐处理顺序

按用户可见度和使用频率排序，建议按以下模块顺序依次处理：

1. **通用组件**（3 个）→ 被 6 个模块复用，优先级最高
   - `reply_bottom_sheet.dart`
   - `edit_history_sheet.dart`
   - `draft_list_sheet.dart`
2. **帖子模块**（7 个）→ 核心功能，用户停留时间最长
3. **个人资料模块**（2 个）→ 高频访问页面
4. **消息模块**（7 个）→ 次核心功能
5. **设置子页面**（6 + 1 部分）→ 深层页面
6. **社区模块**（3 个）→ 独立功能模块
7. **话题模块**（1 个）
8. **认证模块**（8 个）→ 仅注册/登录时可见
9. **相机模块**（1 个）→ 可选

### 2.5 验证清单

每个文件处理完成后，确认以下项目：

- [ ] `dart analyze <file>` 无新增 error
- [ ] 深色模式下视觉效果与改动前一致（无回归）
- [ ] 浅色模式下文字可读（无白底白字或白底浅灰字）
- [ ] 浅色模式下背景层次分明（非全白无层次）
- [ ] `CupertinoThemeData` 的 brightness 已动态化
- [ ] `keyboardAppearance` 已动态化（如有）

---

## 第三部分：分阶段执行计划

> 每个步骤为一个独立可交付的功能模块，完成后可单独验证、不依赖后续步骤。
> 每个步骤内按文件逐一处理，处理完一个文件确认 `dart analyze` 通过后再处理下一个。

---

### 步骤 A：通用共享组件（3 个文件）

**依赖**：无（被其他所有模块依赖，优先处理）

| 序号 | 文件 | 说明 | 复用方 |
|------|------|------|--------|
| A1 | `lib/widget/reply_bottom_sheet.dart` | 回复底部弹窗（回复列表 + 输入框） | 帖子详情页、FeedPostWidget |
| A2 | `lib/widget/edit_history_sheet.dart` | 编辑历史底部弹窗 | FeedPostWidget |
| A3 | `lib/widget/draft_list_sheet.dart` | 草稿列表底部弹窗 | 发帖页 |

**验证方式**：在信息流中点击帖子 → 打开回复弹窗、编辑历史弹窗、草稿弹窗，确认深色/浅色模式均正常。

---

### 步骤 B：帖子核心模块（7 个文件）

**依赖**：步骤 A（reply_bottom_sheet 等）

| 序号 | 文件 | 说明 |
|------|------|------|
| B1 | `lib/pages/post/post_detail_page.dart` | 帖子详情 + 回复列表页（核心页面） |
| B2 | `lib/pages/composePost/post.dart` | 发帖/编辑帖页面（核心页面） |
| B3 | `lib/pages/composePost/widget/composeBottomIconWidget.dart` | 发帖底部工具栏图标组件 |
| B4 | `lib/pages/post/reply_review_page.dart` | 回复审核页 |
| B5 | `lib/pages/post/guest_reply_review_page.dart` | 访客回复审核页 |
| B6 | `lib/pages/post/saved_posts_page.dart` | 收藏帖子列表页 |
| B7 | `lib/pages/post/scheduled_posts_page.dart` | 定时帖子列表页 |

**验证方式**：信息流 → 点击帖子进入详情页 → 切换主题 → 确认详情页、回复列表、发帖页、收藏列表等均正确响应。

**注意事项**：
- B2 `composePost/post.dart` 有 `keyboardAppearance: Brightness.dark` 和大量 `Color.fromARGB` 需逐一替换。
- B2 有投票编辑器、位置选择器等复杂子组件，需确保弹窗背景色也适配。

---

### 步骤 C：个人资料模块（2 个文件）

**依赖**：无

| 序号 | 文件 | 说明 |
|------|------|------|
| C1 | `lib/pages/profile/profile.dart` | 他人资料页（高频访问） |
| C2 | `lib/pages/profile/edit.dart` | 编辑资料页 |

**验证方式**：搜索页点击用户 → 进入他人资料页 → 切换主题 → 确认资料页、编辑资料页均正确响应。

**注意事项**：
- C2 `edit.dart` 有 3 处 `CupertinoThemeData(brightness: Brightness.dark)` 需动态化。
- C2 有多段 TextField 装饰器（`InputDecoration`），需替换 `fillColor`、`border` 颜色。

---

### 步骤 D：消息模块 — 聊天核心（4 个文件）

**依赖**：无

| 序号 | 文件 | 说明 |
|------|------|------|
| D1 | `lib/pages/message/message_list_tile.dart` | 会话列表项组件 |
| D2 | `lib/pages/message/chat_detail_page.dart` | 一对一聊天详情页 |
| D3 | `lib/pages/message/chat_bubble.dart` | 聊天气泡组件 |
| D4 | `lib/pages/message/reaction_picker.dart` | 表情回应选择器 |

**验证方式**：消息 Tab → 点击会话进入聊天页 → 发送消息 → 添加表情回应 → 切换主题 → 确认所有元素正确响应。

**注意事项**：
- D3 `chat_bubble.dart` 中发送方/接收方气泡颜色不同，需分别映射。
- D2 `chat_detail_page.dart` 有输入框、AppBar、背景色等多个区域需适配。

---

### 步骤 E：消息模块 — 群聊功能（4 个文件）

**依赖**：步骤 D（复用 chat_bubble 等）

| 序号 | 文件 | 说明 |
|------|------|------|
| E1 | `lib/pages/message/create_group_page.dart` | 创建群聊页 |
| E2 | `lib/pages/message/group_chat_detail_page.dart` | 群聊详情/设置页 |
| E3 | `lib/pages/message/group_members_page.dart` | 群成员列表页 |
| E4 | `lib/pages/message/join_requests_page.dart` | 入群申请审批页 |

**验证方式**：消息 Tab → 创建群聊 → 进入群详情 → 查看成员/申请列表 → 切换主题确认。

---

### 步骤 F：设置子页面（7 个文件）

**依赖**：无（独立深层页面，互不影响）

| 序号 | 文件 | 说明 |
|------|------|------|
| F1 | `lib/common/settings.dart`（收尾） | 设置主页 — 修复残留的 `Colors.grey` 图标颜色 |
| F2 | `lib/common/settings/notification_settings.dart` | 通知开关设置页 |
| F3 | `lib/common/settings/privacy_settings.dart` | 隐私/回复/提及设置页 |
| F4 | `lib/common/settings/hidden_words_page.dart` | 隐藏词汇设置页 |
| F5 | `lib/common/settings/collections_page.dart` | 收藏集管理页 |
| F6 | `lib/common/settings/links_page.dart` | 社交链接管理页 |
| F7 | `lib/common/settings/relation_control_page.dart` | 屏蔽/限制/静音管理页 |

**验证方式**：设置页 → 逐个进入各子页面 → 切换主题 → 确认开关、列表、输入框等均正确响应。

**注意事项**：
- 这 7 个文件结构相似（Scaffold + AppBar + ListView），都包含开关组件（`Switch`）和列表项，模式统一，处理效率高。
- F2~F7 中 `Switch` 的 thumb/track 颜色如果是硬编码的，也需替换。

---

### 步骤 G：社区模块（3 个文件）

**依赖**：无

| 序号 | 文件 | 说明 |
|------|------|------|
| G1 | `lib/pages/community/community_list_page.dart` | 社区浏览列表页 |
| G2 | `lib/pages/community/community_detail_page.dart` | 社区详情页（帖子/成员 Tab） |
| G3 | `lib/pages/community/community_members_page.dart` | 社区成员列表页 |

**验证方式**：搜索页/消息页进入社区 → 浏览社区列表 → 进入社区详情 → 查看成员列表 → 切换主题确认。

---

### 步骤 H：话题模块（1 个文件）

**依赖**：无

| 序号 | 文件 | 说明 |
|------|------|------|
| H1 | `lib/pages/topic/topic_detail_page.dart` | 话题详情页（帖子列表） |

**验证方式**：搜索页点击话题标签 → 进入话题详情 → 切换主题确认。

---

### 步骤 I：认证模块（8 个文件）

**依赖**：无（仅在注册/登录时可见，使用频率低）

| 序号 | 文件 | 说明 |
|------|------|------|
| I1 | `lib/auth/signup/name.dart` | 登录页（用户名+密码） |
| I2 | `lib/auth/signup/email.dart` | 注册页（邮箱+密码） |
| I3 | `lib/auth/signup/register.dart` | 注册信息填写页 |
| I4 | `lib/auth/signup/signup.dart` | 个人资料定制页 |
| I5 | `lib/auth/signup/account.dart` | 切换账号页 |
| I6 | `lib/auth/onboard/thread.dart` | 引导页 — Threads 说明 |
| I7 | `lib/auth/onboard/privacy.dart` | 引导页 — 隐私选择 |
| I8 | `lib/auth/onboard/follow.dart` | 引导页 — 关注好友 |

**验证方式**：退出登录 → 重新注册/登录 → 逐步浏览每个认证页面 → 切换主题确认。

**注意事项**：
- I4 `signup.dart` 有 `CupertinoThemeData(brightness: Brightness.dark)`。
- I2 `email.dart` 有 `keyboardAppearance: Brightness.dark`。
- 认证页面通常有品牌色的 CTA 按钮（如"注册"按钮），需确认浅色模式下可读。

---

### 步骤 J：相机模块（1 个文件，可选）

**依赖**：无

| 序号 | 文件 | 说明 |
|------|------|------|
| J1 | `lib/pages/camera/camera.dart` | 相机拍摄页 |

**说明**：相机预览通常保持深色主题以获得最佳取景体验，此步骤为可选。如果需要适配，主要替换叠加层文字和按钮的颜色。

---

### 执行依赖关系图

```
步骤 A（通用组件）
  ↓
步骤 B（帖子模块）
  （独立）→ 步骤 C（个人资料）
  （独立）→ 步骤 D（消息-聊天）→ 步骤 E（消息-群聊）
  （独立）→ 步骤 F（设置子页面）
  （独立）→ 步骤 G（社区）
  （独立）→ 步骤 H（话题）
  （独立）→ 步骤 I（认证）
  （独立）→ 步骤 J（相机，可选）
```

### 文件总量统计

| 步骤 | 模块 | 文件数 | 优先级 |
|------|------|--------|--------|
| A | 通用共享组件 | 3 | P0 — 其他模块依赖 |
| B | 帖子核心模块 | 7 | P0 — 核心功能 |
| C | 个人资料模块 | 2 | P1 — 高频页面 |
| D | 消息-聊天核心 | 4 | P1 — 次核心功能 |
| E | 消息-群聊功能 | 4 | P2 — 深层页面 |
| F | 设置子页面 | 7 | P2 — 深层页面 |
| G | 社区模块 | 3 | P3 — 独立模块 |
| H | 话题模块 | 1 | P3 — 独立模块 |
| I | 认证模块 | 8 | P4 — 低频 |
| J | 相机模块 | 1 | P5 — 可选 |
| **合计** | | **40** | |
