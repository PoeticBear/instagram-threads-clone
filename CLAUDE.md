# CLAUDE.md — 项目开发规范

## 项目概述

Instagram Threads Clone — Flutter 客户端，使用 Provider 状态管理。

## 技术栈

- Flutter 3.x + Dart
- Provider（状态管理）
- Iconsax + CupertinoIcons（图标）
- 服务端 API 文档位于 `openapi_docs/`

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
```

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
