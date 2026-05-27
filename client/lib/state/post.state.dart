import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/services/upload_service.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/common/locator.dart';
import '../model/post.module.dart';

class PostState extends AppStates {
  bool isBusy = false;
  Map<String, List<PostModel>?> postReplyMap = {};
  PostModel? _postToReplyModel;
  PostModel? get postToReplyModel => _postToReplyModel;
  set setPostToReply(PostModel model) {
    _postToReplyModel = model;
  }

  List<PostModel>? _feedlist;
  List<PostModel>? _userPosts; // 当前用户帖子列表（用于个人中心）
  List<PostModel>? _postDetailModelList;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isLoadingUserPosts = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingUserPosts => _isLoadingUserPosts;

  List<PostModel>? get userPosts => _userPosts;

  List<PostModel>? get postDetailModel => _postDetailModelList;

  List<PostModel>? get feedlist {
    if (_feedlist == null) {
      return null;
    } else {
      return List.from(_feedlist!);
    }
  }

  PostService? _postService;
  UploadService? _uploadService;

  PostService get postService {
    _postService ??= PostService(apiClient: getIt());
    return _postService!;
  }

  UploadService get uploadService {
    _uploadService ??= UploadService(apiClient: getIt());
    return _uploadService!;
  }

  Future<String?> createPost(
    PostModel model, {
    List<File>? imageFiles,
    List<String>? pollOptions,
    int? replyType,
    String? location,
    List<int>? topicIds,
    int? communityId,
    int? quoteRepostId,
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      print('🚀 PostState.createPost 开始: content="${model.bio}" images=${imageFiles?.length ?? 0} poll=${pollOptions} replyType=$replyType');

      // 如果有图片，逐个上传获取 COS URL
      List<String>? mediaUrls;
      if (imageFiles != null && imageFiles.isNotEmpty) {
        mediaUrls = [];
        for (int i = 0; i < imageFiles.length; i++) {
          print('📤 上传图片 ${i + 1}/${imageFiles.length}: ${imageFiles[i].path}');
          final cosUrl = await uploadService.uploadImage(imageFiles[i]);
          print('✅ 图片 ${i + 1} 上传成功: $cosUrl');
          mediaUrls.add(cosUrl);
        }
      }

      print('📤 调用 postService.createPost: content="${model.bio}" mediaUrls=$mediaUrls pollOptions=$pollOptions replyType=$replyType');

      final post = await postService.createPost(
        content: model.bio ?? '',
        mediaUrls: mediaUrls,
        pollOptions: pollOptions,
        replyType: replyType,
        replyToPostId: model.replyToPostId,
        replyToUserId:
            model.replyToUserId != null ? int.tryParse(model.replyToUserId!) : null,
        location: location,
        topicIds: topicIds,
        communityId: communityId,
        quoteRepostId: quoteRepostId,
      );

      developer.log('✅ 帖子创建成功: postId=${post.id}', name: 'PostState');

      // Convert API Post to PostModel
      final newPost = PostModel(
        key: post.id,
        postId: post.id,
        bio: post.content,
        createdAt: post.createdAt.toIso8601String(),
        imagePath: post.imageUrl,
        user: model.user,
        likesCount: post.likesCount,
        repliesCount: post.repliesCount,
        repostsCount: post.repostsCount,
        isLiked: post.isLiked,
        isSaved: post.isSaved,
        isReposted: post.isReposted,
        pollData: post.pollData,
      );

      _feedlist ??= [];
      _feedlist!.insert(0, newPost);

      isBusy = false;
      notifyListeners();
      return post.id;
    } catch (error, stackTrace) {
      print('❌ 创建帖子失败: $error\n$stackTrace');
      isBusy = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> uploadFile(File file) async {
    try {
      return await uploadService.uploadImage(file);
    } catch (e) {
      developer.log('上传文件失败: $e');
      return null;
    }
  }

  List<PostModel>? getPostListByFollower(UserModel? userModel) {
    if (userModel == null) {
      return null;
    }
    List<PostModel>? list;
    if (!isBusy && feedlist != null && feedlist!.isNotEmpty) {
      list = feedlist!.where((x) {
        if ((x.user!.userId == userModel.userId ||
            (userModel.followingList != null &&
                userModel.followingList!.contains(x.user!.userIdString)))) {
          return true;
        } else {
          return false;
        }
      }).toList();
      if (list.isEmpty) {
        list = null;
      }
    }
    return list;
  }

  List<PostModel>? getPostList(UserModel? userModel) {
    List<PostModel>? list;

    if (!isBusy && feedlist != null && feedlist!.isNotEmpty) {
      list = feedlist!.where((x) {
        return true;
      }).toList();
      if (list.isEmpty) {
        list = null;
      }
    }
    return list;
  }

  set setFeedModel(PostModel model) {
    _postDetailModelList ??= [];

    _postDetailModelList!.add(model);
    notifyListeners();
  }

  Future<bool> databaseInit() async {
    try {
      await getDataFromDatabase();
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<void> getDataFromDatabase() async {
    try {
      isBusy = true;
      _feedlist = null;
      _currentPage = 1;
      _hasMore = true;
      notifyListeners();

      final posts = await postService.getFeed();

      _feedlist = posts.map((apiPost) => PostModel(
        key: apiPost.id,
        postId: apiPost.id,
        bio: apiPost.content,
        createdAt: apiPost.createdAt.toIso8601String(),
        imagePath: apiPost.imageUrl,
        user: UserModel(
          userId: apiPost.user.userId,
          userName: apiPost.user.userName,
          displayName: apiPost.user.displayName,
          profilePic: apiPost.user.profilePic,
        ),
        likesCount: apiPost.likesCount,
        repliesCount: apiPost.repliesCount,
        repostsCount: apiPost.repostsCount,
        sharesCount: apiPost.sharesCount,
        isLiked: apiPost.isLiked,
        isSaved: apiPost.isSaved,
        isReposted: apiPost.isReposted,
        pollData: apiPost.pollData,
      )).toList();

      // Sort by createdAt descending
      _feedlist!.sort((x, y) => DateTime.parse(y.createdAt)
          .compareTo(DateTime.parse(x.createdAt)));

      isBusy = false;
      notifyListeners();
    } catch (error) {
      // API failed, load mock data as fallback
      developer.log('>>> getDataFromDatabase FAILED: $error', name: 'PostState');
      _loadMockData();
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> voteOnPoll(String postId, int optionId) async {
    final postIndex = _feedlist?.indexWhere((p) => p.postId == postId || p.key == postId) ?? -1;
    if (postIndex == -1) return;

    final post = _feedlist![postIndex];
    final oldPollData = post.pollData;

    // Optimistic update
    final updatedOptions = oldPollData!.options.map((o) {
      if (o.id == optionId) {
        return PollOption(id: o.id, optionText: o.optionText, votesCount: o.votesCount + 1);
      }
      return o;
    }).toList();

    _feedlist![postIndex] = post.copyWith(
      pollData: oldPollData.copyWith(
        options: updatedOptions,
        totalVotes: oldPollData.totalVotes + 1,
        userVotedOptionId: optionId,
      ),
    );
    notifyListeners();

    try {
      await postService.votePoll(int.parse(postId), optionId);
    } catch (_) {
      // Rollback on failure
      _feedlist![postIndex] = post.copyWith(pollData: oldPollData);
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _feedlist == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      final posts = await postService.getFeed(page: _currentPage, size: 20);
      if (posts.isEmpty) {
        _hasMore = false;
      } else {
        final newPosts = posts.map((apiPost) => PostModel(
          key: apiPost.id,
          postId: apiPost.id,
          bio: apiPost.content,
          createdAt: apiPost.createdAt.toIso8601String(),
          imagePath: apiPost.imageUrl,
          user: UserModel(
            userId: apiPost.user.userId,
            userName: apiPost.user.userName,
            displayName: apiPost.user.displayName,
            profilePic: apiPost.user.profilePic,
          ),
          likesCount: apiPost.likesCount,
          repliesCount: apiPost.repliesCount,
          repostsCount: apiPost.repostsCount,
          sharesCount: apiPost.sharesCount,
          isLiked: apiPost.isLiked,
          isSaved: apiPost.isSaved,
          isReposted: apiPost.isReposted,
          pollData: apiPost.pollData,
        )).toList();

        _feedlist!.addAll(newPosts);
        _feedlist!.sort((x, y) => DateTime.parse(y.createdAt)
            .compareTo(DateTime.parse(x.createdAt)));
      }
    } catch (_) {
      _currentPage--;
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  void _loadMockData() {
    final now = DateTime.now();

    final mockUsers = [
      UserModel(
        userId: 1,
        userName: 'zhangsan',
        displayName: '张三',
        profilePic: 'https://i.pravatar.cc/150?img=1',
      ),
      UserModel(
        userId: 2,
        userName: 'lisi_dev',
        displayName: '李四',
        profilePic: 'https://i.pravatar.cc/150?img=2',
      ),
      UserModel(
        userId: 3,
        userName: 'wangwu_photo',
        displayName: '王五',
        profilePic: 'https://i.pravatar.cc/150?img=3',
      ),
      UserModel(
        userId: 4,
        userName: 'zhaoliu_tech',
        displayName: '赵六',
        profilePic: 'https://i.pravatar.cc/150?img=4',
      ),
      UserModel(
        userId: 5,
        userName: 'sunqi_travel',
        displayName: '孙七',
        profilePic: 'https://i.pravatar.cc/150?img=5',
      ),
    ];

    _feedlist = [
      PostModel(
        key: 'mock_1',
        postId: 'mock_1',
        bio: '今天上线了一个新功能，支持用户注册和登录了！欢迎大家来体验 🎉',
        createdAt: now.subtract(const Duration(minutes: 5)).toIso8601String(),
        user: mockUsers[0],
        likesCount: 42,
        repliesCount: 7,
        repostsCount: 3,
        isLiked: false,
        isSaved: false,
      ),
      PostModel(
        key: 'mock_2',
        postId: 'mock_2',
        bio: '分享一下最近在用的 Flutter 状态管理方案，Provider + ChangeNotifier 真的很轻量好用',
        createdAt: now.subtract(const Duration(minutes: 30)).toIso8601String(),
        user: mockUsers[1],
        likesCount: 128,
        repliesCount: 23,
        repostsCount: 15,
        isLiked: true,
        isSaved: false,
      ),
      PostModel(
        key: 'mock_3',
        postId: 'mock_3',
        bio: '今天天气真好，拍了张照片 📷',
        createdAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
        imagePath: 'https://picsum.photos/seed/threads1/600/400',
        user: mockUsers[2],
        likesCount: 256,
        repliesCount: 18,
        repostsCount: 8,
        isLiked: false,
        isSaved: true,
      ),
      PostModel(
        key: 'mock_4',
        postId: 'mock_4',
        bio: ' Threads 的 UI 设计真的很简洁，暗色主题看着很舒服。有没有人想一起做一个开源 clone？',
        createdAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
        user: mockUsers[3],
        likesCount: 89,
        repliesCount: 34,
        repostsCount: 12,
        isLiked: false,
        isSaved: false,
      ),
      PostModel(
        key: 'mock_5',
        postId: 'mock_5',
        bio: '刚从日本回来，东京的夜景真的太美了，下次想去北海道 🗻',
        createdAt: now.subtract(const Duration(hours: 8)).toIso8601String(),
        imagePath: 'https://picsum.photos/seed/tokyo/600/400',
        user: mockUsers[4],
        likesCount: 512,
        repliesCount: 45,
        repostsCount: 29,
        isLiked: true,
        isSaved: false,
      ),
      PostModel(
        key: 'mock_6',
        postId: 'mock_6',
        bio: '推荐一个很好用的 API 调试工具，比 Postman 轻量多了',
        createdAt: now.subtract(const Duration(days: 1)).toIso8601String(),
        user: mockUsers[0],
        likesCount: 67,
        repliesCount: 12,
        repostsCount: 5,
        isLiked: false,
        isSaved: false,
      ),
      PostModel(
        key: 'mock_7',
        postId: 'mock_7',
        bio: '周末去爬山了，空气特别好，远离代码一天的感觉也不错 ⛰️',
        createdAt: now.subtract(const Duration(days: 1, hours: 6)).toIso8601String(),
        imagePath: 'https://picsum.photos/seed/mountain/600/400',
        user: mockUsers[1],
        likesCount: 198,
        repliesCount: 21,
        repostsCount: 7,
        isLiked: false,
        isSaved: true,
      ),
      PostModel(
        key: 'mock_8',
        postId: 'mock_8',
        bio: '在学 Dart 的 Isolate，并发编程的思想跟 JavaScript 完全不一样，需要适应一下',
        createdAt: now.subtract(const Duration(days: 2)).toIso8601String(),
        user: mockUsers[3],
        likesCount: 34,
        repliesCount: 8,
        repostsCount: 2,
        isLiked: false,
        isSaved: false,
      ),
    ];
  }

  Future<List<PostModel>> getUserPosts(int userId) async {
    try {
      final posts = await postService.getUserPosts(userId);
      return posts.map((apiPost) => PostModel(
        key: apiPost.id,
        postId: apiPost.id,
        bio: apiPost.content,
        createdAt: apiPost.createdAt.toIso8601String(),
        imagePath: apiPost.imageUrl,
        user: apiPost.user != null ? UserModel(
          userId: apiPost.user!.userId,
          userName: apiPost.user!.userName,
          displayName: apiPost.user!.displayName,
          profilePic: apiPost.user!.profilePic,
        ) : null,
        likesCount: apiPost.likesCount,
        repliesCount: apiPost.repliesCount,
        repostsCount: apiPost.repostsCount,
        isLiked: apiPost.isLiked,
        isSaved: apiPost.isSaved,
        isReposted: apiPost.isReposted,
      )).toList();
    } catch (error) {
      return [];
    }
  }

  /// 加载当前用户帖子到 userPosts
  Future<void> loadUserPosts(int userId) async {
    if (_isLoadingUserPosts) return;
    _isLoadingUserPosts = true;
    notifyListeners();

    try {
      final posts = await getUserPosts(userId);
      _userPosts = posts;
    } catch (error) {
      _userPosts = [];
    }

    _isLoadingUserPosts = false;
    notifyListeners();
  }

  Future<void> likePost(String postId) async {
    _updatePostLikeStatus(postId, true);
    try {
      await postService.likePost(postId);
    } catch (error) {
      _updatePostLikeStatus(postId, false);
    }
  }

  Future<void> unlikePost(String postId) async {
    _updatePostLikeStatus(postId, false);
    try {
      await postService.unlikePost(postId);
    } catch (error) {
      _updatePostLikeStatus(postId, true);
    }
  }

  void _updatePostLikeStatus(String postId, bool isLiked) {
    if (_feedlist != null) {
      final index = _feedlist!.indexWhere((p) => p.key == postId || p.postId == postId);
      if (index != -1) {
        final post = _feedlist![index];
        _feedlist![index] = post.copyWith(
          isLiked: isLiked,
          likesCount: (post.likesCount ?? 0) + (isLiked ? 1 : -1),
        );
        notifyListeners();
      }
    }
  }

  // ==================== Repost ====================

  /// Repost a post with optimistic update.
  /// Sets isReposted=true and increments repostsCount immediately,
  /// then calls the API. Rolls back on failure.
  Future<void> repost(String postId, {String? content}) async {
    _updatePostRepostStatus(postId, true);
    try {
      await postService.repost(postId, content: content);
    } catch (error) {
      developer.log('repost failed, rolling back: $error', name: 'PostState');
      _updatePostRepostStatus(postId, false);
    }
  }

  /// Unrepost a post with optimistic update.
  /// Sets isReposted=false and decrements repostsCount immediately.
  /// Since PostService does not have a dedicated unrepost endpoint,
  /// we call repost again to toggle the state (the backend treats it as a toggle).
  /// Rolls back on failure.
  Future<void> unrepost(String postId, {String? content}) async {
    _updatePostRepostStatus(postId, false);
    try {
      await postService.repost(postId, content: content);
    } catch (error) {
      developer.log('unrepost failed, rolling back: $error', name: 'PostState');
      _updatePostRepostStatus(postId, true);
    }
  }

  void _updatePostRepostStatus(String postId, bool isReposted) {
    if (_feedlist != null) {
      final index = _feedlist!.indexWhere((p) => p.key == postId || p.postId == postId);
      if (index != -1) {
        final post = _feedlist![index];
        _feedlist![index] = post.copyWith(
          isReposted: isReposted,
          repostsCount: (post.repostsCount ?? 0) + (isReposted ? 1 : -1),
        );
        notifyListeners();
      }
    }
  }

  // ==================== Save / Unsave ====================

  /// Save a post with optimistic update.
  /// Sets isSaved=true immediately, then calls the API. Rolls back on failure.
  Future<void> savePost(String postId) async {
    _updatePostSaveStatus(postId, true);
    try {
      await postService.savePost(postId);
    } catch (error) {
      developer.log('savePost failed, rolling back: $error', name: 'PostState');
      _updatePostSaveStatus(postId, false);
    }
  }

  /// Unsave a post with optimistic update.
  /// Sets isSaved=false immediately, then calls the API. Rolls back on failure.
  Future<void> unsavePost(String postId) async {
    _updatePostSaveStatus(postId, false);
    try {
      await postService.unsavePost(postId);
    } catch (error) {
      developer.log('unsavePost failed, rolling back: $error', name: 'PostState');
      _updatePostSaveStatus(postId, true);
    }
  }

  void _updatePostSaveStatus(String postId, bool isSaved) {
    if (_feedlist != null) {
      final index = _feedlist!.indexWhere((p) => p.key == postId || p.postId == postId);
      if (index != -1) {
        final post = _feedlist![index];
        _feedlist![index] = post.copyWith(isSaved: isSaved);
        notifyListeners();
      }
    }
  }

  // ==================== Share ====================

  /// Share a post. No optimistic update needed -- just increments sharesCount
  /// optimistically and calls the API.
  Future<void> sharePost(String postId) async {
    _updatePostShareCount(postId, increment: true);
    try {
      await postService.sharePost(postId);
    } catch (error) {
      developer.log('sharePost failed, rolling back: $error', name: 'PostState');
      _updatePostShareCount(postId, increment: false);
    }
  }

  void _updatePostShareCount(String postId, {required bool increment}) {
    if (_feedlist != null) {
      final index = _feedlist!.indexWhere((p) => p.key == postId || p.postId == postId);
      if (index != -1) {
        final post = _feedlist![index];
        _feedlist![index] = post.copyWith(
          sharesCount: (post.sharesCount ?? 0) + (increment ? 1 : -1),
        );
        notifyListeners();
      }
    }
  }

  // ==================== Report ====================

  /// Report a post. No optimistic UI update needed.
  Future<void> reportPost(String postId, {String? reason}) async {
    try {
      await postService.reportPost(postId, reason: reason);
      developer.log('reportPost succeeded for postId=$postId', name: 'PostState');
    } catch (error) {
      developer.log('reportPost failed: $error', name: 'PostState');
      rethrow;
    }
  }

  // ==================== Delete / Update ====================

  Future<bool> deletePost(String postId) async {
    try {
      await postService.deletePost(postId);
      _feedlist?.removeWhere((p) => p.id == postId);
      _userPosts?.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (error) {
      developer.log('deletePost failed: $error', name: 'PostState');
      return false;
    }
  }

  Future<PostModel?> updatePost(String postId, {String? content, String? imageUrl}) async {
    try {
      final updated = await postService.updatePost(
        postId: postId,
        content: content,
        imageUrl: imageUrl,
      );
      final updatedModel = PostModel(
        key: updated.id,
        postId: updated.id,
        bio: updated.content,
        createdAt: updated.createdAt.toIso8601String(),
        imagePath: updated.imageUrl,
        likesCount: updated.likesCount,
        repliesCount: updated.repliesCount,
        repostsCount: updated.repostsCount,
        sharesCount: updated.sharesCount,
        isLiked: updated.isLiked,
        isSaved: updated.isSaved,
        isReposted: updated.isReposted,
      );
      _updatePostInList(postId, updatedModel);
      return updatedModel;
    } catch (error) {
      developer.log('updatePost failed: $error', name: 'PostState');
      return null;
    }
  }

  // ==================== Pin / Unpin ====================

  Future<void> pinPost(String postId) async {
    try {
      await postService.pinPost(postId);
      _updatePostField(postId, isPinned: true);
    } catch (error) {
      developer.log('pinPost failed: $error', name: 'PostState');
    }
  }

  Future<void> unpinPost(String postId) async {
    try {
      await postService.unpinPost(postId);
      _updatePostField(postId, isPinned: false);
    } catch (error) {
      developer.log('unpinPost failed: $error', name: 'PostState');
    }
  }

  void _updatePostField(String postId, {bool? isPinned}) {
    for (final list in [_feedlist, _userPosts]) {
      if (list == null) continue;
      final index = list.indexWhere((p) => p.id == postId);
      if (index != -1) {
        list[index] = list[index].copyWith(isPinned: isPinned);
      }
    }
    notifyListeners();
  }

  void _updatePostInList(String postId, PostModel updated) {
    for (final list in [_feedlist, _userPosts]) {
      if (list == null) continue;
      final index = list.indexWhere((p) => p.id == postId);
      if (index != -1) {
        list[index] = list[index].copyWith(
          bio: updated.bio,
          imagePath: updated.imagePath,
        );
      }
    }
    notifyListeners();
  }

  // ==================== Saved Posts ====================

  List<PostModel> _savedPosts = [];
  bool _isLoadingSavedPosts = false;
  bool get isLoadingSavedPosts => _isLoadingSavedPosts;
  List<PostModel> get savedPosts => _savedPosts;

  Future<void> loadSavedPosts({int page = 1, int pageSize = 20}) async {
    _isLoadingSavedPosts = true;
    notifyListeners();
    try {
      final posts = await postService.getSavedPosts(page: page, pageSize: pageSize);
      _savedPosts = posts.map((apiPost) => PostModel(
        key: apiPost.id,
        postId: apiPost.id,
        bio: apiPost.content,
        createdAt: apiPost.createdAt.toIso8601String(),
        imagePath: apiPost.imageUrl,
        user: UserModel(
          userId: apiPost.user.userId,
          userName: apiPost.user.userName,
          displayName: apiPost.user.displayName,
          profilePic: apiPost.user.profilePic,
        ),
        likesCount: apiPost.likesCount,
        repliesCount: apiPost.repliesCount,
        repostsCount: apiPost.repostsCount,
        sharesCount: apiPost.sharesCount,
        isLiked: apiPost.isLiked,
        isSaved: true,
        isReposted: apiPost.isReposted,
      )).toList();
    } catch (_) {
      _savedPosts = [];
    }
    _isLoadingSavedPosts = false;
    notifyListeners();
  }

  // ==================== Scheduled Posts ====================

  List<PostModel> _scheduledPosts = [];
  bool _isLoadingScheduled = false;
  bool get isLoadingScheduled => _isLoadingScheduled;
  List<PostModel> get scheduledPosts => _scheduledPosts;

  Future<void> loadScheduledPosts({int page = 1, int size = 20}) async {
    _isLoadingScheduled = true;
    notifyListeners();
    try {
      final posts = await postService.getScheduledPosts(page: page, size: size);
      _scheduledPosts = posts.map((apiPost) => PostModel(
        key: apiPost.id,
        postId: apiPost.id,
        bio: apiPost.content,
        createdAt: apiPost.createdAt.toIso8601String(),
        imagePath: apiPost.imageUrl,
        scheduledTime: apiPost.scheduledTime,
        user: UserModel(
          userId: apiPost.user.userId,
          userName: apiPost.user.userName,
          displayName: apiPost.user.displayName,
          profilePic: apiPost.user.profilePic,
        ),
      )).toList();
    } catch (_) {
      _scheduledPosts = [];
    }
    _isLoadingScheduled = false;
    notifyListeners();
  }

  Future<bool> cancelSchedule(String postId) async {
    try {
      await postService.cancelSchedule(postId);
      _scheduledPosts.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==================== Reply Pin / Unpin ====================

  Future<void> pinReply(int replyId) async {
    try {
      await postService.pinReply(replyId);
      developer.log('pinReply succeeded for replyId=$replyId', name: 'PostState');
    } catch (error) {
      developer.log('pinReply failed: $error', name: 'PostState');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> unpinReply(int replyId) async {
    try {
      await postService.unpinReply(replyId);
      developer.log('unpinReply succeeded for replyId=$replyId', name: 'PostState');
    } catch (error) {
      developer.log('unpinReply failed: $error', name: 'PostState');
      rethrow;
    }
    notifyListeners();
  }
}