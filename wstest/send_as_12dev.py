#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
以 12dev 身份发一帖 '@14dev 你好'，mention 14dev(id=1000382)。

用途：14dev 的真实 app 正在模拟器前台运行（接收方），
跑这个脚本让 12dev 发帖，然后去 14dev 的 flutter run 终端观察：
  - 有没有 [WS] event type=post_mention  ← 期望：没有（这就是 bug）
  - 心形 Tab 有没有实时红点              ← 期望：没有

用法：python3 wstest/send_as_12dev.py
"""
import json
import sys
import urllib.error
import urllib.request

BASE = "http://192.168.1.27:8005"
SENDER = "12dev"          # 发送方
PASSWORD = "123456"
MENTIONED_ID = 1000382    # 接收方 14dev
MENTIONED_NAME = "14dev"


def http(method, path, body=None, token=None):
    url = f"{BASE}/{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=12) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")
    except Exception as e:
        return None, {"_error": str(e)}


def main():
    # 1. 登录 12dev
    st, resp = http("POST", "auth/username/signin",
                    {"username": SENDER, "password": PASSWORD})
    token = (resp or {}).get("data", {}).get("access_token") if isinstance(resp, dict) else None
    print(f"[login {SENDER}] HTTP {st}  token={'OK' if token else 'MISSING'}")
    if not token:
        sys.exit(1)

    # 2. 12dev 发帖，mention 14dev —— 打印完整 HTTP 请求
    content = f"@{MENTIONED_NAME} 你好"
    body = {"content": content, "mentioned_user_ids": [MENTIONED_ID]}
    print("━" * 60)
    print(">>> 完整 HTTP 请求:")
    print(f"    POST {BASE}/post/create")
    print(f"    Headers:")
    print(f"      Content-Type: application/json")
    print(f"      Authorization: Bearer {token}")
    print(f"    Body: {json.dumps(body, ensure_ascii=False)}")
    print(f"    ★ mentioned_user_ids = {body['mentioned_user_ids']}  "
          f"← 提及用户 {MENTIONED_NAME} 的 ID")
    print("━" * 60)

    st, resp = http("POST", "post/create", token=token, body=body)
    print(f"[createPost as {SENDER}] HTTP {st}")
    data = (resp or {}).get("data") if isinstance(resp, dict) else None
    echo = data.get("mentioned_users_info") if isinstance(data, dict) else None
    if echo:
        print(f"  ✅ 服务端接受了 mention — 回带 mentioned_users_info = {echo}")
    else:
        print(f"  ⚠️ 服务端回带无 mentioned_users_info（mention 可能未生效）")
        print(f"     完整响应 = {json.dumps(resp, ensure_ascii=False)[:600]}")
    if isinstance(data, dict):
        print(f"  → post_id={data.get('id')}")
    print()
    print("=" * 60)
    print(">> 现在立刻去 14dev 的 flutter run 终端看：")
    print(">>   1) 有没有出现  [WS] event type=post_mention")
    print(">>   2) 心形 Tab 有没有冒出红点")
    print("=" * 60)


if __name__ == "__main__":
    main()
