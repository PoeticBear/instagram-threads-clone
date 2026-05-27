import 'package:flutter/foundation.dart';
import 'package:threads/model/topic.module.dart';
import 'package:threads/services/topic_service.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/common/locator.dart';

class TopicState extends ChangeNotifier {
  final int topicId;

  TopicState(this.topicId) {
    _init();
  }

  TopicService? _topicService;

  TopicService get topicService {
    _topicService ??= TopicService(apiClient: getIt());
    return _topicService!;
  }

  // ========== 话题详情 ==========
  TopicInfo? _topicDetail;
  TopicInfo? get topicDetail => _topicDetail;

  bool _isBusy = true;
  bool get isBusy => _isBusy;

  bool _isFollowing = false;
  bool get isFollowing => _isFollowing;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  // ========== 话题帖子 ==========
  List<Post> _topicPosts = [];
  List<Post> get topicPosts => _topicPosts;

  bool _isLoadingPosts = false;
  bool get isLoadingPosts => _isLoadingPosts;

  int _postsPage = 1;
  bool _hasMorePosts = true;
  bool get hasMorePosts => _hasMorePosts;

  String _sort = 'latest';
  String get sort => _sort;

  // ========== 相关话题 ==========
  List<TopicInfo> _relatedTopics = [];
  List<TopicInfo> get relatedTopics => _relatedTopics;

  Future<void> _init() async {
    await loadTopicDetail();
    await loadTopicPosts(topicId);
    await loadRelatedTopics();
  }

  // ========== 话题详情加载 ==========
  Future<void> loadTopicDetail() async {
    _isBusy = true;
    notifyListeners();
    try {
      _topicDetail = await topicService.getTopicDetail(topicId);
      _isFollowing = _topicDetail?.isFollowing ?? false;
      _isMuted = _topicDetail?.isMuted ?? false;
    } catch (_) {
      // Topic detail unavailable, keep defaults
    }
    _isBusy = false;
    notifyListeners();
  }

  // ========== 关注/取关（乐观更新）==========
  Future<void> followTopic() async {
    _isFollowing = true;
    notifyListeners();
    try {
      await topicService.followTopic(topicId);
    } catch (_) {
      // Rollback on error
      _isFollowing = false;
      notifyListeners();
    }
  }

  Future<void> unfollowTopic() async {
    _isFollowing = false;
    notifyListeners();
    try {
      await topicService.unfollowTopic(topicId);
    } catch (_) {
      // Rollback on error
      _isFollowing = true;
      notifyListeners();
    }
  }

  // ========== 静音/取消静音 ==========
  Future<void> muteTopic() async {
    _isMuted = true;
    notifyListeners();
    try {
      await topicService.muteTopic(topicId);
    } catch (_) {
      // Rollback on error
      _isMuted = false;
      notifyListeners();
    }
  }

  Future<void> unmuteTopic() async {
    _isMuted = false;
    notifyListeners();
    try {
      await topicService.unmuteTopic(topicId);
    } catch (_) {
      // Rollback on error
      _isMuted = true;
      notifyListeners();
    }
  }

  // ========== 话题帖子列表 ==========
  Future<void> loadTopicPosts(int tid, {String sort = 'latest'}) async {
    _isLoadingPosts = true;
    _sort = sort;
    _postsPage = 1;
    _hasMorePosts = true;
    notifyListeners();
    try {
      _topicPosts = await topicService.getTopicPosts(tid, sort: sort);
      if (_topicPosts.length < 20) _hasMorePosts = false;
    } catch (_) {
      _topicPosts = [];
    }
    _isLoadingPosts = false;
    notifyListeners();
  }

  Future<void> loadMoreTopicPosts() async {
    if (_isLoadingPosts || !_hasMorePosts) return;
    _isLoadingPosts = true;
    notifyListeners();
    try {
      _postsPage++;
      final more = await topicService.getTopicPosts(
        topicId,
        page: _postsPage,
        sort: _sort,
      );
      if (more.isEmpty) {
        _hasMorePosts = false;
        _postsPage--;
      } else {
        _topicPosts.addAll(more);
      }
    } catch (_) {
      _postsPage--;
    }
    _isLoadingPosts = false;
    notifyListeners();
  }

  // ========== 相关话题 ==========
  Future<void> loadRelatedTopics() async {
    try {
      _relatedTopics = await topicService.getRelatedTopics(topicId);
      notifyListeners();
    } catch (_) {
      // Related topics unavailable
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
