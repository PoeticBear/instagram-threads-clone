#!/usr/bin/env python3
"""
将 OpenAPI 3.1 模块文档转换为精简的客户端接口契约格式。

用法: python3 _convert.py [模块名...]
  不传参数则转换所有模块。
"""

import json
import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(os.path.dirname(BASE_DIR), "openapi_20260518.json")

# Headers repeated on almost every endpoint
SKIP_HEADERS = {"Authorization", "device-os", "user-agent", "device-name"}


def resolve_ref(root, ref: str):
    """Follow a $ref and return the resolved schema dict."""
    parts = ref.replace("#/", "").split("/")
    node = root
    for p in parts:
        node = node[p]
    return node


def flatten_type(root, schema, visited=None):
    """
    Return a compact type string, or None if the schema should be inline-expanded.
    """
    if visited is None:
        visited = set()
    if not isinstance(schema, dict):
        return "object"

    # $ref — resolve but prefer the named type over inline expansion
    if "$ref" in schema:
        ref = schema["$ref"]
        name = ref.split("/")[-1]
        if ref in visited:
            return name  # break cycle
        visited.add(ref)
        resolved = resolve_ref(root, ref)
        inner = flatten_type(root, resolved, visited)
        # If resolution says "needs inline expansion", use the type name instead
        # (the schema will be in the schemas section)
        if inner is None:
            return name
        return inner

    # allOf
    if "allOf" in schema:
        return "object"

    # anyOf (typically nullable)
    if "anyOf" in schema:
        non_null = [v for v in schema["anyOf"] if v.get("type") != "null"]
        if len(non_null) == 1:
            inner = flatten_type(root, non_null[0], visited)
            if inner is None:
                return None  # nested object
            return inner + "?"
        parts = []
        for v in non_null:
            p = flatten_type(root, v, visited)
            parts.append(p or "object")
        return " | ".join(parts)

    # oneOf
    if "oneOf" in schema:
        parts = []
        for v in schema["oneOf"]:
            p = flatten_type(root, v, visited)
            parts.append(p or "object")
        return " | ".join(parts)

    t = schema.get("type")
    if t == "integer":
        return "int"
    if t == "number":
        return "float"
    if t == "boolean":
        return "bool"
    if t == "string":
        extras = []
        if "enum" in schema:
            extras.append("enum: " + ", ".join(str(e) for e in schema["enum"]))
        if "maxLength" in schema:
            extras.append(f"max {schema['maxLength']}")
        return "string" + (", " + ", ".join(extras) if extras else "")
    if t == "array":
        items = schema.get("items", {})
        inner = flatten_type(root, items, visited)
        return f"{inner or 'object'}[]"
    if t == "object" and "properties" in schema:
        return None  # needs inline expansion

    return t or "object"


def desc_field(root, schema):
    """Return compact 'type, description' string, or None for inline objects."""
    ft = flatten_type(root, schema)
    if ft is not None:
        parts = [ft]
        desc = schema.get("description", "")
        if desc:
            parts.append(desc)
        default = schema.get("default")
        if default is not None and str(default) != "":
            parts.append(f"default: {default}")
        return ", ".join(parts)
    return None


def expand_fields(root, schema, depth=0, max_depth=2):
    """Expand schema properties into {field: "type, desc"} dict."""
    if depth > max_depth:
        return {}
    # Unwrap anyOf/$ref wrapper
    schema = unwrap_schema(root, schema)

    props = schema.get("properties", {})
    required = set(schema.get("required", []))
    result = {}
    for name, prop in props.items():
        d = desc_field(root, prop)
        if d is not None:
            if name not in required:
                d += ", optional"
            result[name] = d
        else:
            # nested object
            nested = expand_fields(root, prop, depth + 1, max_depth)
            marker = ", optional" if name not in required else ""
            if nested:
                result[name] = nested
                if marker:
                    result[name]["_required"] = False
            else:
                result[name] = "object" + marker
    return result


def unwrap_schema(root, schema):
    """Unwrap anyOf(nullable) / $ref to get the real schema."""
    if "anyOf" in schema:
        non_null = [v for v in schema["anyOf"] if v.get("type") != "null"]
        if len(non_null) == 1:
            schema = non_null[0]
    if "$ref" in schema:
        schema = resolve_ref(root, schema["$ref"])
    return schema


def param_desc(param):
    """Compact description for a single parameter."""
    schema = param.get("schema", {})
    parts = []
    t = schema.get("type", "string")
    if t == "integer":
        parts.append("int")
    elif t == "string":
        parts.append("string")
    else:
        parts.append(t)
    desc = param.get("description", "") or schema.get("description", "")
    if desc:
        parts.append(desc)
    default = schema.get("default")
    if default is not None and str(default) != "":
        parts.append(f"default: {default}")
    minimum = schema.get("minimum")
    maximum = schema.get("maximum")
    if minimum is not None:
        parts.append(f"min: {minimum}")
    if maximum is not None:
        parts.append(f"max: {maximum}")
    return ", ".join(parts)


def response_type_name(root, schema):
    """Human-readable response data type, e.g. 'Page<PostResponse>'."""
    if not schema:
        return "void"
    # Unwrap ResponseModel_X_
    if "$ref" in schema:
        name = schema["$ref"].split("/")[-1]
        if name.startswith("ResponseModel_"):
            inner_name = name[len("ResponseModel_"):].rstrip("_")
            try:
                resolved = resolve_ref(root, schema["$ref"])
                data_schema = resolved.get("properties", {}).get("data", {})
                return _unwrap_data(root, data_schema, inner_name)
            except Exception:
                return inner_name
        return name
    return "object"


def _unwrap_data(root, schema, fallback):
    if "anyOf" in schema:
        non_null = [v for v in schema["anyOf"] if v.get("type") != "null"]
        if len(non_null) == 1:
            return _unwrap_data(root, non_null[0], fallback) + "?"
        return fallback
    if "$ref" in schema:
        name = schema["$ref"].split("/")[-1]
        return _pretty(name)
    if schema.get("type") == "array":
        items = schema.get("items", {})
        inner = _unwrap_data(root, items, "object")
        return f"List<{inner}>"
    if schema.get("type") == "integer":
        return "int"
    if schema.get("type") == "string":
        return "string"
    if schema.get("type") == "object" and not schema.get("properties"):
        return fallback
    return fallback


def _pretty(name):
    if name.startswith("PageMeta_"):
        inner = name[len("PageMeta_"):].rstrip("_")
        return f"Page<{inner}>"
    if name.startswith("ResponseModel_list_"):
        inner = name[len("ResponseModel_list_"):].rstrip("_")
        return f"List<{inner}>"
    if name.startswith("ResponseModel_"):
        inner = name[len("ResponseModel_"):].rstrip("_")
        return inner
    return name


def extract_endpoint(root, path, method, detail):
    """Convert one operation to compact dict."""
    ep = {
        "name": detail.get("summary", ""),
        "method": method.upper(),
        "path": path,
    }

    params = detail.get("parameters", [])

    # auth flag
    if any(p.get("name") == "Authorization" for p in params):
        ep["auth"] = True

    # valuable description (only if longer than summary)
    desc = detail.get("description", "")
    summary = detail.get("summary", "")
    if desc and desc != summary:
        clean = " ".join(desc.split())
        if len(clean) > len(summary) + 10:
            ep["desc"] = clean

    # path params
    pp = {p["name"]: param_desc(p) for p in params if p.get("in") == "path"}
    if pp:
        ep["path_params"] = pp

    # query params (skip common headers)
    qp = {p["name"]: param_desc(p) for p in params if p.get("in") == "query"}
    if qp:
        ep["query"] = qp

    # request body
    rb = detail.get("requestBody", {})
    if rb:
        for _ct, ct_info in rb.get("content", {}).items():
            schema_ref = ct_info.get("schema", {})
            resolved = unwrap_schema(root, schema_ref)
            fields = expand_fields(root, resolved)
            if fields:
                ep["request"] = fields
            break

    # response
    resp_200 = detail.get("responses", {}).get("200", {})
    for _ct, ct_info in resp_200.get("content", {}).items():
        schema_ref = ct_info.get("schema", {})
        ep["response"] = response_type_name(root, schema_ref)
        break

    return ep


# ────────────────────── schema collection ──────────────────────

TYPE_NAME_RE = re.compile(r'\b([A-Z][a-zA-Z]*(?:Response|Request|Item|Info|Result|Input))\b')


def collect_type_names(s):
    """Extract CamelCase schema names from type strings."""
    if not isinstance(s, str):
        return set()
    return set(TYPE_NAME_RE.findall(s))


def collect_all_refs(obj, refs):
    """Recursively find all $ref strings in a JSON structure."""
    if isinstance(obj, dict):
        if "$ref" in obj:
            refs.add(obj["$ref"])
        for v in obj.values():
            collect_all_refs(v, refs)
    elif isinstance(obj, list):
        for v in obj:
            collect_all_refs(v, refs)


def collect_endpoint_schemas(root, endpoints):
    """Collect all schemas referenced by endpoints, including transitive deps."""
    all_schemas = root.get("components", {}).get("schemas", {})
    needed_refs = set()

    # Collect direct refs from endpoints
    for ep in endpoints:
        for v in ep.values():
            if isinstance(v, str):
                for name in collect_type_names(v):
                    needed_refs.add(f"#/components/schemas/{name}")
            elif isinstance(v, dict):
                collect_all_refs(v, needed_refs)

    # Expand transitively
    visited = set()
    result = {}

    def visit(ref):
        if ref in visited:
            return
        visited.add(ref)
        name = ref.split("/")[-1]
        if name not in all_schemas:
            return
        schema = all_schemas[name]
        fields = expand_fields(root, schema)
        if fields:
            result[name] = fields
        # Find sub-refs
        sub_refs = set()
        collect_all_refs(schema, sub_refs)
        for sr in sub_refs:
            visit(sr)
        # Also check field values for type name references
        for v in fields.values():
            if isinstance(v, str):
                for n in collect_type_names(v):
                    visit(f"#/components/schemas/{n}")
            elif isinstance(v, dict):
                collect_all_refs(v, sub_refs)
                for sv in v.values():
                    if isinstance(sv, str):
                        for n in collect_type_names(sv):
                            visit(f"#/components/schemas/{n}")

    for ref in needed_refs:
        visit(ref)

    return result


# ──────────────────────────── main ────────────────────────────

def convert_module(module_name, source_data):
    module_file = os.path.join(BASE_DIR, f"{module_name}.json")
    if not os.path.exists(module_file):
        print(f"  SKIP {module_name}.json (not found)")
        return None

    with open(module_file) as f:
        data = json.load(f)

    # Use source schemas for $ref resolution
    root_schemas = source_data.get("components", {}).get("schemas", {})
    root = {"components": {"schemas": dict(root_schemas)}}

    paths = data.get("paths", {})
    endpoints = []

    for path in sorted(paths.keys()):
        methods = paths[path]
        for method in ("get", "post", "put", "patch", "delete"):
            if method in methods:
                ep = extract_endpoint(root, path, method, methods[method])
                endpoints.append(ep)

    schemas = collect_endpoint_schemas(root, endpoints)

    result = {
        "common": {
            "response_wrapper": "{ code: int, msg: string, data: T }",
            "pagination": "{ total: int, page: int, size: int, items: T[] }",
            "auth_header": "Authorization: string (大部分接口必传)",
            "device_header": "device-os: string (可选)",
        },
        "endpoints": endpoints,
    }
    if schemas:
        result["schemas"] = dict(sorted(schemas.items()))

    return result


def main():
    with open(SOURCE) as f:
        source_data = json.load(f)

    with open(os.path.join(BASE_DIR, "_index.json")) as f:
        index = json.load(f)

    modules = list(index.get("modules", {}).keys())
    if len(sys.argv) > 1:
        modules = [m for m in modules if m in sys.argv[1:]]

    total_before = 0
    total_after = 0

    for mod in modules:
        fpath = os.path.join(BASE_DIR, f"{mod}.json")
        size_before = os.path.getsize(fpath) if os.path.exists(fpath) else 0
        total_before += size_before

        print(f"Converting {mod}...", end=" ")
        result = convert_module(mod, source_data)
        if result is None:
            continue

        with open(fpath, "w") as f:
            json.dump(result, f, indent=2, ensure_ascii=False)

        ep_count = len(result["endpoints"])
        schema_count = len(result.get("schemas", {}))
        size_after = os.path.getsize(fpath)
        total_after += size_after
        print(f"{ep_count} eps, {schema_count} schemas, "
              f"{size_before // 1024}KB → {size_after // 1024}KB")

    # Update index
    new_index = {
        "description": "API 接口契约 - 精简版 (客户端联调用)",
        "source": "openapi_20260518.json",
        "format": "simplified",
        "common": {
            "response_wrapper": "{ code: int, msg: string, data: T }",
            "pagination": "{ total: int, page: int, size: int, items: T[] }",
            "auth_header": "Authorization: string (大部分接口必传)",
        },
        "modules": {},
    }
    for mod in modules:
        fpath = os.path.join(BASE_DIR, f"{mod}.json")
        if os.path.exists(fpath):
            with open(fpath) as f:
                d = json.load(f)
            mod_info = index["modules"].get(mod, {})
            new_index["modules"][mod] = {
                "name": mod_info.get("name", mod),
                "file": f"{mod}.json",
                "endpoints": len(d.get("endpoints", [])),
                "schemas": len(d.get("schemas", {})),
            }

    with open(os.path.join(BASE_DIR, "_index.json"), "w") as f:
        json.dump(new_index, f, indent=2, ensure_ascii=False)

    print(f"\nTotal: {total_before // 1024}KB → {total_after // 1024}KB "
          f"({(1 - total_after / total_before) * 100:.0f}% reduction)")


if __name__ == "__main__":
    main()
