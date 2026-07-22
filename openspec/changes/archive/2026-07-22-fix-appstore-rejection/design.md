## Context

iOS 1.0.0 提审被拒，三项中两项需客户端改代码：

- **Apple 登录按钮不符合 HIG**：当前用 `GestureDetector` + `Container(color: Colors.black)` 手搓，未使用官方组件。
- **缺少 App 内彻底删除账号入口**：违反 Review Guideline 5.1.1(v)，阻断项。

当前现状（探查已确认）：

- 登录主入口是 `NamePage`（`client/lib/auth/signup/name.dart`），并非独立 login 页（`main.dart:220` 会话过期也跳到这里）。Apple 按钮在 419–445 行；页面已有 `_isLoading` + 全屏 `_loadingOverlay`（38–55 行）统一处理加载态。项目已依赖 `sign_in_with_apple: ^6.1.4`，但**未使用其 `SignInWithAppleButton`**，`_handleAppleSignIn`（106–180 行）已用该包做凭据获取。
- 设置页 `SettingsPage`（`client/lib/common/settings.dart`）底部「退出登录」在 482–504 行，点击调 `AuthState.logoutCallback()`。
- 登出清理链路成熟：`AuthState.logoutCallback()`（`auth.state.dart` 92–105）= 禁 WS + 清内存态 + `AuthService.logout()`（发 `DELETE /auth/logout` + `_clearTokens`）+ 清 prefs + `notifyListeners()`；另有被动 `forceSessionExpired()`（112–126）。底层有 `authService.clearLocalSession()`（454–456）。
- 服务端（`openapi_docs/`，122 路径）**无任何删除 / 停用账号接口**；最接近的 `DELETE /auth/logout` 仅清 token。

约束：仅 iOS；不新增依赖；后端删除接口 TBD。

## Goals / Non-Goals

**Goals:**

- Apple 按钮满足 HIG，消除「按钮不像按钮 / 缺合规样式」的拒审点。
- 客户端具备完整的「删除账号」闭环：入口 → 二次确认 → 调用 → 清理登录态 → 回登录页，后端接口落地即可联调上线。
- 中英文案、错误处理到位。

**Non-Goals:**

- 不实现后端 `DELETE /user/me`（TBD，转后端）。
- 不做账号停用 / 数据导出（苹果要求彻底删除，不做退化方案）。
- 不改年龄分级后台（转 ASC 运营）。
- 不做删除后的「冷静期 / 恢复」UI（除非后端契约明确支持）。

## Decisions

**D1. Apple 按钮：改用官方 `SignInWithAppleButton`，而非重新美化手搓 Container。**
- 理由：HIG 明确要求使用官方按钮资产；官方组件自动处理官方 Logo 字形、本地化标题、点击反馈、无障碍语义与 iOS 版本/能力检测。手搓即使视觉接近，复审仍有被拒风险且维护成本高。
- 备选：仅把手搓 Container 调成更明显黑底——被否，合规性才是根因。
- 样式：沿用 `.black`（与现有视觉一致，深浅色主题下均有效）。

**D2. 保留页面级 `_loadingOverlay` 处理加载态，不依赖官方按钮内置 loading。**
- 理由：`NamePage` 已有统一加载遮罩（覆盖 Apple / Google / 账密登录），交互一致性更好。官方按钮替换的只是「视觉 + onPressed」，加载期间由遮罩拦截重复点击。

**D3. 删除账号入口放在 `SettingsPage`，紧邻「退出登录」下方，红色文字。**
- 理由：与 Threads / Instagram 官方一致；苹果要求「易于发现」，设置页底部账号区满足要求。红色传达破坏性操作。

**D4. 二次确认用单个确认弹窗（破坏性文案 + 显式「删除」按钮），不强制密码 / 输入校验。**
- 理由：用户可能通过 Apple / Google / SMS 登录，没有统一密码可二次校验；强制输密码无法覆盖全部登录方式。单弹窗 + 清晰「不可恢复」警告 + 破坏性按钮是 HIG 可接受的标准做法。
- 备选：要求输入 "DELETE" 或密码——被否（不通用、过度摩擦）。若后端后续要求二次身份验证，再扩展。

**D5. 客户端按假定契约 `DELETE /user/me` 实现，后端 TBD。**
- 理由：用户指示「客户端任务全做完，后端待定先跳过」。`DELETE /user/me` 语义最清晰（RESTful）。成功后客户端立即清理登录态。
- 联调点：后端落地后，仅需确认状态码 / 错误码映射，UI 不必改。

**D6. 删除成功后的本地清理复用现有清理链路，不重复造轮子。**
- 理由：`logoutCallback` 已含「禁 WS + 清内存 + 清 token + 清 prefs + notify」全套；删除账号成功后本地效果等同于登出。抽取一个内部 `_clearLocalSessionAndExit()`，供 `logoutCallback` 与 `deleteAccount` 共用，避免逻辑漂移。
- 注意：**不复用** `AuthService.logout()`（它会发 `DELETE /auth/logout`）；删除账号只发 `DELETE /user/me`，本地清理走 `authService.clearLocalSession()` + 清 prefs。

**D7. 注销交互升级为「独立注销页 + 多重确认」，取代早期弹窗方案（依据 `feature-account-cancellation.md`）。**
- 理由：永久删除不可逆，独立页能完整展示注销须知，并用「同意勾选 + 确认按钮 + 二次 alert」多重确认防误触，比单弹窗更规范、更贴合苹果对破坏性操作的态度。
- 与 D4 的关系：D4 的「单个确认弹窗」是早期折中，现由本决策取代；底层 `deleteAccount()` 状态机（D5/D6）不变，只升级 UI 层。
- 须知文案按本项目改写（无内购，去掉"付费退款"条）：个人资料永久删除 / 帖子回复点赞转发清空 / 关注粉丝收藏社区解除 / 第三方登录解绑 / 操作不可撤销。
- 第 4 条「第三方登录解绑」依赖后端删除时是否顺带解绑 Apple/Google（TBD）；前端先按"会解绑"陈述，避免误导。

## Risks / Trade-offs

- **[后端未就绪时按钮报错]** → 客户端捕获错误并提示「删除失败，请稍后重试」；**重新提审前必须确认后端已上线**，并在 `tasks.md` 标为提审前置条件。
- **[退化为停用导致复审被拒]** → D5/D6 明确只做彻底删除语义；spec 约束「不得仅退出 / 停用」。
- **[官方按钮在旧 iOS 上的能力检测]** → `SignInWithAppleButton` 内部已处理；仍需在真机（含 iOS 13+）回归。
- **[误删不可恢复]** → D4 二次确认；删除为破坏性操作，无本地撤销。
- **[删除账号与登出文案混淆]** → 入口红色 + 弹窗明确「永久删除账号与所有数据」，与「退出登录」区隔。

## Migration Plan

- 客户端无数据迁移，发新构建即可。
- 上线顺序：后端 `DELETE /user/me` 落地 → 客户端联调 → 真机录屏（注册 → 注销全流程）→ 连同 Apple 按钮修复一起重新提审。
- 回滚：若删除流程线上出问题，回退客户端构建即可（后端接口保留无副作用）。

## Open Questions

- `DELETE /user/me` 的精确契约：是否需要请求体（二次确认 token / 密码）？响应 shape？删除同步还是异步（N 天清理）？—— **TBD 后端**。
- 是否需要对 Apple / Google 账号做平台侧 token 解绑（revoke）？—— 暂不在客户端处理，待后端确认。
- 年龄分级修改由哪位 ASC 运营负责？—— 转交确认。
