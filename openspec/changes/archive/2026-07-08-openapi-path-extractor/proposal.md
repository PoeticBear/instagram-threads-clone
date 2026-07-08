## Why

`openapi_docs/versions/openapi_20260708.json` 是一份 256KB、含 122 个路径 / 167 个 schema 的 FastAPI OpenAPI 文档。每次想看某个接口（例如 `/user/profile/{user_id}`）的完整契约时，只能在编辑器里翻这份大 JSON，手动跳转、展开 `parameters` / `requestBody` / `responses`，还要跟着 `$ref` 跳到 `components/schemas/` 下拼凑响应结构——既慢又容易看漏字段。我们需要一个轻量命令行工具：输入一个 API 路径，立刻把该接口的完整描述（含被引用的 schema）渲染成可读文本。

## What Changes

- 新增一个**独立 Python 脚本**（不进入 Flutter `client/` 代码树，非项目功能代码），放在仓库根目录的 `scripts/` 下，仅依赖 Python 3 标准库。
- 支持输入一个 API 路径（如 `/user/profile/{user_id}`），脚本定位到该路径在 `paths` 下的条目，输出该接口**每个 HTTP method** 的完整描述：`tags`、`summary`、`description`、`operationId`、`parameters`、`requestBody`、`responses`。
- **递归解析 `$ref`**：把 `responses` / `requestBody` 里形如 `#/components/schemas/XxxResponse` 的引用就地展开为真实字段结构，不再需要手动跳转。
- 支持按 method 过滤（如只看 `GET /user/settings`）。
- 支持模糊/列出模式：当输入的路径匹配不到时，列出全部可用路径供用户挑选；也可用 `--list` 一键打印所有路径。
- 输出既可打印到终端（人类可读），也可用 `--json` 输出机器可读的解析后结构。

## Capabilities

### New Capabilities
- `api-path-docs`: 输入一个 OpenAPI 路径（可选附 method），从指定的 OpenAPI JSON 文档中定位并渲染该接口的完整描述——包含摘要/说明、参数、请求体、响应，并递归展开 `$ref` 引用的 schema。

### Modified Capabilities
<!-- 无已有 spec 需要改动。openspec/specs/ 目录尚不存在，本变更为首个能力。 -->

## Impact

- **新增代码**：仓库根目录新增 `scripts/openapi_doc.py`（独立脚本，约 200–300 行）。
- **依赖**：仅使用 Python 3.9+ 标准库（`json` / `argparse` / `re` / `sys` / `pathlib`），不引入第三方包，无需 `pip install`。
- **不受影响**：Flutter `client/` 代码树、iOS 原生层、服务端。脚本为本地开发辅助工具，不参与任何构建产物。
- **文档**：脚本内置 `--help`，README 级用法以脚本顶部 docstring + `--help` 为准，不额外维护独立文档。
