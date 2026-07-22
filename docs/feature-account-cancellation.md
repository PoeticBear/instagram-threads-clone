# iOS 用户注销功能实现文档

> 本文档整理自「拜老爷」iOS 客户端已实现的**用户注销**功能，用于指导在其他 iOS 项目中实现同样的能力。
>
> 技术栈：Swift + SwiftUI + MVVM，最低 iOS 16。

---

## 1. 功能概述

用户注销功能由一个独立的「账号注销」页面承载，包含**注销须知展示 → 用户勾选同意 → 二次确认 → 执行注销 → 自动返回登录页**的完整流程。

底层执行逻辑复用全局认证状态管理器 `AuthenticationState.performLogout()`：调用后端注销接口撤销会话、解绑第三方（RevenueCat）、清除本地凭证（Keychain），并将 `isAuthenticated` 置为 `false`，由于视图根据该状态渲染，页面会自动回到未登录态。

> 说明：当前实现中，注销页最终调用的是 `performLogout()`（会话级注销 / 退出登录）。本文档按"已实现的注销功能"如实整理，供你在新项目中复用同一套交互与状态流转结构；若新项目需要"永久删除账号"，只需把最后一步换成删除账号 API 即可（见第 7 节）。

---

## 2. 涉及文件清单

| 层级 | 文件 | 作用 |
|------|------|------|
| View | `Views/Settings/AccountCancellationView.swift` | 注销页面 UI + 交互 |
| View | `Views/Settings/SettingsView.swift` | 设置页中的注销入口 & 退出登录按钮 |
| Service | `Services/Auth/AuthenticationState.swift` | 全局认证状态机，`performLogout()` 核心逻辑 |
| Service | `Services/Auth/TokenManager.swift` | Token 管理，`clearAllAuthData()` 清除凭证 |
| Service | `Services/Local/LocalAuthService.swift` | 本地模式下的 `localLogout()` |
| Storage | `Storage/KeychainManager.swift` | Keychain 凭证的实际清除 |
| Networking | `Networking/AuthAPI.swift` | `logout()` API 封装 |
| Networking | `Networking/APIEndpoint.swift` | 端点常量 `/v1/auth/logout` |
| Model | `Models/AuthModels.swift` | `LogoutResponse` / `LogoutAPIResponse` |

---

## 3. 交互流程

```
设置页 SettingsView
   │  NavigationLink "用户注销"
   ▼
账号注销页 AccountCancellationView
   │  1. 展示注销须知（5 条）
   │  2. 用户勾选"我已阅读并同意上述条款" → isAgreed = true
   │  3. 点击"确认注销"（未勾选时按钮禁用）
   │  4. 弹出二次确认 alert
   ▼
performCancellation()
   │  isCancelling = true → 显示"正在处理注销..."的 loading
   ▼
AuthenticationState.performLogout()
   ├─ 解绑 RevenueCat（unbindRevenueCatUser）
   ├─ 本地模式 → performLocalLogout()
   └─ 远程模式 → performRemoteLogout()
        ├─ 调用 AuthAPI.shared.logout()  (DELETE /v1/auth/logout，失败忽略)
        ├─ tokenManager.clearAllAuthData()  (清 Keychain)
        └─ isAuthenticated = false  → 视图自动回到登录页
```

---

## 4. 核心代码实现

### 4.1 注销页面（`AccountCancellationView.swift`）

关键点：
- `@EnvironmentObject var authState: AuthenticationState` 注入全局认证状态。
- `@State isAgreed` 控制"确认注销"按钮是否可用（`.disabled(!isAgreed)`）。
- `@State showCancellationConfirm` 控制二次确认 alert。
- `@State isCancelling` 控制"注销中"的 loading 视图切换。

```swift
struct AccountCancellationView: View {
    @EnvironmentObject var authState: AuthenticationState
    @Environment(\.dismiss) private var dismiss
    @State private var isAgreed = false
    @State private var showCancellationConfirm = false
    @State private var isCancelling = false

    var body: some View {
        ZStack {
            if isCancelling {
                // "正在处理注销..." 的 ProgressView
                cancellingView
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        warningIcon          // 橙色警示三角图标
                        titleText            // "账号注销须知"
                        cancellationNotice   // 5 条须知
                        agreementCheckBox    // 勾选同意
                        buttonSection        // 确认注销 / 取消
                    }
                }
            }
        }
        .navigationTitle("账号注销")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认注销", isPresented: $showCancellationConfirm) {
            Button("取消", role: .cancel) { }
            Button("确认注销", role: .destructive) {
                performCancellation()
            }
        } message: {
            Text("确认注销后将返回登录页面。")
        }
    }

    /// 执行注销操作
    private func performCancellation() {
        isCancelling = true
        Task {
            await authState.performLogout()
            // 注销后 isAuthenticated 变为 false，自动返回登录页
        }
    }
}
```

**注销须知文案（5 条，供参考）：**
1. 账号注销后，所有个人资料将被永久删除，无法恢复
2. 您的祈福记录、功德值、积分等数据将被清空
3. 已购买的付费服务（如有）将无法退款
4. 解除该账号与相关服务的绑定关系
5. 注销操作不可撤销，请谨慎操作

### 4.2 设置页入口（`SettingsView.swift`）

注销入口仅在已登录时显示，并与"退出登录"按钮区分：

```swift
if authState.isAuthenticated {
    // 用户注销入口 → 跳转注销页
    NavigationLink(destination: AccountCancellationView()) {
        MenuItemRow(icon: "person.crop.circle.badge.minus", title: "用户注销")
    }
    .buttonStyle(.plain)

    Divider()

    logoutButton   // 独立的"退出登录"按钮
}
```

### 4.3 认证状态机核心逻辑（`AuthenticationState.swift`）

```swift
@MainActor
final class AuthenticationState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentUser: User?

    private let tokenManager = TokenManager.shared

    /// 执行退出登录 / 注销
    func performLogout() async {
        isLoading = true
        unbindRevenueCatUser()          // 解绑第三方支付
        defer { isLoading = false }

        if AppSettings.shared.isLocalModeEnabled {
            await performLocalLogout()   // 本地模式
        } else {
            await performRemoteLogout()  // 远程模式
        }
    }

    /// 远程模式：调用后端接口 + 清本地凭证 + 重置状态
    private func performRemoteLogout() async {
        do {
            try await AuthAPI.shared.logout()  // 失败也继续，保证本地能登出
        } catch {
            print("退出登录 API 调用失败: \(error.localizedDescription)")
        }
        tokenManager.clearAllAuthData()        // 清 Keychain
        isAuthenticated = false                // 触发 UI 回到登录页
        isAppleIDLoggedIn = false
        currentUserID = nil
        currentUser = nil
        authError = nil
    }
}
```

**要点：** 后端 `logout()` 调用失败被**故意忽略**，以保证即使网络异常，本地凭证仍能被清除、用户仍能成功登出。

### 4.4 网络层（`AuthAPI.swift` + `APIEndpoint.swift`）

```swift
// APIEndpoint.swift
enum Auth {
    static let logout = "/v1/auth/logout"
}

// AuthAPI.swift
func logout() async throws {
    let _: LogoutResponse = try await client.deleteWrapped(
        endpoint: APIEndpoint.Auth.logout
    )
}
```

- HTTP 方法：`DELETE`
- 路径：`/v1/auth/logout`
- 认证：Bearer Token（由 APIClient 拦截器自动附加）
- 响应包装：`{ code, message, data, timestamp }`

### 4.5 数据模型（`AuthModels.swift`）

```swift
struct LogoutResponse: Codable {
    let message: String
}

struct LogoutAPIResponse: Codable {
    let code: Int
    let message: String
    let data: LogoutResponse?
    let timestamp: String?
}
```

---

## 5. 状态与依赖关系

- **状态驱动导航**：视图树根据 `authState.isAuthenticated` 决定展示主界面还是登录页，注销无需手动 `dismiss`，置 `false` 即自动回退。
- **凭证清除**：`TokenManager.clearAllAuthData()` → `KeychainManager.clearAllAuthData()` 清除 Access/Refresh Token 及用户标识。
- **第三方解绑**：`Purchases.shared.logOut()`（RevenueCat）在 `performLogout` 开头执行。
- **本地/远程双模式**：`AppSettings.shared.isLocalModeEnabled` 区分本地模式（`LocalAuthService.localLogout()`）与远程模式。

---

## 6. 在新项目中复用的落地步骤

1. **准备全局认证状态**：确保有一个 `@MainActor` 的 `ObservableObject`（如 `AuthenticationState`），暴露 `@Published var isAuthenticated`，并作为 `@EnvironmentObject` 注入视图树；根视图根据它切换登录/主界面。
2. **实现凭证清理**：封装 `TokenManager.clearAllAuthData()`（清 Keychain 的 access/refresh token）。
3. **封装注销 API**：在 API 层新增 `logout()`（本项目为 `DELETE /v1/auth/logout`）。
4. **实现 `performLogout()`**：解绑第三方 → 调后端接口（失败忽略）→ 清本地凭证 → 置 `isAuthenticated = false`。
5. **搭建注销页 `AccountCancellationView`**：须知列表 + 同意勾选（控制按钮 `disabled`）+ 二次确认 alert + loading 态。
6. **在设置页添加入口**：`NavigationLink` 跳转注销页，仅登录态显示。
7. **验证**：注销后应自动返回登录页，重新进入 App 不应保持登录（Keychain 已清空）。

---

## 7. 若需实现"永久删除账号"（重要提示）

当前实现为**会话级注销**（等价于退出登录）。如果新项目需要满足 App Store 审核指南 **5.1.1(v)**（提供账号创建即须提供**真实的账号删除**），需在以上结构基础上改动：

- **API 层**：新增删除账号端点，如 `DELETE /v1/user/account`，并在 `AuthAPI`/`UserAPI` 中新增 `deleteAccount() async throws`。
- **状态机**：新增 `performAccountDeletion()`，先调用删除账号 API（**此处不应忽略失败**，需向用户反馈），成功后再清本地凭证、置 `isAuthenticated = false`。
- **注销页**：将 `performCancellation()` 内的 `performLogout()` 替换为 `performAccountDeletion()`。
- **文案**：确保 UI 文案（"永久删除，无法恢复"）与实际后端行为一致，避免误导。

---

## 8. 附：文件路径速查

```
apps/ios/BaiLaoYeiOS/
├── Views/Settings/AccountCancellationView.swift   # 注销页面
├── Views/Settings/SettingsView.swift              # 入口
├── Services/Auth/AuthenticationState.swift        # performLogout()
├── Services/Auth/TokenManager.swift               # clearAllAuthData()
├── Services/Local/LocalAuthService.swift          # localLogout()
├── Storage/KeychainManager.swift                  # Keychain 清理
├── Networking/AuthAPI.swift                        # logout()
├── Networking/APIEndpoint.swift                    # /v1/auth/logout
└── Models/AuthModels.swift                         # LogoutResponse
```
