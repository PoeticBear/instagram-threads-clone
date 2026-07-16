## Context

承接 `change-text-note-handoff` 验证阶段的发现 —— 用户在写文字 → 确认 → ComposePost → 发布后,**ComposePost 不会自我 pop**,内容已清空但页面卡住,需要手动返回。根因在 `ComposePost._submit`(L1042)与 `_handleBack`(L462)都只调 `widget.onPostSuccess?.call()` / `widget.onCancel?.call()`,**缺省为 no-op**,不 fallback 到 self-pop。

顺着这条 bug 类串查,发现 `client/lib/widget/feedpost.dart:1249` 的 Edit 入口也缺回调(pre-existing),同一 bug 类。两条路都修了。

## Goals / Non-Goals

**Goals**

- 所有 push / pushReplacement `ComposePost` 的入口都要给出 `onPostSuccess` + `onCancel` 回调,用户发布或取消后能正确退出到上层路由
- 修复手段要一致、可识别

**Non-Goals**

- 不修改 `ComposePost` widget 的契约(不引入 "self-pop on null callback" 默认行为,详见决策 1)
- 不动 `home.dart` Tab=2 与 `feed.dart` FAB(本来就好)

## Decisions

### 决策 1:在调用方补回调,不在 `ComposePost` 内部 default-fallback pop

**选择**:在调用方(provider)显式传 `onPostSuccess` + `onCancel` 回调。

**否决**:在 `ComposePost` 的 `_submit` 末尾加 `if (widget.onPostSuccess == null && Navigator.of(context).canPop()) Navigator.of(context).pop();`

**理由否决默认 pop**:
- `home.dart:39` 把 ComposePost 放在 `IndexedStack` 的 Tab=2 上,它的回调走 `setState(() => tab = 0)`。如果让 ComposePost 在 onPostSuccess 缺省时自我 pop,IndexedStack 内部的 Navigator 状态会出现混乱(Stack 内部没有真正的 Navigator 在处理路由栈,`Navigator.of(context).pop()` 在那个 `context` 里行为未定义,可能 crash 或 no-op)。
- 对调用方来说,**显式声明 nav 行为**比依赖默认值更可读 —— 看 push 的代码就知道完成后会做什么。
- 修起来调用方各加 2 行,总共 2 个入口 ×2 行 = 4 行代码,代价小到可以全文件 grep 验证。

### 决策 2:用 `routeContext` 而不是 outer `context`

**选择**:`MaterialPageRoute(builder: (routeContext) => ComposePost(..., onPostSuccess: () => Navigator.of(routeContext).pop()))` —— 用 builder 入参的 `BuildContext` 而不是闭包外的 `context`。

**理由**:
- `home.dart` Tab=2 / Feed FAB 等场景外层 `context` 是稳的(State 持续活着),但 `feedpost.dart` 的 modal sheet 关闭后外层 `context` 处于 deactivated 状态,`Navigator.of(deactivatedContext)` 触发 "Looking up a deactivated widget's ancestor is unsafe"。
- `pushReplacement` 出来后,被替换的 `TextNotePage` 也被 deactivated,引用 outer `context` 同理不安全。
- `routeContext` 是新路由自己的 BuildContext,生命周期与 `ComposePost` route 一致,在 pop 调用时仍然有效,与外层是否已被销毁无关。

### 决策 3:`onCancel` 也补回调

**选择**:把 `onCancel` 和 `onPostSuccess` 一起传过去,语义对称。

**理由**:用户从 `ComposePost` 系统返回手势退出时,会触发 `_handleBack`(L462)→ `widget.onCancel?.call()`。如果只修发布成功一条,发布会自动跳,取消就卡死 —— 两条路必须一起修,行为对称。

### 决策 4:用 pop 而非 popUntil

**选择**:`Navigator.of(routeContext).pop()`。

**理由**:两个入口都是只 push / pushReplacement 了一级 `ComposePost`,栈结构要么是 `[HomePage, ComposePost]`(TextNotePage 路径),要么是 `[..., ComposePost]`(FAB / Edit 路径)。`.pop()` 弹掉 `ComposePost` 就回到上一级,行为符合预期。`popUntil((r) => r.isFirst)` 过度防御,反而掩盖潜在的栈结构错误。

### 决策 5:不同时让 `feedpost.dart` 做"刷新"

**否决**:`onPostSuccess` 不调 `postState.getDataFromDatabase()`。

**理由**:原代码注释"`PostState.updatePost` 已通过 `_updatePostInList` 完成本地列表的局部更新" 已经把刷新解决了 —— 编辑后的帖子已经在 Feed 上更新过。`onPostSuccess` 只需要管 nav,刷新职责在 `PostState` 内部,留给它。FAB 那边需要显式刷新是因为它走的是"创建新帖 → pop → 回到 Feed"的路径,新帖不在 Feed 自带的 `_updatePostInList` 覆盖范围内,所以 FAB 路径才加了显式 refresh。

## Risks / Trade-offs

- **[R1] 未来调用方可能再忘**(新加一个 `push(ComposePost)` 又不传回调)
  → 加 spec 约束(下条);短期靠 review;长期方向是给 `ComposePost` 加 `assert(widget.onPostSuccess != null || widget.onCancel != null)` 在 debug 模式提醒,但会破坏 FAB 等"只调 onCancel 不调 onPostSuccess"的调用,代价大。
- **[R2] `routeContext` 与 `ComposePost` 的 BuildContext 混淆**
  → `_submit` 内部仍用 `this.context`(`State.context`),这是 ComposePost 自己的 context(生命周期内总有效)。回调里的 `routeContext` 是 Builder 入参,只在闭包里用,不进入 `_submit` / `_handleBack` 的内部逻辑,二者不冲突。

## Open Questions

无。
