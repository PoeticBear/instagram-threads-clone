# Instagram Threads Clone - 已实现功能详细清单

## 项目概述

- **项目位置**: `/client/`
- **技术栈**: Flutter + Firebase (Auth + Realtime Database + Storage)
- **状态管理**: Provider
- **架构**: State-based architecture with ChangeNotifier pattern

---

## 1. 认证与用户管理

### 1.1 认证状态 (AuthState)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 邮箱/密码登录 | `signIn()` 使用 Firebase Auth 验证用户 | `state/auth.state.dart` |
| 邮箱/密码注册 | `signUp()` 创建新用户并存入 Realtime Database | `state/auth.state.dart` |
| 会话管理 | `getCurrentUser()` 获取当前用户并加载 profile | `state/auth.state.dart` |
| 退出登录 | `logoutCallback()` 清除偏好设置并重置认证状态 | `state/auth.state.dart` |
| 更新用户资料 | `updateUserProfile()` 更新 displayName、photoURL 等 | `state/auth.state.dart` |
| 实时资料同步 | `_onProfileChanged()` 监听 Firebase 数据库变更 | `state/auth.state.dart` |
| 上传头像 | `_uploadFileToStorage()` 上传图片至 Firebase Storage | `state/auth.state.dart` |

### 1.2 注册流程页面
| 页面 | 描述 | 代码位置 |
|------|------|----------|
| NamePage | 登录页面入口，支持切换账号 | `auth/signup/name.dart` |
| SignupPage | 个人资料设置（姓名、简介、头像） | `auth/signup/signup.dart` |
| EmailPage | 邮箱和密码注册表单 | `auth/signup/email.dart` |
| SwitchAccount | 多账号切换对话框 | `auth/signup/account.dart` |

### 1.3 引导流程页面
| 页面 | 描述 | 代码位置 |
|------|------|----------|
| PrivacyPage | 隐私设置选择（公开/私密） | `auth/onboard/privacy.dart` |
| FollowerPage | Instagram 账号关注建议 | `auth/onboard/follow.dart` |
| ThreadPage | Threads 功能说明页 | `auth/onboard/thread.dart` |

---

## 2. 帖子与动态

### 2.1 帖子状态 (PostState)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 创建帖子 | `createPost()` 在 Firebase 创建新帖子 | `state/post.state.dart` |
| 上传图片 | `uploadFile()` 上传帖子图片至 Firebase Storage | `state/post.state.dart` |
| 获取动态列表 | `feedlist` getter 返回按时间倒序的帖子 | `state/post.state.dart` |
| 按关注者筛选 | `getPostListByFollower()` 筛选关注用户的帖子 | `state/post.state.dart` |
| 获取所有帖子 | `getPostList()` 返回全部帖子 | `state/post.state.dart` |
| 实时帖子更新 | `onPostAdded()` 通过 `onChildAdded` 监听新帖子 | `state/post.state.dart` |
| 回复功能 | `setPostToReply` / `postReplyMap` 管理回复关系 | `state/post.state.dart` |

### 2.2 动态页面 (FeedPage)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| Threads Logo 动画 | Lottie 动画显示 Threads 标志 | `pages/feed/feed.dart` |
| 帖子列表 | ListView.builder 显示所有帖子 | `pages/feed/feed.dart` |
| 加载状态 | 显示空容器等待数据加载 | `pages/feed/feed.dart` |

### 2.3 帖子组件 (FeedPostWidget)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 用户头像 | CachedNetworkImage 圆形头像 | `widget/feedpost.dart` |
| 显示名称 | 作者姓名，白色字体，粗体 | `widget/feedpost.dart` |
| 时间戳 | `Utility.getdob()` 转换 UTC 为可读日期 | `widget/feedpost.dart` |
| 帖子内容 | 显示文字内容 | `widget/feedpost.dart` |
| 帖子图片 | 300px 高度，20px 圆角 | `widget/feedpost.dart` |
| Thread 连接线 | 垂直灰线连接帖子与回复 | `widget/feedpost.dart` |
| 回复头像 | 小圆形显示回复作者 | `widget/feedpost.dart` |
| 点赞按钮 | Iconsax heart 图标（仅展示） | `widget/feedpost.dart` |
| 分享按钮 | Iconsax share 图标（仅展示） | `widget/feedpost.dart` |
| 转发按钮 | Iconsax repeat 图标（仅展示） | `widget/feedpost.dart` |
| 发送按钮 | Iconsax send_2 图标（仅展示） | `widget/feedpost.dart` |
| 更多菜单 | 三点菜单图标 | `widget/feedpost.dart` |

### 2.4 发布帖子 (ComposePost)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 文字输入 | 多行文本框，280 字符限制 | `pages/composePost/post.dart` |
| 字符计数器 | 显示当前字符数 | `pages/composePost/post.dart` |
| @ 提及检测 | 正则 `(@\w*[a-zA-Z1-9]$)` 检测 @ 提及 | `pages/composePost/post.dart` |
| 用户列表弹窗 | 输入 @ 时显示用户列表 | `pages/composePost/post.dart` |
| 用户选择 | 点击用户插入用户名 | `pages/composePost/post.dart` |
| 图片选择 | 从相册/相机选择 | `pages/composePost/post.dart` |
| 图片预览 | 发布前显示选中图片（200px） | `pages/composePost/post.dart` |
| 提交帖子 | 创建 PostModel 并调用 `createPost()` | `pages/composePost/post.dart` |
| 图片上传 | 先上传至 Firebase Storage 再创建帖子 | `pages/composePost/post.dart` |
| 取消按钮 | 返回上一页 | `pages/composePost/post.dart` |
| 资料展示 | 显示当前用户头像和昵称 | `pages/composePost/post.dart` |

### 2.5 发布栏图标组件 (ComposeBottomIconWidget)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 相册访问 | ImagePicker 从相册选择 | `pages/composePost/widget/composeBottomIconWidget.dart` |
| 图片裁剪 | ImageCropper 矩形裁剪，多比例可选 | `pages/composePost/widget/composeBottomIconWidget.dart` |
| 字符限制计算 | `getPostLimit()` 计算字符限制百分比 | `pages/composePost/widget/composeBottomIconWidget.dart` |

---

## 3. 用户资料

### 3.1 资料状态 (ProfileState)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 资料加载 | 加载当前用户和目标用户资料 | `state/profile.state.dart` |
| 关注/取消关注 | `followUser()` 修改 followingList | `state/profile.state.dart` |
| 粉丝/关注列表 | 更新 `followersList` 和 `followingList` | `state/profile.state.dart` |
| 关注通知 | `addFollowNotification()` 在 Firebase 创建通知 | `state/profile.state.dart` |
| 实时更新 | `_onProfileChanged()` 监听资料变更 | `state/profile.state.dart` |
| 我的资料判断 | `isMyProfile` getter 比较 profileId | `state/profile.state.dart` |

### 3.2 我的资料页面 (MyProfilePage)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 资料头部 | 显示头像（60px）、昵称、用户名、简介、链接 | `pages/profile/myprofile.dart` |
| 编辑资料按钮 | 跳转到 EditProfilePage | `pages/profile/myprofile.dart` |
| 分享资料按钮 | UI 占位（未实现功能） | `pages/profile/myprofile.dart` |
| 设置入口 | Globe 图标跳转到 SettingsPage | `pages/profile/myprofile.dart` |
| 标签栏 | "Threads" 和 "Replies" 两个标签 | `pages/profile/myprofile.dart` |
| Threads 标签 | 显示当前用户发布的帖子 | `pages/profile/myprofile.dart` |
| Replies 标签 | 占位文字 "You haven't posted any threads yet." | `pages/profile/myprofile.dart` |

### 3.3 他人资料页面 (ProfilePage)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 资料头部 | 同 MyProfilePage | `pages/profile/profile.dart` |
| 关注按钮 | 对非本人显示"关注"按钮 | `pages/profile/profile.dart` |
| 编辑资料按钮 | 对本人显示"编辑"按钮 | `pages/profile/profile.dart` |
| 分享资料按钮 | UI 占位 | `pages/profile/profile.dart` |
| 设置入口 | List 图标跳转到 SettingsPage | `pages/profile/profile.dart` |
| 路由方法 | `ProfilePage.getRoute()` 静态方法，fade 动画过渡 | `pages/profile/profile.dart` |

### 3.4 编辑资料页面 (EditProfilePage)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 昵称编辑 | CupertinoTextField，lock 图标前缀 | `pages/profile/edit.dart` |
| 简介编辑 | CupertinoTextField，add 图标前缀，100 字符限制 | `pages/profile/edit.dart` |
| 链接编辑 | CupertinoTextField，add 图标前缀 | `pages/profile/edit.dart` |
| 头像修改 | CircleAvatar + CupertinoActionSheet（相册/相机/删除） | `pages/profile/edit.dart` |
| 头像裁剪 | 圆形裁剪样式，多比例预设 | `pages/profile/edit.dart` |
| 完成按钮 | `_submitButton()` 保存更改 | `pages/profile/edit.dart` |
| 取消按钮 | 返回不保存 | `pages/profile/edit.dart` |
| 验证 | 昵称和简介最多 100 字符 | `pages/profile/edit.dart` |
| 资料更新 | 调用 `state.updateUserProfile()` | `pages/profile/edit.dart` |

---

## 4. 搜索与发现

### 4.1 搜索状态 (SearchState)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 加载所有用户 | `getDataFromDatabase()` 从 Firebase 获取用户 | `state/search.state.dart` |
| 按用户名筛选 | `filterByUsername()` 不区分大小写包含匹配 | `state/search.state.dart` |
| 用户排序 | `selectedFilter` getter 支持： | `state/search.state.dart` |
| | - ALPHABETICALY: 按显示名排序 | |
| | - MAX_FOLLOWER: 按粉丝数排序 | |
| | - NEWEST: 按创建时间倒序 | |
| | - OLDEST: 按创建时间正序 | |
| | - VERIFIED: 不排序 | |
| 获取用户详情 | `getuserDetail()` 通过用户 ID 列表返回 UserModel | `state/search.state.dart` |

### 4.2 搜索页面 (SearchPage)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 搜索框 | TextField，搜索图标，深色键盘，10px 圆角 | `pages/search/search.dart` |
| 实时筛选 | `onChanged` 调用 `state.filterByUsername()` | `pages/search/search.dart` |
| 用户列表 | ListView.separated 显示 UserTilePage | `pages/search/search.dart` |
| 分隔线 | 每个用户后显示 0.5px 灰线（最后一项除外） | `pages/search/search.dart` |

### 4.3 用户条目组件 (UserTileWidget)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 头像 | 40px 圆形 CachedNetworkImage | `widget/list.dart` |
| 显示名称 | TitleText，20px，600 粗细 | `widget/list.dart` |
| 用户名 | 灰色文字，@ 前缀 | `widget/list.dart` |
| 粉丝数 | 显示粉丝数量 | `widget/list.dart` |
| 关注按钮 | Container 显示 "Follow"（功能未连接） | `widget/list.dart` |
| 点击跳转 | 导航到 ProfilePage 并传递 userId | `widget/list.dart` |

---

## 5. 通知

### 5.1 通知页面 (NotificationPage)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 页面标题 | 大字 "Activity" | `pages/notification/notification.dart` |
| 筛选标签 | Horizontal ListView: "All", "Replies", "Mentions", "Verify" | `pages/notification/notification.dart` |
| 通知列表 | 使用 UserTilePage 组件显示 | `pages/notification/notification.dart` |
| 标签点击状态 | `isTap` 变量（onTap 回调已注释） | `pages/notification/notification.dart` |

---

## 6. 相机

### 6.1 相机页面 (CameraPage)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 实时预览 | CameraPreview，FittedBox cover fit | `pages/camera/camera.dart` |
| 相机选择 | 前置（index 1）和后置（index 0/2） | `pages/camera/camera.dart` |
| 切换相机 | `_switchFrontCamera()` 带旋转动画（1000ms） | `pages/camera/camera.dart` |
| 闪光灯切换 | `_flashEnable()` 在 off 和 torch 模式切换 | `pages/camera/camera.dart` |
| 缩放 | Pinch-to-zoom，通过 `setZoomLevel()` | `pages/camera/camera.dart` |
| 超广角切换 | `_switchGiantAngle()` 在 1x 和 0.5x 间切换 | `pages/camera/camera.dart` |
| 拍照 | `_takePicture()` 同时从前后摄像头拍摄 | `pages/camera/camera.dart` |
| 图片上传 | `uploadImageToStorage()` 上传至 Firebase Storage | `pages/camera/camera.dart` |
| 创建帖子 | 使用拍摄图片和用户信息创建 PostModel | `pages/camera/camera.dart` |
| 相机动画 | 旋转动画 via `rotationController` | `pages/camera/camera.dart` |

---

## 7. 首页与导航

### 7.1 首页 (HomePage)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 底部导航栏 | 5 个标签页: | `pages/home.dart` |
| | - Index 0: Feed (Iconsax.home) | |
| | - Index 1: Search (Iconsax.search_normal) | |
| | - Index 2: Compose (Iconsax.edit) | |
| | - Index 3: Notifications (Iconsax.heart) | |
| | - Index 4: Profile (CupertinoIcons.person) | |
| 页面切换 | `tabPage()` 根据选中索引返回对应页面 | `pages/home.dart` |
| 抽屉相机 | CameraPage 作为抽屉（通过汉堡菜单访问） | `pages/home.dart` |
| 状态初始化 | `initPosts()`, `initSearch()`, `initProfile()` | `pages/home.dart` |
| 深色主题 | 黑色背景，白色/灰色图标 | `pages/home.dart` |

---

## 8. 设置

### 8.1 设置页面 (SettingsPage)
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 设置列表 | 图标 + 文字: | `common/settings.dart` |
| | - 关注和邀请好友 (CupertinoIcons.person_add) | |
| | - 通知 (CupertinoIcons.bell) | |
| | - 隐私 (Icons.lock_outline) | |
| | - 帮助 (Icons.help_outline) | |
| | - 关于 (CupertinoIcons.info) | |
| 退出登录 | `state.logoutCallback()` 退出并导航回登录页 | `common/settings.dart` |
| 淡入动画 | FadeInRight 动画效果 | `common/settings.dart` |

---

## 9. 发布状态

### 9.1 ComposePostState
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 内容管理 | `description` 字符串存储帖子文字 | `state/compose.state.dart` |
| 用户列表显示 | `displayUserList` 布尔控制 @ 提及弹窗 | `state/compose.state.dart` |
| 提交按钮状态 | `enableSubmitButton` 布尔（文字 1-280 字符时为 true） | `state/compose.state.dart` |
| 用户名检测 | 正则 `(@\w*[a-zA-Z1-9]$)` 匹配 @ 提及 | `state/compose.state.dart` |
| 内容变化处理 | `onDescriptionChanged()` 处理文本更新 | `state/compose.state.dart` |
| 用户选择 | `onUserSelected()` 选择后隐藏用户列表 | `state/compose.state.dart` |
| 获取内容 | `getDescription()` 将 @ 提及替换为选中用户名 | `state/compose.state.dart` |

---

## 10. 数据模型

### 10.1 用户模型 (UserModel)
| 属性 | 描述 |
|------|------|
| `key` | Firebase 数据库 key |
| `email` | 用户邮箱 |
| `userId` | Firebase Auth UID |
| `bio` | 用户简介 |
| `link` | 外部链接 |
| `userName` | @用户名 |
| `displayName` | 显示名称 |
| `profilePic` | 头像 URL |
| `createAt` | 账号创建时间戳 |
| `isprivate` | 隐私设置 |
| `fcmToken` | Firebase Cloud Messaging token |
| `followersList` | 粉丝用户 ID 列表 |
| `followingList` | 关注用户 ID 列表 |

**方法**: `fromJson()`, `toJson()`, `copyWith()`

### 10.2 帖子模型 (PostModel)
| 属性 | 描述 |
|------|------|
| `key` | Firebase 数据库 key |
| `imagePath` | 帖子图片 URL |
| `bio` | 帖子文字内容 |
| `createdAt` | 创建时间（UTC） |
| `user` | 作者 UserModel |
| `comment` | 评论字符串列表 |

**方法**: `toJson()`, `fromJson()`

---

## 11. 辅助工具

### 11.1 Utility 工具
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 生成用户名 | `getUserName()` 从 id 和显示名生成 @用户名 | `helper/utility.dart` |
| 日期格式化 | `getdob()` 格式化为 "MMM d, yyyy" | `helper/utility.dart` |
| 凭证验证 | `validateCredentials()` 验证邮箱格式和密码长度（8+） | `helper/utility.dart` |
| 邮箱验证 | `validateEmal()` 邮箱正则验证 | `helper/utility.dart` |
| 提示框 | `customSnackBar()` 显示黑色提示框白色文字 | `helper/utility.dart` |

### 11.2 SharedPreference 辅助
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 保存用户资料 | `saveUserProfile()` 将 UserModel 存为 JSON 字符串 | `helper/shared_prefrence_helper.dart` |
| 清除偏好 | `clearPreferenceValues()` 清除所有 SharedPreferences | `helper/shared_prefrence_helper.dart` |

### 11.3 枚举定义
| 枚举 | 值 | 代码位置 |
|------|-----|----------|
| AuthStatus | NOT_DETERMINED, NOT_LOGGED_IN, LOGGED_IN | `helper/enum.dart` |
| SortUser | VERIFIED, ALPHABETICALY, NEWEST, OLDEST, MAX_FOLLOWER | `helper/enum.dart` |
| NotificationType | Follow | `helper/enum.dart` |

---

## 12. 自定义组件

### 12.1 RippleButton
- 透明 splash 颜色按钮
- Stack 包含子组件和透明 TextButton 覆盖层
- 支持自定义圆角

**代码位置**: `widget/custom/rippleButton.dart`

### 12.2 TitleText
- 可复用的 Text 组件，预设白色样式
- 可配置 fontSize、fontWeight、textAlign、overflow

**代码位置**: `widget/custom/title_text.dart`

---

## 13. 动画

### 13.1 可用动画效果
| 动画 | 描述 |
|------|------|
| CubeTransition | 3D 立方体旋转效果 |
| AccordionTransition | 手风琴/缩放效果 |
| ZoomOutSlideTransition | 缩小+滑动 |
| RotateUpTransition | 从底部旋转 |
| RotateDownTransition | 从顶部旋转 |
| TabletTransition | 平板式 3D 旋转 |
| StackTransition | 简单滑动 |
| ParallaxTransition | 视差效果（自定义 clipper） |
| ForegroundToBackgroundTransition | 前景到背景 |
| BackgroundToForegroundTransition | 背景到前景 |
| FlipVerticalTransition | 垂直翻转 |
| FlipHorizontalTransition | 水平翻转 |
| DepthTransition | 深度/缩放效果 |
| DefaultTransition | 默认滑动 |

**代码位置**: `animation/animation.dart`

---

## 14. 应用入口与配置

### 14.1 Main.dart
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| Firebase 初始化 | iOS 和 Android 平台 | `main.dart` |
| 相机初始化 | `availableCameras()` | `main.dart` |
| 依赖注入 | GetIt 设置 SharedPreferenceHelper | `main.dart` |
| SharedPreferences 初始化 | | `main.dart` |
| MultiProvider | AppStates, AuthState, PostState, SearchState | `main.dart` |
| 深色主题配置 | | `main.dart` |
| 启动页面 | SplashPage 作为 home | `main.dart` |

### 14.2 SplashPage
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| 启动延迟 | 1 秒延迟初始化 | `common/splash.dart` |
| 获取当前用户 | `getCurrentUser()` | `common/splash.dart` |
| 认证路由 | NOT_DETERMINED -> 空容器 | `common/splash.dart` |
| | NOT_LOGGED_IN -> NamePage | |
| | LOGGED_IN -> HomePage | |

### 14.3 Locator
| 功能 | 描述 | 代码位置 |
|------|------|----------|
| GetIt 依赖注入 | | `common/locator.dart` |
| 单例注册 | SharedPreferenceHelper | `common/locator.dart` |

---

## 功能实现状态汇总

| 类别 | 功能 | 状态 |
|------|------|------|
| **认证** | 邮箱/密码登录 | ✅ 已实现 |
| **认证** | 邮箱/密码注册 | ✅ 已实现 |
| **认证** | 退出登录 | ✅ 已实现 |
| **认证** | 更新资料 | ✅ 已实现 |
| **认证** | 会话管理 | ✅ 已实现 |
| **帖子** | 创建文字帖子 | ✅ 已实现 |
| **帖子** | 创建带图片帖子 | ✅ 已实现 |
| **帖子** | 查看动态 | ✅ 已实现 |
| **帖子** | 按关注者筛选 | ✅ 已实现 |
| **帖子** | 实时帖子更新 | ✅ 已实现 |
| **资料** | 查看自己资料 | ✅ 已实现 |
| **资料** | 查看他人资料 | ✅ 已实现 |
| **资料** | 编辑资料（姓名、简介、链接） | ✅ 已实现 |
| **资料** | 修改头像 | ✅ 已实现 |
| **资料** | 关注/取消关注 | ⚠️ 部分（UI 存在，列表更新） |
| **搜索** | 按用户名搜索用户 | ✅ 已实现 |
| **搜索** | 筛选/排序用户 | ✅ 已实现 |
| **相机** | 实时相机预览 | ✅ 已实现 |
| **相机** | 切换前后摄像头 | ✅ 已实现 |
| **相机** | 闪光灯切换 | ✅ 已实现 |
| **相机** | 拍照 | ✅ 已实现 |
| **相机** | 缩放 | ✅ 已实现 |
| **相机** | 超广角（0.5x） | ✅ 已实现 |
| **导航** | 底部标签导航 | ✅ 已实现 |
| **设置** | 设置菜单 | ✅ 已实现 |
| **设置** | 退出登录 | ✅ 已实现 |
| **引导** | 隐私选择 | ✅ 已实现 |
| **引导** | 关注建议 | ✅ 已实现 |
| **引导** | 功能说明页 | ✅ 已实现 |

---

## Firebase 集成

| 服务 | 用途 |
|------|------|
| Firebase Auth | 邮箱/密码认证 |
| Firebase Realtime Database | 用户、帖子、通知存储 |
| Firebase Storage | 头像、帖子图片存储 |
| Firebase Analytics | 追踪用户注册事件 |

---

## 注意事项

以下功能 UI 存在但可能未完全连接到后端：
- 帖子上的点赞/发送/转发按钮（仅展示）
- 关注按钮（UI 存在但功能未完全连接）
- 回复功能（部分实现）