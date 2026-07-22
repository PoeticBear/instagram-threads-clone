# Handoff 文档：聊天/私信「协议同意（EULA）拦截」功能

> **目的**：在另一个同时具备「聊天（群聊）」和「私信（DM）」功能的 iOS App 中，复刻本项目已实现的"用户进入聊天/私信前必须先同意协议"的功能点。
>
> **源项目**：拜老爷 iOS（SwiftUI + MVVM，iOS 16+）。
> **参考实现文件**：
> - `Views/Yaju/EULAAgreementView.swift`（协议弹窗 UI）
> - `Views/Yaju/ChatNavigationCoordinator.swift`（拦截协调器 / 状态机）
> - `Views/Yaju/YajuView.swift`（触发容器）
> - `Services/AppSettings.swift`（持久化）

---

## 1. 功能目标（验收标准）

1. 用户首次进入聊天/私信相关页面时，弹出协议弹窗（WebView 展示远程协议），必须点击「同意并继续」才能进入。
2. 点击「不同意」或关闭：不进入目标页，且状态不落库（下次仍会弹）。
3. 同意后：状态持久化（UserDefaults），**下次不再弹**；并**自动继续**用户原本想去的那个页面（无需二次点击）。
4. 覆盖**所有**进入聊天/私信的入口：群聊列表、创建/加入/搜索群聊、进入具体聊天室、**进入私信会话列表、进入某个私信对话**。
5. （建议增强，见 §7）支持协议版本号：协议更新后强制重新同意。

---

## 2. 源项目的设计模式（核心思想）

采用 **"统一导航入口 + 拦截 + 待跳转目标暂存 + 同意后续跑"** 模式，由一个 `ChatNavigationCoordinator`（`@MainActor` `ObservableObject`）集中管理：

```
用户点任意聊天/私信入口
        │
        ▼
coordinator.requestNavigation(to: destination)
        │
   hasAgreed? ──是──▶ executeNavigation(to:)  直接进入目标页
        │
        否
        ▼
   pendingDestination = destination   // 记住用户想去哪
   showEULASheet = true               // 弹协议
        │
   用户点「同意并继续」
        ▼
   handleEULAAgreed():
     - 持久化 hasAgreed = true
     - 关闭弹窗
     - 延迟 0.3s 执行 pendingDestination（等 sheet 关闭动画）
```

**关键点**：所有跳转都不直接 `NavigationLink`/`present`，而是统一走 `requestNavigation(to:)`，把"是否需要拦协议"的判断收敛到一处。这样新增入口时天然被保护，不会漏拦。

---

## 3. 需要移植/新建的组件清单

| 组件 | 源文件 | 移植方式 |
|------|--------|---------|
| 协议弹窗 View | `EULAAgreementView.swift` | 直接移植，替换品牌色/URL |
| WebView 包装器 | `EULAAgreementView.swift` 内 `WebView` | 直接移植（通用，无依赖） |
| 拦截协调器 | `ChatNavigationCoordinator.swift` | 移植并**扩展 Destination 枚举**以覆盖私信 |
| 持久化字段 | `AppSettings.swift` | 新增 2~3 个 UserDefaults 字段 |
| 触发容器接线 | `YajuView.swift` | 在目标 App 的聊天 Tab 根视图接线 |

---

## 4. 分步实现指南

### 步骤 1｜持久化层（AppSettings 或等价单例）

在目标 App 的设置单例中新增字段（沿用源项目命名）：

```swift
// @Published 属性
@Published var hasAgreedToChatEULA: Bool = false
@Published var chatEULAVersion: String = ""   // 增强用，见 §7

private enum Keys {
    static let hasAgreedToChatEULA = "chat_settings_has_agreed_to_eula"
    static let chatEULAVersion      = "chat_settings_eula_version"
}

func loadSettings() {
    hasAgreedToChatEULA = UserDefaults.standard.bool(forKey: Keys.hasAgreedToChatEULA)
    chatEULAVersion     = UserDefaults.standard.string(forKey: Keys.chatEULAVersion) ?? ""
}

func saveSettings() {
    UserDefaults.standard.set(hasAgreedToChatEULA, forKey: Keys.hasAgreedToChatEULA)
    UserDefaults.standard.set(chatEULAVersion, forKey: Keys.chatEULAVersion)
}
```

> 若目标 App 没有 AppSettings，可用一个轻量 `@AppStorage("chat_settings_has_agreed_to_eula") var hasAgreedToChatEULA = false` 替代，但集中式单例更利于版本控制扩展。

### 步骤 2｜协议弹窗 `EULAAgreementView`

直接移植源文件，注意替换 2 处项目专有内容：
- **协议 URL**：`private let eulaURL = URL(string: "<你的协议地址>")!`
- **品牌色**：源码用 `Color.cinnabarRed`，替换为目标 App 主色（或 `Color.accentColor`）。

结构（保持不变）：标题栏「聊天使用协议」+ 关闭按钮（回调 `onDisagreed`）→ `WKWebView` 加载协议 → 底部「不同意」/「同意并继续」双按钮。

`WebView`（`UIViewRepresentable` 包装 `WKWebView`）**原样移植**，无任何项目依赖，含加载态 `isLoading` 绑定与 `navigationDelegate`。

弹窗对外接口只有两个闭包，保持解耦：

```swift
struct EULAAgreementView: View {
    let onAgreed: () -> Void
    let onDisagreed: () -> Void
    // ...
}
```

### 步骤 3｜拦截协调器（扩展以覆盖私信）

移植 `ChatNavigationCoordinator`，**关键改动是扩展 `Destination` 枚举**，把私信入口纳入拦截：

```swift
@MainActor
final class ChatNavigationCoordinator: ObservableObject {
    @Published var showEULASheet = false
    @Published var pendingDestination: Destination?
    @Published var hasAgreedToEULA: Bool = false

    // 具体页面展示开关（按目标 App 实际入口增减）
    @Published var showChatRoomList = false
    @Published var showConversationList = false           // 私信会话列表
    @Published var pendingChatRoom: ChatRoomDetail?
    @Published var pendingConversation: Conversation?      // 具体私信对话

    private var appSettings = AppSettings.shared

    // ⭐ 扩展：群聊 + 私信 都进枚举
    enum Destination: Equatable {
        case chatRoomList
        case createChatRoom
        case chatRoom(ChatRoomDetail)      // 群聊
        case conversationList              // 私信列表
        case conversation(Conversation)    // 私信对话
        // Equatable：case 内含关联值的按 id 比较
    }

    init() {
        hasAgreedToEULA = appSettings.hasAgreedToChatEULA
        if !hasAgreedToEULA { showEULASheet = true }   // 进聊天 Tab 即拦（可选，见下方说明）
    }

    /// 统一入口：所有聊天/私信跳转都走这里
    func requestNavigation(to destination: Destination) {
        if hasAgreedToEULA {
            executeNavigation(to: destination)
        } else {
            pendingDestination = destination
            showEULASheet = true
        }
    }

    func executeNavigation(to destination: Destination) {
        pendingDestination = nil
        switch destination {
        case .chatRoomList:      showChatRoomList = true
        case .createChatRoom:    /* ... */ break
        case .chatRoom(let r):   pendingChatRoom = r
        case .conversationList:  showConversationList = true
        case .conversation(let c): pendingConversation = c
        }
    }

    func handleEULAAgreed() {
        appSettings.hasAgreedToChatEULA = true
        appSettings.saveSettings()
        hasAgreedToEULA = true
        showEULASheet = false
        if let pending = pendingDestination {
            pendingDestination = nil
            // 延迟等 sheet 关闭动画，再执行原目标跳转
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.executeNavigation(to: pending)
            }
        }
    }

    func handleEULADisagreed() {
        showEULASheet = false
        pendingDestination = nil   // 不改 hasAgreed，下次仍拦
    }
}
```

> **关于 `init()` 里"进 Tab 即弹"**：源项目在协调器初始化时若未同意就立即弹窗。若目标 App 更希望"点具体入口才弹"（体验更轻），可删掉 `init()` 里的 `if !hasAgreedToEULA { showEULASheet = true }`，只靠 `requestNavigation` 拦截。两种策略二选一即可。

### 步骤 4｜在聊天 Tab 根视图接线

在目标 App 承载聊天/私信的根视图中：

```swift
struct ChatTabView: View {
    @StateObject private var coordinator = ChatNavigationCoordinator()

    var body: some View {
        content
            // ⭐ 所有入口改为调用 requestNavigation，而非直接跳转
            // 例：群聊管理按钮
            .onTapGesture { coordinator.requestNavigation(to: .chatRoomList) }
            // 例：私信入口按钮 → coordinator.requestNavigation(to: .conversationList)

            .environmentObject(coordinator)   // 供子视图使用

            // 目标页展示（源项目用 fullScreenCover）
            .fullScreenCover(isPresented: $coordinator.showConversationList) { /* 私信列表 */ }
            .fullScreenCover(item: $coordinator.pendingConversation) { convo in /* 私信对话 */ }
            .fullScreenCover(item: $coordinator.pendingChatRoom) { room in /* 群聊 */ }

            // ⭐ 协议弹窗
            .sheet(isPresented: $coordinator.showEULASheet) {
                EULAAgreementView(
                    onAgreed:    { coordinator.handleEULAAgreed() },
                    onDisagreed: { coordinator.handleEULADisagreed() }
                )
            }
    }
}
```

### 步骤 5｜替换所有入口调用

把目标 App 里**每一个**进入聊天/私信的按钮/手势，从直接导航改为 `coordinator.requestNavigation(to: .xxx)`。逐一核对：
- [ ] 群聊列表 / 创建 / 加入 / 搜索 / 进入具体群聊
- [ ] **私信会话列表入口**
- [ ] **从用户主页/帖子点击"发私信"进入对话**
- [ ] 任何推送/深链直达聊天页的入口（深链场景尤其容易漏，见 §6）

---

## 5. 私信（DM）特有的注意事项

源项目**只有群聊**走了协议拦截。目标 App 多了私信，需额外注意：

1. **深链 / 推送直达**：私信常有"从推送点进某个对话"的路径，它绕过了 Tab 根视图的普通入口。务必让这些路径也经过 `requestNavigation(to: .conversation(...))`——若未同意，先弹协议、暂存对话为 `pendingConversation`，同意后再打开。
2. **发消息动作而非仅进入**：若产品要求"可以看但发消息前才需同意"，则拦截点应移到"发送"动作而非"进入对话"。本模式同样适用——把 `requestNavigation` 换成在发送前检查 `hasAgreedToEULA`。**需与产品确认拦截粒度**（见 §8 待确认项）。
3. **协议文案**：群聊与私信若共用一份协议，URL 复用即可；若需区分，可给 `EULAAgreementView` 增加 `url` 参数。

---

## 6. 边界与易错点（来自源码经验）

- **动画时序**：同意后必须**延迟 ~0.3s**再执行 `pendingDestination`，否则 sheet 关闭动画与目标页 present 会冲突/闪烁。源项目用 `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)`。
- **`Destination` 的 `Equatable`**：含关联值（ChatRoomDetail/Conversation）的 case 要按 `id` 比较，避免整个模型 `Equatable` 的负担。
- **拦截收敛**：不要留任何"绕过协调器直接 NavigationLink 进聊天"的入口，否则拦截会漏。深链是最常见的漏点。
- **不同意不落库**：`handleEULADisagreed()` 绝不能写 `hasAgreed = true`，否则用户点了"不同意"下次却不再弹。

---

## 7. 建议增强：协议版本控制（源项目预留但未实现）

源项目声明了 `chatEULAVersion` 字段却从未使用，导致"协议改版后无法强制用户重新同意"。目标 App 建议补齐：

```swift
// 当前线上协议版本（可硬编码或从服务端配置下发）
let kCurrentEULAVersion = "2026-07-01"

var needsAgreement: Bool {
    !appSettings.hasAgreedToChatEULA || appSettings.chatEULAVersion != kCurrentEULAVersion
}

func handleEULAAgreed() {
    appSettings.hasAgreedToChatEULA = true
    appSettings.chatEULAVersion = kCurrentEULAVersion   // ⭐ 记录同意的版本
    appSettings.saveSettings()
    // ...
}
```

判断是否弹窗时用 `needsAgreement` 取代单纯的 `!hasAgreedToEULA`。

---

## 8. 移植前需向产品/后端确认的事项

- [ ] **拦截粒度**：是"进入聊天/私信页即拦" 还是 "发第一条消息前才拦"？
- [ ] **协议范围**：群聊和私信共用一份协议，还是各一份？
- [ ] **协议 URL**：目标 App 的协议页地址；是否需要多语言。
- [ ] **是否需要服务端记录同意状态**（合规审计场景），还是仅本地 UserDefaults 即可。源项目仅本地存储。
- [ ] **版本控制**：是否需要"协议更新强制重新同意"（§7）。
- [ ] **深链/推送**进入私信的路径清单，确保全部经过拦截。

---

## 9. 源码位置速查（供对照移植）

```
apps/ios/BaiLaoYeiOS/
├── Views/Yaju/EULAAgreementView.swift        # 协议弹窗 + WebView 包装器（可直接移植）
├── Views/Yaju/ChatNavigationCoordinator.swift# 拦截协调器（移植 + 扩展私信 Destination）
├── Views/Yaju/YajuView.swift                 # 接线范例（@StateObject 协调器 / .sheet 绑定 / requestNavigation 入口）
└── Services/AppSettings.swift                # 持久化字段 hasAgreedToChatEULA / chatEULAVersion
```

**核心行号参考（源项目）**：
- 拦截判断：`ChatNavigationCoordinator.swift:65-74`
- 同意后续跑：`ChatNavigationCoordinator.swift:96-111`
- 进 Tab 即弹：`ChatNavigationCoordinator.swift:54-60`
- sheet 绑定：`YajuView.swift:250-259`
- 持久化键：`AppSettings.swift:75-76, 107-108, 131-132`
