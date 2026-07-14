## Context

`client/scripts/release.sh`（已有，TestFlight 一键脚本）当前能力上限：完成 `bump → commit → push → flutter build ipa → xcodebuild exportArchive → App Store Connect TestFlight` 全链路。落到 App Store 正式分发时卡在 3 处：

1. **版本记录**：需要在 App Store Connect 网页手动"创建版本"或"选择现有版本"，并填写版本号 `1.0.0`（不带构建号）。
2. **上架资料**：应用名、副标题、描述、关键词、隐私 URL、分类等数十个字段，网页逐项填，跨语言版本还要复制 N 份。
3. **截图**：每个语言 × 每个声明支持的设备尺寸 × 最少 3 张、最多 10 张，需先在网页点 "上传媒体"、再选文件、再拖顺序；尺寸错了 Apple 直接拒绝。

目标：把以上 3 处全部脚本化，**重复发版零手动**；首次发版需要人做的事收敛到：
- 一次性填 metadata 文本文件
- 一次性提供截图（可用 `app-store-screenshots` skill 程序化生成）
- 在 App Store Connect 后台生成并下载 API Key（一次性，5 分钟）

后续每次发布：`$ appstore-release.sh` → 等 5 分钟 → 审核通过 → 自动上架。

## Goals / Non-Goals

**Goals:**

- 首次发版把"上传 metadata + 上传截图 + 提交审核"全部脚本化；用户只需提供素材内容，无需登网页。
- 后续发版"零手动"，`appstore-release.sh` 一条命令完成 build → push metadata → push screenshots → 提交审核。
- 与既有 `release.sh`（TestFlight 流水线）并存、互不依赖；用户可单独使用任一。
- metadata 与 screenshots 走**纯文本 + 图片文件**形式入 git，可 diff、可 code review、可追溯。
- API Key 不入 git，敏感信息走 `.gitignore`。

**Non-Goals:**

- 不实现 CI/CD 自动化（GitHub Actions / GitLab CI 等），本期仅本地脚本。
- 不接入 `pilot` 做 TestFlight 组管理；TestFlight 仍走 `release.sh`。
- 不实现截图自动化生成（用户可单独调 `app-store-screenshots` skill）。
- 不实现审核拒绝后自动重提 / 自动改 metadata 重提；失败时给人清晰报错。
- 不实现"价格 / 内购 / 订阅"配置（应用为免费 App，且本期无内购）。
- 不动 ATB / 开发者账号 / Apple ID 配置，假设就绪。
- 不做 Android 适配。
- 不写新的 Flutter 业务代码。

## Decisions

### 决策 1：用 Fastlane 而不是裸调 App Store Connect API（采用）

候选方案对比：

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | Fastlane 的 `deliver` action | 社区事实标准；自动处理 JWT 签名、分页、错误重试；metadata / screenshots 走标准目录；文档与排查资源最多 |
| B | 直接调 App Store Connect REST API（手写 JWT、分页、错误码映射） | 灵活但工程量大；每个错误场景都要自己测；脚本维护成本高 |
| C | 用 `xcrun altool` / Transporter CLI（仅上传二进制，无 metadata） | 只能传 IPA，metadata 仍需人工 |

`deliver` 几乎覆盖我们全部需求；只有"自定义 fastlane 行为"时才需要切到 B（如需写 lane 编排）。本期纯 A。

### 决策 2：Fastlane 装在 Homebrew Ruby，不污染系统 Ruby 2.6（采用）

候选方案对比：

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | `brew install ruby` + `gem install fastlane` | 干净的隔离 Ruby；权限无坑；卸载方便 |
| B | 用系统 Ruby 2.6.10 + `sudo gem install fastlane` | 系统 Ruby 旧，部分 fastlane 依赖会装不上；`sudo` 与 Homebrew 哲学冲突 |
| C | `rbenv` / `asdf` 多版本 Ruby 管理 | 灵活但对小项目过重；额外配置 `.ruby-version` |

项目只用 Fastlane 一项工具，A 最简；C 是项目演进到多 Ruby 版本依赖时再考虑。

### 决策 3：API Key 鉴权（.p8 + JWT），不用 Apple ID + 2FA（采用）

候选方案对比：

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | App Store Connect 后台生成 API Key（`.p8` 文件 + Key ID + Issuer ID），Fastlane 用 JWT 自动签名 | 无交互、可在 CI 跑、可定时；密钥可单独 rotate；与 Apple 官方推荐一致 |
| B | 用 Apple ID + 应用专用密码（app-specific password） | 仍需人工首次输密码；CI 不友好；Apple 已不推荐 |
| C | 用 Apple ID + 2FA 交互式登录 | 完全不能脚本化 |

`.p8` 文件入 `.gitignore`，Key ID 与 Issuer ID 可入（不属于敏感凭据）。Fastlane 通过 `app_store_connect_api_key` action 读取。

### 决策 4：metadata 走纯文本文件，screenshots 走图片文件，与代码一同入 git（采用）

候选方案对比：

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | `fastlane/metadata/<lang>/*.txt` + `fastlane/screenshots/<lang>/<size>/*.png`，全部入 git | 可 diff、可 code review、可追溯；新人 onboarding 直接看目录就知道有哪些字段；CI 可在 PR 阶段校验 metadata 完整性 |
| B | metadata 存数据库 / 单独 CMS | 引入额外服务；本项目无后端 CMS |
| C | metadata 走环境变量 / 配置文件 | 不便多语言版本管理；不能体现"换皮"场景 |

`fastlane deliver init` 会自动生成目录结构骨架，按其规范命名即可。

### 决策 5：复用 `release.sh` 的 build + push 逻辑，`appstore-release.sh` 不自己跑 build（采用）

候选方案对比：

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | `appstore-release.sh` 直接调用 `release.sh --only-upload --no-bump --no-push` 复用上传；或者按 `release.sh` 风格另写一段 build + IPA + fastlane deliver upload | 复用 release.sh 已验证的卡顿检测 + 自动重试 + 日志落盘；保持 TestFlight / App Store 两路完全独立 |
| B | 把 `release.sh` 改造成可切换 TestFlight / App Store 模式（一个脚本两个出口） | 改动面大；既有 release.sh 已稳定，重构风险高于收益 |
| C | `appstore-release.sh` 内联完整 build + 上传逻辑 | 与 release.sh 重复；以后改 build 流程要改两处 |

最终采用 A 的变体：`appstore-release.sh` 与 `release.sh` 平级**各自完整**，但内部**逐行复用** `release.sh` 的 Step 1–5（API 检查 / 工作区检查 / bump / push / build），Step 6 改成 `fastlane deliver` 而不是 `xcodebuild exportArchive`。Step 7 新增 submit_for_review 与状态轮询。两脚本共享同一份 bump + build 注释 / 颜色 / 日志风格，但**不**互相调用——避免一个脚本依赖另一个脚本的内部实现。

实际落地时通过 `source` 共享工具函数（颜色、need_cmd 等），并把 release.sh 的 Step 1–5 抽成可被 source 的子函数 `release_common_steps.sh`，由两个 shell 各自调用——但这属于实现期重构提案，本变更决策记录为"风格一致 + 内部共享工具函数"，不强求 step-level source。

### 决策 6：API 环境检查沿用 `release.sh` 的 prod 校验（采用）

App Store 正式发布 **绝对不能**带 `--dart-define=APP_ENV=dev`——免费 App 也得走 prod，否则接口连不上。

`appstore-release.sh` 的 Step 1 直接复制 `release.sh` 的 `_prodBaseUrl` + `defaultValue: 'prod'` 双匹配校验逻辑，确保两个脚本的安全门一致。

### 决策 7：截图规范——仅 iPhone，最多 10 张，固定 4 种尺寸之一（采用）

**iPhone-only 应用，仅上传 iPhone 截图。**iPad / Apple Watch 截图不提交（App Store Connect 后台会显示这三个分组，我们只填 iPhone 那组）。

App Store Connect 后台对截图的硬性要求：

- **数量上限**：最多 10 张（最少 1 张；推荐 5–8 张覆盖核心场景）
- **尺寸（任选其一即可）**：
  - `1242 × 2688` px（iPhone 6.5"，最常用）
  - `2688 × 1242` px（横屏 iPhone 6.5"）
  - `1284 × 2778` px（iPhone 6.7"，iPhone 14 Pro Max 等）
  - `2778 × 1284` px（横屏 iPhone 6.7"）
- **App Preview 视频**：最多 3 个（本期**不**做，只做静态截图）

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | 仅 iPhone 截图，6.5"（1242×2688），5 张 × 2 语言（en-US + zh-Hans） | 满足 Apple 全部硬性要求；项目本来就是 iPhone-only；最少工作量；横屏 / 6.7" 二期按需 |
| B | 同时交 6.5" 横屏 + 6.7" | 工作量翻倍；视觉差异不大（同一 App 不同截图比例） |
| C | 交 iPad 截图 | 应用未针对 iPad 优化，暴露布局缺陷；提高审核风险 |

如果未来要兼容 iPad 或扩到 6.7"，再扩 metadata 与 screenshots 即可；Fastlane 目录结构支持任意多尺寸并存。

Fastlane `deliver` 会自动校验每张截图的尺寸是否落在 Apple 允许的清单里，不合规直接报错——这是天然的安全门，我们**不需要**自己写尺寸校验脚本。

### 决策 8：`submit_for_review` 失败时保留 verbose 报错，不自动重试（采用）

`fastlane deliver submit_build` 偶尔会因 App Store Connect 后端状态不一致失败（如版本尚在"处理中"）。候选方案：

| 方案 | 做法 | 评价 |
|---|---|---|
| **A（采用）** | 失败时打印 fastlane 完整错误 + Apple 返回的 JSON + 修复建议，退出非零；用户修复后重跑 | App Store Connect 错误码语义复杂（missing screenshot / wrong privacy manifest / export compliance 未勾 等），自动重试无法针对性修复 |
| B | 检测特定错误码（如"等待处理"）自动重试 | 收益小，常见错误（缺截图 / 隐私清单）重试无意义 |

## Risks / Trade-offs

- **API Key 泄漏风险** → `client/fastlane/api_key.json` 入 `.gitignore`；首次配置时模板化 `api_key.json.template` 引导用户填真实值；任何意外提交 `git log -p` 检查 + 立即到 App Store Connect 后台 revoke 旧 Key、生成新 Key。
- **Apple ID 邮箱暴露** → `Appfile` 的 `apple_id` 字段是开发者账号邮箱（半公开信息），可入 git；不属于敏感凭据。
- **metadata 写错导致审核被拒** → 二期可在 CI 加 `fastlane deliver precheck` 静态校验（必须项非空、关键词长度 ≤100、描述长度 ≤4000 等）；本期依赖人工 code review。
- **截图尺寸 / 数量不达标** → `fastlane/screenshots/README.md` 内嵌 Apple 官方尺寸清单；脚本提交前 dry-run 校验（`fastlane deliver --dry_run upload`）。
- **首次发版 App Store Connect 上无版本记录** → `appstore-release.sh` 调用 `fastlane deliver upload` 时 Fastlane 会**自动创建 App Store 版本**（基于 Appfile 的 `app_identifier`），无需预先在网页手动建。但前提是 App Store Connect 上**必须已存在 App 记录**（bundle ID = `com.yt.threads`）——这是首次发版前的硬性前置条件，由用户在 App Store Connect 网页一次性完成（约 5 分钟）。
- **fastlane 与 Flutter build 产物目录冲突** → `release.sh` 与 `appstore-release.sh` 都写 `client/build/`，但执行时机不重叠（不会同时跑）；fastlane 自己也有 `client/.fastlane/` 缓存目录，与 Flutter 的 `.dart_tool/` 隔离。已加 `.gitignore`。
- **系统 Ruby 2.6 与 Homebrew Ruby 路径冲突** → 用户安装 Homebrew Ruby 后需把 `export PATH="/opt/homebrew/opt/ruby/bin:$PATH"` 写进 `~/.zshrc`，并在 `appstore-release.sh` 头部 `command -v fastlane` 校验；找不到时给出明确安装指引并退出，避免跑到一半才发现 fastlane 缺失。
- **Apple 审核政策变更** → Fastlane 与 App Store Connect API 是 Apple 官方维护，Apple 改字段时 fastlane 通常会先发版本适配；但偶有 breaking change，季度升级 fastlane 即可（`gem update fastlane`）。
- **本地 iOS 工程升级（如 Xcode 大版本）** → `release.sh` 已踩过 Xcode 26.1.1，本变更复用其 build 路径，理论上继承同样的兼容面；出问题参考 release.sh 的踩坑记录。
