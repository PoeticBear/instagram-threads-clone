# 登录流程优化

> 本文档用于记录本次「登录流程优化」任务的上下文与执行过程。
> 使用方式：先定位相关代码 → 再细化优化需求 → 最后落地实施。

## 一、任务目标

对应用内的登录流程进行优化（细节待梳理后补充）。

## 二、当前流程现状

应用有 **4 条进入登录态的路径**，它们全部收口在同一个方法 `AuthState.getProfileUser()`（`auth.state.dart:444`）里拉取并合并用户资料；但「进入应用（跳 HomePage）」的动作却**分散写在 3 个地方**（登录页、注册页、Splash）。目前**没有任何一处对 username 是否为空做校验**——非账号密码注册的用户（如 Apple 登录）登录后 username 可能为空，仍会直接进入应用，导致个人中心等依赖 username 的页面数据残缺。详细代码定位见第三节，拟定方案见第七节。

## 三、相关代码定位

> ⚠️ **重要**:下方 3.1 / 3.2 所列接口契约取自 `openapi_docs/`,**该文档可能已过时**。实际字段、行为与返回结构**一律以真实请求为准**;实施前需用真实账号联调核对(尤其 `username` 相关字段)。

> 待梳理。下方分区供后续按模块逐块填写文件路径与关键逻辑。

### 3.1 接口契约（来源：`openapi_docs/auth.json`）

| # | 接口 | 方法 | 路径 | 用途 | 关键参数 | 返回 |
|---|---|---|---|---|---|---|
| 1 | Apple 登录 | POST | `/auth/apple/login` | 传入 Apple 授权码登录；**老用户直接登录、新用户自动注册并绑定 Apple** | `code` | `SigninResponse` |
| 2 | 用户名登录 | POST | `/auth/username/signin` | 账号密码登录 | `username`、`password` | `SigninResponse` |
| 3 | 用户名注册 | POST | `/auth/username/register` | 账号密码注册 | `username`、`password`、`confirm_password` | `OKResponse` |
| 4 | 刷新令牌 | POST | `/auth/token/refresh` | 用 refresh_token 换新的 access_token | `refresh_token`(可选) | `RefreshTokenResponse` |
| 5 | 退出登录 | DELETE | `/auth/logout` | 退出登录（需登录态） | — | `OKResponse` |

**返回结构：**

- `SigninResponse`（登录成功直接返回）：`id`、`username`、`avatar`、`access_token`、`refresh_token`、`display_name`
- `RefreshTokenResponse`：`access_token`、`refresh_token`

**两条登录路径的关键差异（优化时需注意）：**

- 🍎 **Apple 登录**：登录与注册**一体**，一个接口同时完成登录或注册，直接返回 `SigninResponse`（含 token）。
- 🔑 **账号密码**：注册 `/register` 与登录 `/signin` 是**两个独立接口**；且**注册接口只返回 `OKResponse`（不含 token）**，注册成功后还需再调一次 `/signin` 才能拿到登录态。

### 3.2 用户资料接口契约（来源：`openapi_docs/user.json`）

| # | 接口 | 方法 | 路径 | 用途 | 登录态 | 返回 |
|---|---|---|---|---|---|---|
| 6 | 获取用户资料 | GET | `/user/profile/{user_id}` | 按 user_id 拉取**完整资料**（含粉丝/关注/帖子数等统计） | 文档未要求 | `UserProfileResponse` |
| 7 | 我的信息 | GET | `/user/me` | 拉取**当前登录用户**的最小信息 | 需登录 | `MeUserResponse` |

**返回结构：**

- `UserProfileResponse`（完整资料）：`user_id`、`display_name`、`avatar_url`、`bio`、`pronouns`、`gender`、`location`、`website_url`、`is_verified`、`is_private`、`account_type`、`posts_count`、`followers_count`、`following_count`、`last_active_time`、`create_time`
- `MeUserResponse`（最小信息）：`id`、`username`、`avatar`

**两个接口的关键差异（登录后取信息时要注意）：**

- 🔎 `/user/profile/{user_id}` 字段很全（含粉丝/关注/帖子数等），但**不返回 `username`**；
- 🪪 `/user/me` 字段很少，却是**唯一能拿到 `username`** 的入口；
- 因此登录后若想同时具备 `username` + 完整资料，需两个接口配合：先用 `/user/me` 取 username，再用 `/user/profile/{me.id}` 取完整资料（或以 me 的值兜底 profile 缺失字段）。

### 3.3 登录入口与页面

| 文件 | 角色 | 关键逻辑 |
|---|---|---|
| `lib/auth/signup/name.dart` | 登录主页 NamePage | `_handleLogin`(账号密码)、`_handleAppleSignIn`(Apple)；两者登录成功后均 `Navigator.pushReplacement(HomePage)`（L58、L130） |
| `lib/auth/signup/register.dart` | 账号密码注册页 RegisterPage | `_handleRegister`：校验（username≥2 / pwd≥5 / 两次一致）→ `authState.register()` → 成功后 `pushReplacement(HomePage)`（L78） |
| `lib/common/splash.dart` | 冷启动 / 自动登录 SplashPage | `timer()`：`initAuthService()`(缓存恢复) → `getProfileUser()`；build 按 `authStatus` 渲染：NOT_LOGGED_IN→NamePage，LOGGED_IN→HomePage（L56-61） |

### 3.4 登录表单与交互

- 本次任务非重点。现有校验：`name.dart` 仅空校验；`register.dart` username≥2、password≥5、两次密码一致（注：其 SnackBar 为硬编码中文，属既有 i18n 问题，本次不动）。
- 弹窗的 username 校验规则可参考 `register.dart`，详见 7.3。

### 3.5 登录请求与服务层

`lib/services/auth_service.dart`：

| 方法 | 接口 | 说明 |
|---|---|---|
| `signIn()` L47 | POST `/auth/username/signin` | 存 token，返 LoginResponse |
| `signInWithApple()` L96 | POST `/auth/apple/login` | 存 token，返 LoginResponse |
| `register()` L119 | POST `/auth/username/register` | **不返 token**，需调用方再 signin |
| `getCurrentUser()` L176 | GET `/user/me` | 返 UserInfo（**含 username**） |

`lib/services/user_service.dart`：

| 方法 | 接口 | 说明 |
|---|---|---|
| `getUserProfile(id)` L11 | GET `/user/profile/{id}` | 返 UserInfo（**无 username**） |
| `updateProfile(...)` L23 | PUT `/user/profile` | **当前仅 9 字段（display_name 等），无 username** |

### 3.6 登录态管理（AuthState）— `lib/state/auth.state.dart`

- 4 个登录方法，**全部在末尾调用 `getProfileUser()`**：
  `signIn()` L121、`signInWithApple()` L177（含本次需求雏形 TODO L174-176）、`register()` L263、`initAuthService()` L72（缓存恢复自动登录）。
- **`getProfileUser()` L444 = 统一收口点**：
  1. `getCurrentUser()` → `/user/me` → `userInfo`（**含 username**）
  2. `getUserProfile(userInfo.userId)` → `/user/profile/{id}` → `fullProfile`（无 username）
  3. 合并：`_userModel.userName = userInfo.username`（L467）—— **username 权威来源 = `/user/me`**
  4. 缓存到 SharedPreferences
- `authStatus`（L24-32）：getter/setter 自动广播变化，驱动 Splash 渲染 + WebSocket 连接。

### 3.7 登录后的跳转与初始化

- **「进入应用」出口分散在 3 处**（即 username 兜底弹窗的拦截候选点）：
  - `name.dart` L58（账号密码）、L130（Apple）
  - `register.dart` L78（注册）
  - `splash.dart` L60（冷启动自动登录，由 `authStatus` 驱动）
- 其他初始化：WebSocket 连接（`main.dart` 订阅 `onAuthChanged`）、Deep Link（`splash.dart` L38）。

### 3.8 注册流程

- 账号密码注册：`register.dart` → `AuthState.register()` = `register()` + `signIn()` + `getProfileUser()`（因注册接口不返 token，需补一次 signin 拿 token）。
- 旧残留（当前注册流未使用）：`signup.dart`（早期 Profile 模板，法语文案）、`account.dart`（实为 SwitchAccount 占位页）、`email.dart`。

## 四、优化需求

### 4.1 背景与问题

- `username` 在业务上**必须填写、且不可修改**。它是用户在应用中的**唯一身份标识**(面向用户的、人类可读的身份名),区别于数据库内部的主键 `user_id`。
- **现状缺陷**:目前**只有「账号密码注册」**这一条路径,用户会显式填写 `username`。
- 在其他登录 / 注册方式中,用户并没有机会填写 `username`,因此登录后该字段会**为空**:
  - ✅ 已实现:**Apple 注册 + 登录**(登录注册一体)
  - ⏸ 未来可能扩展(仅作上下文,**本次不实现**):手机号 + 验证码、邮箱 + 验证码 的注册 / 登录。

### 4.2 目标

无论用户走哪种登录方式,**登录成功后只要发现 `username` 为空,就强制弹窗要求补填**,填好并通过校验才放行进入应用;`username` 已存在的用户则正常进入。

### 4.3 功能规则

**触发时机(统一收口在登录成功之后):**

```
用户完成登录
   └─> 拿到服务端返回的 access_token
        └─> 调用「获取用户资料」接口
             └─> 判断 username 是否为空
                   ├─ 为空 ─> 弹出「填写 username」弹窗
                   │           ├─ 用户必须填写并通过校验
                  │           ├─ 弹窗内有醒目提示:username 不可修改,请谨慎填写
                  │           └─ 提交成功 ─> 进入应用
                  └─ 非空 ─> 正常进入应用
```

**分支细则:**

- **username 为空**:
  - 弹出**强制填写**弹窗(不可跳过、不可取消进入应用);
  - 弹窗中需有一行**明显的提示语**,告知用户:此 `username` 一旦设定**不可修改**,请谨慎填写;
  - 用户填写并校验通过后,才允许进入应用。
- **username 非空**:直接正常进入应用。

**适用范围(覆盖所有登录入口):**

- 账号密码登录、Apple 注册 + 登录(登录注册一体场景同样处理);
- 为未来新增的登录方式(手机 / 邮箱验证码等)预留同一套兜底逻辑——新方式接入后自动适用,无需重复实现。

### 4.4 不在本次范围

- ❌ 手机号 + 验证码、邮箱 + 验证码 的注册 / 登录功能本身(本次仅作为上下文,不实现)。

### 4.5 已确认的服务端约束(实施时参考)

- **`username` 服务端层面即不可改**:`PUT /user/profile`(更新用户资料)的可修改字段中**不包含 `username`**(见 3.2 节),所以「不可修改」由后端契约保证,客户端弹窗的提示语有据可依。
- ⚠️ **「判断用的 username 取自哪个接口」需在实施时明确**:`/user/profile/{id}` 返回的完整资料里**没有 `username` 字段**,真正能拿到 `username` 的是 `/user/me` 与登录响应 `SigninResponse`(均见 3.1 / 3.2 节)。需求中「获取用户资料后判断 username 是否为空」的执行口径,需在梳理客户端代码时确认取值来源。

## 五、实施记录

### 已完成（2026-06-26）

按第七节方案落地，共改动 6 个文件、新增 1 个组件，`flutter analyze` 无报错。

| 文件 | 改动 |
|---|---|
| `lib/l10n/app_en.arb` / `app_zh.arb` | 新增 5 个 key：usernameSetupTitle / Warning / EmptyError / TooShortError / Failed（已 `flutter gen-l10n` 重新生成） |
| `lib/services/user_service.dart` | `updateProfile` 增加 `username` 参数，请求体带 `username` 字段 |
| `lib/state/auth.state.dart` | 新增 `needsUsernameSetup` 标志；`getProfileUser` 末尾按 `_userModel.userName` 判空；新增 `setUsername()`（存 + 刷新 + 清标志）；`logoutCallback` / `forceSessionExpired` 复位标志 |
| `lib/auth/username_setup_dialog.dart`（新增） | 强制弹窗：`PopScope(canPop:false)` + `barrierDismissible:false`、醒目「不可修改」提示、username 输入 + 校验（≥2）、提交调 `AuthState.setUsername` |
| `lib/auth/signup/name.dart` | 账号密码登录 / Apple 登录成功后，若 `needsUsernameSetup` 则先弹窗再进 HomePage |
| `lib/auth/signup/register.dart` | 注册成功后同样拦截（防御性） |
| `lib/common/splash.dart` | 冷启动自动登录恢复后，若 `needsUsernameSetup` 同样弹窗 |

### 实测前完善（2026-06-26）

用户确认：① Apple 登录 username 为空即弹窗（当前逻辑已满足）；② 服务端已支持写入 username（文档滞后）。据此补两点：

- **`signInWithApple` 加 dev 日志**：与 `signIn` 对齐，打印完整响应，便于实测时确认 `username` 字段是否为空。
- **保存失败原因透传**：`setUsername` 不再吞异常，`ApiException.message`（如「username 已被占用」）直接显示在弹窗上，而非笼统的「设置失败」。

### 待实测（由用户手动验证，dev 环境 `--dart-define=APP_ENV=dev`）

1. **Apple 登录**：控制台看 `[signInWithApple] 服务端返回` 的 `username` 字段是否为空 → 为空则应弹出补填窗。
2. **保存链路**：弹窗提交 → `PUT /user/profile` 带 `username` → 应成功关闭弹窗；填**已占用的 username** 时应显示后端返回的具体原因。
3. **不误拦**：用 `14dev`（已有 username）登录，应直接进首页、不弹窗。
4. **冷启动**：username 为空的账号杀进程重开，自动登录后应再次弹窗。
5. 校验规则若需收紧（字符集 / 查重），再迭代。

## 六、联调资源

- **开发环境测试账号**:用户名 `14dev` / 密码 `123456`(开发环境专用,用于联调核对真实返回字段)。
- **开发环境地址**:`http://192.168.1.27:8005/`(见 CLAUDE.md「API 环境切换」,以 `--dart-define=APP_ENV=dev` 启动)。
- **用途**:登录后核对 `SigninResponse`、`/user/me`、`/user/profile/{id}` 的真实返回(尤其 `username` 的来源与是否为空),校准 3.1 / 3.2 接口契约,并验证「username 兜底弹窗」的触发逻辑。

## 七、实施方案设计（拟定 — 待退出 explore 模式后实施）

> 本节为 explore 阶段沉淀的方案要点，最终以实施时的代码为准。

### 7.1 核心策略：一处判空 + 多点拦截

```
getProfileUser()  ← 4 条路径共同收口
   ├─ 取得 userInfo.username（来自 /user/me）
   ├─ 合并 _userModel
   └─【新增判空】userName 为空 → AuthState.needsUsernameSetup = true
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        ▼                          ▼                          ▼
  name.dart 登录/Apple        register.dart 注册        splash.dart 冷启动
  (result != null 后)         (result != null 后)       (getProfileUser 后)
        │                          │                          │
        └──────────────┬───────────┴──────────────────────────┘
                       ▼
            检查 needsUsernameSetup
              ├─ true  → 弹「填写 username」弹窗（强制）
              └─ false → 正常进 HomePage
```

- **判空统一收口**在 `getProfileUser()`（`auth.state.dart:444`），自动覆盖全部登录方式（含未来手机 / 邮箱验证码）。
- 新增 `AuthState.needsUsernameSetup` 标志位承载判空结果。
- **弹窗在「进入应用」的出口处触发**（弹窗需 BuildContext，不适合放在 State 层）：`name.dart`(L58/L130)、`register.dart`(L78)、`splash.dart`(getProfileUser 之后)。

### 7.2 保存 username 的方式

- 接口：`PUT /user/profile`（更新用户资料）。
- ⚠️ **风险 / 待实测**：openapi_docs 中该接口的可改字段**未列出 `username`**（仅 display_name 等 9 个），客户端 `user_service.updateProfile` 也未传 username。本次按「文档过期、后端实际支持」的假设推进：给 `updateProfile` 增加 `username` 参数，请求体带 `username` 字段。
- **实测验证点**：弹窗提交 → `PUT /user/profile` 带 username → 后端是否接受 → 重新 `/user/me` 能否取到新 username。若后端不接受，需后端加字段或换接口。

### 7.3 弹窗要素（产品要求）

- **强制**：不可跳过、不可取消进入应用。
- **醒目提示语**：username 一旦设定**不可修改**，请谨慎填写。
- username 输入框 + 校验（可参考 `register.dart` 的 ≥2 字符；是否再加字符集 / 查重规则待定）。
- 提交成功 → 刷新 `_userModel` → 进入应用。

### 7.4 冷启动自动登录（已确认要拦）

- `splash.dart` 在 `getProfileUser()` 后，若 `needsUsernameSetup`，同样弹窗；逻辑与其他入口一致。

### 7.5 待实测 / 待确认项

1. `PUT /user/profile` 是否接受 `username` 字段（见 7.2）—— 决定「能不能存」。
2. Apple 登录 `SigninResponse.username` 是否真的为空（见 4.1）—— 决定 Apple 路径是否触发（用户手动实测）。
3. username 校验规则的细节（长度下限 / 允许的字符集 / 是否需要查重）。
