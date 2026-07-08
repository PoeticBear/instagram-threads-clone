# Implementation Tasks — openapi-path-extractor

> 落地一个零依赖的独立 Python 脚本 `scripts/openapi_doc.py`：输入 API 路径，输出该接口完整描述（`$ref` 递归展开）。
> 设计依据见 `design.md`，行为契约见 `specs/api-path-docs/spec.md`。

## 1. 脚手架与默认文档定位

- [x] 1.1 在仓库根目录新建 `scripts/openapi_doc.py`，顶部 docstring 写清用法（路径参数 + `--method`/`--file`/`--list`/`--json`/`--help`）
- [x] 1.2 用 `argparse` 搭好 CLI：`PATH` 位置参数（与 `--list` 互斥）、`-m/--method`、`-f/--file`、`-l/--list`、`--json`、`-h/--help`
- [x] 1.3 实现 `resolve_default_file()`：未传 `--file` 时，用 `pathlib` 扫描 `openapi_docs/versions/openapi_*.json`，取文件名日期段最大者；并在 stdout 打印一行 `Using: <相对路径>`
- [x] 1.4 实现 `load_doc(path)`：读取 JSON；文件不存在或解析失败时在 stderr 报错并以非零状态码退出

## 2. `$ref` 递归解析（核心）

- [x] 2.1 实现 `resolve_ref(node, root, seen, depth)`：深拷贝传入节点，遇到 `"$ref": "#/..."` 时按路径切片定位目标、对副本继续递归
- [x] 2.2 加环检测：用 `seen` 集合记录当前解析链路上的 ref，命中重复 ref 时输出 `"<$ref cycle: #/...>"` 并停止该分支展开
- [x] 2.3 加递归深度硬上限（如 32）兜底，防止异常文档栈溢出
- [x] 2.4 仅处理 `#/` 开头的内部引用；外部/URL 引用原样保留并 stderr 告警；解析不到的目标输出 `"<unresolved $ref: ...>"` 且不抛异常
- [x] 2.5 确保解析只在 `doc` 的副本上进行，原始 `doc` 对象不被原地修改（多次查询互不污染）

## 3. 路径匹配（含容错）

- [x] 3.1 实现 `match_path(doc, raw)`：精确命中优先（`doc["paths"].get(raw)`）
- [x] 3.2 标准化重试：补/去掉前导 `/` 后再查一次
- [x] 3.3 模糊回退：对所有 path 做子串匹配（忽略 `{占位符}`），唯一命中则直接渲染；多候选则列出全部候选并提示用户用更精确路径重试（不自动选）
- [x] 3.4 完全无匹配：提示未找到 + 建议用 `--list`，非零状态码退出

## 4. 文本渲染

- [x] 4.1 实现 `render_operation(method, path, op, doc)`：分区打印 method/路径、Tags、Summary、Description、OperationId
- [x] 4.2 渲染 Parameters：每条参数打印 `name (in, type, required)`
- [x] 4.3 渲染 RequestBody：打印 content-type + 解析后的 schema 字段结构
- [x] 4.4 渲染 Responses：每条状态码打印描述 + 展开后的 schema（类 JSON 缩进块）
- [x] 4.5 多 method 时循环渲染全部（除非 `--method` 过滤）；`--method` 大小写不敏感

## 5. `--list` 与 `--json` 输出

- [x] 5.1 实现 `--list`：遍历 `doc["paths"]`，每行打印 `路径 -> [methods]`
- [x] 5.2 实现 `--json`：把 `path` + 解析后 `methods` 组成 `{path, methods:{...}}`，`json.dumps(ensure_ascii=False, indent=2)` 输出（`$ref` 已全部展开）

## 6. 验证

- [x] 6.1 对 `/user/profile/{user_id}` 运行脚本，确认 200 响应的 `ResponseModel_UserProfileResponse_` 被展开为真实字段
- [x] 6.2 对 `/user/settings` 运行（多 method），确认 `--method put` 只输出 PUT、不传则同时输出 GET/PUT
- [x] 6.3 输入 `/user/profile`（不带占位符）验证唯一候选自动渲染；输入 `/user`（多候选）验证列出候选而非自动选
- [x] 6.4 验证 `--list` 输出全部路径（应为 122 条）
- [x] 6.5 验证 `--json` 输出是合法 JSON 且 `responses` 内无残留 `$ref`
- [x] 6.6 验证 `--file openapi_docs/versions/openapi_20260616.json` 可切换旧版；传不存在的文件以非零码退出
- [x] 6.7 在系统 Python 3.9 下确认零第三方依赖、`--help` 正常
