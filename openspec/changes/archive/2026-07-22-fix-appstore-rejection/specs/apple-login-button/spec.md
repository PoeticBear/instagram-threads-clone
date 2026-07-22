## ADDED Requirements

### Requirement: 使用官方 Sign in with Apple 按钮组件

App 的「通过 Apple 登录」入口 SHALL 使用 `sign_in_with_apple` 包提供的官方 `SignInWithAppleButton` 组件渲染，而非自定义 `Container` + `GestureDetector`。

#### Scenario: 浅色主题下展示黑底 Apple 登录按钮

- **WHEN** 用户处于登录页（`NamePage`）、浅色主题且未处于加载态
- **THEN** 页面渲染官方 `SignInWithAppleButton`，样式为 `.black`，按钮高度与现有登录主按钮一致

#### Scenario: 深色主题下展示白底黑字 Apple 登录按钮

- **WHEN** 用户处于登录页（`NamePage`）、深色主题（`Theme.of(context).brightness == Brightness.dark`）
- **THEN** 按钮样式切换为 `SignInWithAppleButtonStyle.white`（白底黑字），避免纯黑按钮融入深色背景而无法辨识

#### Scenario: 点击触发 Apple 登录流程

- **WHEN** 用户点击 Apple 登录按钮
- **THEN** 触发现有的 `_handleAppleSignIn` 流程（获取 Apple 凭据 → 调后端 `/auth/apple/login`）

### Requirement: 加载与禁用态

按钮 SHALL 在登录进行中阻止重复触发，并通过页面级加载遮罩反馈进度。

#### Scenario: 登录进行中拦截重复点击

- **WHEN** Apple 登录流程进行中（`_isLoading` 为 true）
- **THEN** 页面级 `_loadingOverlay` 覆盖按钮区域，阻止用户再次触发登录

### Requirement: 满足 HIG 可访问性

按钮 SHALL 通过官方组件获得正确的 Apple Logo 字形、本地化标题与无障碍语义标签，符合 Apple Human Interface Guidelines。

#### Scenario: VoiceOver 可识别按钮用途

- **WHEN** 视障用户通过 VoiceOver 聚焦到 Apple 登录按钮
- **THEN** 读出本地化的「通过 Apple 登录」语义，且该控件可被激活

### Requirement: 按钮文案跟随 App 语言设置

按钮文字 SHALL 跟随用户在「设置 → 语言」选择的语言（中文 / 英文），而非写死英文。通过向官方组件传入本地化的 `loginWithApple` 文案实现（`sign_in_with_apple` 的 `text` 默认是写死的英文 `'Sign in with Apple'`，组件本身不做本地化）。

#### Scenario: 中文环境下显示中文文案

- **WHEN** App 语言设置为中文（`LocaleProvider.locale == Locale('zh')`）
- **THEN** Apple 登录按钮显示「通过 Apple 登录」

#### Scenario: 英文环境下显示英文文案

- **WHEN** App 语言设置为英文（`Locale('en')`）
- **THEN** Apple 登录按钮显示「Continue with Apple」
