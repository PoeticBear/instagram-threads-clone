# P4 Implementation Plan

## Execution Order

### Batch 1: Tech Debt (C1-C4)
- **C1**: Fix FollowService path mismatch (follow_service.dart)
- **C2**: Fix NotificationPage filter type mismatch (notification.dart + notification.state.dart)
- **C3**: Fix FeedPostWidget hardcoded Copy Link URL (feedpost.dart)
- **C4**: Audit NotificationState completeness (already complete, just verify)

### Batch 2: Service Layer (A1-A6)
- **A1**: Add getScheduledPosts() and cancelSchedule() to PostService
- **A2**: Add getEditHistory() to PostService
- **A3**: updatePost() already exists
- **A4**: deletePost() already exists
- **A5**: Add getNearbyPosts() to PostService
- **A6**: Add getOEmbed() to PostService

### Batch 3: State Layer
- Add scheduledPosts, editHistory methods to PostState
- Add deletePost, updatePost, pinPost, unpinPost to PostState

### Batch 4: i18n
- Add all new keys for P4 features

### Batch 5: UI Pages
- **B1**: ProfilePage - real post list in TabBarView
- **B2**: MyProfilePage - replies tab
- **B3**: PostDetailPage (new)
- **B4**: NotificationPage i18n fix
- **B5**: NotificationPage navigation
- **B6**: SavedPostsPage (new)
- **B7**: FeedPostWidget more menu (edit/delete/pin)
- **B8**: Quote repost UI

### Batch 6: dart analyze
