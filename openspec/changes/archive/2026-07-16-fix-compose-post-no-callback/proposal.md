## Why

`ComposePost._submit`(client/lib/pages/composePost/post.dart:1042)发布成功后,清空本地状态(正文 / 媒体 / 投票 / 位置 / 定时),然后调用 `widget.onPostSuccess?.call()` 就返回 — **`onPostSuccess` 为 null 时整个方法 no-op**,路由不会自我 pop。同理 `_handleBack`(L462)走 `widget.onCancel?.call()`,缺省也 no-op。

这个契约隐含要求:**任何 `push` / `pushReplacement` 实例化 `ComposePost` 的调用方,都必须显式传 `onPostSuccess` 与 `onCancel` 回调**,否则用户发布后会卡在内容已清空的 `ComposePost` 上,只能手动返回。

调用方盘点(grep`ComposePost(`4 处):

| 入口 | 文件:行 | 当前状态 |
|---|---|---|
| 主 Tab Tab=2 | `client/lib/pages/home.dart:39` | ✅ 传 `onPostSuccess: () => setState(() => tab = 0)`,切回 Feed |
| Feed FAB | `client/lib/pages/feed/feed.dart:292` | ✅ 传 `onPostSuccess: () { getDataFromDatabase(); Navigator.of(context).pop(); }` |
| Edit 帖子 | `client/lib/widget/feedpost.dart:1249` | ❌ **缺回调**(pre-existing bug,代码注释"不需要 onPostSuccess 触发刷新"暴露了作者没意识到缺省的 no-op 语义) |
| 写文字 → 确认(change-text-note-handoff 引入) | `client/lib/pages/textNote/text_note_page.dart:173` | ❌ **缺回调**(随 `change-text-note-handoff` 引入,因移除 `_publish` 中原有的 `Navigator.pop(true)` 后未补新回调) |

后两条都已经在本 change 中修好(走 `Navigator.of(routeContext).pop()`)。

## What Changes

- 修改 `client/lib/widget/feedpost.dart`:在 modal sheet 选项里 `push ComposePost` 时显式传 `onPostSuccess` / `onCancel` 回调,均走 `Navigator.of(routeContext).pop()`。
- 修改 `client/lib/pages/textNote/text_note_page.dart`:`pushReplacement` 出去的 `ComposePost` 同样补上两个 pop 回调。

不改 `ComposePost` widget 本身的契约(见 `design.md` 决策 1)。

## Capabilities

### New Capabilities

无新增 capability;调整现有 `text-note` 行为约束,见 `specs/compose-post/spec.md`。

### Modified Capabilities

- `compose-post`:新增 requirement「ComposePost 实例化方必须显式提供 navigation 回调」 — 见 `specs/compose-post/spec.md`。

## Impact

**修改文件**

- `client/lib/widget/feedpost.dart`(L1249 附近)
- `client/lib/pages/textNote/text_note_page.dart`(L173 附近)

**新增文件**

- 无

**依赖包**

- 无变化

**服务端**

- 无变化

**平台**

- 沿用项目规范,只维护 iOS。

**supersedes**

无(本 change 是独立修复,不覆盖既有 change 的设计/任务)。
