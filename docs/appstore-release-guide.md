# iOS 发布到 App Store 正式环境 — 完整指南

> 把 Tweet 推上 App Store 公开分发的端到端指南。`appstore-release.sh` 已经封装了 90% 的工作，本文重点讲**首次配置**与**排错**。

## 0. 整体流程

```
┌──────────────────────────────────────────────────────────────────────┐
│  一次性配置（首次）                                                    │
│  ───────────────                                                      │
│  1. 装 fastlane                                                       │
│  2. App Store Connect 后台生成 API Key                                 │
│  3. 填 client/fastlane/api_key.json + 放 .p8 文件                      │
│  4. 改 client/fastlane/Appfile 的 apple_id                             │
│  5. 准备 metadata（11 个文本文件 × N 语言）                            │
│  6. 准备截图（最多 10 张 × N 语言）                                    │
│  7. App Store Connect 后台创建 App 记录                                │
│  8. ATB（协议 / 税务 / 银行）一次性签署                                │
│                                                                      │
│  每次发版（一条命令搞定）                                              │
│  ──────────────────                                                   │
│  $ ./client/scripts/appstore-release.sh                               │
│                                                                      │
│  → bump → commit → push → build → 上传 IPA → 上传 metadata → 提交审核   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 1. 前置条件清单

### 1.1 工具

| 工具 | 最低版本 | 安装 |
|---|---|---|
| Ruby | ≥ 2.6（推荐 3.0+） | `brew install ruby` |
| fastlane | 最新 | `gem install fastlane --no-document` |
| Flutter | 3.x | https://flutter.dev |
| Xcode | 15+ | App Store |
| xcodebuild | 与 Xcode 同 | Xcode Command Line Tools |

### 1.2 Apple 端

- [ ] **付费 Apple Developer Program**（$99/年）—— 发布任何 App 到 App Store 的前提
- [ ] **ATB（协议 / 税务 / 银行）已生效**——5–10 分钟搞定
- [ ] **App Store Connect App 记录已存在**（bundle ID = `com.yt.threads`）

### 1.3 项目端

- [ ] `client/fastlane/api_key.json` 已配置
- [ ] `client/fastlane/auth/AuthKey_<KEY_ID>.p8` 已就位
- [ ] `client/fastlane/Appfile` 的 `apple_id` 已填真实邮箱
- [ ] `client/fastlane/metadata/{en-US,zh-Hans}/*.txt` 已就位（隐私政策 URL 不能是占位）
- [ ] `client/fastlane/screenshots/{en-US,zh-Hans}/iPhone6.5/*.png` 是**真实 App 截图**

---

## 2. 首次配置详解

### 2.1 装 fastlane

```bash
# 推荐用 Homebrew Ruby，避免污染系统 Ruby
brew install ruby
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc

# 装 fastlane
gem install fastlane --no-document

# 验证
fastlane --version
```

### 2.2 生成 App Store Connect API Key

1. 打开 https://appstoreconnect.apple.com
2. 顶部 **用户和访问** → **集成** → **App Store Connect API**
3. 点 **生成 API Key**：
   - 名称：任意（如 `tweet-fastlane`）
   - 访问权限：**App Manager** 或更高
4. 生成后**立即下载** `.p8` 文件（**只能下载一次**），记下：
   - **Key ID**（10 位字符串）
   - **Issuer ID**（UUID 格式）

### 2.3 落盘 .p8 + 填 api_key.json

```bash
mkdir -p client/fastlane/auth
cp ~/Downloads/AuthKey_<KEY_ID>.p8 client/fastlane/auth/

cp client/fastlane/api_key.json.template client/fastlane/api_key.json
# 编辑 api_key.json，把 REPLACE_WITH_* 替换成真实值
```

```json
{
  "key_id": "<KEY_ID>",
  "issuer_id": "<ISSUER_ID>",
  "key_filepath": "auth/AuthKey_<KEY_ID>.p8",
  "duration": 1200,
  "in_house": false
}
```

### 2.4 改 Appfile

```ruby
# client/fastlane/Appfile
app_identifier "com.yt.threads"
apple_id "your-real-apple-id@example.com"  # ← 改成真实 Apple ID 邮箱
team_id "B3885SFCQJ"
```

### 2.5 准备 metadata

首版覆盖 `en-US` + `zh-Hans`。每个语言下 11 个文本文件：

| 文件 | 限制 | 说明 |
|---|---|---|
| `name.txt` | ≤ 30 字符 | App Store 上显示的应用名 |
| `subtitle.txt` | ≤ 30 字符 | 副标题，名字下面那一行 |
| `description.txt` | ≤ 4000 字符 | 详细描述 |
| `keywords.txt` | ≤ 100 字符 | 逗号分隔，搜索关键词 |
| `release_notes.txt` | ≤ 4000 字符 | 本次发版说明 |
| `privacy_url.txt` | URL | **必填**，否则审核被拒 |
| `support_url.txt` | URL | 用户支持页面 |
| `marketing_url.txt` | URL（可选） | 营销页面 |
| `copyright.txt` | 字符串 | 版权信息 |
| `primary_category.txt` | 类别名 | `Social Networking` |
| `secondary_category.txt` | 类别名 | `Photo & Video` |

### 2.6 准备截图（iPhone-only 应用）

**Apple 硬性要求：**

- **数量**：最多 10 张（推荐 5–8 张）
- **尺寸（任选其一）**：
  - `1242×2688`（6.5" iPhone，最常用）
  - `2688×1242`（横屏）
  - `1284×2778`（6.7" iPhone）
  - `2778×1284`（横屏）
- **不交**：iPad 截图、Apple Watch 截图、App Preview 视频

**生成真实截图的方法：**

```bash
# 1. 启动模拟器
open -a Simulator

# 2. 在模拟器里打开 App，导航到要截的页面

# 3. 截图
xcrun simctl io booted screenshot ~/Desktop/01_login.png

# 4. 调整尺寸（如果原始尺寸不对）
sips -z 2688 1242 ~/Desktop/01_login.png --out client/fastlane/screenshots/en-US/iPhone6.5/01_login.png
```

**真机**：iPhone 截屏 → AirDrop → `sips` 调尺寸 → 归档到对应目录。

### 2.7 创建 App 记录

1. App Store Connect → **我的 App** → **+** → **新建 App**
2. 填写：
   - 平台：iOS
   - 名称：Tweet
   - 主要语言：简体中文 / English
   - Bundle ID：com.yt.threads
   - SKU：任意（如 001）
3. 创建后无需填写任何资料——`appstore-release.sh` 会自动同步

### 2.8 ATB（首次开发者账号一次性）

App Store Connect → 顶部 **协议 / 税务 / 银行业务** 标签页：
- 签署最新《Apple Developer Program License Agreement》
- 完成税务问卷（W-9 / W-8BEN 等）
- （可选）填银行账号——免费 App 也能不填，但建议填好为未来内购做准备

**全部检查项看到绿勾即可。** 5–10 分钟搞定。

---

## 3. 首次发布

```bash
# 1. 跑 dry-run 校验（不动 App Store Connect）
cd client && fastlane ios precheck

# 2. 准备但暂不提交（先肉眼确认）
./client/scripts/appstore-release.sh --no-submit

# 3. 登录 App Store Connect → 我的 App → Tweet → 活动 → 找到新上传的版本
#    检查：metadata / 截图 / 选中的构建 / 加密合规 / 隐私问卷
#    一切 OK 后：

# 4. 完整流程（含提交审核）
./client/scripts/appstore-release.sh
```

**预计耗时**：bump + build + 上传 IPA + 上传 metadata ≈ 10–20 分钟，**审核 24–48 小时**。

---

## 4. 排错

### 4.1 API Key 错误

```
Authentication failed. Please verify your credentials.
```

排查：
1. `api_key.json` 的 `key_id` / `issuer_id` 与后台一致？
2. `.p8` 文件路径正确？
3. API Key 角色是 App Manager？
4. Apple Developer Program 账号未过期？

### 4.2 Metadata 缺字段

```
❌ The following metadata is missing: privacy_url
```

`privacy_url.txt` 还在占位符 `[TODO: REPLACE WITH YOUR REAL PRIVACY POLICY URL]` —— 填真实 URL。

### 4.3 截图尺寸不合规

```
❌ Screenshot size 1170×2532 is not supported
```

跑 `sips` 把截图调整到 `1242×2688`（或 Apple 允许的其他三种尺寸之一）。

### 4.4 审核被拒

| 拒绝理由 | 原因 | 解决 |
|---|---|---|
| 隐私政策 URL 不可访问 | URL 是假的或私有 | 部署真实公开页面 |
| 截图与实际功能不符 | 当前是 AI 占位图 | 替换为真实 App 截图 |
| 缺失 export compliance 声明 | 后台加密合规未勾选 | App Store Connect → App 信息 → 加密 → 选「不适用」 |
| 数据收集声明不准确 | App 隐私问卷填错 | 后台如实填写 |
| 误导性元数据 | 描述 / 截图承诺的功能 App 实际没有 | 调整元数据与实际功能一致 |

---

## 5. 进阶

### 5.1 加更多语言

每加一国语言，建一个 `client/fastlane/metadata/<locale>/` 子目录，放 11 个 .txt 文件，截图放 `client/fastlane/screenshots/<locale>/iPhone6.5/`。

常用 locale：`en-US`、`zh-Hans`、`zh-Hant`、`ja`、`ko`、`fr-FR`、`de-DE`、`es-ES`、`pt-BR`。

### 5.2 iPad 支持

如果未来要支持 iPad：
- 在 `Info.plist` 加 `UISupportedInterfaceOrientations~ipad` 已有
- 在 `Info.plist` 加 `UIDeviceFamily` = `[1, 2]`（1 = iPhone，2 = iPad）
- 跑模拟器生成 iPad 截图，归档到 `screenshots/<locale>/iPad*.png`
- 调整 `Fastfile` 跳过 iPad 尺寸警告

### 5.3 App Preview 视频

Apple 允许最多 3 个 15-30 秒的 App Preview 视频（演示 App 怎么用）。本期未做，需要后续扩展：
- 用 QuickTime 录屏
- 用 iMovie 剪辑
- 导出 H.264 编码的 `.mov` 或 `.m4v`
- 归到 `screenshots/<locale>/<device>/`（与截图同目录）
- 尺寸与对应截图一致

---

## 6. 与 TestFlight 流水线的关系

| | TestFlight（release.sh） | App Store（appstore-release.sh） |
|---|---|---|
| 推到哪里 | App Store Connect → TestFlight | App Store Connect → 正式版本 |
| 可见范围 | 仅测试员（受邀） | 全网公开 |
| 是否需要审核 | 否（TestFlight 快速审核） | 是（24-48h） |
| metadata | 不用 | 必填 |
| 截图 | 不用 | 必填 |
| 何时用 | 内部迭代 / QA | 准备上架 / 正式发版 |

**最佳实践**：开发期内用 release.sh 推 TestFlight 做 QA；临近发版时切到 appstore-release.sh。
