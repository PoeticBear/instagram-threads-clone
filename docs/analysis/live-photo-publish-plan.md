# iOS Live Photo 发布与回显 — 技术实施方案

> 范围：`client/` Flutter 端 + `openapi_docs/post.json` + `openapi_docs/_misc.json` 服务端契约
> 目标版本：待定（实施后 bump `client/pubspec.yaml` 的 `version: x.y.z+N`）
> 制定日期：2026-06-22
> 适用平台：**仅 iOS**（按 `CLAUDE.md` 平台策略，Android 不在目标范围）

---

## 一、背景与目标

### 1.1 需求原文

> 在【发布帖子】的时候，支持用户从相册中选择实况图片（iOS 系统），然后在发布之后，也能够在查看帖子的场景中（如：首页帖子信息流、帖子详情页等位置）直接以实况图片的形式进行查看，而不是静态图片。

### 1.2 iOS Live Photo 的本质

Live Photo 不是单文件，而是「静态图（HEIC / JPG）+ 短视频（MOV，约 1.5–3 s，含拍照前后约 0.5 s 缓冲）」的**对偶资产**，由系统通过 `PHAsset.mediaSubtypes & .photoLive == 1` 关联。

- 原生播放控件：`PHLivePhotoView`（AVFoundation 解 MOV）
- **缺 MOV → 无法播放**（当前现状）
- **缺 HEIC → `PHLivePhotoView` 无法构造，直接失败 / 黑屏**

Flutter 自身没有内建 `PHLivePhotoView`，必须通过 `UiKitView` + MethodChannel 桥接。

### 1.3 改造目标

| # | 目标 | 验收标准 |
| --- | --- | --- |
| 1 | 发布页支持从相册选实况图 | 底部 sheet 出现「实况」入口，点击进入相册后能识别 `.photoLive` 资源 |
| 2 | 实况图正常上传并发布 | 服务端存储后，Feed / 详情页能拿到配对的图 + 视频 URL |
| 3 | Feed 中按压 / 长按实况图触发播放 | 渲染时显示静态图封面 + LIVE 角标；按压播放 MOV |
| 4 | 帖子详情页同样支持 | 详情页内嵌的媒体列表项也能按压播放 |
| 5 | 草稿保存恢复后仍为实况图 | 草稿恢复时配对的图 + 视频同时还原 |

---

## 二、为什么必须改服务端（已与产品对齐）

`client/` 端的 `image_picker ^0.8.7`（`post.dart:305-318`）只能取 `PHAsset.imageData` 单文件，无法表达「图 + 视频」的对偶关系。当前服务端契约：

- `MediaType` 枚举：`1=image, 2=video, 3=gif, 4=voice, 5=text`（`openapi_docs/post.json:18, 61, 601, 737`）
- `media_urls[]` + `media_types[]` 是两个**平行数组**——一个数组项就是一个媒体位（`post.json:17-18, 60-61, 736-737`）
- 帖子响应 `PostResponse.media_list[]` 的 `MediaItem` schema（`post.json:599-610`）只含 `url` / `thumb_url` / `media_type` / `duration` 等字段，**没有**任何字段表达「这一项是实况图、其配对视频在另一 URL」

> 如果服务端不配合新增 `MediaType=6` 和配对字段，客户端在回显时无法把「图 + 视频」识别为同一张实况图，必然退化为「1 张图 + 1 个独立视频」两个媒体位——这与需求「以实况图片的形式进行查看」直接冲突。

服务端改动量极小（一个枚举值 + 一个字段），换前端整个端到端实现干净、可维护。**这是唯一可行的方案。**

---

## 三、关键设计决策（已与产品对齐）

| 决策点 | 选择 | 理由 |
| --- | --- | --- |
| 服务端 `MediaType` 新增值 | **`live_photo = 6`** | 与现有 1–5 风格一致；`6` 在 iOS 14+ 之后才出现 Live Photo 概念，避开历史值 |
| 配对字段位置 | **`MediaItem` 新增 `paired_video_url: string?`** | 不破坏 `media_list[]` 的「一项一媒体」语义；只在 `media_type=6` 时有值 |
| 实况图占媒体位 | **1 个** | 用户预期「一张实况图 = 一条媒体」，不应当占 2 个 |
| 选择器包 | **`photo_manager` + `wechat_assets_picker`（v6+）** | `wechat_assets_picker` 是 Flutter 社区最成熟的多选相册选择器，v6 起官方支持 Live Photo 标识；`photo_manager` 提供底层 `PHAsset` 访问 |
| 配对资产导出 | **自写 iOS MethodChannel** | `wechat_assets_picker` 只返回 `AssetEntity`，导出 `.pairedVideo` 需用 `PHAssetResource.assetResources(for:)` 写到沙盒 |
| 回显播放 | **自写 iOS MethodChannel + `UiKitView` 嵌入 `PHLivePhotoView`** | Flutter 无内建 widget；自写可控且可被本项目长期维护 |
| 远端 URL 处理 | **客户端预下载到本地临时文件后喂给 `PHLivePhotoView`** | `PHLivePhotoView` 不支持远端 URL；下载期间显示静态图 + LIVE 角标占位 |
| 相机路径 | **本期不做** | Live Photo 必须由 iOS 原生相机拍；Flutter `camera` 包拍不出。需求原文只要求「从相册选择」，不在本期范围 |
| 老版本兼容 | **本期仅对升级到最新版的 iOS 客户端生效** | 老 iOS 客户端会把这个实况图帖子按 `media_type=6` 渲染失败（显示降级占位），但不会崩溃 |

---

## 四、服务端契约（Phase 0，前置依赖）

> **本节所有改动必须在客户端开工前先与后端对齐并落地。**

### 4.1 `MediaType` 枚举扩展

`openapi_docs/post.json:18, 61, 601, 737` 的 `media_types` 字段说明文档更新：

```
int[], 媒体类型列表：1=图片，2=视频，3=GIF，4=语音，5=文本附件，6=实况图（iOS Live Photo）, default: [], optional
```

### 4.2 `MediaItem` schema 新增字段

`openapi_docs/post.json:599-610` 的 `MediaItem` schema 新增：

```jsonc
{
  "paired_video_url": "string?, 实况图配对视频URL（仅 media_type=6 时有值）, optional"
}
```

### 4.3 `MediaItem` 的语义约定

- `media_type=6` 时：
  - `url` 是静态图（HEIC / JPG）URL
  - `paired_video_url` 是配对视频（MOV）URL
  - `thumb_url` 沿用 `url`（静态图作为缩略图）
  - `width` / `height` 是静态图尺寸
  - `duration` 是 MOV 时长（约 1.5–3 s）
- 其他 `media_type` 时：`paired_video_url` 为 `null`

### 4.4 不改动的接口

- `POST /upload/presigned_url`（`openapi_docs/_misc.json:33-44`）**无需改动**——实况图的图、视频分别走两次 presigned URL 上传，文件名后缀区分（`*.heic` / `*.mov`）
- 创建帖子接口 `POST /post/create`（`openapi_docs/post.json:10-41`）的 `media_urls[]` / `media_types[]` **无需改动**——仍然一个数组项 = 一个媒体位；实况图通过 `media_types=6` 单值表达

---

## 五、Flutter 端技术选型

### 5.1 新增依赖（`client/pubspec.yaml`）

```yaml
dependencies:
  photo_manager: ^2.7.0          # 底层 PHAsset 访问 + mediaSubtypes 读取
  wechat_assets_picker: ^9.0.0   # 相册选择器（v6+ 支持 Live Photo 标识）
```

> 锁定具体版本前需在本地试跑 iOS 端，确认 Live Photo 标识在目标 iOS 版本（iOS 14+）上能稳定返回。

### 5.2 不替换 `image_picker`

当前 `image_picker` 还在头像选择（`edit.dart:57-66`、`signup.dart:40-49`）中使用，那里**不需要** Live Photo。本期**只替换** `post.dart` 的图片选择入口，**不动头像**。

### 5.3 平台通道设计（Swift 端）

| Channel | Method | 方向 | 用途 |
| --- | --- | --- | --- |
| `live_photo/export` | `exportPair` | Dart → Swift | 接收 `assetId`，Swift 端 `PHAsset.fetchAssets(withLocalIdentifiers:)` + `PHAssetResource.assetResources(for:)` 导出 `.photo` + `.pairedVideo` 到沙盒，返回两个本地路径 |
| `live_photo/play` | `attach` | Dart → Swift | 接收 `imagePath` + `videoPath`（本地），创建 `PHLivePhoto`，绑定到 `PHLivePhotoView`；通过 `UiKitView` 嵌入 |
| `live_photo/play` | `playbackState` | Swift → Dart | 播放开始 / 结束事件回调（用于 UI 反馈） |

### 5.4 远端 URL → 本地缓存策略

新建 `client/lib/services/live_photo_cache.dart`：

- 用 `path_provider` 的 `getTemporaryDirectory()` 作为缓存目录
- 文件命名规则：`live_photo_{postId}_{hash}.{heic|jpg|mov}`
- 缓存策略：**LRU 上限 50 MB**，超出时按最后访问时间淘汰
- 删除时机：app 冷启动时（避免占用存储）

---

## 六、客户端实施计划

### 6.1 Phase 1 — 选择器替换

**改动文件：**

| 文件 | 改动 |
| --- | --- |
| `client/pubspec.yaml` | 加 `photo_manager` + `wechat_assets_picker` |
| `client/ios/Runner/AppDelegate.swift` | 注册 `live_photo/export` MethodChannel handler |
| `client/ios/Runner/LivePhotoExporter.swift`（新） | `exportPair(assetId:)` 实现，导出 `.photo` + `.pairedVideo` |
| `client/lib/services/live_photo_service.dart`（新） | Dart 端包装 MethodChannel 调用 |
| `client/lib/pages/composePost/post.dart` | `_showMediaPickerSheet`（`post.dart:406-452`）增加「实况」入口；新增 `_pickLivePhoto()` |

**实现要点：**

- `wechat_assets_picker` 配置：限定 `requestType: common` + 显式 `allowLivePhotos: true`（v6+ API）
- 选中后取 `AssetEntity`，调用 `live_photo/export` 拿本地路径对
- 返回结构体 `LivePhotoPair { imagePath, videoPath, imageWidth, imageHeight, videoDurationMs, fileSizeBytes }`

### 6.2 Phase 2 — 数据模型扩展

**改动文件：**

| 文件 | 改动 |
| --- | --- |
| `client/lib/model/media_draft_item.dart` | `DraftMediaType`（`media_draft_item.dart:6-33`）加 `livePhoto` case；`mediaTypeInt` → 6；`MediaDraftItem` 加 `pairedLocalVideo` / `pairedRemoteVideoUrl` / `isLivePhoto` getter |
| `client/lib/model/post.module.dart` | `MediaType` 常量加 `livePhoto = 6`（与 `post.json` 对齐） |

**关键设计：**

- `LivePhotoDraftItem` **不单独建类**，复用 `MediaDraftItem` + `pairedLocalVideo` 字段；这样 `_mediaDrafts` 列表模型不变，所有现有调用方无需感知
- `MediaDraftItem.copyWith` 必须正确传播 `pairedLocalVideo` / `pairedRemoteVideoUrl`
- `_pickLivePhoto` 创建 `MediaDraftItem.fromLocalLivePhoto(pair)` 工厂方法

### 6.3 Phase 3 — 上传管线

**改动文件：**

| 文件 | 改动 |
| --- | --- |
| `client/lib/services/upload_service.dart` | `uploadMedia`（`upload_service.dart:23-60`）新增 `MediaType.livePhoto` 分支：先调两次 `uploadMedia`（图一次、视频一次），组装 `(imageCosUrl, videoCosUrl, MediaType=6)` 返回 |

**实现要点：**

- 图片部分：HEIC / JPG 走现有图片管线（`UploadService.uploadMedia` 第一次调用）
- 视频部分：MOV 走现有视频管线（**注意：现有视频上限 100MB、时长 300s**——`upload_service.dart:15, 17`；实况图视频通常 1.5–3 s / 1.5–3 MB，正常通过）
- 进度回调：两阶段合并（先图后视频），整体进度 = `imageProgress * 0.5 + videoProgress * 0.5`
- 上传失败的清理：MOV 已上传但图片失败 → 调服务端未公开的删除接口（如果后端愿意提供）；否则 COS 上会有孤儿文件

### 6.4 Phase 4 — Feed / 详情页回显

**改动文件：**

| 文件 | 改动 |
| --- | --- |
| `client/lib/services/live_photo_cache.dart`（新） | 远端 URL → 本地缓存 |
| `client/lib/widget/live_photo_view.dart`（新） | Flutter widget + `UiKitView` 嵌入 `PHLivePhotoView` |
| `client/ios/Runner/LivePhotoViewFactory.swift`（新） | `UiKitView` factory：接收 `imageUrl` + `videoUrl`，预下载、构造 `PHLivePhoto`、绑定 `PHLivePhotoView` |
| `client/lib/pages/feedpost.dart` | 渲染循环加 `media.mediaType == livePhoto` 分支 |
| `client/lib/pages/post_detail_page.dart` | 同样加分支 |

**实现要点：**

- 加载时序：
  1. 立即用 `CachedNetworkImage` 显示静态图（来自 `MediaItem.url`）+ LIVE 角标
  2. 后台用 `LivePhotoCache` 下载 `MediaItem.paired_video_url` 的 MOV
  3. 两者都就绪后，通过 MethodChannel 把 `localImagePath` + `localVideoPath` 喂给 `PHLivePhotoView`
  4. `UiKitView` swap 上去
- 失败降级：**保持静态图 + LIVE 角标**（不崩溃，不显示 ❌），点击角标时 SnackBar 提示「实况加载失败」
- 播放触发：iOS 原生行为是「按压 / 长按」，不需要客户端逻辑干预；客户端只负责 setPlaybackHint

### 6.5 Phase 5 — 草稿保存与恢复

**改动文件：**

| 文件 | 改动 |
| --- | --- |
| `client/lib/state/draft.state.dart` | 草稿序列化时把 `pairedLocalVideo` / `pairedRemoteVideoUrl` 一起存到本地 DB；恢复时正确反序列化 |
| `client/lib/services/upload_service.dart` | 草稿上传链路走 Phase 3 的双上传逻辑（`DraftState.saveDraft` 内部调 `UploadService`） |

**实现要点：**

- 草稿未发布时：`pairedLocalVideo` 是本地文件路径；如果 app 卸载或草稿被清理，本地文件丢失 → 草稿恢复后该媒体位降级为「仅静态图」，**不**显示 LIVE 角标
- 草稿已上传但未发布：`pairedRemoteVideoUrl` 是 COS URL；草稿恢复后仍可正常显示实况

### 6.6 Phase 6 — 媒体位上限

**改动文件：**

| 文件 | 改动 |
| --- | --- |
| `client/lib/pages/composePost/post.dart` | `_maxMediaCount = 10`（`post.dart:68`）保持不变；实况图算 1 个媒体位；UI 提示文案「最多 10 个媒体位（实况图算 1 个）」 |

---

## 七、文件改动清单（汇总）

### 7.1 新增

| 路径 | 用途 |
| --- | --- |
| `client/ios/Runner/LivePhotoExporter.swift` | `PHAsset` → 本地双文件导出 |
| `client/ios/Runner/LivePhotoViewFactory.swift` | `UiKitView` 工厂 + `PHLivePhotoView` 包装 |
| `client/lib/services/live_photo_service.dart` | Dart 端 MethodChannel 包装 |
| `client/lib/services/live_photo_cache.dart` | 远端 URL → 本地临时文件缓存 |
| `client/lib/widget/live_photo_view.dart` | Flutter 端实况图 widget |

### 7.2 修改

| 路径 | 改动概要 |
| --- | --- |
| `client/pubspec.yaml` | 加 `photo_manager` + `wechat_assets_picker` |
| `client/ios/Runner/AppDelegate.swift` | 注册两个 MethodChannel |
| `client/lib/model/media_draft_item.dart` | `DraftMediaType` + `MediaDraftItem` 扩展 |
| `client/lib/model/post.module.dart` | `MediaType.livePhoto = 6` |
| `client/lib/services/upload_service.dart` | 双资产上传分支 |
| `client/lib/pages/composePost/post.dart` | `_showMediaPickerSheet` + `_pickLivePhoto` + 上限文案 |
| `client/lib/pages/feedpost.dart` | 渲染分支 |
| `client/lib/pages/post_detail_page.dart` | 渲染分支 |
| `client/lib/state/draft.state.dart` | 草稿序列化 / 反序列化扩展 |
| `client/lib/l10n/`（i18n 文件） | 加新文案（AppLocalizations） |

### 7.3 服务端（与后端对齐后落地）

| 路径 | 改动 |
| --- | --- |
| `openapi_docs/post.json:18, 61, 601, 737` | `media_types` 字段说明加 `6=实况图` |
| `openapi_docs/post.json:599-610` | `MediaItem` schema 加 `paired_video_url` 字段 |

---

## 八、风险与回退

| # | 风险 | 严重度 | 缓解 / 回退 |
| --- | --- | --- | --- |
| 1 | Phase 0 服务端改动延迟上线 | **高** | 客户端不进 Phase 1；接口对齐后开工 |
| 2 | `wechat_assets_picker` / `photo_manager` Live Photo API 在某些 iOS 版本不稳定 | 中 | 锁定具体版本；CI 跑 iOS 14/15/16 三个 target 实测 |
| 3 | `PHLivePhotoView` 不支持远端 URL → 必须预下载 | 中 | 缓存 + 角标占位；首屏显示静态图，下载完成后 swap |
| 4 | 草稿卸载后本地视频丢失 | 低 | 草稿恢复降级为静态图，不显示 LIVE 角标 |
| 5 | 老版本 iOS 客户端渲染 `media_type=6` 失败 | 中 | 服务端返回时检查客户端最低支持版本（如果能识别）；否则老客户端看到的是「1 个未知类型媒体」+ 角标降级为静态图 |
| 6 | COS 孤儿文件（图上传成功、视频失败 或 反之） | 低 | 在 `UploadService` 失败回调里主动调服务端删除接口（如果后端愿意提供）；否则接受 GC 任务异步清理 |
| 7 | iOS-only 包在 iPad 端的横屏 / 多任务适配 | 低 | 本期暂不考虑，列入下一迭代 |

### 8.1 整体回退策略

如果 Phase 3 / Phase 4 中途出现技术 blocker（比如 `wechat_assets_picker` 升级导致 Live Photo 标识回归），回退到「选择器可以选实况图但只能上传图片」的中间状态：实况图被识别后只导出 HEIC、按 `MediaType=1` 上传；UI 降级为静态图 + 不显示 LIVE 角标。**该回退可独立上线**——服务端新增的 `MediaType=6` 和 `paired_video_url` 字段不会被使用，无副作用。

---

## 九、测试方案

### 9.1 单元测试

- `MediaDraftItem` 的 `isLivePhoto` getter、`copyWith` 字段传播
- `UploadService.uploadMedia` 的 `livePhoto` 分支：模拟两次 `uploadMedia` 调用、组装返回结构
- `LivePhotoCache` 的 LRU 淘汰逻辑

### 9.2 集成测试

- 选择器：iOS 模拟器中放入 Live Photo 资源（用 `xcrun simctl addmedia`），验证 `wechat_assets_picker` 标识正确
- 上传链路：本地 mock 服服务端，验证两次 `presigned_url` 请求 + 两次 PUT + 一次 `post/create`（`media_types=[6]`，`media_urls=[imageUrl]`，**不**带 video URL）
- 回显：mock 一个 `MediaItem { media_type: 6, url: ..., paired_video_url: ... }`，验证 widget 切换

### 9.3 手动测试 checklist

- [ ] 从相册选 1 张实况图 → 草稿预览显示静态图 + LIVE 角标
- [ ] 从相册选 3 张实况图 → 草稿 3 个媒体位，每个都有 LIVE 角标
- [ ] 混合：1 张实况图 + 1 张普通图 → 草稿 2 个媒体位
- [ ] 超出 10 个媒体位时 SnackBar 提示
- [ ] 发布成功 → Feed 列表项显示静态图 + LIVE 角标
- [ ] 按压 Feed 项中的实况图 → 视频播放
- [ ] 帖子详情页同样按压播放
- [ ] 草稿保存后退出 app → 重新打开 → 草稿恢复仍是实况图
- [ ] 弱网环境（视频下载慢）→ 静态图立即显示，LIVE 角标变成 loading 状态，视频就绪后 swap
- [ ] 删除草稿 → 草稿列表不出现该条
- [ ] 草稿中的实况图被取消选中 → 草稿变为「仅静态图」

---

## 十、验收标准

| # | 项 | 验证方法 |
| --- | --- | --- |
| 1 | 服务端 `MediaType=6` + `MediaItem.paired_video_url` 字段上线 | `openapi_docs/post.json` 字段说明更新；服务部署完成 |
| 2 | 发布页支持选择实况图 | 手动测试 + Playwright（如果 CI 跑 iOS 模拟器） |
| 3 | 实况图正常发布且服务端存储 | 检查服务端数据库 / 日志，确认 `media_types=[6]` 且 `paired_video_url` 写入 |
| 4 | Feed / 详情页长按实况图触发播放 | 手动测试 + Flutter widget test |
| 5 | 草稿保存 / 恢复不丢失实况图配对 | 手动测试 checklist |
| 6 | 老版本 iOS 客户端不会崩溃 | 备份一份 v1.0.0+18 客户端，装新服务端后验证不崩溃 |
| 7 | 弱网 / 加载失败 → 降级为静态图 | 手动测试（飞行模式 / 弱网模拟） |
| 8 | CI 全绿 | `flutter test` + `flutter build ipa --release` 通过 |

---

## 十一、上线步骤

按 `CLAUDE.md`「发布 TestFlight」流水线，并在末尾加 changelog：

1. 确认服务端 `MediaType=6` + `paired_video_url` 已上线
2. 提交本期所有客户端改动（按 Conventional Commits，建议拆 3 个 commit：`feat(compose): 实况图选择器` / `feat(media): 实况图上传管线` / `feat(feed): 实况图回显播放`）
3. 递增 `client/pubspec.yaml` 构建序号
4. `git push origin main`
5. `flutter build ipa --release`
6. `xcodebuild -exportArchive` 上传 TestFlight
7. 在 `docs/changelog/v{主}.{次}.{修}+{新构建号}.md` 新建文件，登记本次发版
8. 回报版本号、commit hash、上传状态

---

_最后更新：2026-06-22 — 由 Claude 基于 2026-06-22 需求澄清对话整理，输出 Path A（端到端方案）。所有 Path B / Path C / 「仅传视频」等降级方案均已排除。_
