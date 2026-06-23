import 'dart:async';

import 'package:flutter/material.dart';
import 'package:threads/services/notification_service.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/network/ws_notification_mapping.dart';
import 'dart:developer' as developer;

class NotificationState extends AppStates {
  NotificationService? _notificationService;

  NotificationService get notificationService {
    _notificationService ??= NotificationService(apiClient: getIt());
    return _notificationService!;
  }

  // 通知列表
  List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;

  // 筛选类型（null = 全部）
  // 1=点赞, 2=回复, 3=关注, 4=提及, 5=转发, 6=引用
  int? _filterType;
  int? get filterType => _filterType;

  // 未读数
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  // 分页
  int _currentPage = 1;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  // 加载状态
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  /// 加载通知列表（refresh=true 时重置分页）
  Future<void> loadNotifications({bool refresh = false}) async {
    try {
      if (refresh) {
        _currentPage = 1;
        _hasMore = true;
        _notifications = [];
      }

      isBusy = true;
      notifyListeners();

      developer.log('🔄 开始加载通知列表: page=$_currentPage, filterType=$_filterType', name: 'NotificationState');

      final items = await notificationService.getNotifications(
        page: _currentPage,
        pageSize: 20,
        type: _filterType,
      );

      developer.log('📦 通知列表加载成功: page=$_currentPage, count=${items.length}', name: 'NotificationState');

      if (refresh) {
        _notifications = items;
      } else {
        _notifications.addAll(items);
      }

      _hasMore = items.length >= 20;
      isBusy = false;
      notifyListeners();
    } catch (error) {
      developer.log('❌ 通知列表加载失败: $error', name: 'NotificationState', error: error is Error ? error : null);
      isBusy = false;
      notifyListeners();
    }
  }

  /// 加载更多（分页）
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      _isLoadingMore = true;
      notifyListeners();

      _currentPage++;
      final items = await notificationService.getNotifications(
        page: _currentPage,
        pageSize: 20,
        type: _filterType,
      );

      _notifications.addAll(items);
      _hasMore = items.length >= 20;
      _isLoadingMore = false;
      notifyListeners();
    } catch (error) {
      developer.log('❌ 加载更多通知失败: $error', name: 'NotificationState', error: error is Error ? error : null);
      _isLoadingMore = false;
      _currentPage--;
      notifyListeners();
    }
  }

  /// 设置筛选类型
  Future<void> setFilter(int? type) async {
    _filterType = type;
    notifyListeners();
    await loadNotifications(refresh: true);
  }

  /// 获取未读数
  Future<void> fetchUnreadCount() async {
    try {
      _unreadCount = await notificationService.getUnreadCount();
      developer.log('📬 未读通知数: $_unreadCount', name: 'NotificationState');
      notifyListeners();
    } catch (error) {
      developer.log('❌ 获取未读数失败: $error', name: 'NotificationState');
    }
  }

  /// 标记指定通知为已读
  Future<void> markAsRead(List<String> ids) async {
    try {
      await notificationService.markAsRead(ids);
      for (int i = 0; i < _notifications.length; i++) {
        final n = _notifications[i];
        if (ids.contains(n.id) && !n.isRead) {
          _notifications[i] = NotificationItem(
            id: n.id,
            type: n.type,
            body: n.body,
            fromUserId: n.fromUserId,
            fromUsername: n.fromUsername,
            fromDisplayName: n.fromDisplayName,
            fromProfilePic: n.fromProfilePic,
            postId: n.postId,
            isRead: true,
            createdAt: n.createdAt,
            wsEventType: n.wsEventType,
          );
        }
      }
      await fetchUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  /// 标记全部已读
  Future<void> markAllAsRead() async {
    try {
      await notificationService.markAsRead([]);
      for (int i = 0; i < _notifications.length; i++) {
        final n = _notifications[i];
        if (!n.isRead) {
          _notifications[i] = NotificationItem(
            id: n.id,
            type: n.type,
            body: n.body,
            fromUserId: n.fromUserId,
            fromUsername: n.fromUsername,
            fromDisplayName: n.fromDisplayName,
            fromProfilePic: n.fromProfilePic,
            postId: n.postId,
            isRead: true,
            createdAt: n.createdAt,
            wsEventType: n.wsEventType,
          );
        }
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  // ============================================================
  // WebSocket 事件入口(由 ws_handlers/notification_handlers.dart 调用)
  // ============================================================

  /// 防抖 Timer:WS 事件触发后 500ms 合并成一次 HTTP `loadNotifications(refresh: true)`。
  /// 避免短时间多次 WS 事件(如点赞 + notification_new 并发推送)各自打一次 HTTP。
  Timer? _refreshDebounce;

  /// 未读数 +1。仅本地增量,不发 HTTP。
  void incrementUnread() {
    _unreadCount++;
    notifyListeners();
  }

  /// 防抖触发 HTTP refresh。
  /// 服务端权威数据回流后整体替换本地列表(简单可靠的对账策略)。
  void _scheduleDebouncedRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
      loadNotifications(refresh: true);
    });
  }

  /// WS 通知事件统一入口(Step 1 基础设施,Step 2 起所有 handler 走这里)。
  ///
  /// 流程:
  /// 1. 查 [WsNotificationMapping.specFor];未注册或 spec=null → 跳过本地插入
  /// 2. `needsLocalInsert=true` → [NotificationItem.fromWsEvent] 本地构造 + 去重插入列表头
  /// 3. [incrementUnread]
  /// 4. [_scheduleDebouncedRefresh] 防抖触发 HTTP refresh
  ///
  /// `notification_new` 等 `needsLocalInsert=false` 的事件仅做 3、4 步。
  void handleWsEvent(String eventType, Map<String, dynamic> json) {
    final spec = WsNotificationMapping.specFor(eventType);
    if (spec != null && spec.needsLocalInsert) {
      try {
        final item = NotificationItem.fromWsEvent(eventType, json, spec);
        final exists = _notifications.any((n) => n.id == item.id);
        if (!exists) {
          _notifications.insert(0, item);
        }
      } catch (e) {
        developer.log('handleWsEvent local insert failed for $eventType: $e',
            name: 'NotificationState');
      }
    }
    incrementUnread();
    _scheduleDebouncedRefresh();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    super.dispose();
  }
}
