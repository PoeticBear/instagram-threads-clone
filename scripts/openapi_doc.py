#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
openapi_doc.py — OpenAPI 接口描述截取工具（零第三方依赖）

输入一个 API 路径，输出该接口的完整描述（parameters / requestBody / responses），
并把所有 `$ref` 引用递归展开为真实字段结构，无需手动在 JSON 里跳转。

用法:
  python3 scripts/openapi_doc.py <PATH> [options]
  python3 scripts/openapi_doc.py --list [options]

示例:
  python3 scripts/openapi_doc.py /user/profile/{user_id}
  python3 scripts/openapi_doc.py /user/settings --method put
  python3 scripts/openapi_doc.py /user/profile --json
  python3 scripts/openapi_doc.py --list
  python3 scripts/openapi_doc.py /health --file openapi_docs/versions/openapi_20260616.json

参数:
  PATH                   要查询的 API 路径（如 /user/profile/{user_id}）
  -m, --method METHOD    只看某个 HTTP method（get/post/put/delete/...，大小写不敏感）
  -f, --file FILE        OpenAPI JSON 路径，默认 openapi_docs/versions 下最新版本
  -l, --list             列出文档中全部路径及其方法（与 PATH 互斥）
  --json                 输出解析（$ref 已展开）后的 JSON，便于管道处理
  -h, --help             显示本帮助
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

HTTP_METHODS = ("get", "post", "put", "delete", "patch", "options", "head", "trace")
MAX_REF_DEPTH = 32
DEFAULT_DOCS_GLOB = "openapi_docs/versions/openapi_*.json"


# --------------------------------------------------------------------------- #
# 文档加载
# --------------------------------------------------------------------------- #
def resolve_default_file():
    """在 openapi_docs/versions/ 下取文件名日期段最大的那份。找不到返回 None。"""
    cwd = Path.cwd()
    candidates = sorted(cwd.glob(DEFAULT_DOCS_GLOB))
    if not candidates:
        return None
    return candidates[-1]


def load_doc(path):
    """读取 JSON。文件不存在或解析失败时，stderr 报错并以非零状态码退出。"""
    p = Path(path)
    if not p.exists():
        sys.stderr.write(f"错误: 文件不存在: {path}\n")
        sys.exit(1)
    try:
        with p.open("r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        sys.stderr.write(f"错误: JSON 解析失败: {path}: {e}\n")
        sys.exit(1)


# --------------------------------------------------------------------------- #
# $ref 递归解析（核心）
# --------------------------------------------------------------------------- #
def resolve_pointer(root, ref):
    """按 JSON Pointer 解析 '#/components/schemas/Foo' 形式的内部引用。找不到返回 None。"""
    if not ref.startswith("#"):
        return None
    pointer = ref[1:]
    if pointer in ("", "/"):
        return root
    if not pointer.startswith("/"):
        return None
    cur = root
    for part in pointer.split("/")[1:]:
        part = part.replace("~1", "/").replace("~0", "~")
        if isinstance(cur, dict):
            if part not in cur:
                return None
            cur = cur[part]
        elif isinstance(cur, list):
            try:
                idx = int(part)
            except ValueError:
                return None
            if idx < 0 or idx >= len(cur):
                return None
            cur = cur[idx]
        else:
            return None
    return cur


def deref(node, root, seen, depth=0):
    """递归把内部 $ref 展开为全新结构；原始 doc 永不被原地修改。

    - seen: 当前解析链路上已展开过的 ref 集合，命中即判环。
    - depth: 递归深度硬上限兜底。
    """
    if depth > MAX_REF_DEPTH:
        return "<max depth reached>"
    if isinstance(node, dict):
        if "$ref" in node and isinstance(node["$ref"], str):
            ref = node["$ref"]
            if not ref.startswith("#"):
                sys.stderr.write(f"警告: 外部/URL $ref 未解析，原样保留: {ref}\n")
                return node
            if ref in seen:
                return f"<$ref cycle: {ref}>"
            target = resolve_pointer(root, ref)
            if target is None:
                return f"<unresolved $ref: {ref}>"
            return deref(target, root, seen | {ref}, depth + 1)
        return {k: deref(v, root, seen, depth + 1) for k, v in node.items()}
    if isinstance(node, list):
        return [deref(v, root, seen, depth + 1) for v in node]
    return node


# --------------------------------------------------------------------------- #
# 路径匹配（含容错）
# --------------------------------------------------------------------------- #
def strip_placeholder(s):
    """去掉 {param} 占位符，便于模糊匹配。"""
    return re.sub(r"\{[^}]*\}", "", s)


def match_path(doc, raw):
    """返回 (matched_path, candidates)。

    matched_path 非空表示无歧义命中；为空时 candidates 给出模糊匹配到的候选列表。
    """
    paths = doc.get("paths", {})
    # 1. 精确命中
    if raw in paths:
        return raw, []
    # 2. 标准化前导斜杠后重试
    normalized = raw if raw.startswith("/") else "/" + raw
    if normalized in paths:
        return normalized, []
    if raw.startswith("/") and raw[1:] in paths:
        return raw[1:], []
    # 3. 模糊回退：子串匹配，忽略 {占位符}
    raw_norm = strip_placeholder(normalized)
    matches = []
    for p in paths:
        if raw in p or raw_norm in strip_placeholder(p):
            matches.append(p)
    matches = list(dict.fromkeys(matches))  # 去重保序
    if len(matches) == 1:
        return matches[0], []
    return None, matches


# --------------------------------------------------------------------------- #
# 文本渲染
# --------------------------------------------------------------------------- #
def render_schema(schema, indent):
    """把已解析的 schema 缩进打印成 JSON 块。空 schema 返回空串。"""
    if schema is None:
        return ""
    block = json.dumps(schema, ensure_ascii=False, indent=2)
    pad = " " * indent
    return "\n".join(pad + line for line in block.splitlines())


def param_type(pschema):
    pschema = pschema or {}
    ptype = pschema.get("type")
    if not ptype and "enum" in pschema:
        ptype = ",".join(str(x) for x in pschema["enum"])
    return ptype or "?"


def render_operation(method, path, op, root):
    lines = [f"{method.upper()} {path}"]
    if op.get("tags"):
        lines.append(f"  Tags:        {', '.join(op['tags'])}")
    if op.get("summary"):
        lines.append(f"  Summary:     {op['summary']}")
    if op.get("description"):
        lines.append(f"  Description: {op['description']}")
    if op.get("operationId"):
        lines.append(f"  OperationId: {op['operationId']}")

    # Parameters
    params = op.get("parameters") or []
    if params:
        lines += ["", "  Parameters:"]
        for prm in params:
            name = prm.get("name", "?")
            loc = prm.get("in", "?")
            required = "required" if prm.get("required") else "optional"
            ptype = param_type(prm.get("schema"))
            lines.append(f"    - {name} ({loc}, {ptype}, {required})")

    # Request Body
    rb = op.get("requestBody")
    if rb:
        rb_resolved = deref(rb, root, set())
        lines += ["", "  Request Body:"]
        content = rb_resolved.get("content", {}) or {}
        if not content:
            lines.append("    (no content)")
        for ctype, cval in content.items():
            lines.append(f"    [{ctype}]")
            block = render_schema((cval or {}).get("schema"), indent=6)
            if block:
                lines.append(block)

    # Responses
    responses = op.get("responses") or {}
    if responses:
        lines += ["", "  Responses:"]
        for code in sorted(responses.keys(), key=lambda c: (len(c), c)):
            r_resolved = deref(responses[code], root, set())
            desc = r_resolved.get("description", "")
            header = f"    {code}  {desc}".rstrip()
            lines.append(header)
            content = r_resolved.get("content", {}) or {}
            for ctype, cval in content.items():
                lines.append(f"        [{ctype}]")
                block = render_schema((cval or {}).get("schema"), indent=10)
                if block:
                    lines.append(block)
    return "\n".join(lines)


def get_methods(item, want=None):
    """返回 path item 下的 (method, op) 列表，可按 method 过滤（大小写不敏感）。"""
    want = (want or "").lower()
    out = []
    for m in HTTP_METHODS:
        op = item.get(m)
        if isinstance(op, dict):
            if want and m != want:
                continue
            out.append((m, op))
    return out


# --------------------------------------------------------------------------- #
# 命令分支
# --------------------------------------------------------------------------- #
def cmd_list(doc):
    paths = doc.get("paths", {})
    print(f"共 {len(paths)} 个路径:")
    for p in paths:
        ms = [m.upper() for m in HTTP_METHODS if isinstance(paths[p].get(m), dict)]
        print(f"  {p}  ->  [{', '.join(ms)}]")


def cmd_show(doc, raw_path, method, as_json):
    matched, candidates = match_path(doc, raw_path)
    if matched is None:
        if candidates:
            sys.stderr.write(f"未精确命中，匹配到 {len(candidates)} 个候选:\n")
            for c in candidates:
                sys.stderr.write(f"  {c}\n")
            sys.stderr.write("请用更精确的路径重试。\n")
        else:
            sys.stderr.write(f"未找到路径: {raw_path}\n建议运行 --list 查看全部可用路径。\n")
        sys.exit(2)
    item = doc["paths"][matched]
    pairs = get_methods(item, method)
    if not pairs:
        sys.stderr.write(f"路径 {matched} 上没有方法 {method or '(空)'}\n")
        sys.exit(2)
    if as_json:
        payload = {
            "path": matched,
            "methods": {m: deref(op, doc, set()) for m, op in pairs},
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print("\n\n".join(render_operation(m, matched, op, doc) for m, op in pairs))


# --------------------------------------------------------------------------- #
# 入口
# --------------------------------------------------------------------------- #
def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="openapi_doc.py",
        description="OpenAPI 接口描述截取工具：输入路径，输出该接口完整描述（$ref 递归展开）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("path", nargs="?", help="要查询的 API 路径")
    parser.add_argument("-m", "--method", help="只看某个 HTTP method（大小写不敏感）")
    parser.add_argument("-f", "--file", help="OpenAPI JSON 路径，默认最新版本")
    parser.add_argument("-l", "--list", action="store_true", help="列出全部路径")
    parser.add_argument("--json", dest="as_json", action="store_true", help="输出解析后的 JSON")
    args = parser.parse_args(argv)

    if not args.list and not args.path:
        parser.error("需要提供 PATH，或使用 --list")

    # 解析目标文档
    if args.file:
        doc_path = Path(args.file)
    else:
        resolved = resolve_default_file()
        if resolved is None:
            sys.stderr.write(f"错误: 未找到默认文档（{DEFAULT_DOCS_GLOB}），请用 --file 指定\n")
            sys.exit(1)
        doc_path = resolved
    sys.stderr.write(f"Using: {os.path.relpath(str(doc_path))}\n")

    doc = load_doc(str(doc_path))

    if args.list:
        cmd_list(doc)
        return

    cmd_show(doc, args.path, args.method, args.as_json)


if __name__ == "__main__":
    main()
