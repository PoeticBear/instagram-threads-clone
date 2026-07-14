# CLAUDE.md — 项目开发规范

## 项目概述

Instagram Threads Clone — Flutter 客户端，使用 Provider 状态管理。

## 技术栈

- Flutter 3.x + Dart
- Provider（状态管理）
- Iconsax + CupertinoIcons（图标）
- 服务端 API 文档位于 `openapi_docs/`

## 平台策略：仅维护 iOS

**本项目只维护 iOS 端，Android 不再是目标平台。**

从现在起，所有改动（功能开发、Bug 修复、重构、依赖升级、UI 调整、文档）**都忽略 Android**：

- 平台判断时**不**为 Android 写兼容代码、**不**保留 Android 入口、**不**写 Android 降级 UI。
- 新功能直接以 iOS 为目标实现。
- Android 原生层（`MainActivity.kt`、`AndroidManifest.xml`、`android/app/src/main/`）和 Android 资源**不要修改**。
- Flutter 端如需为 Android 写 `try/catch MissingPluginException` 之类的降级路径——**不需要**，直接假设 iOS 一定已实现。
- 已存在的 Android 代码可以原样保留，但不作为新功能的目标平台。
- 计划、文档、汇报、测试范围：除非显式要求，否则**不**讨论 Android 适配。

## 项目结构

```
client/
  lib/
    pages/          # 页面（每个功能一个子目录）
      home.dart     # 主页 + 底部导航栏（IndexedStack）
    state/          # Provider 状态类（全局单例）
    services/       # API 服务层
    model/          # 数据模型
    theme/          # 主题和颜色
    l10n/           # 国际化
    network/        # API Client
  ios/              # iOS 原生配置
docs/
  code-locations/   # 各核心页面 / 模块的代码定位清单
```

### 代码定位规范

当用户提出「定位某页面 / 某模块代码」类任务时：

1. **优先检索** `docs/code-locations/` 目录下是否已有对应清单（命名规则 `<feature>.md`，例如 `publish-post.md`）。
2. 若已存在对应文档，**直接返回文档内容**，并附上文件路径与最后更新时间，无需重新跑 `Glob` / `Grep`。
3. 若不存在，**再执行代码定位**（`Glob` / `Grep` / `Read`），并按现有文档的章节结构补一份新的清单写入 `docs/code-locations/<feature>.md`，再向用户回报路径。

> 现有清单：
> - [`docs/code-locations/publish-post.md`](docs/code-locations/publish-post.md) — 发布帖子（ComposePost / ComposeCameraPage）相关代码位置。
> - [`docs/code-locations/select-media.md`](docs/code-locations/select-media.md) — 选择媒体（相册 / 相机 / 上传 / 预览）相关代码位置 + 简要设计分析。
> - [`docs/code-locations/user-avatar-with-follow.md`](docs/code-locations/user-avatar-with-follow.md) — 带头像关注加号的可复用组件（`UserAvatarWithFollow`）代码定位 + 显示判定 + PostModel/PostState 扩展点 + 复用点清单。

## 架构约定

### 底部导航栏

- 使用 `IndexedStack` 常驻 5 个 Tab 页面，切换时仅改变 `index`，不销毁重建
- 5 个 Tab：Feed、Search、ComposePost、Notification、Profile
- 每个 Tab 使用 `Expanded` 等分导航栏宽度，整行均可点击
- 发帖页（ComposePost）切换离开时，通过 `handleTabSwitch` 拦截，弹出草稿保存确认对话框

### 状态管理

- `AuthState`、`PostState`、`SearchState`、`NotificationState`、`DraftState` — 全局单例（`MultiProvider` 注册）
- `ProfileState` — 本地创建（每个 ProfilePage 独立实例）

### API 服务层

- 所有 HTTP 请求通过 `ApiClient`（`client/lib/network/api_client.dart`）统一处理
- 服务类在 `client/lib/services/` 中，按功能拆分

## 编码规范

- 使用 `AppLocalizations` 进行国际化，禁止硬编码中文/英文字符串
- 颜色统一通过 `Theme.of(context).extension<AppColorsExtension>()!.colors` 获取
- 状态类中异步操作完成后需检查 `mounted` 再调用 `setState` / `notifyListeners`

## 提交代码（"提交代码" 指令规范）

当用户发送「提交代码」指令时，Claude 必须严格按以下流程执行（add → commit → push 一气呵成）。

### 执行步骤

1. **检查工作区状态**

   ```bash
   git status        # 查看所有修改和未跟踪文件
   git diff          # 查看修改细节（已跟踪文件）
   git log -5 --oneline  # 参考最近提交的风格
   ```

2. **识别并排除敏感文件**

   以下文件**严禁提交**（必须主动跳过）：
   - `.claude/settings.json` — 包含 `ANTHROPIC_AUTH_TOKEN` 等密钥
   - `*.ips` — iOS 崩溃日志（如 `Runner-*.ips`）
   - `.env`、`credentials.json`、`*.p12`、`*.mobileprovision` — 任何凭证 / 证书
   - `build/`、`.dart_tool/`、`*.log` — 编译产物和日志
   - 临时调试文件、个人 IDE 配置

   若用户明确要求提交敏感文件，必须先警告并请用户二次确认。

3. **精确暂存代码改动**

   只暂存与本次需求相关的源代码文件，使用显式路径而非 `git add .`：

   ```bash
   git add lib/path/to/file1.dart lib/path/to/file2.dart pubspec.yaml
   ```

4. **撰写规范的提交信息**

   - **标题（首行）**：`<type>: <简短中文描述> — <可选副标题>`
     - `type` 使用 [Conventional Commits](https://www.conventionalcommits.org/) 前缀：
       - `feat:` 新功能
       - `fix:` Bug 修复
       - `refactor:` 重构（不改变行为）
       - `style:` 仅样式 / 格式（不改逻辑）
       - `docs:` 文档变更
       - `chore:` 构建 / 依赖 / 工具变更
       - `perf:` 性能优化
       - `test:` 测试相关
     - 标题保持 50 字以内，无句号
   - **正文（可选）**：用 `-` 列出关键改动点，聚焦「为什么」而非「做了什么」
   - **Footer（必加）**：Claude Code 协作标识

   使用 HEREDOC 传递消息以保证格式正确：

   ```bash
   git commit -m "$(cat <<'EOF'
   fix: 完善注册与个人中心 — 自动登录跳转 + username 兜底 + 刷新不丢数据

   - 注册成功后自动调用 signin 拿 token，再加载用户资料并跳转 HomePage
   - /user/profile/{id} 接口不返回 username，改用 /user/me 的值兜底
   - MyProfilePage 用 listen: false 避免下拉刷新时 ProfileState 被重建
   - 个人中心 displayName 为空时回退显示 username

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

5. **推送到远程仓库**

   ```bash
   git push origin main
   ```

6. **验证结果**

   ```bash
   git status            # 确认工作区干净（或仅剩未跟踪的敏感文件）
   git log -1 --oneline  # 确认提交已落地
   ```

### 安全红线

- ❌ 永远不要使用 `git add .` 或 `git add -A`（会把敏感文件一并暂存）
- ❌ 永远不要使用 `--no-verify`、`--force` 等绕过校验的参数（除非用户显式要求）
- ❌ 永远不要修改 `.gitconfig`（用户身份配置）
- ❌ 永远不要 `git commit --amend` 已推送到远程的 commit
- ✅ 若 pre-commit hook 失败，修复问题后**创建新 commit**，而非 amend

### 撤销策略

若用户在 push 之后要求撤销，使用 `git revert <commit>` 生成反向 commit，**不要**用 `git reset --hard` 改写远程历史。

## API 环境切换

通过编译期 `--dart-define=APP_ENV=...` 控制 `client/lib/network/api_config.dart` 中的 `baseUrl`：

- **默认（Release / TestFlight）**：`baseUrl` = `https://api.tweetcaht.com/`
- **开发调试**：`flutter run --dart-define=APP_ENV=dev`（指向 `http://192.168.1.27:8005/`）
- **打 dev 包**：`flutter build ipa --dart-define=APP_ENV=dev`

> 任何非 `dev` 的值（含 `prod`、`staging`、空串）一律走 prod。任何 release / TestFlight 构建都不要带 `--dart-define=APP_ENV=dev`。

## TestFlight 发布流程

详细指南见 `docs/testflight-release-guide.md`。

### 快速发布步骤

```bash
# 1. 更新版本号（在 client/pubspec.yaml 中）
#    格式：version: {主版本}.{次版本}.{修订号}+{构建序号}
#    例：1.0.0+6 → 1.0.0+7

# 2. 构建 Release IPA
cd client
flutter build ipa --release

# 3. 创建上传配置
mkdir -p build/ios/upload
cat > build/ios/upload/UploadOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>B3885SFCQJ</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
EOF

# 4. 导出并上传到 TestFlight
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/upload \
  -exportOptionsPlist build/ios/upload/UploadOptions.plist \
  -allowProvisioningUpdates
```

### 版本号规则

- **主版本.次版本.修订号**：功能变更时手动更新（如 1.0.0 → 1.1.0）
- **构建序号**（`+` 后的数字）：每次发布递增 1，不可重复
- 每次发布前必须更新构建序号，否则上传会被 App Store Connect 拒绝

## 一键发布到 TestFlight（「发布 TestFlight」/「发版」指令）

当用户发送「**发布 TestFlight**」「**发版**」「**打包发布**」指令时，Claude 必须按以下流水线**一次性、按顺序**完成发布，无需用户逐步确认（遇到报错或敏感文件时除外）。详细命令参数见 `docs/testflight-release-guide.md`。

### 触发指令

- `发布 TestFlight`
- `发版`
- `打包发布到 TestFlight`

### 推荐方式：使用 `client/scripts/release.sh`

收到发版指令时，**优先使用** `client/scripts/release.sh` 一键脚本完成整个流水线。脚本封装了下方「流水线步骤」的全部 6 步，并额外提供：

- **实时进度展示**：xcodebuild 原始输出（含 `Progress xx%`）直接打印到终端，不再「看不到进度」
- **日志落盘**：同步 `tee` 到 `client/build/ios/upload/upload.<timestamp>.log`，便于排错
- **卡顿检测 + 自动重试**：上传日志 5 分钟无更新判定为 Apple 端卡顿 → 自动 `kill` 重试，最多 3 次（实测正常 1 分 30 秒左右完成）
- **参数化**：`--only-upload`（仅重传 IPA）/ `--no-bump`（跳过构建号递增）/ `--no-push`（跳过 git push）

```bash
# 完整发布（默认）
./client/scripts/release.sh

# 只重新上传（IPA 已存在，跳过 bump/build；默认隐含 --no-bump）
./client/scripts/release.sh --only-upload

# 跳过构建号 bump（用于上传失败重试，避免重复递增）
./client/scripts/release.sh --no-bump

# 组合使用
./client/scripts/release.sh --only-upload --no-bump

# 查看完整用法
./client/scripts/release.sh --help
```

> 推荐设置 alias：`echo "alias release='$PWD/client/scripts/release.sh'" >> ~/.zshrc && source ~/.zshrc`，之后在任何目录执行 `release` 即可。

脚本若因环境问题不可用（如缺少依赖、权限异常），回退到下方手动流水线步骤。

### 流水线步骤（脚本底层逻辑 / 手动回退参考）

1. **确认 API 指向生产环境**
   - 读 `client/lib/network/api_config.dart`，确认 `_prodBaseUrl` = `https://api.tweetcaht.com/` 且 `defaultValue: 'prod'`。
   - 若被临时改成 dev，先改回 prod 再继续。

2. **提交未发布代码**（遵循上文「## 提交代码」全部规范）
   - `git status` / `git diff` 审查改动；**跳过** `.claude/settings.json`、`*.ips`、`.env`、证书等敏感文件。
   - 精确 `git add <路径>` 暂存功能改动并 `git commit`（Conventional Commits + HEREDOC + Claude 协作 footer）。
   - 若工作区无未提交功能改动，跳过本步。

3. **递增构建序号**
   - 在 `client/pubspec.yaml` 中把 `+N` 改成 `+(N+1)`。
   - 作为**独立 commit**：`chore: bump build to {版本}+{新序号} for TestFlight release`。

4. **推送到远程**
   - `git push origin main`。

5. **构建 Release IPA**
   - `cd client && flutter build ipa --release`。
   - **禁止**带 `--dart-define=APP_ENV=dev`（release / TestFlight 一律走 prod）。
   - 确认产物 `build/ios/archive/Runner.xcarchive` 存在，Version / Build Number 与预期一致。

6. **导出并上传到 App Store Connect**
   - 创建 `build/ios/upload/UploadOptions.plist`（`method: app-store-connect` + `destination: upload`）。
   - `xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportPath build/ios/upload -exportOptionsPlist build/ios/upload/UploadOptions.plist -allowProvisioningUpdates`。
   - 看到 `** EXPORT SUCCEEDED **` 即上传成功。

7. **回报结果**
   - 给出本次版本号（如 `1.0.0+12`）、commit hash、上传状态。
   - 提醒：App Store Connect 处理约需 5–15 分钟，之后可在 TestFlight 看到新构建。

### 失败处理

- 构建 / 上传失败：定位错误（签名 / 网络 / 配置），修复后从失败步骤重试；**不要**再次递增构建序号，除非上一次已经上传成功。
- 上传成功后被 App Store Connect 拒绝（如 ITMS-90683）：按报错修完后，**必须**再递增一次构建序号重新上传。

### 安全红线（同「## 提交代码」）

- ❌ 不用 `git add .` / `git add -A`
- ❌ release 包**绝不**带 `--dart-define=APP_ENV=dev`
- ❌ 不提交 `.claude/settings.json`、`*.ips`
- ✅ build bump 的 commit 信息必须显式标注版本号

## 一键发布到 App Store 正式环境（「发布 App Store」/「分发」指令）

与「发布 TestFlight」平级。本流水线把 IPA 推到 **App Store 正式分发**（公开上架），首次需要完成 App Store Connect 端的若干一次性配置；后续发版一键搞定。

### 与 TestFlight 的关系

| 用途 | 脚本 | 推到哪里 |
|---|---|---|
| 内测 / TestFlight 测试 | `./client/scripts/release.sh` | TestFlight（仅测试员可见） |
| **正式分发 / 上架** | `./client/scripts/appstore-release.sh` | App Store 公开（审核后全网可见） |

两脚本**平级并存、互不依赖**，可以单独使用任一。

### 前置条件（首次需一次性配置）

1. **已安装 fastlane**：`gem install fastlane`（建议 Homebrew Ruby，避免污染系统 Ruby 2.6）
2. **App Store Connect API Key**：
   - 后台生成：`用户和访问` → `集成` → `App Store Connect API` → 生成（角色：App Manager）
   - 填入 `client/fastlane/api_key.json`（模板：`api_key.json.template`，已 gitignore）
   - `.p8` 放 `client/fastlane/auth/AuthKey_<KEY_ID>.p8`（目录已 gitignore）
3. **`Appfile` 的 `apple_id`** 替换为真实 Apple ID 邮箱
4. **App Store Connect 上 App 记录已存在**（bundle ID = `com.yt.threads`）
5. **ATB（协议 / 税务 / 银行）已生效**——首次开发者账号一次性完成，5–10 分钟
6. **元数据**：`client/fastlane/metadata/{en-US,zh-Hans}/*.txt`（已含 AI 占位文案，待替换）
7. **截图**：`client/fastlane/screenshots/{en-US,zh-Hans}/iPhone6.5/*.png`（当前为占位图，提交前必须替换为真实 App 截图）

### 触发指令

- `发布到 App Store`
- `分发到 App Store`
- `上架`

### 流水线步骤（脚本底层逻辑）

`appstore-release.sh` 按顺序执行 9 个 Step：

1. **API 环境检查**：读 `client/lib/network/api_config.dart`，确认 `_prodBaseUrl` 与 `defaultValue: 'prod'`
2. **API Key 检查**：校验 `api_key.json` + `.p8` 文件 + `Appfile` 已配置
3. **工作区检查**：排除 `.claude/`、`.ips`、fastlane 敏感文件，未提交改动提示
4. **bump 构建号**：解析 `pubspec.yaml` 的 `version: X.Y.Z+N`，独立 commit
5. **git push**：推送到 origin main
6. **flutter build ipa --release**（禁止带 `--dart-define=APP_ENV=dev`）
7. **上传 IPA**：复用 `release.sh` 的 xcodebuild exportArchive + 卡顿检测 + 自动重试
8. **上传 metadata + 截图**：`fastlane ios upload_listing`（跳过人机交互 `force: true`）
9. **提交审核**：`fastlane ios submit_for_review`（`automatic_release: true` 审核通过自动上架）

### 常用命令

```bash
# 完整发布
./client/scripts/appstore-release.sh

# 跳过 bump（上传失败重试）
./client/scripts/appstore-release.sh --no-bump

# 只重新上传 + 提交（IPA 已存在）
./client/scripts/appstore-release.sh --only-upload

# 准备但暂不提交审核
./client/scripts/appstore-release.sh --no-submit

# 推荐 alias
echo "alias release-appstore='$PWD/client/scripts/appstore-release.sh'" >> ~/.zshrc && source ~/.zshrc
```

### 失败处理

- **API Key 错误（401）**：检查 `api_key.json` 的 `key_id` / `issuer_id` / `.p8` 路径
- **Metadata 缺字段**：跑 `cd client && fastlane ios precheck` 看具体缺啥
- **截图尺寸不合规**：`fastlane ios precheck` 会列出不合规文件
- **审核被拒**：常见是「隐私政策 URL 不可访问」或「截图与实际功能不符」

详细排错见 `docs/appstore-release-guide.md`。

### 安全红线

- ❌ `api_key.json` 与 `auth/*.p8` **绝不**入 git（已在 `.gitignore`）
- ❌ App Store 包**绝不**带 `--dart-define=APP_ENV=dev`
- ❌ 不写 Android 适配（本项目仅维护 iOS）
- ✅ build bump 的 commit 信息必须显式标注版本号
- ✅ 提交前确认截图是真实 App 截图（非 AI 占位图）

## 变更日志（changelog）约定

每次完成「**发布 TestFlight**」流水线后，Claude **必须**在 `docs/changelog/` 下记录本次发版。变更日志面向**人**（团队成员、TestFlight 测试员、未来的自己），与 `git log` 互为补充——commit 记录「改了哪些文件」，changelog 记录「用户能感知到什么」。

### 文件命名

| 类型 | 命名 | 何时使用 | 是否必填 |
| --- | --- | --- | --- |
| 摘要文件 | `v{主}.{次}.{修}.md`（如 `v1.0.0.md`） | SemVer 升级时对该版本做总览 | 可选 |
| 构建文件 | `v{主}.{次}.{修}+{构建号}.md`（如 `v1.0.0+18.md`） | 每次 TestFlight 发布后新建 | **必填** |

> SemVer 升级到 1.0.1 后，构建文件命名切换为 `v1.0.1+N.md`，同时建议新建一份 `v1.0.1.md` 摘要作为该 SemVer 的门面。

### 写入内容

按 Conventional Commits 分类（✨ 新增功能 / 🐛 修复 / ⚡ 性能优化 / 🎨 样式调整 / ♻️ 重构 / 📝 文档 / 🔧 构建），每条**简述用户可感知的改动**（不是 commit 标题的复述），并标注 commit hash 前 7 位。模板见 [`docs/changelog/template.md`](docs/changelog/template.md)。

### 索引维护

同步在 [`docs/changelog/README.md`](docs/changelog/README.md) 的「全部版本」表追加一行，**最新版本放最上方**；同时更新「当前版本」区的指向。

### 与「发布 TestFlight」流程的衔接

在原有流水线 6 步之后，**新增步骤 7**：

1. 确认 API 指向生产环境
2. 提交未发布代码
3. 递增构建序号
4. 推送到远程
5. 构建 Release IPA
6. 导出并上传到 App Store Connect
7. **新增** — 在 `docs/changelog/v{主}.{次}.{修}+{新构建号}.md` 新建文件，按本次发版涉及的 commit 填写各分类；同时更新 `docs/changelog/README.md` 索引；`git add docs/changelog/` + commit `docs: 更新 changelog — v{主}.{次}.{修}+{新构建号}` + push。
8. 回报结果（版本号、commit hash、上传状态）

### 安全红线

- ❌ 变更日志里**不要**写密钥、token、内部接口地址
- ❌ 变更日志文件**不**参与 release 包构建（只在 `docs/` 下，不在 `client/` 下）
- ✅ changelog commit 与发版 commit 分离，标题加 `docs:` 前缀
