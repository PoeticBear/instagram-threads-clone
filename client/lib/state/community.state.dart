import 'package:flutter/material.dart';
import 'package:threads/model/community.module.dart';
import 'package:threads/services/community_service.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/common/locator.dart';

class CommunityState extends ChangeNotifier {
  CommunityService? _communityService;
  CommunityService get communityService {
    _communityService ??= CommunityService(apiClient: getIt());
    return _communityService!;
  }

  // ========== 社区列表 ==========
  List<CommunityInfo> _communities = [];
  List<CommunityInfo> get communities => _communities;
  bool _isLoadingCommunities = false;
  bool get isLoadingCommunities => _isLoadingCommunities;
  int _communityPage = 1;
  bool _hasMoreCommunities = true;
  bool get hasMoreCommunities => _hasMoreCommunities;

  Future<void> loadCommunities() async {
    _isLoadingCommunities = true;
    _communityPage = 1;
    _hasMoreCommunities = true;
    notifyListeners();
    try {
      final result = await communityService.getCommunities(page: 1);
      _communities = result['items'] as List<CommunityInfo>;
      _communityPage = 1;
      if (_communities.length < 20) _hasMoreCommunities = false;
    } catch (_) {}
    _isLoadingCommunities = false;
    notifyListeners();
  }

  Future<void> loadMoreCommunities() async {
    if (_isLoadingCommunities || !_hasMoreCommunities) return;
    _isLoadingCommunities = true;
    notifyListeners();
    try {
      _communityPage++;
      final result = await communityService.getCommunities(page: _communityPage);
      final more = result['items'] as List<CommunityInfo>;
      if (more.isEmpty) {
        _hasMoreCommunities = false;
        _communityPage--;
      } else {
        _communities.addAll(more);
      }
    } catch (_) {
      _communityPage--;
    }
    _isLoadingCommunities = false;
    notifyListeners();
  }

  // ========== 社区详情 ==========
  CommunityInfo? _communityDetail;
  CommunityInfo? get communityDetail => _communityDetail;
  bool _isLoadingDetail = false;
  bool get isLoadingDetail => _isLoadingDetail;

  Future<void> loadCommunityDetail(int communityId) async {
    _isLoadingDetail = true;
    notifyListeners();
    try {
      _communityDetail = await communityService.getCommunityDetail(communityId);
    } catch (_) {}
    _isLoadingDetail = false;
    notifyListeners();
  }

  // ========== 加入/退出社区 ==========
  Future<void> joinCommunity(int communityId) async {
    try {
      await communityService.joinCommunity(communityId);
      if (_communityDetail != null && _communityDetail!.id == communityId) {
        _communityDetail = _communityDetail!.copyWith(isJoined: true);
      }
      // Update in list if present
      final idx = _communities.indexWhere((c) => c.id == communityId);
      if (idx >= 0) {
        _communities[idx] = _communities[idx].copyWith(isJoined: true);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> leaveCommunity(int communityId) async {
    try {
      await communityService.leaveCommunity(communityId);
      if (_communityDetail != null && _communityDetail!.id == communityId) {
        _communityDetail = _communityDetail!.copyWith(isJoined: false);
      }
      final idx = _communities.indexWhere((c) => c.id == communityId);
      if (idx >= 0) {
        _communities[idx] = _communities[idx].copyWith(isJoined: false);
      }
      notifyListeners();
    } catch (_) {}
  }

  // ========== 社区成员 ==========
  List<CommunityMember> _members = [];
  List<CommunityMember> get members => _members;
  bool _isLoadingMembers = false;
  bool get isLoadingMembers => _isLoadingMembers;
  int _membersPage = 1;
  bool _hasMoreMembers = true;
  bool get hasMoreMembers => _hasMoreMembers;

  Future<void> loadMembers(int communityId) async {
    _isLoadingMembers = true;
    _membersPage = 1;
    _hasMoreMembers = true;
    notifyListeners();
    try {
      final result = await communityService.getCommunityMembers(communityId);
      _members = result['items'] as List<CommunityMember>;
      _membersPage = 1;
      if (_members.length < 20) _hasMoreMembers = false;
    } catch (_) {}
    _isLoadingMembers = false;
    notifyListeners();
  }

  Future<void> loadMoreMembers(int communityId) async {
    if (_isLoadingMembers || !_hasMoreMembers) return;
    _isLoadingMembers = true;
    notifyListeners();
    try {
      _membersPage++;
      final result = await communityService.getCommunityMembers(communityId, page: _membersPage);
      final more = result['items'] as List<CommunityMember>;
      if (more.isEmpty) {
        _hasMoreMembers = false;
        _membersPage--;
      } else {
        _members.addAll(more);
      }
    } catch (_) {
      _membersPage--;
    }
    _isLoadingMembers = false;
    notifyListeners();
  }

  // ========== 社区帖子 ==========
  List<Post> _communityPosts = [];
  List<Post> get communityPosts => _communityPosts;
  bool _isLoadingPosts = false;
  bool get isLoadingPosts => _isLoadingPosts;
  int _postsPage = 1;
  bool _hasMorePosts = true;
  bool get hasMorePosts => _hasMorePosts;

  Future<void> loadCommunityPosts(int communityId, {String sort = 'recent'}) async {
    _isLoadingPosts = true;
    _postsPage = 1;
    _hasMorePosts = true;
    notifyListeners();
    try {
      _communityPosts = await communityService.getCommunityPosts(communityId, sort: sort);
      _postsPage = 1;
      if (_communityPosts.length < 20) _hasMorePosts = false;
    } catch (_) {}
    _isLoadingPosts = false;
    notifyListeners();
  }

  Future<void> loadMoreCommunityPosts(int communityId, {String sort = 'recent'}) async {
    if (_isLoadingPosts || !_hasMorePosts) return;
    _isLoadingPosts = true;
    notifyListeners();
    try {
      _postsPage++;
      final more = await communityService.getCommunityPosts(communityId, page: _postsPage, sort: sort);
      if (more.isEmpty) {
        _hasMorePosts = false;
        _postsPage--;
      } else {
        _communityPosts.addAll(more);
      }
    } catch (_) {
      _postsPage--;
    }
    _isLoadingPosts = false;
    notifyListeners();
  }

  // ========== Champion ==========
  Future<void> setChampion(int communityId, int userId) async {
    try {
      await communityService.setChampion(communityId, userId);
      // Refresh members list
      await loadMembers(communityId);
    } catch (_) {}
  }

  Future<void> removeChampion(int communityId, int userId) async {
    try {
      await communityService.removeChampion(communityId, userId);
      await loadMembers(communityId);
    } catch (_) {}
  }
}
