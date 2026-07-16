## Context

`NamePage`（`client/lib/auth/signup/name.dart`，512 行）是 iOS 客户端的登录入口（session 过期后 `main.dart:208-211` 也跳此页面），承载 4 个登录入口：账号密码、Apple、Google、跳转 `PhoneLoginPage`。当前 `class _NamePageState` 持有一个页面级 `bool _isLoading`，由 `_handleLogin` / `_handleAppleSignIn` / `_handleGoogleSignIn` 三个 handler 共享开关。

页面渲染时，账号密码按钮与 Apple 按钮的 `child` 都按以下模式编写：

```dart
child: _isLoading
    ? CircularProgressIndicator(color: appColors.background)  // 登录按钮
    : Text(...)
```

```dart
child: _isLoading
    ? Center(child: SizedBox(width: 20, height: 20,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))  // Apple 按钮
    : Row(...)
```

后果：用户点击任一入口 → `_isLoading = true` → 重建后两个按钮的 child 都被替换为 spinner，**实际只有一处请求在飞**，但 UI 表现成「两个动作同时在跑」。Google 按钮的 onTap 也被 `onTap: _isLoading ? null : _handleGoogleSignIn` 禁用但视觉不变，更强化了「不一致」的观感。

## Goals / Non-Goals

**Goals：**

- 任何登录请求在飞时，**全页只显示一个加载指示器**，位置居中、不依附于按钮
- 加载期间所有可点击元素（4 个登录入口 + 输入框）整体不可交互
- 加载期间拦截系统返回手势，防止用户「取消中误触返回」导致 `_isLoading` 卡在 true 或重复触发请求
- 改动范围限定在 `name.dart` 一个文件

**Non-Goals：**

- 不抽公共 `LoadingOverlay` 组件到 `client/lib/common/`（YAGNI；`phone.dart` / `register.dart` 没此 bug）
- 不重构 `_isLoading` 为 `AuthState.isBusy`（后者会被 `getProfileUser` 等流程污染）
- 不动 `phone.dart` / `register.dart`（它们用拆分 flag 已规避同问题）
- 不新增 l10n 文案（遮罩不展示文字）
- 不动 `docs/code-locations/login.md`

## Decisions

### Decision 1：在文件内私有 helper，不抽公共组件

- **选择**：在 `_NamePageState` 旁新增私有 method `_loadingOverlay({required bool loading, required Widget child})`
- **理由**：
  - 当前只有 `name.dart` 有此 bug，`phone.dart` 用拆分 flag 规避、`register.dart` 单按钮无问题
  - 提前抽公共组件违反 YAGNI——若未来真出现第二个使用场景再抽
  - 私有 helper 比内联 `Stack` 可读性更好，方法名即文档
- **替代方案**：抽到 `client/lib/common/loading_overlay.dart` 全项目共享——否决，理由同上

### Decision 2：遮罩结构 = `Stack` + `Positioned.fill` + `IgnorePointer` + `ColoredBox` + `Center`

- **选择**：
  ```dart
  Widget _loadingOverlay({required bool loading, required Widget child}) {
    return Stack(
      children: [
        child,
        if (loading)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0xCC000000),  // 半透明黑
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
  ```
- **理由**：
  - `Positioned.fill` 保证遮罩覆盖整个 `Scaffold.body`（含 SafeArea），不挡住底部导航等系统级 UI
  - `IgnorePointer`（默认行为）屏蔽所有点击；不需要再用 `AbsorbPointer`，因为我们想让 spinner 之后的 child 树继续响应（其实也不会，因为遮罩在最上层）
  - 颜色用 `0xCC000000`（80% 不透明黑）而非 `appColors.background.withOpacity(0.6)`：后者在浅色模式下白底配白 spinner 完全不可见；黑色 + 白色 spinner 在浅深主题下都有足够对比度
  - `Colors.white` 配黑色背景是兜底安全选择，不依赖 `appColors.textPrimary`（在某些主题下可能与黑色背景冲突）
- **替代方案**：
  - 用 `appColors.background.withOpacity(0.6)` + `appColors.textPrimary` spinner——否决，浅色主题下白底白 spinner 不可见
  - 用 `ModalBarrier`（dismissible 拦截 + 半透明）——否决，`ModalBarrier` 是 `Navigator` 层级的，更适合拦截路由而非渲染遮罩
  - 抽到独立组件并加 `AnimatedOpacity` 平滑过渡——否决，登录请求一般 < 1s 反馈，平滑过渡反而显得迟钝；保持闪现/消失更直接

### Decision 3：拦截返回 = `PopScope(canPop: !_isLoading)`

- **选择**：
  ```dart
  return PopScope(
    canPop: !_isLoading,
    child: Scaffold(...),
  );
  ```
- **理由**：
  - `NamePage` 无 AppBar，左上无返回按钮，但系统级「右滑返回」手势仍可触发
  - 转圈期间拦截返回避免：
    1. 用户「转圈太久以为卡了，手滑返回」后 `_isLoading` 残留在 `true` 状态（虽然页面已 dispose，但若 push 回退栈时复用 state 会出问题）
    2. 用户在请求途中重进登录页触发重复请求
  - 加载完成后 `canPop` 自动恢复为 `true`，无需手动 setState
- **替代方案**：不拦截——否决，理由同上

### Decision 4：保持局部 `_isLoading`，不复用 `AuthState.isBusy`

- **选择**：维持 `bool _isLoading` 字段，仅在 helper 入参读取
- **理由**：
  - `AuthState.isBusy` 在 `getProfileUser` / `signIn` / `signInWithApple` / `signInWithGoogle` / `signInWithSms` / `register` / `setUsername` / `updateUserProfile` / `getCurrentUser` 等多个流程都会被置 `true`
  - 登录请求飞完后还有 `getProfileUser` 阶段（`name.dart:147` 的 `await getProfileUser()`），此阶段 `isBusy` 也是 `true`——但此时用户视角的「loading」应该结束了
  - 用局部 `_isLoading` 严格只在三个 handler 的 `setState(() => _isLoading = true/false)` 区间内为 `true`，与「页面级遮罩该何时显示」的语义精确对应
- **替代方案**：
  - 用 `Consumer<AuthState>` 监听 `isBusy`——否决，理由同上
  - 新增独立的 `LoginLoadingState` Provider——否决，scope 不符

## Risks / Trade-offs

- **[Risk] 浅色主题下黑色半透明遮罩可能略突兀** → Mitigation：选 0xCC（80%）不透明而非 0x88（53%），避免下方表单文字透过；用户能感知到「页面被锁定」即可，符合「加载中」的通用隐喻；上线后如收到反馈再调透明度
- **[Risk] 遮罩期间 Apple ID / Google Sign-In 系统弹窗可能还在显示** → Mitigation：`Positioned.fill` 覆盖整个 `Scaffold.body` 但不会覆盖到 `Navigator` 顶层的系统弹窗（Apple/Google SDK 自己用 UIWindow 渲染），spinner 出现在弹窗后方是正常行为，与 iOS 系统惯例一致
- **[Risk] Google 按钮目前 UI 完整但 onTap 仍禁用，按钮「无视觉反馈」的不一致仍然存在** → Mitigation：本次聚焦「spinner 重复」bug 修复；Google 按钮禁用样式不一致是另一个独立 UI 任务，不在本次 scope；如需顺手可加 `color: _isLoading ? appColors.surfaceSecondary : Colors.white` 灰化背景，留待后续
- **[Trade-off] 没有 `AnimatedOpacity` 平滑过渡，加载结束 spinner 突然消失** → 接受：登录请求通常 < 1s，硬切换更直接；如未来接 SSO/邮箱等长耗时登录再考虑加淡出
- **[Trade-off] `IgnorePointer` 会让遮罩期间无法点击 TextField 输入** → 接受：这是改进而非退化（用户不该在请求中改表单）；原代码下 `onPressed: _isLoading ? null` 只禁按钮不禁输入框，新行为更严格
