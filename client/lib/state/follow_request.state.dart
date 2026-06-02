import 'package:flutter/material.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';
import 'package:threads/state/app.state.dart';

class FollowRequestState extends AppStates {
  UserService? _userService;

  UserService get userService {
    _userService ??= UserService(apiClient: getIt());
    return _userService!;
  }

  List<FollowRequest> _requests = [];
  List<FollowRequest> get requests => _requests;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  int? _processingId;
  int? get processingId => _processingId;

  Future<void> loadRequests() async {
    try {
      isBusy = true;
      notifyListeners();
      _requests = await userService.getFollowRequests();
      isBusy = false;
      notifyListeners();
    } catch (e) {
      debugPrint('FollowRequestState.loadRequests error: $e');
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> approve(int requestId) async {
    try {
      _processingId = requestId;
      _isProcessing = true;
      notifyListeners();

      await userService.approveFollowRequest(requestId, action: 1);
      _requests = _requests.where((r) => r.id != requestId).toList();

      _isProcessing = false;
      _processingId = null;
      notifyListeners();
    } catch (e) {
      debugPrint('FollowRequestState.approve error: $e');
      _isProcessing = false;
      _processingId = null;
      notifyListeners();
    }
  }

  Future<void> reject(int requestId) async {
    try {
      _processingId = requestId;
      _isProcessing = true;
      notifyListeners();

      await userService.approveFollowRequest(requestId, action: 2);
      _requests = _requests.where((r) => r.id != requestId).toList();

      _isProcessing = false;
      _processingId = null;
      notifyListeners();
    } catch (e) {
      debugPrint('FollowRequestState.reject error: $e');
      _isProcessing = false;
      _processingId = null;
      notifyListeners();
    }
  }
}
