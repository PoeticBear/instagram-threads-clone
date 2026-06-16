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
