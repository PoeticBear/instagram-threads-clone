#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WS 通知接收验证探针 —— 覆盖 6 个场景（post_mention 已跑通，除外）

对每个场景自动执行四步：
  ① 12dev 自建目标（帖 / 回复）          —— 保证每次都是全新 target，规避「已点赞」去重
  ② 12dev 连 WS 监听
  ③ 14dev 触发动作
  ④ 判定三件套：未读增量 / 通知列表条目 / WS 实时帧

判定（对照 docs/ws-notification-scenario-guide.md §6.3 矩阵）：
  未读 Δ>0 + 列表有 + WS 有帧  → ✅ 客户端能正常接收
  未读 Δ>0 + 列表有 + 无帧     → ⚠️ 服务端建了通知但不推 WS（post_mention 当初就是这个坑）
  未读 Δ=0                     → ❌ 服务端没建通知（触发 / 接口字段问题）

注意：脚本含 dev 账号密码，本地 wstest/ 不提交 git。
"""
import asyncio
import json
import time
import urllib.error
import urllib.parse
import urllib.request

import websockets

BASE = "http://192.168.1.27:8005"
WS_BASE = "ws://192.168.1.27:8005/websocket/ws"
USER_A = "14dev"   # actor（触发方）
USER_B = "12dev"   # recipient（接收方）
PASSWORD = "123456"

# notification HTTP 列表里 type 整数 → 名字（镜像客户端 _typeIntToString）
TYPE_NAME = {1: "like", 2: "reply", 3: "follow", 4: "mention", 5: "repost", 6: "quote"}


# ── HTTP 工具 ───────────────────────────────────────────────
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


def login(username):
    st, resp = http("POST", "auth/username/signin",
                    {"username": username, "password": PASSWORD})
    data = (resp or {}).get("data", {}) if isinstance(resp, dict) else {}
    token = data.get("access_token")
    uid = data.get("user_id") or data.get("id")
    print(f"[login {username}] HTTP {st}  uid={uid}  token={'ok' if token else 'MISSING'}")
    return token, uid


def me(token):
    st, resp = http("GET", "user/me", token=token)
    return (resp or {}).get("data", {}) if isinstance(resp, dict) else {}


# ── 触发动作 ────────────────────────────────────────────────
def create_post(token, content, **extra):
    body = {"content": content, **extra}
    st, resp = http("POST", "post/create", token=token, body=body)
    data = (resp or {}).get("data", {}) if isinstance(resp, dict) else {}
    pid = data.get("id") or data.get("post_id")
    return pid, st, resp


def create_reply(token, post_id, content, mentioned=None):
    body = {"post_id": post_id, "content": content}
    if mentioned:
        body["mentioned_user_ids"] = mentioned
    st, resp = http("POST", "post/reply", token=token, body=body)
    data = (resp or {}).get("data", {}) if isinstance(resp, dict) else {}
    rid = data.get("id") or data.get("reply_id")
    return rid, st, resp


def like_post(token, post_id):
    return http("POST", f"post/like/{post_id}", token=token)


def like_reply(token, reply_id):
    return http("POST", f"post/reply/like/{reply_id}", token=token)


def repost(token, post_id):
    return http("POST", f"post/repost/{post_id}", token=token, body={"repost_type": 1})


def quote_post(token, quote_post_id, content):
    return http("POST", "post/create", token=token,
                body={"content": content, "quote_post_id": quote_post_id})


# ── 接收侧查询 ──────────────────────────────────────────────
def get_unread(token):
    st, resp = http("GET", "notification/notifications/unread-count", token=token)
    d = (resp or {}).get("data") if isinstance(resp, dict) else None
    try:
        return int(d)
    except Exception:
        return None


def get_notifications(token, size=8):
    st, resp = http("GET", "notification/notifications", token=token,
                    query={"page": 1, "size": size})
    d = (resp or {}).get("data") if isinstance(resp, dict) else None
    if isinstance(d, dict):
        return d.get("items") or []
    if isinstance(d, list):
        return d
    return []


def _etype(frame_text):
    """从帧文本提取归一化 event_type（镜像客户端 _onData 的多候选取值 + toLowerCase）。"""
    try:
        j = json.loads(frame_text)
    except Exception:
        return None
    if not isinstance(j, dict):
        return None
    raw = j.get("event_type") or j.get("type") or j.get("event")
    if raw is None and isinstance(j.get("data"), dict):
        raw = j["data"].get("event_type") or j["data"].get("type")
    return str(raw).lower() if raw else None


async def watch_ws(token, want, seconds=9):
    """连 WS 监听 seconds 秒；返回 (matched:[命中的目标事件], all_frames:[所有帧文本])。"""
    url = f"{WS_BASE}?{urllib.parse.urlencode({'access_token': f'Bearer {token}'})}"
    matched, allf = [], []
    want = [w.lower() for w in want]
    deadline = time.monotonic() + seconds
    try:
        async with websockets.connect(
            url,
            additional_headers={"Authorization": f"Bearer {token}"},
            open_timeout=10,
        ) as ws:
            try:
                await ws.send("ping")
            except Exception:
                pass
            while time.monotonic() < deadline:
                remaining = max(0.5, deadline - time.monotonic())
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=remaining)
                except asyncio.TimeoutError:
                    break
                allf.append(msg)
                t = _etype(msg)
                if t and t in want:
                    matched.append(t)
    except Exception as e:
        allf.append(f"[WS ERROR] {type(e).__name__}: {e}")
    return matched, allf


# ── 单场景执行器 ────────────────────────────────────────────
async def run_scenario(name, tokenA, tokenB, uidB, setup, trigger,
                       want_events, expect_type=None, expect_obj=None):
    print(f"\n{'=' * 72}\n▶ 场景: {name}   期望 WS 事件: {want_events}\n{'=' * 72}")
    # ① 12dev 自建目标
    try:
        target = setup(tokenB)
    except Exception as e:
        print(f"  ❌ setup 抛异常: {e}")
        return {"name": name, "verdict": "❌ SETUP 异常", "delta": "-", "list": False, "ws": False}
    pid = target.get("post_id")
    rid = target.get("reply_id")
    if not pid:
        print(f"  ❌ setup 未拿到 post_id: {target}")
        return {"name": name, "verdict": "❌ SETUP 失败", "delta": "-", "list": False, "ws": False}
    print(f"  目标: post_id={pid}" + (f"  reply_id={rid}" if rid else ""))

    # ② baseline 未读
    before = get_unread(tokenB)
    # ③ WS 监听 + ④ 14dev 触发（边监听边触发）
    task = asyncio.ensure_future(watch_ws(tokenB, want_events, seconds=10))
    await asyncio.sleep(2.5)  # 等 WS 握手 + 鉴权
    tst, tresp = trigger(tokenA, pid, rid)
    print(f"  [trigger] HTTP {tst}")
    await asyncio.sleep(2.0)  # 等服务端建通知 + 推送

    # HTTP 对账
    after = get_unread(tokenB)
    delta = (after - before) if (isinstance(before, int) and isinstance(after, int)) else "?"
    items = get_notifications(tokenB)

    matched, allf = await task

    # 列表命中判定（reply 场景用 object_type 区分 post/reply）
    list_hit = False
    for it in items[:8]:
        if expect_type is not None and it.get("type") == expect_type:
            if expect_obj is None or it.get("object_type") == expect_obj:
                list_hit = True
                break

    ws_hit = len(matched) > 0

    # 裁定
    if not isinstance(delta, int):
        verd = "❓ 未读查询失败"
    elif delta == 0:
        verd = "❌ 服务端没建通知 (Δ=0)"
    elif not ws_hit:
        verd = "⚠️ 建了通知但不推 WS (Δ>0 无帧)"
    else:
        verd = "✅ 完全通过 (收到 WS 帧)"

    print(f"  未读: {before} → {after}   Δ={delta}")
    print(f"  列表命中(type={expect_type}/{TYPE_NAME.get(expect_type)}, obj={expect_obj}): {list_hit}")
    print(f"  WS 命中: {matched if matched else '无'}   收到总帧数={len(allf)}")
    for f in allf[:6]:
        print(f"    · {str(f)[:180]}")

    return {"name": name, "verdict": verd, "delta": delta,
            "list": list_hit, "ws": ws_hit, "matched": matched}


async def main():
    print("=" * 72)
    print("STEP 1: 登录两个账号")
    print("=" * 72)
    tokenA, uidA = login(USER_A)
    tokenB, uidB = login(USER_B)
    if not tokenA or not tokenB:
        print("❌ 登录失败，终止。")
        return
    meA = me(tokenA)
    meB = me(tokenB)
    uidA = meA.get("id") or meA.get("user_id") or uidA
    uidB = meB.get("id") or meB.get("user_id") or uidB
    print(f"→ 触发方 {USER_A} id={uidA}   接收方 {USER_B} id={uidB}")

    # 场景表：setup(tokenB)->{post_id,reply_id?}  trigger(tokenA,pid,rid)->(status,resp)
    scenarios = [
        {
            "name": "post_like",
            "want": ["post_like"], "expect_type": 1, "expect_obj": "post",
            "setup": lambda tB: {"post_id": create_post(tB, "probe-target-post_like")[0]},
            "trigger": lambda tA, pid, rid: like_post(tA, pid),
        },
        {
            "name": "post_reply",
            "want": ["post_reply"], "expect_type": 2, "expect_obj": "post",
            "setup": lambda tB: {"post_id": create_post(tB, "probe-target-post_reply")[0]},
            "trigger": lambda tA, pid, rid: create_reply(tA, pid, "probe reply from 14dev")[1:],
        },
        {
            "name": "post_repost",
            "want": ["post_repost"], "expect_type": 5, "expect_obj": "post",
            "setup": lambda tB: {"post_id": create_post(tB, "probe-target-post_repost")[0]},
            "trigger": lambda tA, pid, rid: repost(tA, pid),
        },
        {
            "name": "post_quote",
            "want": ["post_quote"], "expect_type": 6, "expect_obj": "post",
            "setup": lambda tB: {"post_id": create_post(tB, "probe-target-post_quote")[0]},
            "trigger": lambda tA, pid, rid: quote_post(tA, pid, "probe quote from 14dev"),
        },
        {
            "name": "reply_like",
            "want": ["reply_like"], "expect_type": 1, "expect_obj": "reply",
            "setup": lambda tB: _setup_reply_target(tB),
            "trigger": lambda tA, pid, rid: like_reply(tA, rid),
        },
        {
            "name": "reply_mention",
            "want": ["reply_mention"], "expect_type": 4, "expect_obj": "reply",
            "setup": lambda tB: {"post_id": create_post(tB, "probe-target-reply_mention")[0]},
            # 14dev 在回复中 @ 12dev（uidB）—— 探针侧带 mentioned_user_ids，验证服务端是否接受 + 下推
            "trigger": lambda tA, pid, rid: create_reply(
                tA, pid, f"@{USER_B} probe reply mention", mentioned=[uidB])[1:],
        },
    ]

    results = []
    for sc in scenarios:
        r = await run_scenario(
            sc["name"], tokenA, tokenB, uidB,
            sc["setup"], sc["trigger"], sc["want"],
            sc.get("expect_type"), sc.get("expect_obj"),
        )
        results.append(r)

    # 汇总
    print("\n" + "=" * 72)
    print("汇总（接收链路验证结果）")
    print("=" * 72)
    print(f"{'场景':<16}{'未读Δ':<8}{'列表':<6}{'WS帧':<6}{'判定'}")
    print("-" * 72)
    for r in results:
        print(f"{r['name']:<16}{str(r['delta']):<8}"
              f"{'✓' if r['list'] else '✗':<6}"
              f"{'✓' if r['ws'] else '✗':<6}{r['verdict']}")
    print("=" * 72)
    ok = sum(1 for r in results if r["verdict"].startswith("✅"))
    print(f"完全通过: {ok}/{len(results)}")


def _setup_reply_target(tokenB):
    """12dev 建帖 + 建回复，返回 {post_id, reply_id}（供 reply_like）。"""
    pid, _, _ = create_post(tokenB, "probe-target-reply_like")
    rid, _, _ = create_reply(tokenB, pid, "12dev 自己的回复")
    return {"post_id": pid, "reply_id": rid}


if __name__ == "__main__":
    asyncio.run(main())
