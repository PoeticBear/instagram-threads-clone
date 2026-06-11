import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:threads/model/user.module.dart';
import 'package:threads/model/media_draft_item.dart';
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

  /// Convert API Post to UI PostModel, preserving all quote/repost/thread data.
  PostModel _apiPostToModel(Post apiPost) {
    return PostModel(
      key: apiPost.id,
      postId: apiPost.id,
      bio: apiPost.content,
      createdAt: apiPost.createdAt.toIso8601String(),
      imagePath: apiPost.imageUrl,
      mediaList: apiPost.mediaList
          .map((m) => m.toMediaItemModel())
          .toList(),
      user: UserModel(
        userId: apiPost.userId,
        userName: apiPost.username,
        displayName: apiPost.displayName,
        profilePic: apiPost.profilePic,
      ),
      likesCount: apiPost.likesCount,
      repliesCount: apiPost.repliesCount,
      repostsCount: apiPost.repostsCount,
      sharesCount: apiPost.sharesCount,
      isLiked: apiPost.isLiked,
      isSaved: apiPost.isSaved,
      isReposted: apiPost.isReposted,
      pollData: apiPost.pollData,
      location: apiPost.location,
      isGhost: apiPost.isGhost,
      communityId: apiPost.communityId,
      replySettings: apiPost.replySettings,
      quoteRepostId: apiPost.quoteRepostId,
      isPinned: apiPost.isPinned,
      scheduledTime: apiPost.scheduledTime,
      isAi: apiPost.isAi,
      // Quote / Repost / Thread fields
      quoteContent: apiPost.quoteContent,
      quotePost: apiPost.quotePost != null ? _apiPostToModel(apiPost.quotePost!) : null,
      isRepost: apiPost.isRepost,
      repostParentId: apiPost.repostParentId,
      threadPosts: apiPost.threadPosts.map((tp) => _apiPostToModel(tp)).toList(),
      threadPostIds: apiPost.threadPostIds,
      quotesCount: apiPost.quotesCount,
    );
  }

  Future<String?> createPost(
    PostModel model, {
    /// 多类型媒体草稿（image / video / gif）。新代码请使用此参数。
    /// 与 [mediaTypes] 配合传入 PostService。
    List<MediaDraftItem>? mediaDrafts,
    /// 旧的图片上传 API（保留向后兼容）。
    @Deprecated('Use mediaDrafts with mixed media types')
    List<File>? imageFiles,
    @Deprecated('Use mediaDrafts with mixed media types')
    List<String>? preUploadedUrls,
    List<String>? pollOptions,
    int? replyType,
    String? location,
    List<int>? topicIds,
    int? communityId,
    int? quoteRepostId,
    String? scheduledTime,
  }) async {
    try {
      isBusy = true;
      notifyListeners();

      // 1) 处理媒体草稿：上传本地文件 → 收集 (mediaUrls, mediaTypes)
      List<String>? mediaUrls;
      List<int>? mediaTypes;
      if (mediaDrafts != null && mediaDrafts.isNotEmpty) {
        mediaUrls = [];
        mediaTypes = [];
        for (int i = 0; i < mediaDrafts.length; i++) {
          final item = mediaDrafts[i];
          final url = item.needsUpload && item.localFile != null
              ? await uploadService.uploadMedia(
                  item.localFile!,
                  mediaType: item.mediaTypeInt,
                  durationMs: item.durationMs,
                )
              : (item.remoteUrl ?? '');
          if (url.isEmpty) {
            throw StateError('MediaDraftItem[$i] has no URL after upload');
          }
          mediaUrls.add(url);
          mediaTypes.add(item.mediaTypeInt);
        }
      } else if (imageFiles != null && imageFiles.isNotEmpty) {
        // 兼容旧 API：纯图片
        mediaUrls = [...?preUploadedUrls];
        mediaTypes = mediaUrls.map((_) => MediaType.image).toList();
        for (int i = 0; i < imageFiles.length; i++) {
          final cosUrl = await uploadService.uploadImage(imageFiles[i]);
          mediaUrls.add(cosUrl);
          mediaTypes.add(MediaType.image);
        }
      } else if (preUploadedUrls != null && preUploadedUrls.isNotEmpty) {
        mediaUrls = [...preUploadedUrls];
        mediaTypes = mediaUrls.map((_) => MediaType.image).toList();
      }

      final post = await postService.createPost(
        content: model.bio ?? '',
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        pollOptions: pollOptions,
        replyType: replyType,
        replyToPostId: model.replyToPostId,
        replyToUserId:
            model.replyToUserId != null ? int.tryParse(model.replyToUserId!) : null,
        location: location,
        topicIds: topicIds,
        communityId: communityId,
        quoteRepostId: quoteRepostId,
        scheduledTime: scheduledTime,
      );

      developer.log('✅ 帖子创建成功: postId=${post.id}', name: 'PostState');

      // Convert API Post to PostModel
      final newPost = PostModel(
        key: post.id,
        postId: post.id,
        bio: post.content,
        createdAt: post.createdAt.toIso8601String(),
        imagePath: post.imageUrl,
        mediaList: post.mediaList
            .map((m) => m.toMediaItemModel())
            .toList(),
        user: model.user,
        likesCount: post.likesCount,
        repliesCount: post.repliesCount,
        repostsCount: post.repostsCount,
        isLiked: post.isLiked,
        isSaved: post.isSaved,
        isReposted: post.isReposted,
        pollData: post.pollData,
      );

      if (scheduledTime == null) {
        _feedlist ??= [];
        _feedlist!.insert(0, newPost);
      }

      isBusy = false;
      notifyListeners();
      return post.id;
    } catch (error, stackTrace) {
      developer.log('❌ 创建帖子失败: $error\n$stackTrace', name: 'PostState');
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

      _feedlist = posts.map((apiPost) {
        return _apiPostToModel(apiPost);
      }).toList();

      // Sort by createdAt descending
      _feedlist!.sort((x, y) => DateTime.parse(y.createdAt)
          .compareTo(DateTime.parse(x.createdAt)));

      isBusy = false;
      notifyListeners();
    } catch (error) {
      developer.log('>>> getDataFromDatabase FAILED: $error', name: 'PostState');
      isBusy = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh: reload feed without showing full-page loading spinner.
  Future<void> refresh() async {
    try {
      _currentPage = 1;
      _hasMore = true;

      final posts = await postService.getFeed();

      _feedlist = posts.map((apiPost) {
        return _apiPostToModel(apiPost);
      }).toList();

      _feedlist!.sort((x, y) => DateTime.parse(y.createdAt)
          .compareTo(DateTime.parse(x.createdAt)));
    } catch (error) {
      developer.log('>>> refresh FAILED: $error', name: 'PostState');
    }
    notifyListeners();
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

    try {
      _currentPage++;
      final posts = await postService.getFeed(page: _currentPage, size: 20);
      if (posts.isEmpty) {
        _hasMore = false;
      } else {
        final newPosts = posts.map((apiPost) => _apiPostToModel(apiPost)).toList();

        _feedlist!.addAll(newPosts);
        _feedlist!.sort((x, y) => DateTime.parse(y.createdAt)
            .compareTo(DateTime.parse(x.createdAt)));
      }
    } catch (_) {
      _currentPage--;
      _hasMore = false;
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  // ==================== User Posts ====================

  Future<List<PostModel>> getUserPosts(int userId) async {
    try {
      final posts = await postService.getUserPosts(userId);
      return posts.map((apiPost) => _apiPostToModel(apiPost)).toList();
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

  // ==================== Quote Post Detail ====================

  /// Fetch a single post by ID (used when list API omits quote_post).
  Future<PostModel?> fetchQuotePostDetail(int quotePostId) async {
    try {
      final apiPost = await postService.getPostDetail(quotePostId.toString());
      return _apiPostToModel(apiPost);
    } catch (error) {
      developer.log('fetchQuotePostDetail failed for id=$quotePostId: $error', name: 'PostState');
      return null;
    }
  }

  // ==================== Repost ====================

  /// Repost a post with optimistic update.
  /// Sets isReposted=true and increments repostsCount immediately,
  /// then calls the API. If the API fails because already reposted,
  /// keeps the local state as reposted (idempotent).
  Future<void> repost(String postId, {String? content}) async {
    _updatePostRepostStatus(postId, true);
    try {
      await postService.repost(postId, content: content);
    } catch (error) {
      // Don't rollback — the server may reject because already reposted
      // (e.g. after a local-only unrepost). The local state is correct.
      developer.log('repost API error (kept local state): $error', name: 'PostState');
    }
  }

  /// Unrepost a post (local-only until backend adds DELETE /post/repost/{id}).
  /// Sets isReposted=false and decrements repostsCount in the local list.
  Future<void> unrepost(String postId) async {
    _updatePostRepostStatus(postId, false);
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

  /// Report content (post, reply, user, etc.). No optimistic UI update needed.
  /// [targetType]: 1=Post, 2=Reply, 3=User, 4=Direct Message
  /// [reportType]: 1=Spam, 2=Harassment, 3=Hate Speech, 4=Self-harm,
  ///               5=Violence, 6=Privacy Violation, 7=Misinformation,
  ///               8=Intellectual Property, 9=Other
  Future<void> reportContent({
    required int targetType,
    required int targetId,
    required int reportType,
    String? description,
  }) async {
    try {
      await postService.reportContent(
        targetType: targetType,
        targetId: targetId,
        reportType: reportType,
        description: description,
      );
      developer.log('reportContent succeeded for targetId=$targetId', name: 'PostState');
    } catch (error) {
      developer.log('reportContent failed: $error', name: 'PostState');
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
        mediaList: updated.mediaList
            .map((m) => m.toMediaItemModel())
            .toList(),
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

  /// Increment repliesCount for a post (called after a successful reply).
  void incrementReplyCount(String postId) {
    for (final list in [_feedlist, _userPosts]) {
      if (list == null) continue;
      final index = list.indexWhere((p) => p.id == postId || p.key == postId || p.postId == postId);
      if (index != -1) {
        final post = list[index];
        list[index] = post.copyWith(
          repliesCount: (post.repliesCount ?? 0) + 1,
        );
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
      _savedPosts = posts.map((apiPost) {
        final model = _apiPostToModel(apiPost);
        return model.copyWith(isSaved: true);
      }).toList();
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
      _scheduledPosts = posts.map((apiPost) => _apiPostToModel(apiPost)).toList();
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