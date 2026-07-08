sihangpeng@SihangdeMac-mini instagram-threads-clone % python3 wstest/send_notify.py post_like    

════════════════════════════════════════════════════════════════
 场景: post_like
 14dev 赞 12dev 的帖子 → 12dev 应收到 post_like
 期望 WS 事件: post_like
════════════════════════════════════════════════════════════════
[login 14dev] HTTP 200  uid=1000382  token=OK
[login 12dev] HTTP 200  uid=1000383  token=OK
→ 14dev=触发方   12dev=接收方 id=1000383
[接收方建目标] post_id=2000145
[接收方未读基线] unread=34
[接收方 WS] 连接监听 post_like …
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>>> 触发方 14dev 执行动作: 点赞帖子 post_id=2000145
>>> 完整 HTTP 请求:
    POST http://192.168.1.27:8005/post/like/2000145
    Headers:
      Content-Type: application/json
      Authorization: Bearer eyJhbGciOiJIUzI1…（已脱敏）
    Body: （无）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[trigger] HTTP 200
  响应 = {"code": 0, "msg": "success", "data": {}}
[接收方未读] 34 → 35   Δ=1  ← 服务端建了通知
[接收方通知列表] 是否有 post_like 对应条目(type=1/like, obj=post): ✓ 有
[接收方 WS] 收到总帧数=1
    · raw='pong'
[接收方 WS] 期望 post_like 帧: ✗ 未收到
════════════════════════════════════════════════════════════════
 结论: ⚠️ 服务端建了【post_like】通知(列表有/Δ=1) 但【没推 WS 帧】—— post_mention 同款 bug
 ── 以上日志可直接复制发给后端排障 ──
 （真机 app 登录 12dev 时，同步看 flutter run 是否出现 [WS] event type=post_like）
════════════════════════════════════════════════════════════════
sihangpeng@SihangdeMac-mini instagram-threads-clone % python3 wstest/send_notify.py post_reply   

════════════════════════════════════════════════════════════════
 场景: post_reply
 14dev 回复 12dev 的帖子 → 12dev 应收到 post_reply
 期望 WS 事件: post_reply
════════════════════════════════════════════════════════════════
[login 14dev] HTTP 200  uid=1000382  token=OK
[login 12dev] HTTP 200  uid=1000383  token=OK
→ 14dev=触发方   12dev=接收方 id=1000383
[接收方建目标] post_id=2000148
[接收方未读基线] unread=35
[接收方 WS] 连接监听 post_reply …
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>>> 触发方 14dev 执行动作: 回复帖子 post_id=2000148
>>> 完整 HTTP 请求:
    POST http://192.168.1.27:8005/post/reply
    Headers:
      Content-Type: application/json
      Authorization: Bearer eyJhbGciOiJIUzI1…（已脱敏）
    Body: {"post_id": 2000148, "content": "probe reply from 14dev 15:39:00"}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[trigger] HTTP 200
  响应 = {"code": 0, "msg": "success", "data": {"id": 2000149, "user": {"id": 1000382, "username": "14dev", "avatar": "https://cdn.tweetcaht.com/static/default/avatar.png", "display_name": "14dev", "is_verified": 0}, "content": "probe reply from 14dev 15:39:00", "media_list": [], "is_private": false, "is_pinned": false, "likes_count": 0, "replies_count": 0, "is_edited": false, "edit_count": 0, "last_edit_time": null, "review_status": 1, "is_liked": false, "parent_id": null, "mentioned_users": "", "mentio
[接收方未读] 35 → 36   Δ=1  ← 服务端建了通知
[接收方通知列表] 是否有 post_reply 对应条目(type=2/reply, obj=post): ✓ 有
[接收方 WS] 收到总帧数=2
    · raw='pong'
    · event_type='reply_create', post_id=2000148, reply_id=2000149, user_id=1000382
[接收方 WS] 期望 post_reply 帧: ✗ 未收到
════════════════════════════════════════════════════════════════
 结论: ⚠️ 服务端建了【post_reply】通知(列表有/Δ=1) 但【没推 WS 帧】—— post_mention 同款 bug
 ── 以上日志可直接复制发给后端排障 ──
 （真机 app 登录 12dev 时，同步看 flutter run 是否出现 [WS] event type=post_reply）
════════════════════════════════════════════════════════════════
sihangpeng@SihangdeMac-mini instagram-threads-clone % python3 wstest/send_notify.py post_repost  

════════════════════════════════════════════════════════════════
 场景: post_repost
 14dev 转发 12dev 的帖子 → 12dev 应收到 post_repost
 期望 WS 事件: post_repost
════════════════════════════════════════════════════════════════
[login 14dev] HTTP 200  uid=1000382  token=OK
[login 12dev] HTTP 200  uid=1000383  token=OK
→ 14dev=触发方   12dev=接收方 id=1000383
[接收方建目标] post_id=2000151
[接收方未读基线] unread=36
[接收方 WS] 连接监听 post_repost …
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>>> 触发方 14dev 执行动作: 转发帖子 post_id=2000151
>>> 完整 HTTP 请求:
    POST http://192.168.1.27:8005/post/repost/2000151
    Headers:
      Content-Type: application/json
      Authorization: Bearer eyJhbGciOiJIUzI1…（已脱敏）
    Body: {"repost_type": 1}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[trigger] HTTP 200
  响应 = {"code": 0, "msg": "success", "data": {}}
[接收方未读] 36 → 37   Δ=1  ← 服务端建了通知
[接收方通知列表] 是否有 post_repost 对应条目(type=5/repost, obj=post): ✓ 有
[接收方 WS] 收到总帧数=1
    · raw='pong'
[接收方 WS] 期望 post_repost 帧: ✗ 未收到
════════════════════════════════════════════════════════════════
 结论: ⚠️ 服务端建了【post_repost】通知(列表有/Δ=1) 但【没推 WS 帧】—— post_mention 同款 bug
 ── 以上日志可直接复制发给后端排障 ──
 （真机 app 登录 12dev 时，同步看 flutter run 是否出现 [WS] event type=post_repost）
════════════════════════════════════════════════════════════════
sihangpeng@SihangdeMac-mini instagram-threads-clone % python3 wstest/send_notify.py reply_like   

════════════════════════════════════════════════════════════════
 场景: reply_like
 14dev 赞 12dev 的回复 → 12dev 应收到 reply_like
 期望 WS 事件: reply_like
════════════════════════════════════════════════════════════════
[login 14dev] HTTP 200  uid=1000382  token=OK
[login 12dev] HTTP 200  uid=1000383  token=OK
→ 14dev=触发方   12dev=接收方 id=1000383
[接收方建目标] post_id=2000154  reply_id=2000155
[接收方未读基线] unread=37
[接收方 WS] 连接监听 reply_like …
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>>> 触发方 14dev 执行动作: 点赞回复 reply_id=2000155
>>> 完整 HTTP 请求:
    POST http://192.168.1.27:8005/post/reply/like/2000155
    Headers:
      Content-Type: application/json
      Authorization: Bearer eyJhbGciOiJIUzI1…（已脱敏）
    Body: （无）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[trigger] HTTP 200
  响应 = {"code": 0, "msg": "success", "data": {}}
[接收方未读] 37 → 38   Δ=1  ← 服务端建了通知
[接收方通知列表] 是否有 reply_like 对应条目(type=1/like, obj=reply): ✓ 有
[接收方 WS] 收到总帧数=1
    · raw='pong'
[接收方 WS] 期望 reply_like 帧: ✗ 未收到
════════════════════════════════════════════════════════════════
 结论: ⚠️ 服务端建了【reply_like】通知(列表有/Δ=1) 但【没推 WS 帧】—— post_mention 同款 bug
 ── 以上日志可直接复制发给后端排障 ──
 （真机 app 登录 12dev 时，同步看 flutter run 是否出现 [WS] event type=reply_like）
════════════════════════════════════════════════════════════════
sihangpeng@SihangdeMac-mini instagram-threads-clone % python3 wstest/send_notify.py post_quote   

════════════════════════════════════════════════════════════════
 场景: post_quote
 14dev 引用 12dev 的帖子 → 12dev 应收到 post_quote
 期望 WS 事件: post_quote
════════════════════════════════════════════════════════════════
[login 14dev] HTTP 200  uid=1000382  token=OK
[login 12dev] HTTP 200  uid=1000383  token=OK
→ 14dev=触发方   12dev=接收方 id=1000383
[接收方建目标] post_id=2000158
[接收方未读基线] unread=38
[接收方 WS] 连接监听 post_quote …
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>>> 触发方 14dev 执行动作: 引用发帖 quote_post_id=2000158
>>> 完整 HTTP 请求:
    POST http://192.168.1.27:8005/post/create
    Headers:
      Content-Type: application/json
      Authorization: Bearer eyJhbGciOiJIUzI1…（已脱敏）
    Body: {"content": "probe quote from 14dev 15:40:02", "quote_post_id": 2000158}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[trigger] HTTP 200
  响应 = {"code": 0, "msg": "success", "data": {"id": 2000159, "user": {"id": 1000382, "username": "14dev", "avatar": "https://cdn.tweetcaht.com/static/default/avatar.png", "display_name": "14dev", "is_verified": 0}, "content": "probe quote from 14dev 15:40:02", "media_list": [], "media_count": 0, "content_character_count": 31, "content_remaining_chars": 469, "reply_type": 1, "need_review": false, "is_guest_post": 0, "is_archived": 0, "location": "", "latitude": null, "longitude": null, "quote_post_id": 
[接收方未读] 38 → 38   Δ=0
[接收方通知列表] 是否有 post_quote 对应条目(type=6/quote, obj=post): ✗ 无
[接收方 WS] 收到总帧数=1
    · raw='pong'
[接收方 WS] 期望 post_quote 帧: ✗ 未收到
════════════════════════════════════════════════════════════════
 结论: ❌ 服务端没建通知 (Δ=0) —— 触发动作字段未被识别或未实现该通知
 ── 以上日志可直接复制发给后端排障 ──
 （真机 app 登录 12dev 时，同步看 flutter run 是否出现 [WS] event type=post_quote）
════════════════════════════════════════════════════════════════
sihangpeng@SihangdeMac-mini instagram-threads-clone % python3 wstest/send_notify.py reply_mention

════════════════════════════════════════════════════════════════
 场景: reply_mention
 14dev 在回复中 @ 12dev → 12dev 应收到 reply_mention
 期望 WS 事件: reply_mention
════════════════════════════════════════════════════════════════
[login 14dev] HTTP 200  uid=1000382  token=OK
[login 12dev] HTTP 200  uid=1000383  token=OK
→ 14dev=触发方   12dev=接收方 id=1000383
[接收方建目标] post_id=2000160
[接收方未读基线] unread=38
[接收方 WS] 连接监听 reply_mention …
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>>> 触发方 14dev 执行动作: 回复帖子并 @ 接收方 post_id=2000160 mentioned_user_ids=[1000383]
>>> 完整 HTTP 请求:
    POST http://192.168.1.27:8005/post/reply
    Headers:
      Content-Type: application/json
      Authorization: Bearer eyJhbGciOiJIUzI1…（已脱敏）
    Body: {"post_id": 2000160, "content": "@12dev probe reply mention 15:40:21", "mentioned_user_ids": [1000383]}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[trigger] HTTP 200
  响应 = {"code": 0, "msg": "success", "data": {"id": 2000161, "user": {"id": 1000382, "username": "14dev", "avatar": "https://cdn.tweetcaht.com/static/default/avatar.png", "display_name": "14dev", "is_verified": 0}, "content": "@12dev probe reply mention 15:40:21", "media_list": [], "is_private": false, "is_pinned": false, "likes_count": 0, "replies_count": 0, "is_edited": false, "edit_count": 0, "last_edit_time": null, "review_status": 1, "is_liked": false, "parent_id": null, "mentioned_users": "100038
[接收方未读] 38 → 39   Δ=1  ← 服务端建了通知
[接收方通知列表] 是否有 reply_mention 对应条目(type=4/mention, obj=reply): ✗ 无
[接收方 WS] 收到总帧数=2
    · raw='pong'
    · event_type='reply_create', post_id=2000160, reply_id=2000161, user_id=1000382
[接收方 WS] 期望 reply_mention 帧: ✗ 未收到
════════════════════════════════════════════════════════════════
 结论: ⚠️ 未建【reply_mention】通知：未读 Δ=1 但列表无对应条目（Δ 来自联动事件，如回复动作自带的 post_reply）
 ── 以上日志可直接复制发给后端排障 ──
 （真机 app 登录 12dev 时，同步看 flutter run 是否出现 [WS] event type=reply_mention）
════════════════════════════════════════════════════════════════
