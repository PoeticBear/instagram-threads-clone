#!/usr/bin/env python3
"""
将 openapi_20260518.json 按 URL 首段拆分为多个子文档。

业务模块划分规则：
  - 取每个 path 的第一段（如 /user/me -> user）作为模块名
  - group / public-key / upload / moderation 等小模块合并为 _misc
  - 每个子文档保留完整的 openapi 结构（info, paths, components）
  - components 中仅保留该模块实际引用到的 schemas（通过递归解析 $ref）

输出目录: openapi_docs/
"""

import json
import os
import re
from collections import defaultdict
from copy import deepcopy
from pathlib import Path

SOURCE_FILE = "openapi_20260518.json"
OUTPUT_DIR = "openapi_docs"

# --- 模块名映射（小模块合并） ---
MERGE_INTO_MISC = {"group", "public-key", "upload", "moderation"}

MODULE_DISPLAY_NAMES = {
    "community": "Community 社区",
    "follow": "Follow 关注",
    "message": "Message 消息",
    "notification": "Notification 通知",
    "post": "Post 帖子",
    "search": "Search 搜索",
    "topic": "Topic 话题",
    "user": "User 用户",
    "_misc": "Misc 杂项",
}


def load_source(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def get_module_name(url_path: str) -> str:
    """从 /user/me 提取 user 作为模块名"""
    seg = url_path.strip("/").split("/")[0]
    return seg if seg not in MERGE_INTO_MISC else "_misc"


def group_paths_by_module(paths: dict) -> dict[str, dict]:
    """按模块分组 paths"""
    modules: dict[str, dict] = defaultdict(dict)
    for url_path, methods in paths.items():
        mod = get_module_name(url_path)
        modules[mod][url_path] = methods
    return dict(modules)


# ---------- Schema 依赖收集 ----------

def collect_refs(schema: dict, collected: set[str]) -> None:
    """递归收集所有 $ref 引用的 schema 名称"""
    if not isinstance(schema, dict):
        return
    ref = schema.get("$ref")
    if ref and isinstance(ref, str):
        # #/components/schemas/Foo -> Foo
        name = ref.rsplit("/", 1)[-1]
        if name not in collected:
            collected.add(name)
    for v in schema.values():
        if isinstance(v, dict):
            collect_refs(v, collected)
        elif isinstance(v, list):
            for item in v:
                if isinstance(item, dict):
                    collect_refs(item, collected)


def resolve_used_schemas(module_paths: dict, all_schemas: dict) -> dict[str, dict]:
    """收集模块 paths 中用到的所有 schemas（递归解析依赖）"""
    needed: set[str] = set()

    # 第一遍：收集 paths 里直接出现的 $ref
    collect_refs(module_paths, needed)

    # 反复扩展，直到没有新的 schema 被引入
    prev_len = -1
    while len(needed) != prev_len:
        prev_len = len(needed)
        for name in list(needed):
            if name in all_schemas:
                collect_refs(all_schemas[name], needed)

    # 构建子集
    return {name: all_schemas[name] for name in sorted(needed) if name in all_schemas}


# ---------- 构建子文档 ----------

def build_sub_doc(source: dict, module_name: str, module_paths: dict) -> dict:
    doc = {
        "openapi": source["openapi"],
        "info": {
            **source["info"],
            "title": f"{MODULE_DISPLAY_NAMES.get(module_name, module_name)} API",
        },
        "paths": module_paths,
    }

    used_schemas = resolve_used_schemas(module_paths, source.get("components", {}).get("schemas", {}))
    if used_schemas:
        doc["components"] = {"schemas": used_schemas}

    return doc


# ---------- 主流程 ----------

def main():
    source = load_source(SOURCE_FILE)
    modules = group_paths_by_module(source.get("paths", {}))

    out_dir = Path(OUTPUT_DIR)
    out_dir.mkdir(exist_ok=True)

    print(f"共识别 {len(modules)} 个模块，开始拆分...\n")

    for mod_name, mod_paths in sorted(modules.items()):
        sub_doc = build_sub_doc(source, mod_name, mod_paths)
        filename = f"{mod_name}.json"
        filepath = out_dir / filename

        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(sub_doc, f, ensure_ascii=False, indent=2)

        display = MODULE_DISPLAY_NAMES.get(mod_name, mod_name)
        schema_count = len(sub_doc.get("components", {}).get("schemas", {}))
        endpoint_count = sum(len(v) for v in mod_paths.values())
        print(f"  [{display}]  {endpoint_count:>3} endpoints  {schema_count:>3} schemas  -> {filename}")

    # 生成索引文件
    index = {
        "description": "API 文档索引 - 按业务模块拆分",
        "source": SOURCE_FILE,
        "modules": {},
    }
    for mod_name in sorted(modules.keys()):
        display = MODULE_DISPLAY_NAMES.get(mod_name, mod_name)
        index["modules"][mod_name] = {
            "name": display,
            "file": f"{mod_name}.json",
            "endpoints": list(modules[mod_name].keys()),
        }

    with open(out_dir / "_index.json", "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    print(f"\n全部完成！文件输出到 {out_dir.resolve()}/")


if __name__ == "__main__":
    main()
