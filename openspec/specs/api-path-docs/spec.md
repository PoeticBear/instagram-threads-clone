# api-path-docs Specification

## Purpose

提供一个轻量命令行工具（`scripts/openapi_doc.py`），输入一个 OpenAPI 路径（可选附 method），从指定的 OpenAPI JSON 文档中定位并渲染该接口的完整描述——包含摘要/说明、参数、请求体、响应，并递归展开 `$ref` 引用的 schema。脚本仅依赖 Python 3.9+ 标准库，为本地开发辅助工具，不参与任何构建产物。

## Requirements

### Requirement: 按 API 路径查询接口描述

脚本 SHALL 接受一个 API 路径作为位置参数，在指定的 OpenAPI JSON 文档中定位 `paths` 下对应条目，并输出该接口的完整描述。

定位与输出 MUST 至少包含以下字段（若 operation 中存在）：`tags`、`summary`、`description`、`operationId`、`parameters`、`requestBody`、`responses`。

#### Scenario: 精确路径命中
- **WHEN** 用户运行 `python3 scripts/openapi_doc.py /user/profile/{user_id}`
- **THEN** 脚本定位到 `paths["/user/profile/{user_id}"]`
- **AND** 打印该路径下每个 HTTP method 的 tags / summary / description / operationId / parameters / responses

#### Scenario: 路径下有多个 method
- **WHEN** 用户查询 `/user/settings`（该路径同时有 `get` 和 `put`）
- **AND** 未指定 `--method`
- **THEN** 脚本同时输出 `GET` 和 `PUT` 两个 method 的完整描述

#### Scenario: 用 --method 过滤
- **WHEN** 用户运行 `python3 scripts/openapi_doc.py /user/settings --method put`
- **THEN** 脚本只输出 `PUT /user/settings` 的描述，不输出 `GET`

#### Scenario: method 大小写与默认
- **WHEN** 用户传 `--method GET` 或 `--method get`
- **THEN** 脚本对大小写不敏感，均匹配到 `get` operation

### Requirement: 递归展开 `$ref` 引用

脚本 SHALL 递归地把响应、请求体及参数中形如 `#/components/schemas/...` 的内部 `$ref` 引用就地展开为被引用 schema 的真实结构，使输出无需人工跳转即可读到完整字段。

展开 MUST 在 JSON 文档的**副本**上进行，不得修改原始 `doc` 对象（保证多次查询互不污染）。

#### Scenario: 响应引用被展开
- **WHEN** 某接口 200 响应 schema 为 `{"$ref": "#/components/schemas/ResponseModel_UserProfileResponse_"}`
- **THEN** 输出中该响应显示为展开后的真实字段结构（如 `code` / `message` / `data`），而非原始 `$ref` 字符串

#### Scenario: 嵌套引用递归展开
- **WHEN** 被引用的 schema 的某个属性又通过 `$ref` 引用另一个 schema
- **THEN** 脚本继续递归展开，直到所有可达的内部 `$ref` 都被解析为具体结构

#### Scenario: 循环引用不导致崩溃
- **WHEN** schema A 引用 schema B，B 又引用回 A（成环）
- **THEN** 脚本检测到环并停止展开，在成环节点输出可读的循环标记（如 `"<$ref cycle: #/components/schemas/A>"`）
- **AND** 进程正常退出，不抛 `RecursionError`、不栈溢出

#### Scenario: 无法解析的引用不中断
- **WHEN** 某个 `$ref` 指向文档中不存在的路径
- **THEN** 脚本在该位置输出 `"<unresolved $ref: ...>"`，继续渲染其余内容，不抛异常退出

### Requirement: 默认文档与 `--file` 切换

脚本 SHALL 在未显式指定文件时，自动选用 `openapi_docs/versions/openapi_*.json` 中文件名日期段最大的一份，并打印一行提示实际使用的是哪份文档。用户可通过 `--file` 指定任意 OpenAPI JSON。

#### Scenario: 默认取最新版本
- **WHEN** 用户运行 `python3 scripts/openapi_doc.py /health` 且未传 `--file`
- **THEN** 脚本选用 `openapi_docs/versions/` 下日期最大的 JSON（当前为 `openapi_20260708.json`）
- **AND** 在输出前打印一行 `Using: <相对路径>` 指明实际文档

#### Scenario: 用 --file 指定旧版
- **WHEN** 用户运行 `python3 scripts/openapi_doc.py /health --file openapi_docs/versions/openapi_20260616.json`
- **THEN** 脚本从指定的旧版文档读取并渲染该接口

#### Scenario: 指定文件不存在
- **WHEN** 用户传了一个不存在的 `--file` 路径
- **THEN** 脚本以非零状态码退出，并在 stderr 打印明确的错误信息

### Requirement: 路径模糊匹配与候选列出

当用户输入的路径未精确命中时，脚本 SHALL 尝试容错匹配（忽略 `{占位符}`、子串匹配）给出候选；命中唯一候选时可直接渲染，命中多个候选时列出全部并提示用户用更精确的路径重试。

#### Scenario: 忽略占位符后唯一命中
- **WHEN** 用户输入 `/user/profile`（文档中实际路径为 `/user/profile/{user_id}`），且该子串只匹配到这一个路径
- **THEN** 脚本直接渲染 `/user/profile/{user_id}` 的描述

#### Scenario: 多候选列出而非猜测
- **WHEN** 用户输入的子串匹配到多个路径（如 `/user` 匹配到多条 `/user/...` 路径）
- **THEN** 脚本打印全部候选路径列表，提示用户重新指定更精确的路径
- **AND** 不自动选择其中任意一个渲染（避免给错信息）

#### Scenario: 完全无匹配
- **WHEN** 用户输入的路径经所有容错规则仍匹配不到任何 path
- **THEN** 脚本提示未找到并建议使用 `--list` 查看全部可用路径，以非零状态码退出

### Requirement: 列出全部路径（`--list`）

脚本 SHALL 提供 `--list` 选项，列出当前文档中所有可用 API 路径及其支持的方法，方便用户挑选。

#### Scenario: 列出全部路径
- **WHEN** 用户运行 `python3 scripts/openapi_doc.py --list`
- **THEN** 脚本打印文档中全部 122 个路径，每行包含路径与其支持的 method 列表

### Requirement: 机器可读 JSON 输出（`--json`）

脚本 SHALL 提供 `--json` 选项，把解析（`$ref` 已展开）后的结构以紧凑、可管道化的 JSON 形式输出，供其他工具消费。

#### Scenario: JSON 输出结构
- **WHEN** 用户运行 `python3 scripts/openapi_doc.py /user/profile/{user_id} --json`
- **THEN** stdout 输出合法 JSON，顶层结构包含 `path` 与 `methods` 两个键
- **AND** `methods[method]` 下的 `responses` / `requestBody` 中所有内部 `$ref` 均已展开为具体结构

### Requirement: 零第三方依赖与可移植性

脚本 SHALL 仅依赖 Python 3.9+ 标准库，可在不执行任何 `pip install` 的情况下直接运行。

#### Scenario: 无需安装依赖
- **WHEN** 在一台仅有系统 Python 3.9 的机器上 clone 仓库后
- **THEN** 直接执行 `python3 scripts/openapi_doc.py --list` 即可成功运行，无需安装任何第三方包
