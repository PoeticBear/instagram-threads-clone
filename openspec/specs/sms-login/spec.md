# sms-login Specification

## Purpose
TBD - created by archiving change add-sms-and-google-login. Update Purpose after archive.
## Requirements
### Requirement: 国家区号选择

手机号登录 SHALL 把「国家/地区区号」与「手机号本地号码」作为两个独立字段采集，区号须以 `+` 开头（如 `+86`），与服务端 `phone_country_code`（长度 2–10）约束一致。

客户端 SHALL 提供一个区号选择器：内置常用国家列表（含国旗 emoji、国家名、拨号码），顶部支持按国家名或区号搜索，并允许手动输入自定义区号（校验 `^\+\d{1,9}$` 且长度 ≤ 10）。默认选中 `+86`。

#### Scenario: 从列表选择常用区号

- **WHEN** 用户在手机号登录页点区号位打开选择器
- **AND** 在搜索框输入「日本」或「81」
- **THEN** 列表过滤出日本条目（🇯🇵 日本 +81）
- **AND** 用户点选后，登录页区号位回填为 `+81`

#### Scenario: 手动输入自定义区号

- **WHEN** 用户在选择器底部点「自定义区号」
- **AND** 输入 `+852`（长度 4，符合 2–10）
- **THEN** 区号位回填为 `+852` 并关闭选择器

#### Scenario: 自定义区号格式不合法

- **WHEN** 用户在自定义区号输入 `86`（缺 `+`）或 `+12345678901`（长度 12 > 10）
- **THEN** 客户端拒绝回填
- **AND** 提示区号格式须为 `+` 开头、长度 2–10

### Requirement: 发送短信验证码

客户端 SHALL 调用 `POST /auth/sms/send`，请求体 `{ "phone_country_code": <区号>, "phone": <本地手机号> }`，为指定手机号下发短信验证码。结果以顶层 `code` 判定：`code == 0` 为发送成功，进入倒计时；`code != 0` 按 `msg` 提示且不进入倒计时，允许用户修正后重发。

#### Scenario: 发码成功进入倒计时

- **WHEN** 用户输入合法区号 + 手机号并点「获取验证码」
- **AND** `/auth/sms/send` 返回 `code == 0`
- **THEN** 客户端提示验证码已发送
- **AND** 「获取验证码」按钮进入 60 秒不可点倒计时

#### Scenario: 发码失败不进入倒计时

- **WHEN** `/auth/sms/send` 返回 `code != 0`（如手机号格式不合法被业务拒绝）
- **THEN** 客户端按 `msg` 展示失败提示
- **AND** 「获取验证码」按钮保持可点，用户可立即修正重发

#### Scenario: 缺字段不发请求

- **WHEN** 用户未填手机号就点「获取验证码」
- **THEN** 客户端不发请求、不进入倒计时
- **AND** 提示请输入手机号

### Requirement: 验证码倒计时与重发

发码成功后，客户端 SHALL 将「获取验证码」按钮置为不可点并显示 60 秒倒计时；倒计时归零后恢复可点，允许重新发送。客户端 SHALL 在离开登录页（`dispose`）时取消倒计时定时器，并在更新倒计时 UI 前检查 `mounted`。

#### Scenario: 倒计时归零后可重发

- **WHEN** 一次发码成功的 60 秒倒计时走完
- **THEN** 「获取验证码」按钮恢复可点
- **AND** 用户可再次点击重新发送

#### Scenario: 倒计时期间点击无效

- **WHEN** 倒计时进行中用户再次点「获取验证码」
- **THEN** 客户端不发起 `/auth/sms/send` 请求

### Requirement: 短信验证码登录 / 注册

客户端 SHALL 调用 `POST /auth/sms/signin`，请求体 `{ "phone_country_code": <区号>, "phone": <本地手机号>, "code": <验证码> }`（验证码长度 4–6）。该接口对已注册用户直接登录、新用户自动注册。成功响应 `data` 为 `SigninResponse` 时，客户端 SHALL 复用既有登录态落地逻辑（持久化 token、置已登录、过 `needsUsernameSetup` 闸门后进主页），与其它登录方式行为一致。

客户端 SHALL 以业务码判定结果：`code != 0`（如验证码错误、验证码过期）按 `msg` 提示，不落地 token、不改变登录态。

#### Scenario: 验证码正确登录成功

- **WHEN** 用户输入区号 + 手机号 + 收到的验证码并点登录
- **AND** `/auth/sms/signin` 返回 `code == 0` 且 `data` 含有效 token
- **THEN** 客户端持久化 token、置登录态为已登录
- **AND** 导航至主页（若需补用户名则先弹用户名设置闸门）

#### Scenario: 验证码错误登录失败

- **WHEN** `/auth/sms/signin` 返回 `code != 0`（如验证码错误）
- **THEN** 客户端不落地 token、不改变登录态
- **AND** 按 `msg` 在登录页展示失败提示，允许用户重输验证码

### Requirement: 短信登录接口豁免 401 刷新重试

`/auth/sms/signin` 属于登录类接口，客户端 SHALL 将其纳入 `api_client` 的 `skipPaths` 豁免名单，命中 401 时不触发 token 刷新与重试。

#### Scenario: 短信登录返回 401 不触发刷新

- **WHEN** `/auth/sms/signin` 收到 HTTP 401
- **THEN** 客户端不调用 `auth/token/refresh`、不自动重试
- **AND** 错误抛回登录页处理

