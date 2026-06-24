#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WS 通知发送侧探针（单场景 · 手动跑 · 日志可直接发后端）

风格参照 wstest/send_as_12dev.py：打印触发动作的【完整 HTTP 请求 + 服务端响应】，
额外自动连接收方 WS、报告是否收到对应 event_type 帧。整段输出复制即可发给后端排障。

约定:
  14dev = 触发方(actor)     12dev = 接收方(拥有目标帖/回复 + 收通知)
  → 你的真机 app 登录 12dev 即可同步观察 flutter run 里的 [WS] 日志（脚本也会自动连 12dev WS 复核）

用法（6 条命令，每条对应一个场景）:
  python3 wstest/send_notify.py post_like
  python3 wstest/send_notify.py post_reply
  python3 wstest/send_notify.py post_repost
  python3 wstest/send_notify.py post_quote
  python3 wstest/send_notify.py reply_like
  python3 wstest/send_notify.py reply_mention

注意: 含 dev 账号密码，本地 wstest/ 不提交 git。
"""
import asyncio
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import websockets

BASE = "http://192.168.1.27:8005"
WS_BASE = "ws://192.168.1.27:8005/websocket/ws"
ACTOR = "14dev"       # 触发方
RECIPIENT = "12dev"   # 接收方
PASSWORD = "123456"

# 通知列表里 type 整数 → 名字 + 期望 object_type（用于精确判定是否真建了对应通知）
TYPE_NAME = {1: "like", 2: "reply", 4: "mention", 5: "repost", 6: "quote"}


# ── HTTP 工具 ───────────────────────────────────────────────
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


def login(username):
    st, resp = http("POST", "auth/username/signin",
                    {"username": username, "password": PASSWORD})
    data = (resp or {}).get("data", {}) if isinstance(resp, dict) else {}
    token = data.get("access_token")
    uid = data.get("user_id") or data.get("id")
    print(f"[login {username}] HTTP {st}  uid={uid}  token={'OK' if token else 'MISSING'}")
    return token, uid


def me(token):
    st, resp = http("GET", "user/me", token=token)
    return (resp or {}).get("data", {}) if isinstance(resp, dict) else {}


# ── 接收方建目标 / 触发方动作 ───────────────────────────────
def _ts():
    """当前时分秒（HH:MM:SS），用于帖子/回复内容拼接，便于多次跑脚本时区分。"""
    return time.strftime("%H:%M:%S", time.localtime())


def create_post(token, content, **extra):
    st, resp = http("POST", "post/create", token=token, body={"content": content, **extra})
    data = (resp or {}).get("data", {}) if isinstance(resp, dict) else {}
    return data.get("id") or data.get("post_id"), st, resp


def create_reply(token, post_id, content, mentioned=None):
    body = {"post_id": post_id, "content": content}
    if mentioned:
        body["mentioned_user_ids"] = mentioned
    st, resp = http("POST", "post/reply", token=token, body=body)
    data = (resp or {}).get("data", {}) if isinstance(resp, dict) else {}
    return data.get("id") or data.get("reply_id"), st, resp


def get_unread(token):
    st, resp = http("GET", "notification/notifications/unread-count", token=token)
    try:
        return int((resp or {}).get("data")) if isinstance(resp, dict) else None
    except Exception:
        return None


def get_notifications(token, size=8):
    st, resp = http("GET", "notification/notifications", token=token)
    d = (resp or {}).get("data") if isinstance(resp, dict) else None
    if isinstance(d, dict):
        return d.get("items") or []
    if isinstance(d, list):
        return d
    return []


# ── WS 监听 ─────────────────────────────────────────────────
def _parse_frame(frame_text):
    """解析帧为 dict。无法解析时返回 None。"""
    try:
        j = json.loads(frame_text)
    except Exception:
        return None
    return j if isinstance(j, dict) else None


def _etype(frame_text):
    """从帧文本提取归一化 event_type（镜像客户端 _onData 取值 + toLowerCase）。"""
    j = _parse_frame(frame_text)
    if j is None:
        return None
    raw = j.get("event_type") or j.get("type") or j.get("event")
    if raw is None and isinstance(j.get("data"), dict):
        raw = j["data"].get("event_type") or j["data"].get("type")
    return str(raw).lower() if raw else None


# 通知类事件的关键字段（与 docs/event-types-doc.md 对齐）
_NOTIFY_FIELDS = ("event_type", "actor_id", "actor_name", "post_id",
                  "reply_id", "user_id", "community_id", "notification_id")


def _summarize(frame):
    """从帧里提取关键字段，便于排障打印。frame 可能是字符串或 dict。"""
    if isinstance(frame, dict):
        j = frame
    else:
        j = _parse_frame(frame)
    if j is None:
        return f"raw={str(frame)[:120]!r}"
    # data 嵌套兜底（部分服务端把字段塞在 data 里）
    flat = {k: j.get(k) for k in _NOTIFY_FIELDS}
    data = j.get("data")
    if isinstance(data, dict):
        for k in _NOTIFY_FIELDS:
            if flat[k] in (None, "") and data.get(k) is not None:
                flat[k] = data.get(k)
    # 只输出非空的字段
    parts = [f"{k}={flat[k]!r}" for k in _NOTIFY_FIELDS if flat[k] not in (None, "")]
    return ", ".join(parts) if parts else f"raw={json.dumps(j, ensure_ascii=False)[:200]}"


async def watch_ws(token, want, seconds=10):
    url = f"{WS_BASE}?{urllib.parse.urlencode({'access_token': f'Bearer {token}'})}"
    matched, allf = [], []
    want = [w.lower() for w in want]
    deadline = time.monotonic() + seconds
    try:
        async with websockets.connect(
            url, additional_headers={"Authorization": f"Bearer {token}"}, open_timeout=10,
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


# ── 场景配置 ────────────────────────────────────────────────
# 每个触发器返回 (method, path, body, 说明)，用于打印完整请求 + 执行。
def _t_like(pid, rid):
    return ("POST", f"post/like/{pid}", None, f"点赞帖子 post_id={pid}")


def _t_reply(pid, rid):
    return ("POST", "post/reply",
            {"post_id": pid, "content": f"probe reply from 14dev {_ts()}"},
            f"回复帖子 post_id={pid}")


def _t_repost(pid, rid):
    return ("POST", f"post/repost/{pid}", {"repost_type": 1}, f"转发帖子 post_id={pid}")


def _t_quote(pid, rid):
    return ("POST", "post/create",
            {"content": f"probe quote from 14dev {_ts()}", "quote_post_id": pid},
            f"引用发帖 quote_post_id={pid}")


def _t_like_reply(pid, rid):
    return ("POST", f"post/reply/like/{rid}", None, f"点赞回复 reply_id={rid}")


def _t_reply_mention(pid, rid, recipient_id):
    return ("POST", "post/reply",
            {"post_id": pid, "content": f"@{RECIPIENT} probe reply mention {_ts()}",
             "mentioned_user_ids": [recipient_id]},
            f"回复帖子并 @ 接收方 post_id={pid} mentioned_user_ids=[{recipient_id}]")


SCENARIOS = {
    "post_like":     {"event": "post_like",     "need_reply": False, "trig": _t_like,
                      "etype": 1, "obj": "post",
                      "desc": "14dev 赞 12dev 的帖子 → 12dev 应收到 post_like"},
    "post_reply":    {"event": "post_reply",    "need_reply": False, "trig": _t_reply,
                      "etype": 2, "obj": "post",
                      "desc": "14dev 回复 12dev 的帖子 → 12dev 应收到 post_reply"},
    "post_repost":   {"event": "post_repost",   "need_reply": False, "trig": _t_repost,
                      "etype": 5, "obj": "post",
                      "desc": "14dev 转发 12dev 的帖子 → 12dev 应收到 post_repost"},
    "post_quote":    {"event": "post_quote",    "need_reply": False, "trig": _t_quote,
                      "etype": 6, "obj": "post",
                      "desc": "14dev 引用 12dev 的帖子 → 12dev 应收到 post_quote"},
    "reply_like":    {"event": "reply_like",    "need_reply": True,  "trig": _t_like_reply,
                      "etype": 1, "obj": "reply",
                      "desc": "14dev 赞 12dev 的回复 → 12dev 应收到 reply_like"},
    "reply_mention": {"event": "reply_mention", "need_reply": False, "trig": _t_reply_mention,
                      "etype": 4, "obj": "reply",
                      "desc": "14dev 在回复中 @ 12dev → 12dev 应收到 reply_mention"},
}


def _mask(token):
    return f"{token[:16]}…（已脱敏）" if token else "（无）"


async def run(scenario):
    cfg = SCENARIOS[scenario]
    bar = "═" * 64
    print(f"\n{bar}\n 场景: {scenario}\n {cfg['desc']}\n 期望 WS 事件: {cfg['event']}\n{bar}")

    # 1. 登录两账号
    tokenA, _ = login(ACTOR)
    tokenB, _ = login(RECIPIENT)
    if not tokenA or not tokenB:
        print("❌ 登录失败，终止。")
        return
    meB = me(tokenB)
    recipient_id = meB.get("id") or meB.get("user_id")
    print(f"→ {ACTOR}=触发方   {RECIPIENT}=接收方 id={recipient_id}")

    # 2. 接收方建目标（全新，规避「已点赞」去重）
    pid, st, resp = create_post(tokenB, f"target-{scenario} {_ts()}")
    if not pid:
        print(f"❌ 接收方建帖失败 HTTP {st}: {json.dumps(resp, ensure_ascii=False)[:400]}")
        return
    rid = None
    if cfg["need_reply"]:
        rid, st2, resp2 = create_reply(tokenB, pid, f"12dev 自己的回复 {_ts()}")
        print(f"[接收方建目标] post_id={pid}  reply_id={rid}")
        if not rid:
            print(f"❌ 接收方建回复失败 HTTP {st2}: {json.dumps(resp2, ensure_ascii=False)[:400]}")
            return
    else:
        print(f"[接收方建目标] post_id={pid}")

    # 3. 未读基线 + 连 WS 监听
    before = get_unread(tokenB)
    print(f"[接收方未读基线] unread={before}")
    print(f"[接收方 WS] 连接监听 {cfg['event']} …")
    task = asyncio.ensure_future(watch_ws(tokenB, [cfg["event"]], seconds=12))
    await asyncio.sleep(2.5)  # 等 WS 握手 + 鉴权

    # 4. 触发方执行动作 —— 打印完整 HTTP 请求
    trig = cfg["trig"](pid, rid, recipient_id) if scenario == "reply_mention" \
        else cfg["trig"](pid, rid)
    method, path, body, note = trig
    print("━" * 64)
    print(f">>> 触发方 {ACTOR} 执行动作: {note}")
    print(f">>> 完整 HTTP 请求:")
    print(f"    {method} {BASE}/{path}")
    print(f"    Headers:")
    print(f"      Content-Type: application/json")
    print(f"      Authorization: Bearer {_mask(tokenA)}")
    print(f"    Body: {json.dumps(body, ensure_ascii=False) if body else '（无）'}")
    print("━" * 64)

    st, resp = http(method, path, body=body, token=tokenA)
    print(f"[trigger] HTTP {st}")
    print(f"  响应 = {json.dumps(resp, ensure_ascii=False)[:500]}")
    await asyncio.sleep(2.0)  # 等服务端建通知 + 推送

    # 5. 未读对账
    after = get_unread(tokenB)
    delta = (after - before) if (isinstance(before, int) and isinstance(after, int)) else "?"
    print(f"[接收方未读] {before} → {after}   Δ={delta}"
          + ("  ← 服务端建了通知" if isinstance(delta, int) and delta > 0 else ""))

    # 6. 通知列表核查（区分 Δ 到底是不是本场景的通知，避免被联动事件误导）
    items = get_notifications(tokenB)
    list_hit = any(
        it.get("type") == cfg["etype"] and
        (cfg["obj"] is None or it.get("object_type") == cfg["obj"])
        for it in items[:8]
    )
    print(f"[接收方通知列表] 是否有 {cfg['event']} 对应条目"
          f"(type={cfg['etype']}/{TYPE_NAME.get(cfg['etype'])}, obj={cfg['obj']}): "
          + ("✓ 有" if list_hit else "✗ 无"))

    # 7. WS 结果
    matched, allf = await task
    print(f"[接收方 WS] 收到总帧数={len(allf)}")
    for f in allf[:8]:
        print(f"    · {_summarize(f)}")
    ws_hit = len(matched) > 0
    print(f"[接收方 WS] 期望 {cfg['event']} 帧: "
          + ("✓ 收到" if ws_hit else "✗ 未收到"))

    # 8. 结论
    print(bar)
    if not isinstance(delta, int):
        verdict = "❓ 未读查询失败，无法判定"
    elif delta == 0:
        verdict = f"❌ 服务端没建通知 (Δ=0) —— 触发动作字段未被识别或未实现该通知"
    elif not list_hit:
        verdict = (f"⚠️ 未建【{cfg['event']}】通知：未读 Δ={delta} 但列表无对应条目"
                   f"（Δ 来自联动事件，如回复动作自带的 post_reply）")
    elif not ws_hit:
        verdict = (f"⚠️ 服务端建了【{cfg['event']}】通知(列表有/Δ={delta}) "
                   f"但【没推 WS 帧】—— post_mention 同款 bug")
    else:
        verdict = f"✅ 收到 WS {cfg['event']} 帧 —— 接收链路通了"
    print(f" 结论: {verdict}")
    print(f" ── 以上日志可直接复制发给后端排障 ──")
    print(f" （真机 app 登录 {RECIPIENT} 时，同步看 flutter run 是否出现 "
          f"[WS] event type={cfg['event']}）")
    print(bar)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in SCENARIOS:
        print("用法: python3 wstest/send_notify.py <scenario>")
        print("  scenario: " + " | ".join(SCENARIOS.keys()))
        sys.exit(1)
    asyncio.run(run(sys.argv[1]))


if __name__ == "__main__":
    main()
