## 1. feedpost.dart 修复

- [x] 1.1 在 `client/lib/widget/feedpost.dart:1249` 把 `builder: (_) => ComposePost(...)` 改为 `builder: (routeContext) => ComposePost(...)`
- [x] 1.2 给 `ComposePost` 加 `onPostSuccess: () => Navigator.of(routeContext).pop()` 与 `onCancel: () => Navigator.of(routeContext).pop()`
- [x] 1.3 替换原注释 `// 不需要 onPostSuccess 触发刷新:PostState.updatePost 已通过 _updatePostInList 完成本地列表的局部更新(决策点 A3)` 为新的说明:`// 修复:onPostSuccess 缺省会让 ComposePost 在 edit 保存后卡住(同 TextNotePage → pushReplacement 那条 bug),见 change-text-note-handoff 决策 1。PostState.updatePost 已通过 _updatePostInList 完成本地列表的局部更新(决策点 A3),不需要在回调里再触发刷新,只需 pop 回列表;onCancel 同样。`

## 2. text_note_page.dart 修复

- [x] 2.1 在 `client/lib/pages/textNote/text_note_page.dart:173` 把 `builder: (_) => ComposePost(...)` 改为 `builder: (routeContext) => ComposePost(...)`
- [x] 2.2 给 `ComposePost` 加 `onPostSuccess: () => Navigator.of(routeContext).pop()` 与 `onCancel: () => Navigator.of(routeContext).pop()`
- [x] 2.3 在 pushReplacement 上方加注释解释为什么需要 routeContext 与为什么两条回调都补

## 3. 验证

- [x] 3.1 `flutter analyze lib/widget/feedpost.dart lib/pages/textNote/text_note_page.dart` 无新增报错。结论:仅 2 条 pre-existing `withOpacity` warning(lines 1502/1520),与本改动无关
- [x] 3.2 grep `ComposePost(` 全项目,确认所有调用方现在要么 `_submit` 兜底,要么 `onPostSuccess` / `onCancel` 已显式提供。结论:`home.dart:39` / `feed.dart:292` 原生就好;`feedpost.dart:1249` / `text_note_page.dart:173` 本 change 修复
- [ ] 3.3 iOS 模拟器手动验证两条修复路径(需用户手动跑):
  - **写文字路径**:`+` → 写文字 → 输入 → 点「确认」→ 进 ComposePost → 点「发布」→ 应回到 HomePage 且 Feed 顶部出现新帖
  - **Edit 路径**:Feed 中长按自己的帖 → 选「编辑」→ 改文字 → 点「发布」→ 应回到帖子详情(Feed 该帖位置已局部更新,无需刷新)
