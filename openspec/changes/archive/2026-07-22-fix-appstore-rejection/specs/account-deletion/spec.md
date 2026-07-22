## ADDED Requirements

### Requirement: 注销账号入口

App SHALL 在「设置」页（`SettingsPage`）提供「注销账号」入口，采用与其它菜单项一致的菜单行样式（图标 + 标题 + 箭头），位于「关于」菜单项下方，确保用户易于发现。

#### Scenario: 已登录用户可发现注销账号入口

- **WHEN** 已登录用户进入「设置」页的菜单列表
- **THEN** 在「关于」菜单项正下方可见与其它菜单项样式一致的「注销账号」入口

### Requirement: 独立注销页

App SHALL 提供一个独立的「账号注销」页面承载注销流程（而非弹窗），页面包含：警示图标、「账号注销须知」标题、注销须知列表、「我已阅读并同意」勾选框、确认 / 取消按钮。

#### Scenario: 从设置入口进入注销页

- **WHEN** 已登录用户在「设置」页点击「注销账号」入口
- **THEN** 跳转到独立的「账号注销」页面，展示注销须知与同意勾选框

### Requirement: 注销须知展示

注销页 SHALL 展示完整的注销须知，让用户充分知晓后果：个人资料永久删除、发布内容与互动清空、关注 / 粉丝 / 收藏 / 社区关系解除、第三方登录解绑、操作不可撤销。

#### Scenario: 注销页展示须知

- **WHEN** 用户进入「账号注销」页
- **THEN** 页面列出全部注销须知条目

### Requirement: 多重确认防误触

注销 SHALL 设置多重确认：用户必须先勾选「我已阅读并同意上述条款」使「确认注销」按钮可用；点击后再弹出二次确认 alert，最终确认才执行注销。

#### Scenario: 未勾选时确认按钮禁用

- **WHEN** 用户未勾选同意框
- **THEN** 「确认注销」按钮处于禁用态，无法触发注销

#### Scenario: 勾选后点击确认弹出二次确认

- **WHEN** 用户勾选同意框后点击「确认注销」
- **THEN** 弹出二次确认 alert（取消 / 确认注销），未最终确认不执行注销

#### Scenario: 取消注销

- **WHEN** 用户在二次确认 alert 点击「取消」
- **THEN** alert 关闭，账号不被注销，用户留在注销页

### Requirement: 注销页加载态

执行注销期间，注销页 SHALL 切换为「正在处理注销…」加载视图，并阻止重复触发。

#### Scenario: 注销进行中展示 loading

- **WHEN** 用户最终确认注销、注销请求进行中
- **THEN** 页面切换为加载视图，按钮不可重复点击

### Requirement: 彻底删除而非退出/停用

删除流程 SHALL 调用账号删除接口执行彻底删除，MUST NOT 退化为退出登录或停用账号。

#### Scenario: 调用彻底删除接口

- **WHEN** 用户确认删除
- **THEN** 客户端向 `DELETE /user/me` 发起请求（携带当前 access token），而非向 `/auth/logout` 发起请求

### Requirement: 删除成功后清理本地登录态

App SHALL 在删除成功后清空登录态、token 与本地缓存，并将用户带回登录页。

#### Scenario: 删除成功后回到登录页

- **WHEN** `DELETE /user/me` 返回成功
- **THEN** 客户端禁用 WebSocket、清空内存登录态、清除 access/refresh token 与本地 prefs，并将路由切回登录页（`NamePage`）

### Requirement: 注销失败的错误处理

App SHALL 在注销失败时提示用户「注销失败」，并保留当前登录态以供重试。

#### Scenario: 接口失败时不清登录态

- **WHEN** `DELETE /user/me` 返回错误（网络失败 / 4xx / 5xx）
- **THEN** 关闭加载态、展示本地化错误提示，账号保持登录，用户可重试

### Requirement: 后端契约（TBD）

客户端 SHALL 按假定契约 `DELETE /user/me` 实现；精确契约（请求体、响应、同步/异步）TBD 后端确认。

#### Scenario: 联调仅需对齐错误码

- **WHEN** 后端 `DELETE /user/me` 接口落地
- **THEN** 客户端无需改动 UI，仅需确认状态码 / 错误码映射即可联调
