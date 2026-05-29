import 'package:flutter/material.dart';
import 'package:threads/services/notification_service.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/common/locator.dart';

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

      final items = await notificationService.getNotifications(
        page: _currentPage,
        pageSize: 20,
        type: _filterType,
      );

      if (refresh) {
        _notifications = items;
      } else {
        _notifications.addAll(items);
      }

      _hasMore = items.length >= 20;
      isBusy = false;
      notifyListeners();
    } catch (error) {
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
      notifyListeners();
    } catch (_) {}
  }

  /// 标记指定通知为已读
  Future<void> markAsRead(List<String> ids) async {
    try {
      await notificationService.markAsRead(ids);
      for (final notification in _notifications) {
        if (ids.contains(notification.id)) {
          // NotificationItem is immutable, so we rebuild the list
          break;
        }
      }
      await fetchUnreadCount();
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
            title: n.title,
            body: n.body,
            fromUserId: n.fromUserId,
            fromUsername: n.fromUsername,
            fromDisplayName: n.fromDisplayName,
            fromProfilePic: n.fromProfilePic,
            postId: n.postId,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }
}
