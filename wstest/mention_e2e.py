#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mention → 红点 端到端探针（脱离 Flutter 客户端）

复刻这条链路，逐跳打印，定位断点：
  14dev 发帖 "@12dev 你好" + mentioned_user_ids=[12devId]
   └─▶ 服务端是否: (a) 接受 mention  (b) 给 12dev 建通知  (c) 实时推 WS post_mention

判定矩阵:
  unread-count 增量=0 且 通知列表无 mention → 服务端没建 mention 通知（断在 ④ 检测）
  unread-count 增量>0 / 列表有 mention，但 WS 没收到 post_mention → 断在 WS 推送 ⑤
  三者都 OK 但 Flutter 仍不亮红点 → 断在客户端接收链路（需在 app 内查）
"""
import asyncio
import json
import time
import urllib.request
import urllib.parse
import urllib.error

import websockets

BASE = "http://192.168.1.27:8005"
WS_BASE = "ws://192.168.1.27:8005/websocket/ws"

USER_A = "14dev"   # 发送方
USER_B = "12dev"   # 被提及方
PASSWORD = "123456"


def http(method, path, body=None, token=None, query=None):
    url = f"{BASE}/{path}"
    if query:
        url += "?" + urllib.parse.urlencode(query)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw) if raw else None
        except Exception:
            return e.code, {"_raw": raw}
    except Exception as e:
        return None, {"_error": str(e)}


def login(username, password):
    status, resp = http("POST", "auth/username/signin",
                        {"username": username, "password": password})
    data = (resp or {}).get("data", {}) if isinstance(resp, dict) else {}
    token = data.get("access_token")
    uid = data.get("user_id") or data.get("id")
    print(f"[login {username}] HTTP {status}  uid={uid}")
    return token, uid


def me(token):
    status, resp = http("GET", "user/me", token=token)
    data = (resp or {}).get("data", {}) if isinstance(resp, dict) else {}
    print(f"[me] HTTP {status}  id={data.get('id') or data.get('user_id')}  "
          f"username={data.get('username')}")
    return data


def _delta(base, after):
    try:
        return int(after) - int(base)
    except Exception:
        return "?"


async def _watch(token, who, seconds=10):
    """连上 WS，观察 N 秒，打印收到的所有帧。"""
    url = f"{WS_BASE}?{urllib.parse.urlencode({'access_token': f'Bearer {token}'})}"
    print(f"[ws {who}] connecting ...")
    frames = []
    deadline = time.monotonic() + seconds
    try:
        async with websockets.connect(
            url,
            additional_headers={"Authorization": f"Bearer {token}"},
            open_timeout=10,
        ) as ws:
            print(f"[ws {who}] ✅ connected. listening {seconds}s ...")
            try:
                await ws.send("ping")
            except Exception:
                pass
            while time.monotonic() < deadline:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=remaining)
                    print(f"[ws {who}] 📩 FRAME: {msg}")
                    frames.append(msg)
                except asyncio.TimeoutError:
                    break
            print(f"[ws {who}] done. frames received = {len(frames)}")
    except Exception as e:
        print(f"[ws {who}] ❌ error: {type(e).__name__}: {e}")
    return frames


def main():
    print("=" * 70)
    print("STEP 1: 登录两个账号")
    print("=" * 70)
    tokenA, uidA = login(USER_A, PASSWORD)
    tokenB, uidB = login(USER_B, PASSWORD)
    if not tokenA or not tokenB:
        print("❌ 登录失败，终止。")
        return
    meA = me(tokenA)
    meB = me(tokenB)
    uidB_real = meB.get("id") or meB.get("user_id") or uidB
    print(f"\n→ 发送方 {USER_A} id={uidA}   被提及方 {USER_B} id={uidB_real}")

    print("\n" + "=" * 70)
    print("STEP 2: 12dev 发帖前的未读基线")
    print("=" * 70)
    st, resp = http("GET", "notification/notifications/unread-count", token=tokenB)
    baseline = (resp or {}).get("data") if isinstance(resp, dict) else None
    print(f"[unread-count before] HTTP {st}  unread={baseline}")

    print("\n" + "=" * 70)
    print(f"STEP 3: 14dev 发帖 '@{USER_B} 你好'  + mentioned_user_ids=[{uidB_real}]")
    print("=" * 70)
    st, resp = http("POST", "post/create", token=tokenA,
                    body={"content": f"@{USER_B} 你好",
                          "mentioned_user_ids": [uidB_real]})
    print(f"[createPost] HTTP {st}")
    print(f"  响应 = {json.dumps(resp, ensure_ascii=False)[:800]}")
    data = (resp or {}).get("data", {}) if isinstance(resp, dict) else {}
    echo = (data.get("mentioned_users"), data.get("mentioned_users_info"),
            data.get("mentioned_user_ids"))
    print(f"  服务端回带的 mention 字段={echo}")

    print("\n" + "=" * 70)
    print("STEP 4: 发帖后立刻 HTTP 查 12dev 通知（绕开 WS）")
    print("=" * 70)
    st, resp = http("GET", "notification/notifications/unread-count", token=tokenB)
    after = (resp or {}).get("data") if isinstance(resp, dict) else None
    print(f"[unread-count after] HTTP {st}  unread={after}  "
          f"(基线={baseline} → 增量={_delta(baseline, after)})")

    st, resp = http("GET", "notification/notifications",
                    token=tokenB, query={"page": 1, "size": 10})
    items = []
    if isinstance(resp, dict):
        d = resp.get("data")
        if isinstance(d, dict):
            items = d.get("items") or []
        elif isinstance(d, list):
            items = d
    print(f"[notifications list] HTTP {st}  count={len(items)}")
    for it in items[:6]:
        print(f"   - id={it.get('id')} type={it.get('type')} "
              f"read={it.get('is_read')} content={str(it.get('content'))[:40]!r} "
              f"sender={it.get('sender')}")

    print("\n" + "=" * 70)
    print("STEP 5: 12dev 先连 WS，3s 后 14dev 再发一帖，看实时推送")
    print("=" * 70)

    async def ws_then_post():
        task_ws = asyncio.ensure_future(_watch(tokenB, USER_B, seconds=12))
        await asyncio.sleep(3)
        print(f"   >> 14dev 再发一帖（带 mention）...")
        st2, resp2 = http("POST", "post/create", token=tokenA,
                          body={"content": f"@{USER_B} 实时测试",
                                "mentioned_user_ids": [uidB_real]})
        d2 = (resp2 or {}).get("data", {}) if isinstance(resp2, dict) else {}
        print(f"   >> [createPost#2] HTTP {st2}  post_id={d2.get('id')}")
        await task_ws

    asyncio.run(ws_then_post())

    print("\n" + "=" * 70)
    print("判定：对照开头的「判定矩阵」看 STEP 4 / STEP 5")
    print("=" * 70)


if __name__ == "__main__":
    main()
