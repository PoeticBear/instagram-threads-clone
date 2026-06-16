# 上传文件（Upload File）— 代码定位 + 简要分析

> 本文档定位 iOS 客户端中「上传文件」功能的核心代码：`UploadService`（预签名 URL + 流式 PUT 上传到 COS）以及它的**两条主要调用管线**：
>
> 1. **帖子媒体上传**（发布帖子 + 草稿保存）— 图片 / 视频 / GIF / 语音
> 2. **头像 / 资料图上传**（注册 + 编辑个人资料）— 图片
>
> 与 [`docs/code-locations/select-media.md`](select-media.md) 互补：后者聚焦「媒体选择」（相册 / 相机 / 预览 / 工具类），本文档聚焦「上传管线」本身（服务 / API / 模型 / 状态 / 边界）。

---

## 1. 涉及文件总览

| 类别 | 路径 | 行数 | 职责 |
| --- | --- | --- | --- |
| **服务层（核心）** | `client/lib/services/upload_service.dart` | 233 | 预签名 URL + 流式 PUT 上传到 COS |
| 状态层（帖子） | `client/lib/state/post.state.dart` | — | `createPost` 中调用 `uploadMedia` |
| 状态层（帖子） | `client/lib/state/draft.state.dart` | — | 草稿保存时调用 `uploadMedia` |
| 状态层（用户） | `client/lib/state/auth.state.dart` | — | `updateUserProfile` 中调用 `uploadImage` |
| 数据模型 | `client/lib/model/media_draft_item.dart` | 232 | 帖子媒体草稿（含 `needsUpload` / `isUploading` / `uploadProgress`） |
| 数据模型 | `client/lib/model/post.module.dart` | — | `MediaType` 常量（1=image / 2=video / 3=gif） |
| UI 入口（帖子） | `client/lib/pages/composePost/post.dart` | 1667 | `_resolveDraftMedia` — 提交时统一上传所有未传媒体 |
| UI 入口（头像-编辑） | `client/lib/pages/profile/edit.dart` | — | `_buildAvatarEdit`（`edit.dart:336-398`） |
| UI 入口（头像-注册） | `client/lib/auth/signup/signup.dart` | — | `getImage`（`signup.dart:40-49`） |
| OpenAPI 契约 | `openapi_docs/_misc.json` | — | `POST /upload/presigned_url` 端点定义（`_misc.json:33-45`） |

---

## 2. 核心服务：`UploadService`

- **路径**：`client/lib/services/upload_service.dart`
- **行数**：233
- **职责**：客户端**唯一**的媒体 / 头像上传入口。所有需要把本地文件传到 COS 的场景都走它。

### 2.1 公共方法

| 方法 | 行号 | 说明 |
| --- | --- | --- |
| `uploadMedia(File file, {required int mediaType, int? durationMs, onProgress})` | `upload_service.dart:25-67` | **推荐入口**。一站式：校验 → MIME 推断 → 拿预签名 URL → 流式 PUT → 返回 `cosUrl`。 |
| `uploadImage(File file)` | `upload_service.dart:123-126` | **已废弃**。`uploadMedia(file, mediaType: MediaType.image)` 的别名，仅供旧调用方（`auth.state.dart:346`）。新代码应直接调 `uploadMedia`。 |
| `getPresignedUrl({filename, contentType, fileSize, duration})` | `upload_service.dart:130-153` | 分步上传步骤 1：`POST upload/presigned_url`。 |
| `uploadToPresignedUrl({uploadUrl, file, contentType, onProgress})` | `upload_service.dart:155-173` | 分步上传步骤 2：流式 PUT 到已拿到的 `uploadUrl`。 |

### 2.2 私有方法

| 方法 | 行号 | 说明 |
| --- | --- | --- |
| `_isPlayableMedia(int mediaType)` | `upload_service.dart:120-122` | 判断是否需要透传 `duration`（视频 / 语音） |
| `_uploadWithPresignedUrlRetry(...)` | `upload_service.dart:69-106` | 申请预签名 URL + 流式 PUT；命中「URL 过期」时**自动重新申请并重试 1 次** |
| `_isExpiredPresignedUrlError(ApiException e)` | `upload_service.dart:110-118` | 识别 COS 预签名 URL 过期（HTTP 401/403 + body 含 `expired` / `AccessDenied`） |
| `_streamPut({uploadUrl, file, contentType, onProgress})` | `upload_service.dart:183-230` | 真正的上传逻辑：`HttpClient.putUrl` + `file.openRead()` 流式写入，按 chunk 报进度 |
| `_validateSize(int mediaType, int fileSize)` | `upload_service.dart:232-242` | 大小上限校验（抛 `ApiException`） |
| `_kindName(int mediaType)` | `upload_service.dart:244-258` | `mediaType` → 中文名（视频 / GIF / 语音 / 文本 / 图片） |
| `_sizeLimitFor(int mediaType)` | `upload_service.dart:260-273` | 按 `mediaType` 返回上限（图片 10MB / 视频 100MB / GIF 10MB / 语音·文本 10MB） |
| `_inferContentType(String path, {int? mediaType})` | `upload_service.dart:280-305` | 扩展名 + mediaType → MIME 推断表（图片 fallback `image/jpeg`；视频不含 hevc） |

### 2.3 关键常量

| 常量 | 值 | 行号 |
| --- | --- | --- |
| `_maxImageSizeBytes` | 10 MB | `upload_service.dart:14` |
| `_maxVideoSizeBytes` | 100 MB | `upload_service.dart:15` |
| `_maxGifSizeBytes` | 10 MB | `upload_service.dart:16` |
| `_maxVoiceOrTextSizeBytes` | 10 MB | `upload_service.dart:17` |

### 2.4 响应模型 `PresignedUrlResponse`

- **路径**：`client/lib/services/upload_service.dart:308-326`
- **字段**：`uploadUrl` / `cosUrl` / `expiresIn`（默认 600s）
- **JSON key 映射**：`upload_url` / `cos_url` / `expires_in`

---

## 3. 调用管线一：帖子媒体上传

> 完整选片 / 相机 / 预览细节见 [`select-media.md`](select-media.md)。本节只列**触发上传**的代码位置。

### 3.1 提交时统一上传：`ComposePostState._resolveDraftMedia`

- **路径**：`client/lib/pages/composePost/post.dart:602-633`（在文档最新版本中实际调用点为 `post.dart:609`）
- **逻辑**：遍历 `_mediaDrafts`，对每个 `needsUpload == true && localFile != null` 的项调 `uploadService.uploadMedia(...)`，把返回的 `cosUrl` 替换回草稿，**未上传**的项直接用 `remoteUrl`。
- **触发时机**：`ComposePostState._submit`（`post.dart:688-798`）— 用户点「发帖」按钮时。

### 3.2 草稿保存：`DraftState.saveDraft`

- **路径**：`client/lib/state/draft.state.dart`
- **逻辑**：同 `_resolveDraftMedia`，对未上传的 `MediaDraftItem` 调 `uploadMedia`，拿到 `cosUrl` 后调 `POST /drafts` 保存草稿。
- **入口**：`ComposePostState._saveCurrentDraft`（`post.dart:635-684`）。

### 3.3 调用点一览（帖子管线）

| 调用方 | 位置 | 备注 |
| --- | --- | --- |
| `PostState.createPost` | `post.state.dart:180` | 经 `_resolveDraftMedia` 间接调用 |
| `PostState._resolveDraftMedia`（`post.dart:609`） | `post.dart:609` | 提交发布时 |
| `DraftState.saveDraft` | `draft.state.dart`（具体行号视当前实现） | 草稿保存时 |

---

## 4. 调用管线二：头像 / 资料图上传

> 头像上传**入口在 UI 层**（编辑资料 / 注册），**实现在状态层**（`AuthState.updateUserProfile`），**核心调用**是 `AuthState.uploadService.uploadImage(...)`。

### 4.1 状态层入口：`AuthState.updateUserProfile`

- **路径**：`client/lib/state/auth.state.dart:335-370`
- **关键代码（`auth.state.dart:338-356`）**：
  ```dart
  bool removeAvatar = false,
  // ...
  String? avatarUrl;
  if (image != null) {
    avatarUrl = await uploadService.uploadImage(image);   // ← 关键调用
  } else if (removeAvatar) {
    avatarUrl = '';
  }
  // ...
  await userService.updateProfile(
    name, bio, ..., avatarUrl: avatarUrl ?? userModel.profilePic,
  );
  ```
- **三个分支**：
  1. 选了新图 → 先 `uploadImage` 拿 `cosUrl`，再 `updateProfile` 写入
  2. 用户主动「移除」 → `avatarUrl = ''`（空串表示清除）
  3. 没改头像 → 不传 `avatarUrl`，服务端保留旧值

### 4.2 UI 入口 A：编辑资料页 `EditProfilePage`

- **路径**：`client/lib/pages/profile/edit.dart`
- **关键代码**：
  - 状态字段 `_image` / `_avatarRemoved`（`edit.dart:26-27`）
  - 头像编辑弹层 `_buildAvatarEdit`（`edit.dart:336-398`）— `CupertinoActionSheet`：相册 / 相机 / 移除
  - 提交 `_submitButton`（`edit.dart:464-502`）— 校验后调 `state.updateUserProfile(model, image: _image, removeAvatar: _avatarRemoved)`
  - 选图工具 `getImage(context, source, onImageSelected)`（`edit.dart:57-66`）— 用 `image_picker` 拿 `File` 回调

### 4.3 UI 入口 B：注册页 `SignupPage`

- **路径**：`client/lib/auth/signup/signup.dart`
- **关键代码**：
  - `getImage(...)`（`signup.dart:40-49`）— 与 `edit.dart` 几乎一致，`image_picker` 选图
  - 上层收到 `File` 后，组装到 `UserModel` 一并走注册 / 更新流程（具体入口需结合 `auth/signup/` 目录的其它文件确认）

### 4.4 调用点一览（头像管线）

| 调用方 | 位置 | 备注 |
| --- | --- | --- |
| `AuthState.updateUserProfile` | `auth.state.dart:335-370`（关键调用 `auth.state.dart:346`） | 唯一发起头像上传的状态方法 |
| `EditProfilePage._submitButton` | `edit.dart:464-502` | 编辑资料场景 |
| `SignupPage` | `signup/signup.dart` | 注册场景 |

---

## 5. 完整上传流程图

```
┌────────────────────────────────────────────────────────────────────────┐
│                          触发上传的场景                                 │
│                                                                        │
│  帖子管线                                                                │
│  ┌─────────────────────────────────────────────┐                       │
│  │ ComposePostState._resolveDraftMedia         │ (post.dart:609)       │
│  │   遍历 _mediaDrafts 中 needsUpload 的项      │                       │
│  └────────────┬────────────────────────────────┘                       │
│               │                                                        │
│  头像管线                                                                │
│  ┌─────────────────────────────────────────────┐                       │
│  │ AuthState.updateUserProfile                  │ (auth.state.dart:335)│
│  │   image != null → uploadImage(image)         │                       │
│  │   removeAvatar → avatarUrl = ''              │                       │
│  └────────────┬────────────────────────────────┘                       │
└───────────────┼────────────────────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────────────────────────────────┐
│              UploadService.uploadMedia(file, mediaType: ...)           │
│              (upload_service.dart:25-67)                               │
│                                                                        │
│   1) 校验文件大小（按 mediaType）→ _validateSize                       │
│   2) 推断 MIME（按 mediaType + 扩展名）→ _inferContentType             │
│   3) POST upload/presigned_url → { uploadUrl, cosUrl, expiresIn }      │
│   4) _streamPut: HttpClient.putUrl + file.openRead() → 流式 PUT         │
│   5) 返回 cosUrl                                                       │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────────────────┐
│                上传结果回写到上层                                        │
│                                                                        │
│  帖子管线：cosUrl → MediaDraftItem.remoteUrl → PostService.createPost  │
│  头像管线：cosUrl → avatarUrl → UserService.updateProfile              │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 6. OpenAPI 契约

### 6.1 端点：`POST /upload/presigned_url`

- **文档**：`openapi_docs/_misc.json:33-45`
- **鉴权**：是（`auth: true`）
- **请求体**：
  | 字段 | 类型 | 必填 | 说明 |
  | --- | --- | --- | --- |
  | `filename` | string | ✅ | 文件名（含扩展名） |
  | `content_type` | string | ✅ | MIME 类型，如 `image/jpeg` |
  | `file_size` | int | ✅ | 文件大小（字节） |
  | `duration` | int? | ❌ | 视频 / 语音时长（**秒**），仅在 `mediaType` 为视频或语音时透传 |
- **响应**（`PresignedUrlResponse?`）：
  | 字段 | 类型 | 说明 |
  | --- | --- | --- |
  | `upload_url` | string | 预签名上传 URL（前端直接 PUT 至此地址） |
  | `cos_url` | string | 上传成功后的 COS 访问 URL（**这才是要存到数据库的地址**） |
  | `expires_in` | int | 预签名 URL 有效期（秒），默认 600 |

### 6.2 上传流程（端到端）

```
1) 前端：POST /upload/presigned_url
        body: {filename, content_type, file_size, duration?}
2) 后端：返回 {upload_url, cos_url, expires_in}
3) 前端：PUT file → upload_url（无需鉴权，URL 自身签名有效期内有效）
4) 前端：cos_url 存入媒体库 / 用户资料
```

### 6.3 时长单位注意

- `MediaDraftItem.durationMs` 字段：毫秒
- `MediaDraftItem.mediaTypeInt` 字段：枚举 int（`MediaType` 1/2/3）
- `UploadService.uploadMedia` 入参 `durationMs`：**毫秒**，内部 `~/ 1000` 转秒后透传给后端
- `openapi_docs/_misc.json` `duration` 字段：**秒**

---

## 7. 数据模型

### 7.1 `MediaDraftItem`（`client/lib/model/media_draft_item.dart:41-224`）

| 字段 | 类型 | 用途 |
| --- | --- | --- |
| `localFile` | `File?` | 选中的本地文件路径（**未上传时**） |
| `remoteUrl` | `String?` | 已上传 / 草稿恢复时的远端 URL |
| `thumbPath` | `String?` | 本地缩略图（视频首帧） |
| `remoteThumbUrl` | `String?` | 远端缩略图 |
| `type` | `DraftMediaType` | image / video / gif |
| `durationMs` | `int?` | 视频时长（毫秒） |
| `fileSizeBytes` | `int?` | 文件大小 |
| `isUploading` | `bool` | 是否正在上传（UI 用） |
| `uploadProgress` | `double?` | 0..1 上传进度（UI 用） |
| 派生 getter | — | `isImage` / `isVideo` / `isGif` / **`needsUpload`** / `mediaTypeInt` |
| 工厂方法 | — | `fromLocalImage` / `fromLocalVideo` / `fromLocalGif` / `fromRemote` |
| `copyWith(...)` | — | 不可变更新 |

> 关键设计：`needsUpload` getter（`media_draft_item.dart:161`）一行判断是否要走上传管线 — `localFile != null`。

### 7.2 `MediaType` 常量（`client/lib/model/post.module.dart:5-9`）

```dart
class MediaType {
  static const int image = 1;
  static const int video = 2;
  static const int gif = 3;
}
```

> 注：`UploadService._isPlayableMedia`（`upload_service.dart:122-124`）还引用了 `MediaType.voice`（暂未在常量表中显式列出，预留扩展点）。

---

## 8. 限制 & 边界

| 项 | 上限 | 来源 |
| --- | --- | --- |
| 图片大小 | ≤ 10 MB | `upload_service.dart:14` |
| 视频大小 | ≤ 100 MB | `upload_service.dart:15` |
| GIF 大小 | ≤ 10 MB | `upload_service.dart:16` |
| 语音 / 文本大小 | ≤ 10 MB | `upload_service.dart:17` |
| 预签名 URL 有效期 | 600 s | `_misc.json:50`（响应默认值） |
| 预签名 URL 过期重试 | 自动重试 1 次 | `upload_service.dart:69-106` |
| 帖子媒体数量 | ≤ 10 | `post.dart:68` (`_maxMediaCount`) |
| 帖子内容长度 | ≤ 500 字符 | `post.dart:71` (`_maxContentLength`) |
| 视频时长 | ≤ 300s | `post.dart:74` / `compose_camera_page.dart:49` |

---

## 9. 流式上传细节（OOM 防护）

- **实现**：`UploadService._streamPut`（`upload_service.dart:183-230`）
- **机制**：
  1. `file.openRead()` 把文件按 chunk 转成 `Stream<List<int>>`
  2. `request.addStream(stream)` 把 stream 作为请求 body（HttpClient 自动 chunked）
  3. 进度回调通过 `.map((chunk) { sentBytes += chunk.length; onProgress(...); return chunk; })` 实现
- **为什么不一次性 `readAsBytes()`**：大视频 / GIF 一次性读入内存会 OOM。流式是发布页能稳定处理 100MB 视频的关键。
- **错误体读取**：上传失败时读取响应体最多 4KB（`upload_service.dart:214-220`）辅助诊断。

---

## 10. 关键设计点

### ① 单一上传入口

整个项目**只有 `UploadService` 一个上传实现**，所有需要 COS 上传的场景都走它：
- 帖子媒体（`post.state.dart` / `draft.state.dart`）
- 头像 / 资料图（`auth.state.dart:346`）

新增上传场景时，**直接复用 `UploadService.uploadMedia`**，不要自己拼 HTTP。

### ② `mediaType` 必须显式传

- `uploadMedia(file, mediaType: ...)` 是推荐入口 — `mediaType` 决定大小上限和 MIME 推断路径
- `uploadImage(file)` 是已废弃别名，等价于 `uploadMedia(file, mediaType: MediaType.image)`
- 头像场景本应改用 `uploadMedia(file, mediaType: MediaType.image)`，但 `auth.state.dart:346` 暂未迁移

### ③ duration 仅视频 / 语音透传

- `UploadService._isPlayableMedia`（`upload_service.dart:122-124`）判断 `mediaType == MediaType.video || MediaType.voice`
- 命中且 `durationMs != null` 时，`durationMs ~/ 1000` 转秒后传给 `/upload/presigned_url`
- 图片 / GIF 不传 `duration`

### ④ 上传 vs 选择解耦

- `select-media.md` 关注「怎么选」（相册 / 相机 / 预览）
- `upload-file.md`（本文档）关注「怎么传」（服务 / API / 状态）
- 两者通过 `MediaDraftItem` 串联：选择 → 构造草稿 → 提交时上传

### ⑤ iOS 平台策略

- 本项目**只维护 iOS**（见 [CLAUDE.md](../../CLAUDE.md)「平台策略」）
- `UploadService` 使用 `dart:io` 的 `HttpClient`，iOS 上由 NSAppTransportSecurity 默认放行 HTTPS（`cos.ap-xxx.myqcloud.com`）
- 不需要为 Android 写 `MissingPluginException` 降级路径

---

## 11. 快速检索指引

| 需求 | 检索关键词 | 关键文件 |
| --- | --- | --- |
| 修改上传大小上限 | `_maxImageSizeBytes` / `_maxVideoSizeBytes` / `_maxGifSizeBytes` / `_maxVoiceOrTextSizeBytes` | `client/lib/services/upload_service.dart:14-17` |
| 修改 MIME 推断表 | `_inferContentType` | `client/lib/services/upload_service.dart:280-305` |
| 改流式上传策略 | `_streamPut` | `client/lib/services/upload_service.dart:183-230` |
| 改预签名 URL 接口字段 | `getPresignedUrl` body | `upload_service.dart:137-160` + `openapi_docs/_misc.json:33-45` |
| 改预签名 URL 过期重试 | `_uploadWithPresignedUrlRetry` / `_isExpiredPresignedUrlError` | `upload_service.dart:69-106` / `110-118` |
| 修改帖子媒体上传入口 | `_resolveDraftMedia` | `client/lib/pages/composePost/post.dart:602-633`（调用点 `post.dart:609`） |
| 修改头像上传逻辑 | `updateUserProfile` | `client/lib/state/auth.state.dart:335-370`（关键调用 `auth.state.dart:346`） |
| 修改编辑资料页头像 UI | `_buildAvatarEdit` | `client/lib/pages/profile/edit.dart:336-398` |
| 修改注册页头像 UI | `getImage` | `client/lib/auth/signup/signup.dart:40-49` |
| 新增上传场景（消息附件等） | `uploadMedia` | `client/lib/services/upload_service.dart:25-67` |
| 添加新 MediaType 枚举 | `MediaType` + `DraftMediaType` | `client/lib/model/post.module.dart:5-9` + `client/lib/model/media_draft_item.dart:6-33` |

---

## 12. 相关文档

- [`select-media.md`](select-media.md) — 选择媒体（相册 / 相机 / 预览），是上传管线的**前置**环节
- [`publish-post.md`](publish-post.md) — 发布帖子（ComposePost / ComposeCameraPage），是上传管线的**主要触发点**
- [`profile-page.md`](profile-page.md) — 个人主页（`EditProfilePage._buildAvatarEdit`），是头像上传的**触发点之一**
- [CLAUDE.md](../../CLAUDE.md) — 项目规范（iOS 平台策略 / 状态管理 / 编码规范）

---

_最后更新：2026-06-16 — 由 Claude 自动化梳理（基于代码静态分析 + 关键模块阅读），并对齐服务端 `openapi_docs/_misc.json` 文件上传规范（图片 10MB / 视频 100MB / GIF 10MB / 语音·文本 10MB / 视频时长 300s / 帖子媒体数 ≤ 10 / 预签名 URL 过期自动重试）。_
