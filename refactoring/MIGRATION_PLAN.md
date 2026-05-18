# Flutter 客户端迁移计划：从 Firebase 改造为自建 REST API

## 项目状态：已完成 ✅

### API 基础配置
- **Base URL**: `http://192.168.1.27:8005/`

---

## 一、已完成的工作

### 阶段 1: API 网络层 ✅
**新增文件：**
- `lib/network/api_config.dart` - API 配置（base URL, headers, 超时设置）
- `lib/network/api_exception.dart` - 自定义异常类（ApiException, AuthException, NetworkException等）
- `lib/network/api_client.dart` - HTTP 客户端封装，支持 GET/POST/PUT/PATCH/DELETE

### 阶段 2: API 服务类 ✅
**新增文件：**
- `lib/services/auth_service.dart` - 认证相关 API（登录、注册、登出、获取当前用户、刷新Token）
- `lib/services/user_service.dart` - 用户资料 API（获取/更新用户资料、设置、关注请求）
- `lib/services/post_service.dart` - 帖子相关 API（创建/获取/删除/编辑帖子、点赞、评论）
- `lib/services/follow_service.dart` - 关注 API（关注/取消关注、获取粉丝/关注列表）
- `lib/services/search_service.dart` - 搜索 API（搜索用户/帖子/话题、搜索历史、热门话题）
- `lib/services/notification_service.dart` - 通知 API（获取通知列表、标记已读、未读数）
- `lib/services/upload_service.dart` - 文件上传 API（Presigned URL 模式）

### 阶段 3: 数据模型改造 ✅
**修改文件：**
- `lib/model/user.module.dart` - 支持 Firebase 和 API 双格式（camelCase/snake_case）
- `lib/model/post.module.dart` - 支持 Firebase 和 API 双格式

### 阶段 4: State 类改造 ✅
**修改文件：**
- `lib/state/auth.state.dart` - 从 Firebase Auth 改为 AuthService + UserService
- `lib/state/post.state.dart` - 从 Firebase Database 改为 PostService
- `lib/state/profile.state.dart` - 从 Firebase 改为 FollowService + UserService
- `lib/state/search.state.dart` - 从 Firebase 改为 SearchService

### 阶段 5: 应用入口改造 ✅
**修改文件：**
- `lib/main.dart` - 移除 Firebase 初始化，添加 ApiClient 和 SharedPreferences 初始化
- `lib/helper/utility.dart` - 移除 Firebase 全局引用（kAnalytics, kDatabase）

### 阶段 6: 清理依赖 ✅
**修改文件：**
- `pubspec.yaml` - 移除 Firebase 相关依赖，添加 http 包

---

## 二、API 端点映射

### 2.1 用户认证 (`/user/*`)

| Firebase 操作 | REST API | 说明 |
|--------------|----------|------|
| `signInWithEmailAndPassword` | `POST /user/signin` | 用户名登录 |
| `createUserWithEmailAndPassword` | `POST /user/register` | 用户注册 |
| `signOut` | `DELETE /user/logout` | 退出登录 |
| `currentUser` | `GET /user/me` | 获取当前用户信息 |
| Token 刷新 | `POST /user/token/refresh` | 刷新 JWT |
| `updateDisplayName/PhotoURL` | `PUT /user/profile` | 更新个人资料 |

### 2.2 用户资料 (`/user/profile/*`)

| Firebase 路径 | REST API | 说明 |
|---------------|----------|------|
| `profile/{userId}` (read) | `GET /user/profile/{user_id}` | 获取用户资料 |
| `profile/{userId}` (write) | `PUT /user/profile` | 更新用户资料 |
| follow 操作 | `POST /follow/{user_id}` | 关注用户 |
| unfollow 操作 | `DELETE /follow/{user_id}` | 取消关注 |

### 2.3 帖子 (`/post/*`)

| Firebase 操作 | REST API | 说明 |
|--------------|----------|------|
| `post` collection (read) | `GET /post/feed` | 获取信息流 |
| `post` collection (create) | `POST /post/create` | 创建帖子 |
| `post/{postId}` (delete) | `DELETE /post/{post_id}` | 删除帖子 |
| `post/{postId}` (update) | `PUT /post/{post_id}` | 编辑帖子 |
| like | `POST /post/like/{post_id}` | 点赞帖子 |
| unlike | `DELETE /post/like/{post_id}` | 取消点赞 |
| reply | `POST /post/reply` | 创建回复 |
| replies list | `GET /post/reply/list/{post_id}` | 回复列表 |

### 2.4 图片上传

| Firebase Storage | REST API |
|------------------|----------|
| Firebase Storage | `POST /upload/upload/presigned_url` 获取预签名 URL |

### 2.5 搜索

| Firebase 查询 | REST API |
|---------------|----------|
| `profile` 模糊搜索 | `GET /search` |

### 2.6 通知

| Firebase Realtime | REST API |
|-------------------|----------|
| `notification` 监听 | `GET /notification/notifications` |
| 未读数 | `GET /notification/notifications/unread-count` |

---

## 三、新增文件清单

| 文件路径 | 说明 |
|----------|------|
| `lib/network/api_config.dart` | API 配置 |
| `lib/network/api_exception.dart` | 异常类 |
| `lib/network/api_client.dart` | HTTP 客户端 |
| `lib/services/auth_service.dart` | 认证服务 |
| `lib/services/user_service.dart` | 用户服务 |
| `lib/services/post_service.dart` | 帖子服务 |
| `lib/services/follow_service.dart` | 关注服务 |
| `lib/services/search_service.dart` | 搜索服务 |
| `lib/services/notification_service.dart` | 通知服务 |
| `lib/services/upload_service.dart` | 上传服务 |

---

## 四、修改文件清单

| 文件路径 | 修改内容 |
|----------|----------|
| `lib/main.dart` | 移除 Firebase 初始化，使用 ApiClient |
| `lib/state/auth.state.dart` | Firebase Auth → AuthService |
| `lib/state/post.state.dart` | Firebase Database → PostService |
| `lib/state/profile.state.dart` | Firebase → FollowService + UserService |
| `lib/state/search.state.dart` | Firebase → SearchService |
| `lib/model/user.module.dart` | 支持 API snake_case 格式 |
| `lib/model/post.module.dart` | 支持 API snake_case 格式 |
| `lib/helper/utility.dart` | 移除 kAnalytics, kDatabase |
| `pubspec.yaml` | 移除 Firebase 依赖，添加 http |

---

## 五、待完成的工作

> 以下功能需要根据实际 API 响应格式进行进一步调整：

1. **页面适配** - 各页面可能需要小幅调整以适配新的数据模型
2. **图片上传** - UploadService 需要根据实际云存储服务调整
3. **错误处理** - 根据实际 API 错误响应格式调整异常处理
4. **实时更新** - 原 Firebase 实时监听已改为拉取模式，如需实时功能请添加轮询

---

## 六、注意事项

1. **JWT Token 管理**：通过 AuthService 管理，已实现存储和刷新
2. **API 兼容性**：数据模型同时支持 Firebase (camelCase) 和 API (snake_case) 格式
3. **服务定位器**：使用 get_it 进行依赖注入，ApiClient 注册在 getIt<ApiClient>()