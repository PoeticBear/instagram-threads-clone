# Phase 3 — Community Module + User Controls + Data Model Completion

> Objective: Implement Community module, User relation controls, Collections, Hidden Words/Links, Data Model field completion, Settings UI
> Files: ~25 new, ~15 modified
> Prerequisites: P0 + P1 + P2 completed

---

## Sub-task Overview

| # | Sub-task | Type | Dependencies | Status |
|---|----------|------|--------------|--------|
| 3.1 | Community model definition (CommunityInfo, CommunityMember) | Model | None | Not started |
| 3.2 | CommunityService implementation (8 endpoints) | Service | 3.1 | Not started |
| 3.3 | CommunityState implementation | State | 3.2 | Not started |
| 3.4 | Community list page | UI | 3.3 | Not started |
| 3.5 | Community detail page + members page | UI | 3.3 | Not started |
| 3.6 | UserService extension: Relation Controls (3 endpoints) | Service | None | Not started |
| 3.7 | UserService extension: Save Collections (3 endpoints) | Service | None | Not started |
| 3.8 | UserService extension: Hidden Words (3 endpoints) + Links (4 endpoints) | Service | None | Not started |
| 3.9 | Relation Control settings page (Muted/Restricted/Blocked users) | UI | 3.6 | Not started |
| 3.10 | Save Collections management page | UI | 3.7 | Not started |
| 3.11 | Hidden Words + Links management pages | UI | 3.8 | Not started |
| 3.12 | UserModel field completion (lastActiveTime) | Model | None | Not started |
| 3.13 | PostModel field completion (location, topicIds, isGhost, communityId, replySettings, quoteRepostId, isPinned, sharesCount parsing) | Model | None | Not started |
| 3.14 | Settings notification UI (NotificationSettingsPage) | UI | None | Not started |
| 3.15 | Settings privacy UI (PrivacySettingsPage) | UI | None | Not started |
| 3.16 | P3 i18n string additions | i18n | All UI | Not started |
| 3.17 | main.dart MultiProvider registration update | Config | 3.3 | Not started |

---

## Execution Order & Dependency Graph

```
3.1 Community Model ──→ 3.2 CommunityService ──→ 3.3 CommunityState ──→ 3.4 + 3.5 Community UI

3.6 UserService Relation Controls ──→ 3.9 Relation Control UI
3.7 UserService Collections ──→ 3.10 Collections UI
3.8 UserService Hidden Words/Links ──→ 3.11 Hidden Words + Links UI

3.12 UserModel completion (independent)
3.13 PostModel completion (independent)

3.14 + 3.15 Settings UI (independent, uses existing SettingsState)

All UI ──→ 3.16 i18n
3.3 ──→ 3.17 MultiProvider
```

### Batch Execution Plan

**Batch 1 (Models + Services, parallel):**
- 3.1 Community Model (new file)
- 3.2 CommunityService (new file)
- 3.6 + 3.7 + 3.8 UserService extensions (modify existing)
- 3.12 UserModel completion
- 3.13 PostModel completion

**Batch 2 (State layers, parallel):**
- 3.3 CommunityState
- 3.17 MultiProvider update

**Batch 3 (UI pages, parallel):**
- 3.4 + 3.5 Community UI pages
- 3.9 Relation Control settings page
- 3.10 Collections management page
- 3.11 Hidden Words + Links pages
- 3.14 Notification Settings UI
- 3.15 Privacy Settings UI

**Batch 4 (i18n + finalize):**
- 3.16 i18n string additions
- Final dart analyze
