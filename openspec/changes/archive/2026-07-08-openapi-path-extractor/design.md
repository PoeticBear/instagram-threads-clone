## Context

仓库 `openapi_docs/versions/` 下是 FastAPI 自动生成的 OpenAPI 3.1.0 文档（最新版 `openapi_20260708.json`，256KB / 122 路径 / 167 schema）。结构上：

- 顶层只有 `openapi` / `info` / `paths` / `components`（`components` 仅含 `schemas`，无 `securitySchemes`）。
- 每个 path 下按 HTTP method 分（`get`/`post`/`put`/`delete`/...），operation 内含 `tags`/`summary`/`description`/`operationId`/`parameters`/`requestBody`/`responses`。
- 响应与请求体的真实结构几乎都通过 `$ref: "#/components/schemas/XxxResponse"` 间接引用，schema 之间还会互相 `$ref`（嵌套引用），个别甚至可能成环。

约束：
- 这是**本地开发辅助工具**，不是产品功能；不进 Flutter 构建链。
- 用户机器 Python 为 3.9.6（`/usr/bin/python3`），希望**零依赖**、`git clone` 后直接跑。
- 路径输入可能带或不带前导斜杠、可能记不准（如把 `/user/profile/{user_id}` 记成 `/user/profile`）。

## Goals / Non-Goals

**Goals:**
- 输入一个路径，秒级输出该接口**所有 method** 的完整描述（含参数 / 请求体 / 响应）。
- 递归展开 `$ref`，让用户一眼看到真实字段，不必手动跳转。
- 零第三方依赖、单文件脚本、跨 `openapi_docs/versions/*.json` 任意版本可切。
- 路径记不准时给出候选列表，降低使用门槛。

**Non-Goals:**
- 不做 OpenAPI 校验 / 语义检查（不判断 schema 是否合法）。
- 不生成客户端代码、不 mock 服务、不发起真实 HTTP 请求。
- 不处理 OpenAPI 2.x / Swagger 文档（只针对当前 3.1.0 结构）。
- 不解析 `securitySchemes` / `security`（当前文档没有这些字段）。
- 不维护 GUI 或长期服务。

## Decisions

### 1. 形态：单文件 CLI 脚本，stdlib only
**选择**：一个 `scripts/openapi_doc.py`，仅用 `json` / `argparse` / `re` / `sys` / `pathlib`。
**理由**：脚本核心就是「加载 JSON → 按路径取子树 → 递归解 `$ref` → 打印」，逻辑足够薄，引入 `openapi-core` / `prance` / `pyyaml` 反而增加安装成本，违背「零依赖、开箱即用」。
**备选**：用 `prance`（自带 `$ref` resolver）——被否决，因为需要 `pip install` 且其默认行为会改写文档结构，不利于「原样截取描述」。

### 2. CLI 接口
```
python3 scripts/openapi_doc.py <PATH> [options]
  <PATH>                  要查询的 API 路径，如 /user/profile/{user_id}
  -m, --method METHOD     只看某个 method（get/post/put/delete/...），不传则输出全部
  -f, --file FILE         OpenAPI JSON 路径，默认 openapi_docs/versions 下最新版本
  -l, --list              列出文档中全部路径（与 <PATH> 互斥）
  --json                  输出解析后的 JSON（$ref 已展开），而非人类可读文本
  -h, --help              用法说明
```
**理由**：`<PATH>` 位置参数最直观；`--method` / `--file` / `--json` / `--list` 覆盖常见用法。默认文件取 `versions/` 下文件名日期最大的那个，省去每次手输路径。

### 3. `$ref` 递归解析策略
**选择**：写一个 `resolve_ref(node, root, seen)` 递归函数——
- 命中 `"$ref": "#/..."` 时，按 `#/components/schemas/X` 切片定位到目标节点，复制后对**复制体**继续递归（绝不原地改原始 `doc`，保证多次查询互不污染）。
- **环检测**：维护一个「本次解析链路上已展开过的 ref 链」`seen` 集合，再次遇到同一 ref 时停止展开，标记为 `"<$ref cycle: #/components/schemas/X>"`，防止无限递归。
- **深度上限**：额外加一个递归深度硬上限（如 32），作为兜底。
- 只处理内部引用（`#/` 开头）；遇到外部/URL 引用直接原样保留 ref 字符串并打印告警（当前文档不存在此类引用）。
**理由**：FastAPI 文档 schema 互相引用普遍，必须有环检测；对复制体操作避免污染 `doc` 全局对象（影响后续 `--json` 多次输出或同一进程内多次查询）。

### 4. 路径匹配（容错）
按优先级回退：
1. **精确匹配**：`doc["paths"].get(input)` 命中即用。
2. **标准化重试**：补/去掉前导 `/`、把空格转义差异归一后再查一次。
3. **子串/模糊**：仍无命中时，对所有 path 做子串匹配（忽略 `{xxx}` 占位符，例如 `/user/profile` 能命中 `/user/profile/{user_id}`），打印候选并提示用户用更精确的路径重试；若唯一命中则直接渲染。
**理由**：用户经常记不清 `{user_id}` 这类占位符，子串匹配 + 占位符忽略大幅降低心智负担。多候选时**不自动选**，列出来让用户决定，避免给错信息。

### 5. 输出渲染
**默认（人类可读）**：分区打印——
```
GET /user/profile/{user_id}
  Tags:        用户
  Summary:     获取用户资料
  Description: 获取指定用户的资料
  OperationId: get_user_profile_...

  Parameters:
    - user_id (path, integer, required)

  Responses:
    200  Successful Response
         -> ResponseModel_UserProfileResponse_ {
             "code": integer,
             "message": string,
             "data": UserProfileResponse { ... }
           }
    422  Validation Error -> HTTPValidationError { ... }
```
schema 渲染为类 JSON 缩进块（展开后字段类型来自解析后的 `type`/`properties`）。

**`--json`**：输出 `json.dumps(resolved, ensure_ascii=False, indent=2)`，结构为 `{path, methods: {method: <operation-with-refs-resolved>}}`，方便管道给其他工具。

### 6. 默认文件定位
`--file` 未传时，`pathlib` 扫描 `openapi_docs/versions/openapi_*.json`，取文件名（日期段）字典序最大者，并打印一行 `Using: openapi_docs/versions/openapi_20260708.json` 提示用的是哪份。
**理由**：文档按日期命名，新版本即最大日期；提示行避免「看的是旧版还不自知」。

## Risks / Trade-offs

- **环引用导致栈溢出** → `seen` 集合 + 深度硬上限双重保护；遇环打可读标记而非崩溃。
- **大 schema 递归展开输出过长**（如响应 data 套很多层）→ `--json` 模式原样保留；文本模式对深层嵌套 schema 也照常渲染，但在 design 中**不**做截断（用户明确要「完整」截取）。若实测过长，后续可在 tasks 里加一个 `--max-depth` 开关（留作 Open Question）。
- **`$ref` 指向不存在路径**（脏文档）→ 捕获后输出 `"<unresolved $ref: ...>"`，不抛异常中断。
- **路径占位符匹配过宽，误命中多个** → 多候选一律列出不自动选，把选择权交给用户。
- **未来 OpenAPI 文档新增 `securitySchemes` 等顶层字段** → 当前不解析，但渲染时对未知字段走通用 fallback（原样打印 key），不会崩溃；届时再补渲染规则即可。

## Migration Plan

- 全新脚本，无迁移、无回滚需求。
- 落地后可直接 `python3 scripts/openapi_doc.py /user/profile/{user_id}` 试用；无需改动任何现有代码 / 构建配置。

## Open Questions

- 是否需要 `--max-depth N` 控制深层 schema 展开层数（防止个别巨型响应刷屏）？倾向**先不加**，保持「完整截取」语义；若实测某个接口输出过长，再在 tasks 里追加。
- 默认文件取「最新日期」是否要改成显式写死当前版本，避免悄悄切到未审核的新版？倾向**取最新 + 打印提示行**，提示行已足够防范。
