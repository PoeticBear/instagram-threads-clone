## Why

当前 `client/scripts/release.sh` 只能把 IPA 上传到 **TestFlight**，要走到 App Store 正式分发仍需人工：登录 App Store Connect 网页 → 创建/更新版本号 → 逐项填写应用名、副标题、描述、关键词、隐私 URL、分类等 → 上传 6.5"/5.5" 等多套截图 → 选择构建 → 提交审核。每一次发版都要重复一遍，且文案散落在网页后台，难追溯、难协作。

本变更新增"App Store 正式发布"自动化脚本与配套配置（Fastlane）：首次一次性把所有上架资料（应用名 / 描述 / 关键词 / 隐私 URL / 截图等）以**纯文本 + 图片文件**形式落到 `client/fastlane/metadata/` 与 `client/fastlane/screenshots/`，与代码一同入 git；之后每次发版只需执行 `appstore-release.sh`，即可完成 **build → 上传 IPA → 同步 metadata → 同步截图 → 提交审核**，全程无需打开浏览器。

复用既有 `release.sh` 已验证的 build/push/上传逻辑，把"App Store 上架"这一段独立成新脚本，新旧两路并存：TestFlight 内测继续用 `release.sh`，App Store 正式发布用 `appstore-release.sh`。

## What Changes

- **新增 Fastlane 工具链**：通过 Homebrew 装 Ruby 与 fastlane（不污染系统 Ruby 2.6），所有 Fastlane 配置集中在 `client/fastlane/`。
- **新增 API Key 鉴权**：在 App Store Connect 后台生成 API Key（`.p8` 文件 + Key ID + Issuer ID），放到 `client/fastlane/api_key.json` 并加入 `.gitignore`。脚本通过 JWT 鉴权访问 App Store Connect API，**不**依赖 Apple ID + 2FA。
- **新增 `client/fastlane/Appfile`**：声明 `apple_id`（开发者账号邮箱）、`team_id`（`B3885SFCQJ`，与 `release.sh` 一致）、`app_identifier`（`com.yt.threads`）。
- **新增 `client/fastlane/Fastfile`**：定义 lanes——
  - `upload_listing`：调 `fastlane deliver upload`，把 `metadata/` + `screenshots/` 推到 App Store Connect 的当前版本
  - `submit_for_review`：调 `fastlane deliver submit_build`，提交当前版本审核
  - `full_release`：串联 build → 上传 IPA → upload_listing → submit_for_review，**不**自己跑 flutter build（由外层 shell 脚本驱动，避免重复构建）
- **新增 `client/fastlane/metadata/`**：以语言为子目录（首版 `en-US`、`zh-Hans`），每个语言下放纯文本文件：`name.txt`、`subtitle.txt`、`description.txt`、`keywords.txt`、`release_notes.txt`、`privacy_url.txt`、`support_url.txt`、`marketing_url.txt`、`copyright.txt`、`primary_category.txt`、`secondary_category.txt`。
- **新增 `client/fastlane/screenshots/`**：按语言 + 设备尺寸分子目录（`en-US/iPhone6.5/`, `zh-Hans/iPhone6.5/` 等），文件名按 Fastlane 规范命名（如 `01_login.png`、`02_feed.png`）。
- **新增 `client/scripts/appstore-release.sh`**：仿照 `release.sh` 的风格（header / info / ok / warn / err 颜色 + step 进度 + 日志落盘 + 卡顿重试），执行流程：API 环境检查 → 工作区检查 → bump 构建号 → git push → flutter build ipa → fastlane upload_listing → fastlane submit_for_review → 回报版本号 + commit hash。支持 `--only-upload`、`--no-bump`、`--no-push`、`--no-submit` 四个 flag。
- **新增 `client/fastlane/README.md`**：简述目录结构 + 首次使用步骤 + 截图生成指引 + 常见问题。
- **`.gitignore` 增量**：
  - `client/fastlane/api_key.json`（敏感）
  - `client/build/`、`client/.dart_tool/`、`client/.fastlane/`（fastlane 缓存）

## Capabilities

### New Capabilities

无 —— `openspec/specs/` 目前只有 `api-path-docs`（API 文档相关）。本变更属**工具链 / 研发流水线**，不引入新的产品能力，不改任何面向用户的 spec。

### Modified Capabilities

无。

## Impact

- **新增文件**：
  - `client/scripts/appstore-release.sh`
  - `client/fastlane/Appfile`
  - `client/fastlane/Fastfile`
  - `client/fastlane/README.md`
  - `client/fastlane/api_key.json.template`（含字段说明，**不含**真实密钥）
  - `client/fastlane/metadata/{en-US,zh-Hans}/*.txt`（约 11 个文件 × 2 语言 = 22 个）
  - `client/fastlane/screenshots/{en-US,zh-Hans}/iPhone6.5/*.png`（首批 5 张 × 2 语言 = 10 张）
- **修改文件**：
  - `client/.gitignore`：追加 `fastlane/api_key.json` 与 fastlane 缓存
  - `CLAUDE.md`：在「一键发布到 TestFlight」段落下方新增「一键发布到 App Store」段落（命令 + 前置条件 + 截图规范要点）
  - `docs/testflight-release-guide.md`（或新建 `docs/appstore-release-guide.md`）：补 App Store 正式发布指南
- **不动**：
  - `client/scripts/release.sh`（TestFlight 流水线继续独立运作）
  - `client/lib/` 下任何业务代码（纯工具链变更）
  - `client/ios/Runner.xcodeproj/`、`client/ios/Runner/`
  - Android 端任何文件（项目仅维护 iOS）

非目标（明确不做）：

- 不实现 CI/CD（如 GitHub Actions 自动跑 `appstore-release.sh`），本期仅本地一键脚本。
- 不接入 `pilot`（TestFlight 内部组管理）—— TestFlight 仍走 `release.sh`。
- 不实现截图自动化生成（用户后续可单独调用项目内的 `app-store-screenshots` skill）。
- 不实现版本回滚 / 审核拒绝后自动重提，提交失败由人肉介入。
- 不写 Android 适配（项目仅维护 iOS）。
- 不实现"价格 / 内购 / 订阅"配置（应用为免费 App，且暂不引入内购）。
- 不动 ATB（协议 / 税务 / 银行）—— 假设开发者账号已就绪（本变更执行前需用户确认）。
