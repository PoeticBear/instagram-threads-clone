# Tasks — appstore-release-automation

> 实现顺序：先**打底**（装 fastlane + 配 API Key + .gitignore）→ 再**素材**（写 metadata 文本 + 生成截图）→ 再**配置**（Appfile / Fastfile）→ 再**脚本**（appstore-release.sh）→ 最后**端到端验证**（App Store Connect 上跑一次完整流程）。每步独立可运行。

## 1. 工具链安装

- [ ] 1.1 安装 Homebrew Ruby
  - `brew install ruby`
  - 把 `export PATH="/opt/homebrew/opt/ruby/bin:$PATH"` 加进 `~/.zshrc`，使新 Ruby 优先于系统 Ruby 2.6
  - `ruby --version` 确认 ≥ 3.0（fastlane 当前最低要求 2.6，但 3.0+ 兼容性更好）
- [ ] 1.2 安装 fastlane
  - `gem install fastlane --no-document`
  - `fastlane --version` 确认安装成功，记录版本号
- [ ] 1.3 验证基础环境
  - `which fastlane` 指向 Homebrew Ruby gem 路径（**不是** `/usr/bin/`）
  - `xcodebuild -version` 与 `flutter --version` 仍正常（Fastlane 不冲突）

## 2. App Store Connect API Key 生成与配置

> 一次性前置，5 分钟搞定，后续脚本全自动。

- [ ] 2.1 在 App Store Connect 后台生成 API Key
  - 登录 https://appstoreconnect.apple.com
  - 用户和访问 → 集成 → App Store Connect API → 生成 API Key
  - 角色选「App Manager」或更高（需有「管理」权限）
  - 下载 `.p8` 文件，记下 `Key ID`（10 位字符串）与 `Issuer ID`（UUID 格式）
- [ ] 2.2 落盘 Key 文件
  - 把 `.p8` 放到 `client/fastlane/auth/`（新建子目录）
  - `client/fastlane/auth/` 加入 `.gitignore`
  - 文件名建议 `AuthKey_<KEY_ID>.p8`（Fastlane 约定）
- [ ] 2.3 创建 `client/fastlane/api_key.json`
  ```json
  {
    "key_id": "ABC1234567",
    "issuer_id": "00000000-0000-0000-0000-000000000000",
    "key_filepath": "fastlane/auth/AuthKey_ABC1234567.p8",
    "duration": 1200,
    "in_house": false
  }
  ```
  - 把实际值填进去；`client/fastlane/api_key.json` 加入 `.gitignore`
- [ ] 2.4 创建 `client/fastlane/api_key.json.template`（入 git）
  - 内容同上但值全部写 `REPLACE_ME`
  - 在 `client/fastlane/README.md` 里说明首次使用流程

## 3. .gitignore 增量

- [ ] 3.1 `client/.gitignore` 追加
  ```gitignore
  # Fastlane — App Store release automation
  client/fastlane/api_key.json
  client/fastlane/auth/
  client/.fastlane/
  ```
  - 注意：`client/fastlane/metadata/` 与 `client/fastlane/screenshots/` **不**忽略（要入 git）

## 4. Fastlane 配置

- [ ] 4.1 创建 `client/fastlane/Appfile`
  ```ruby
  app_identifier "com.yt.threads"
  apple_id "REPLACE_WITH_YOUR_APPLE_ID@example.com"  # 用户填真实邮箱
  team_id "B3885SFCQJ"
  ```
- [ ] 4.2 创建 `client/fastlane/Fastfile`
  ```ruby
  default_platform(:ios)

  platform :ios do
    before_all do
      api_key = app_store_connect_api_key(
        key_id: ENV["ASC_KEY_ID"],
        issuer_id: ENV["ASC_ISSUER_ID"],
        key_filepath: File.expand_path("auth/AuthKey_#{ENV["ASC_KEY_ID"]}.p8", __dir__),
        in_house: false
      )
      ENV["APP_STORE_CONNECT_API_KEY"] = api_key[:api_key] if api_key.is_a?(Hash)
    end

    desc "Push metadata + screenshots to App Store Connect"
    lane :upload_listing do
      deliver(
        api_key: app_store_connect_api_key(
          key_id: ENV["ASC_KEY_ID"],
          issuer_id: ENV["ASC_ISSUER_ID"],
          key_filepath: File.expand_path("auth/AuthKey_#{ENV["ASC_KEY_ID"]}.p8", __dir__),
        ),
        skip_binary_upload: true,
        skip_metadata: false,
        skip_screenshots: false,
        force: true,
        precheck_include_in_app_purchases: false,
        automatic_release: true,
        submit_for_review: false,
      )
    end

    desc "Submit current build for App Store review"
    lane :submit_for_review do
      deliver(
        api_key: app_store_connect_api_key(
          key_id: ENV["ASC_KEY_ID"],
          issuer_id: ENV["ASC_ISSUER_ID"],
          key_filepath: File.expand_path("auth/AuthKey_#{ENV["ASC_KEY_ID"]}.p8", __dir__),
        ),
        skip_binary_upload: true,
        skip_metadata: true,
        skip_screenshots: true,
        submit_for_review: true,
        automatic_release: true,
        precheck_include_in_app_purchases: false,
      )
    end

    desc "Full local release (assumes IPA already uploaded by shell script)"
    lane :appstore_full_release do
      upload_listing
      submit_for_review
    end
  end
  ```
- [ ] 4.3 创建 `client/fastlane/README.md`
  - 目录结构图
  - 首次使用 4 步走（API Key → Appfile 填 apple_id → 写 metadata → 提供截图）
  - 常用命令：`fastlane ios upload_listing`、`fastlane ios submit_for_review`、`./client/scripts/appstore-release.sh`
  - 截图尺寸规范表（6.5" / 5.5" / iPad）
  - 排错：API Key 无效 / metadata 缺字段 / 截图尺寸错误 / 审核被拒

## 5. 元数据（metadata）撰写

> 首版覆盖 `en-US` 与 `zh-Hans` 两个语言；其余语言二期按需补。每个 `<lang>` 子目录下放 11 个文本文件：

- [ ] 5.1 `client/fastlane/metadata/en-US/`
  - `name.txt` — 应用名（英文，30 字符以内）
  - `subtitle.txt` — 副标题（30 字符以内）
  - `description.txt` — 详细描述（最多 4000 字符）
  - `keywords.txt` — 关键词（逗号分隔，≤100 字符）
  - `release_notes.txt` — 本次发版说明
  - `privacy_url.txt` — 隐私政策 URL（**必须**，否则审核被拒）
  - `support_url.txt` — 支持 URL
  - `marketing_url.txt` — 营销 URL（可选，留空可省略文件）
  - `copyright.txt` — 版权信息（如 `© 2026 Threads Inc.`）
  - `primary_category.txt` — 主分类（社交 / 摄影 / 效率 等，对应 App Store Connect 分类 ID）
  - `secondary_category.txt` — 副分类（可选）
- [ ] 5.2 `client/fastlane/metadata/zh-Hans/`
  - 同上，中文版本
- [ ] 5.3 占位符
  - 真实内容由用户提供；提案归档前先用 `REPLACE_ME` 占位，标注"待用户确认"

## 6. 截图（screenshots）生成与归档

> **iPhone-only 应用**。仅生成 iPhone 截图，不交 iPad / Apple Watch。
>
> Apple 硬性要求（App Store Connect 后台）：
> - **最多 10 张，最少 1 张**（推荐 5–8 张覆盖核心场景）
> - **尺寸任选其一**：`1242×2688`、`2688×1242`、`1284×2778`、`2778×1284`
> - **App Preview 视频**：最多 3 个（本期**不做**，仅静态截图）

- [ ] 6.1 确认项目内有 `app-store-screenshots` skill 可用
  - `ls .claude/skills/` 确认 skill 存在
  - 跑一次 skill，按 iPhone 6.5"（1242×2688）生成 5 张
- [ ] 6.2 归档到 `client/fastlane/screenshots/en-US/iPhone6.5/`
  - 文件名规范：`01_<feature>.png`（如 `01_login.png`、`02_feed.png`、`03_compose.png`、`04_notifications.png`、`05_profile.png`）
  - 尺寸校验：`sips -g pixelWidth -g pixelHeight <file>` 必须落在 Apple 允许的清单里（1242×2688 / 2688×1242 / 1284×2778 / 2778×1284）
- [ ] 6.3 归档到 `client/fastlane/screenshots/zh-Hans/iPhone6.5/`
  - 中文 UI 截图 5 张，命名同上
- [ ] 6.4 写 `client/fastlane/screenshots/README.md`
  - Apple 官方尺寸要求清单（含上述 4 种尺寸）
  - 数量限制说明（最多 10 张）
  - 明确说明「本应用 iPhone-only，不交 iPad / Apple Watch 截图」
  - 生成工具指引（app-store-screenshots skill）
  - 文件命名规范

## 7. `appstore-release.sh` 脚本

> 仿照 `client/scripts/release.sh` 的风格（颜色、header、info/ok/warn/err、step 进度、日志落盘、卡顿重试）。

- [ ] 7.1 脚本骨架
  - `#!/usr/bin/env bash`、`set -euo pipefail`
  - 颜色变量 + `header` / `info` / `ok` / `warn` / `err` / `dim` 函数（与 `release.sh` 完全一致）
  - `need_cmd` 前置检查（flutter / xcodebuild / git / fastlane）
  - 参数解析：`--only-upload`、`--no-bump`、`--no-push`、`--no-submit`、 `--help`
- [ ] 7.2 Step 1 — API 环境检查
  - 完全复用 `release.sh` Step 1 的 `_prodBaseUrl` + `defaultValue: 'prod'` 双匹配
  - 失败拒绝继续（App Store 包**绝不**能带 `--dart-define=APP_ENV=dev`）
- [ ] 7.3 Step 2 — 工作区检查
  - 同 `release.sh` Step 2：忽略 `.claude/`、`*.ips`，其他未提交改动提示先 commit
- [ ] 7.4 Step 3 — bump 构建号
  - 同 `release.sh` Step 3：解析 `client/pubspec.yaml` 的 `version: X.Y.Z+N`，递增 N+1，独立 commit
  - `--no-bump` 时跳过
- [ ] 7.5 Step 4 — git push
  - 同 `release.sh` Step 4
  - `--no-push` 时跳过
- [ ] 7.6 Step 5 — flutter build ipa --release
  - 同 `release.sh` Step 5
  - `--only-upload` 时复用已有 archive（同 release.sh 校验）
- [ ] 7.7 Step 6 — 上传 IPA 到 App Store Connect
  - **不**用 `xcodebuild exportArchive`（那是 TestFlight 流）；改用 `fastlane deliver upload` 的 binary-only 模式，或继续用 `xcodebuild exportArchive` 把 IPA 传上去再让 fastlane 选 build
  - 决策：复用 release.sh 已验证的 xcodebuild upload（避免引入新的上传路径卡顿问题），fastlane 仅负责 metadata / screenshots / submit
- [ ] 7.8 Step 7 — fastlane upload_listing
  - 从环境变量读 `ASC_KEY_ID` / `ASC_ISSUER_ID`
  - 调 `fastlane ios upload_listing`
  - tee 日志到 `client/build/ios/upload/metadata.<timestamp>.log`
  - 卡顿检测 + 自动重试（复用 release.sh 的 watchdog 模式）
- [ ] 7.9 Step 8 — fastlane submit_for_review
  - `--no-submit` 时跳过（只准备好审核包，但不真提交）
  - 调 `fastlane ios submit_for_review`
  - 成功 → 打印审核 ID 与预计审核时长（24–48h）
- [ ] 7.10 Step 9 — 回报
  - 版本号、commit hash、IPA 路径、日志路径
  - 提醒：App Store Connect 处理约 5–15 分钟，审核约 24–48h

## 8. 文档

- [ ] 8.1 更新 `CLAUDE.md`
  - 「一键发布到 TestFlight」段落下方新增「一键发布到 App Store」段落
  - 命令：`./client/scripts/appstore-release.sh`
  - 前置条件：API Key 已配置（`client/fastlane/api_key.json` + `client/fastlane/auth/`）+ App Store Connect 上 App 记录已存在（bundle ID = `com.yt.threads`）
  - 与 `release.sh` 的关系：TestFlight 内测 vs App Store 正式分发，两路并存
- [ ] 8.2 新建 `docs/appstore-release-guide.md`
  - 复用 `docs/testflight-release-guide.md` 的章节结构
  - 重点：API Key 生成图文指引、metadata 字段说明、截图规范、首次发布步骤
- [ ] 8.3 新建 `docs/changelog/v1.0.0+22.md`
  - 首次 App Store 正式发布 changelog
  - 待 7.x 任务真正跑通后再写

## 9. 端到端验证

> 静态分析 + dry-run + 真机提交三步。

- [ ] 9.1 静态检查
  - `cd client && bash -n scripts/appstore-release.sh`（语法检查）
  - `cd client/fastlane && fastlane lanes`（确认 lane 注册成功）
- [ ] 9.2 fastlane precheck（dry-run）
  - `cd client && fastlane ios upload_listing --dry_run`
  - 检查 metadata 完整性、截图尺寸是否合规、有无缺字段
- [ ] 9.3 真实发版（首次）
  - 在 App Store Connect 网页确认 App 记录已存在（bundle ID = `com.yt.threads`）
  - 确认 ATB 状态（协议 / 税务 / 银行）已生效
  - `./client/scripts/appstore-release.sh --no-submit`（先不上交审核，只把 metadata + 截图 + IPA 全推到 App Store Connect 后台，肉眼确认无误）
  - 肉眼确认 App Store Connect 后台所有字段正确
  - `./client/scripts/appstore-release.sh --no-bump --no-push`（完整流程，包含提交审核）
  - 等待 24–48h，审核通过 → 自动上架
- [ ] 9.4 二次发版验证
  - 后续小版本发版：`./client/scripts/appstore-release.sh`，确认 metadata 增量更新 + 截图替换 + 重新提交审核链路通畅
