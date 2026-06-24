#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WS 鉴权契约探测脚本（脱离 Flutter / Dart，纯 Python）

目的：开发服务器握手能过、但连上 ~50ms 就被服务端关闭。
逐个尝试不同的 token 传法，观察每种结果：

  ✅ 握手成功 + 连接保持 / 收到消息  → 服务端接受这种鉴权方式（这就是答案）
  ❌ 握手被拒 (HTTP 4xx)              → 路径错 / token 缺失 / token 过期
  ⚡ 握手成功但立刻被关闭              → 应用层鉴权参数不被接受（最可能就是当前问题）

用法：
  python3 wstest.py <JWT>
  WS_TOKEN=<JWT> python3 wstest.py
  # 或直接编辑下面的 DEFAULT_TOKEN
"""
import asyncio
import os
import sys

import websockets
from websockets.exceptions import (
    ConnectionClosed,
    InvalidHandshake,
    InvalidStatus,
)

HOST = "192.168.1.27"
PORT = 8005
PATH = "/websocket/ws"

# 调试用 token（从客户端日志复制，会过期；排障时换成最新登录拿到的 token）
DEFAULT_TOKEN = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpZCI6MTAwMDM4MiwidXNlcm5hbWUiOiIxNGRldiIsImV4cCI6MTc4MjM1MjE1NiwidG9rZW5fdHlwZSI6ImFjY2VzcyIsImp0aSI6IjEwMDAzODIxNzgyMjM2OTU2LjY1NjgwOSJ9."
    "fCwpcVRaQ8zZAKfGp9c3edXqxxFBOrfm-E_HlFd71F4"
)

BASE = f"ws://{HOST}:{PORT}{PATH}"
WAIT = 2.0  # 连上后观察多久（秒）


def close_hint(code):
    if code == 1008:
        return "Policy Violation（典型：鉴权/业务拒绝）"
    if code == 1006:
        return "Abnormal Closure（TCP 直接断，没发 close 帧）"
    if code in (1000, 1001):
        return "正常关闭"
    return "自定义关闭码（看服务端约定）"


async def try_variant(name, uri, headers=None):
    print(f"\n━━━━━━ {name} ━━━━━━")
    print(f"  URI    : {uri}")
    if headers:
        for k, v in headers.items():
            shown = v if len(v) < 40 else v[:37] + "..."
            print(f"  Header : {k}: {shown}")
    try:
        async with websockets.connect(
            uri, additional_headers=headers or {}, open_timeout=8
        ) as ws:
            print("  ✅ 握手成功 (HTTP 101)")
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=WAIT)
                print(f"  📩 收到消息: {msg!r}")
                print("  🎉 连接存活 + 推来消息 → 这就是服务端要的鉴权方式！")
            except asyncio.TimeoutError:
                print(f"  ✅ 连接保持 {WAIT}s 未被关闭（安静）")
                print("  🎉 这种鉴权方式服务端接受 → 客户端改成这一种")
            except ConnectionClosed as e:
                print(f"  ⚡ 连上后被关闭 code={e.code} reason={e.reason!r}")
                print(f"     → {close_hint(e.code)}")
                print("     → 握手过了但应用层立刻踢：token 传法不对 / token 过期")
    except InvalidStatus as e:
        print(f"  ❌ 握手被拒: HTTP {e.response.status_code}")
        try:
            body = e.response.body
            if body:
                print(f"     body: {body[:200]!r}")
        except Exception:
            pass
        print("     → 路径错 / HTTP 层就要 token 且没收到 / token 过期")
    except InvalidHandshake as e:
        print(f"  ❌ 握手异常: {type(e).__name__}: {e}")
    except (OSError, asyncio.TimeoutError) as e:
        print(f"  ❌ 连不上服务器: {type(e).__name__}: {e}")


async def main():
    token = (
        sys.argv[1] if len(sys.argv) > 1
        else os.environ.get("WS_TOKEN", DEFAULT_TOKEN)
    )
    print(f"目标: {BASE}")
    print(f"token: {token[:20]}...{token[-8:]}  (len={len(token)})")

    variants = [
        ("1. query  access_token=裸JWT",
         f"{BASE}?access_token={token}", None),
        ("2. query  access_token=Bearer%20JWT（标准空格编码）",
         f"{BASE}?access_token=Bearer%20{token}", None),
        ("3. query  access_token=Bearer+JWT（复现 Flutter 现状 form 编码）",
         f"{BASE}?access_token=Bearer+{token}", None),
        ("4. query  token=裸JWT（换 key 名）",
         f"{BASE}?token={token}", None),
        ("5. header Authorization: Bearer JWT",
         BASE, {"Authorization": f"Bearer {token}"}),
        ("6. header Authorization: 裸JWT",
         BASE, {"Authorization": token}),
        ("7. 双通道: query 裸JWT + header Bearer JWT",
         f"{BASE}?access_token={token}", {"Authorization": f"Bearer {token}"}),
    ]

    for name, uri, headers in variants:
        await try_variant(name, uri, headers)
        await asyncio.sleep(0.3)

    print("\n━━━━━━ 结论 ━━━━━━")
    print("看上面哪一条出现 🎉，那就是服务端接受的鉴权契约。")
    print("据此改 client/lib/network/ws_config.dart 的")
    print("  authMode / authQueryKey / authHeaderPrefix 三行即可。")


if __name__ == "__main__":
    asyncio.run(main())
