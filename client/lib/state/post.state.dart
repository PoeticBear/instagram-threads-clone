import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/model/media_draft_item.dart';
import 'package:threads/services/post_service.dart';
import 'package:threads/services/upload_service.dart';
import 'package:threads/services/follow_service.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/common/locator.dart';
import '../model/post.module.dart';
import '../network/api_exception.dart';

/// 创建帖子的结果。
///
/// - 成功：[postId] 非空（UI 用于跳转 / 提示），[isSuccess] = true
/// - 失败：[errorMessage] 是给用户看的简短描述（直接放进 SnackBar），
///   [error] / [stackTrace] 是给开发者日志用的完整异常，
///   [stage] 标记失败发生在哪个阶段（用于日志定位，如「上传媒体 #3/20」或「提交 post/create」）
class PostCreationResult {
  final String? postId;
  final String? errorMessage;
  final String? stage;
  final Object? error;
  final StackTrace? stackTrace;

  const PostCreationResult.success(this.postId)
      : errorMessage = null,
        stage = null,
        error = null,
        stackTrace = null;

  const PostCreationResult.failure({
    required this.errorMessage,
    this.stage,
    this.error,
    this.stackTrace,
  }) : postId = null;

  bool get isSuccess => postId != null;

  /// 从任意异常中提取「给用户看的简短消息」。
  static String _messageOf(Object e) {
    if (e is ApiException) return e.message;
    if (e is StateError) return e.message;
    return e.toString();
  }

  /// 构造一个失败结果（自动从异常提取消息）。
  factory PostCreationResult.fromException(
    Object e,
    StackTrace s, {
    required String stage,
  }) {
    return PostCreationResult.failure(
      errorMessage: _messageOf(e),
      stage: stage,
      error: e,
      stackTrace: s,
    );
  }
}

class PostState extends AppStates {
  /// AuthState 引用 —— 用于监听当前用户资料（profilePic/displayName/userName）变化，
  /// 当 EditProfilePage 提交新头像/昵称后，回写到 feedlist / userPosts / postDetail 等
  /// 所有缓存的 PostModel.user 字段，让首页 Feed / 个人中心 Threads Tab 等位置的
  /// 作者头像/昵称实时刷新（无需下拉刷新）。
  final AuthState _authState;
  VoidCallback? _authStateUserListener;

  PostState(this._authState) {
    _authStateUserListener = _syncCurrentUserAcrossLists;
    _authState.addListener(_authStateUserListener!);
  }

  bool isBusy = false;
  PostModel? _postToReplyModel;
  PostModel? get postToReplyModel => _postToReplyModel;
  set setPostToReply(PostModel model) {
    _postToReplyModel = model;
  }

  List<PostModel>? _feedlist;
  /// Feed 加载错误类型 key：
  /// - `null`：无错误（首次加载中 / 加载成功）
  /// - `'server'`：服务端异常（ServerException / 其他 ApiException）
  /// - `'network'`：网络异常（NetworkException，离线 / DNS 失败 / 连接超时）
  ///
  /// UI 据此区分『暂无帖子』和『加载失败 + 重试按钮』。
  /// 在 [getDataFromDatabase] / [refresh] 的 catch 中赋值，成功路径清空。
  String? _feedErrorKey;
  String? get feedErrorKey => _feedErrorKey;
  List<PostModel>? _userPosts; // 当前用户帖子列表（用于个人中心）
  List<PostModel>? _postDetailModelList;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isLoadingUserPosts = false;

  // ==================== 嵌套回复（Nested Replies）状态 ====================
  // 缓存策略:
  //   _topRepliesByPostId: postId -> 该帖子的一级回复列表(由 PostDetailPage 自己维护,
  //                          本字段暂作可选缓存,本任务暂不迁移 detail 页的一级状态)。
  //   _childRepliesByParent: parentReplyId -> 该回复的子回复列表(主缓存,跨 widget 共享)。
  //   _childPageByParent: parentReplyId -> 子回复当前分页(从 1 开始)。
  //   _childHasMoreByParent: parentReplyId -> 是否还有更多子回复。
  //   _childLoadingByParent: parentReplyId -> 是否正在加载(防止并发请求)。
  //   _expandedParentIds: 已展开的父回复 ID 集合(持久化展开态,避免重复网络请求)。
  final Map<String, List<Reply>> _topRepliesByPostId = {};
  final Map<String, List<Reply>> _childRepliesByParent = {};
  final Map<String, int> _childPageByParent = {};
  final Map<String, bool> _childHasMoreByParent = {};
  final Map<String, bool> _childLoadingByParent = {};
  final Set<String> _expandedParentIds = {};

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingUserPosts => _isLoadingUserPosts;

  List<PostModel>? get userPosts => _userPosts;

  List<PostModel>? get postDetailModel => _postDetailModelList;

  // ==================== 嵌套回复 Getters ====================

  /// 获取某父回复的子回复列表(只读快照,避免外部修改内部状态)。
  List<Reply> childRepliesFor(String parentReplyId) =>
      List.unmodifiable(_childRepliesByParent[parentReplyId] ?? const []);

  /// 该父回复是否已展开(用于"收起/展开"按钮文案切换)。
  bool isParentExpanded(String parentReplyId) =>
      _expandedParentIds.contains(parentReplyId);

  /// 该父回复是否正在加载子回复(用于 spinner 显示)。
  bool isChildLoading(String parentReplyId) =>
      _childLoadingByParent[parentReplyId] ?? false;

  /// 该父回复是否还有更多子回复(用于"加载更多"按钮显隐)。
  bool childHasMore(String parentReplyId) =>
      _childHasMoreByParent[parentReplyId] ?? true;

  List<PostModel>? get feedlist {
    if (_feedlist == null) {
      return null;
    } else {
      return List.from(_feedlist!);
    }
  }

  PostService? _postService;
  UploadService? _uploadService;
  FollowService? _followService;

  PostService get postService {
    _postService ??= PostService(apiClient: getIt());
    return _postService!;
  }

  UploadService get uploadService {
    _uploadService ??= UploadService(apiClient: getIt());
    return _uploadService!;
  }

  FollowService get followService {
    _followService ??= FollowService(apiClient: getIt());
    return _followService!;
  }

  /// Convert API Post to UI PostModel, preserving all quote/repost/thread data.
  PostModel _apiPostToModel(Post apiPost) {
    return PostModel(
      key: apiPost.id,
      postId: apiPost.id,
      bio: apiPost.content,
      createdAt: apiPost.createdAt.toIso8601String(),
      imagePath: apiPost.imageUrl,
      mediaList: apiPost.mediaList.map((m) => m.toMediaItemModel()).toList(),
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
      quotePost: apiPost.quotePost != null
          ? _apiPostToModel(apiPost.quotePost!)
          : null,
      isRepost: apiPost.isRepost,
      repostParentId: apiPost.repostParentId,
      threadPosts:
          apiPost.threadPosts.map((tp) => _apiPostToModel(tp)).toList(),
      threadPostIds: apiPost.threadPostIds,
      quotesCount: apiPost.quotesCount,
      // Edit-related fields
      isEdited: apiPost.isEdited,
      editCount: apiPost.editCount,
      lastEditTime: apiPost.lastEditTime,
      // Sensitive content fields
      isSensitive: apiPost.isSensitive,
      contentWarning: apiPost.contentWarning,
      // @mention 字段同步（服务端响应 → UI 模型）
      mentionedUserIds: apiPost.mentionedUserIds.isEmpty
          ? null
          : apiPost.mentionedUserIds,
      mentionedUsers: apiPost.mentionedUsers.isEmpty
          ? null
          : apiPost.mentionedUsers,
    );
  }

  Future<PostCreationResult> createPost(
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
    double? latitude,
    double? longitude,
    List<int>? topicIds,
    int? communityId,
    int? quoteRepostId,
    String? scheduledTime,
  }) async {
    // 当前阶段标记 — 出错时写入 PostCreationResult.stage，方便日志定位
    // 是「上传某张媒体」失败，还是「提交 post/create」失败。
    var stage = '准备';
    isBusy = true;
    notifyListeners();

    developer.log(
      '📝 [开始] createPost: mediaDrafts=${mediaDrafts?.length ?? 0}, '
      'imageFiles=${imageFiles?.length ?? 0}, '
      'preUploadedUrls=${preUploadedUrls?.length ?? 0}, '
      'pollOptions=${pollOptions?.length ?? 0}, '
      'scheduled=${scheduledTime != null}',
      name: 'PostState',
    );

    try {
      // 1) 处理媒体草稿：上传本地文件 → 收集 (mediaUrls, mediaTypes)
      List<String>? mediaUrls;
      List<int>? mediaTypes;
      if (mediaDrafts != null && mediaDrafts.isNotEmpty) {
        stage = '上传媒体';
        mediaUrls = [];
        mediaTypes = [];
        developer.log('📤 [上传阶段] 共 ${mediaDrafts.length} 个媒体待上传',
            name: 'PostState');
        for (int i = 0; i < mediaDrafts.length; i++) {
          final item = mediaDrafts[i];
          stage = '上传媒体 #${i + 1}/${mediaDrafts.length}';
          String url;
          if (item.needsUpload && item.localFile != null) {
            developer.log(
              '📤 [$stage] path=${item.localFile!.path}, '
              'mediaType=${item.mediaTypeInt}, durationMs=${item.durationMs}',
              name: 'PostState',
            );
            url = await uploadService.uploadMedia(
              item.localFile!,
              mediaType: item.mediaTypeInt,
              durationMs: item.durationMs,
            );
            developer.log('✅ [$stage] 成功 → $url', name: 'PostState');
          } else {
            url = item.remoteUrl ?? '';
            developer.log('⏭ [$stage] 跳过上传（已存在）→ $url', name: 'PostState');
          }
          if (url.isEmpty) {
            throw StateError('MediaDraftItem[$i] has no URL after upload');
          }
          mediaUrls.add(url);
          mediaTypes.add(item.mediaTypeInt);
        }
      } else if (imageFiles != null && imageFiles.isNotEmpty) {
        // 兼容旧 API：纯图片
        stage = '上传图片（旧 API）';
        mediaUrls = [...?preUploadedUrls];
        mediaTypes = mediaUrls.map((_) => MediaType.image).toList();
        developer.log('📤 [上传阶段-旧API] 共 ${imageFiles.length} 张图片待上传',
            name: 'PostState');
        for (int i = 0; i < imageFiles.length; i++) {
          stage = '上传图片 #${i + 1}/${imageFiles.length}（旧 API）';
          final cosUrl = await uploadService.uploadImage(imageFiles[i]);
          developer.log('✅ [$stage] 成功 → $cosUrl', name: 'PostState');
          mediaUrls.add(cosUrl);
          mediaTypes.add(MediaType.image);
        }
      } else if (preUploadedUrls != null && preUploadedUrls.isNotEmpty) {
        mediaUrls = [...preUploadedUrls];
        mediaTypes = mediaUrls.map((_) => MediaType.image).toList();
      }

      // 2) 提交到 post/create
      stage = '提交 post/create';
      final payload = <String, dynamic>{
        'content': model.bio ?? '',
        'media_count': mediaUrls?.length ?? 0,
        'replyType': replyType,
        'communityId': communityId,
        'quoteRepostId': quoteRepostId,
        'scheduled': scheduledTime != null,
      };
      developer.log('📞 [$stage] payload=${payload.toString()}',
          name: 'PostState');

      final post = await postService.createPost(
        content: model.bio ?? '',
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        pollOptions: pollOptions,
        replyType: replyType,
        replyToPostId: model.replyToPostId,
        replyToUserId: model.replyToUserId != null
            ? int.tryParse(model.replyToUserId!)
            : null,
        location: location,
        latitude: latitude,
        longitude: longitude,
        topicIds: topicIds,
        communityId: communityId,
        quoteRepostId: quoteRepostId,
        scheduledTime: scheduledTime,
        // 透传被提及用户 userId 列表（需求 1：身份绑定）。
        mentionedUserIds: model.mentionedUserIds,
      );

      developer.log('✅ [完成] 帖子创建成功: postId=${post.id}', name: 'PostState');

      // Convert API Post → PostModel. 复用 _apiPostToModel 而不是手写构造，
      // 否则会漏掉 quoteRepostId / quotePost 等字段，导致引用帖发布后被引用
      // 区域不显示（必须刷新 Feed 才能看到）。
      final newPost = _apiPostToModel(post);

      if (scheduledTime == null) {
        _feedlist ??= [];
        _feedlist!.insert(0, newPost);
      }

      isBusy = false;
      notifyListeners();
      return PostCreationResult.success(post.id);
    } catch (error, stackTrace) {
      developer.log(
        '❌ [失败 stage="$stage"] $error',
        name: 'PostState',
        error: error,
        stackTrace: stackTrace,
      );
      isBusy = false;
      notifyListeners();
      return PostCreationResult.fromException(error, stackTrace, stage: stage);
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
      _feedErrorKey = null; // 重置错误标记，避免上次失败的状态残留
      _currentPage = 1;
      _hasMore = true;
      notifyListeners();

      final posts = await postService.getFeed();

      _feedlist = posts.map((apiPost) {
        return _apiPostToModel(apiPost);
      }).toList();

      // Sort by createdAt descending
      _feedlist!.sort((x, y) =>
          DateTime.parse(y.createdAt).compareTo(DateTime.parse(x.createdAt)));

      isBusy = false;
      notifyListeners();
    } catch (error) {
      developer.log('>>> getDataFromDatabase FAILED: $error',
          name: 'PostState');
      _feedErrorKey = _classifyFeedError(error);
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

      _feedlist!.sort((x, y) =>
          DateTime.parse(y.createdAt).compareTo(DateTime.parse(x.createdAt)));
      _feedErrorKey = null; // 刷新成功 → 清空错误标记
    } catch (error) {
      developer.log('>>> refresh FAILED: $error', name: 'PostState');
      _feedErrorKey = _classifyFeedError(error);
    }
    notifyListeners();
  }

  /// 把 feed 拉取异常归类为 UI 可识别的错误类型 key。
  /// - [NetworkException]（离线 / DNS / 连接超时）→ `'network'`
  /// - 其他 API 异常（含 [ServerException] 业务码失败 / 5xx）→ `'server'`
  /// - 未知异常保守按 `'server'` 处理（实际最常见）
  String _classifyFeedError(Object error) {
    if (error is NetworkException) return 'network';
    return 'server';
  }

  Future<bool> voteOnPoll(String postId, int optionId) async {
    // 提前解析 postId，非数字直接放弃（不抛、不发起网络请求）
    final pid = int.tryParse(postId);
    if (pid == null) {
      developer.log('>>> voteOnPoll: invalid postId=$postId',
          name: 'PostState');
      return false;
    }

    final postIndex =
        _feedlist?.indexWhere((p) => p.postId == postId || p.key == postId) ??
            -1;
    if (postIndex == -1) return false;

    final post = _feedlist![postIndex];
    final oldPollData = post.pollData;
    if (oldPollData == null) return false;

    // 1) 构造新的 PollData（局部辅助，避免重复写两次）
    PollData buildUpdated(
        {required int? votedOptionId, required int? deltaVotes}) {
      final updatedOptions = oldPollData.options.map((o) {
        if (o.id == optionId) {
          return PollOption(
              id: o.id,
              optionText: o.optionText,
              votesCount: o.votesCount + (deltaVotes ?? 0));
        }
        return o;
      }).toList();
      return oldPollData.copyWith(
        options: updatedOptions,
        totalVotes: oldPollData.totalVotes + (deltaVotes ?? 0),
        userVotedOptionId: votedOptionId,
      );
    }

    // 2) 乐观更新 _feedlist
    _feedlist![postIndex] = post.copyWith(
      pollData: buildUpdated(votedOptionId: optionId, deltaVotes: 1),
    );

    // 3) 乐观同步 _userPosts（仅 poll，不扩展到其他写操作）
    final userPostIndex = _userPosts?.indexWhere(
          (p) => p.postId == postId || p.key == postId,
        ) ??
        -1;
    if (userPostIndex != -1) {
      final userPost = _userPosts![userPostIndex];
      _userPosts![userPostIndex] = userPost.copyWith(
        pollData: buildUpdated(votedOptionId: optionId, deltaVotes: 1),
      );
    }
    notifyListeners();

    // 4) 调 API；失败回滚
    try {
      await postService.votePoll(pid, optionId);
      return true;
    } catch (error) {
      developer.log('>>> voteOnPoll FAILED: $error', name: 'PostState');
      _feedlist![postIndex] = post.copyWith(pollData: oldPollData);
      if (userPostIndex != -1) {
        _userPosts![userPostIndex] =
            _userPosts![userPostIndex].copyWith(pollData: oldPollData);
      }
      notifyListeners();
      return false;
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
        final newPosts =
            posts.map((apiPost) => _apiPostToModel(apiPost)).toList();

        _feedlist!.addAll(newPosts);
        _feedlist!.sort((x, y) =>
            DateTime.parse(y.createdAt).compareTo(DateTime.parse(x.createdAt)));
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

  /// 用户转发列表（GET /post/user/{user_id}/reposts）
  ///
  /// 返回该用户转发过的所有帖子（被转发原始帖子的完整信息），
  /// 用于个人中心 Reposts Tab。与 [getUserPosts] 行为对齐：
  /// 失败时返回空列表，不抛异常。
  ///
  /// 过滤 id 为空的记录（包装层 schema 异常时 Post.fromJson 会得到空 id），
  /// 防止「空壳帖子」污染列表。
  Future<List<PostModel>> getUserReposts(int userId) async {
    try {
      final posts = await postService.getUserReposts(userId);
      return posts
          .where((p) => p.id.isNotEmpty)
          .map((apiPost) => _apiPostToModel(apiPost))
          .toList();
    } catch (error) {
      return [];
    }
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
      final index =
          _feedlist!.indexWhere((p) => p.key == postId || p.postId == postId);
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
      // [debug] service Post 关键字段
      // ignore: avoid_print
      print('[fetchQuotePostDetail] id=$quotePostId '
          'content="${apiPost.content}" '
          'imageUrl=${apiPost.imageUrl} '
          'mediaList.len=${apiPost.mediaList.length} '
          'mediaList=${apiPost.mediaList.map((m) => "{type=${m.mediaType} url=${m.url} thumb=${m.thumbUrl} duration=${m.duration}").toList()}');
      return _apiPostToModel(apiPost);
    } catch (error) {
      developer.log('fetchQuotePostDetail failed for id=$quotePostId: $error',
          name: 'PostState');
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
      developer.log('repost API error (kept local state): $error',
          name: 'PostState');
    }
  }

  /// Unrepost a post (local-only until backend adds DELETE /post/repost/{id}).
  /// Sets isReposted=false and decrements repostsCount in the local list.
  Future<void> unrepost(String postId) async {
    _updatePostRepostStatus(postId, false);
  }

  void _updatePostRepostStatus(String postId, bool isReposted) {
    if (_feedlist != null) {
      final index =
          _feedlist!.indexWhere((p) => p.key == postId || p.postId == postId);
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
      developer.log('unsavePost failed, rolling back: $error',
          name: 'PostState');
      _updatePostSaveStatus(postId, true);
    }
  }

  void _updatePostSaveStatus(String postId, bool isSaved) {
    if (_feedlist != null) {
      final index =
          _feedlist!.indexWhere((p) => p.key == postId || p.postId == postId);
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
      developer.log('sharePost failed, rolling back: $error',
          name: 'PostState');
      _updatePostShareCount(postId, increment: false);
    }
  }

  void _updatePostShareCount(String postId, {required bool increment}) {
    if (_feedlist != null) {
      final index =
          _feedlist!.indexWhere((p) => p.key == postId || p.postId == postId);
      if (index != -1) {
        final post = _feedlist![index];
        _feedlist![index] = post.copyWith(
          sharesCount: (post.sharesCount ?? 0) + (increment ? 1 : -1),
        );
        notifyListeners();
      }
    }
  }

  // ==================== Follow / Unfollow ====================

  /// Follow a post's author with optimistic update.
  /// Sets the post's `isFollowing=true` locally first, then calls the API.
  /// Rolls back to `false` and rethrows on failure.
  ///
  /// 注：当前 API /post/feed 不返回 is_following 字段，PostModel.isFollowing
  /// 始终为 null（UI 视为「未关注」）。本方法首次执行后，Feed 中同一作者的
  /// 帖子 isFollowing 才会被乐观更新。
  Future<void> followPostAuthor(String postId, int userId) async {
    _setFollowing(postId, true);
    try {
      await followService.followUser(userId);
    } catch (error) {
      developer.log('followPostAuthor failed, rolling back: $error',
          name: 'PostState');
      _setFollowing(postId, false);
      rethrow;
    }
  }

  /// Unfollow a post's author with optimistic update.
  Future<void> unfollowPostAuthor(String postId, int userId) async {
    _setFollowing(postId, false);
    try {
      await followService.unfollowUser(userId);
    } catch (error) {
      developer.log('unfollowPostAuthor failed, rolling back: $error',
          name: 'PostState');
      _setFollowing(postId, true);
      rethrow;
    }
  }

  void _setFollowing(String postId, bool value) {
    if (_feedlist == null) return;
    final index =
        _feedlist!.indexWhere((p) => p.key == postId || p.postId == postId);
    if (index == -1) return;
    _feedlist![index] = _feedlist![index].copyWith(isFollowing: value);
    notifyListeners();
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
      developer.log('reportContent succeeded for targetId=$targetId',
          name: 'PostState');
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

  /// 编辑帖子（PUT /post/{post_id}）
  ///
  /// 服务端约束：帖子发布后 15 分钟内允许编辑，最多 5 次。
  /// 仅可编辑 [content] / [isSensitive] / [contentWarning]。
  /// 服务端拒绝时（超 15 分钟 / 达 5 次 / 网络错误）抛 ApiException，
  /// 返回 null，调用方应捕获并展示 message。
  Future<PostModel?> updatePost({
    required String postId,
    String? content,
    bool? isSensitive,
    String? contentWarning,
  }) async {
    try {
      final updated = await postService.updatePost(
        postId: postId,
        content: content,
        isSensitive: isSensitive,
        contentWarning: contentWarning,
      );
      final updatedModel = _apiPostToModel(updated);
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
      final index = list.indexWhere(
          (p) => p.id == postId || p.key == postId || p.postId == postId);
      if (index != -1) {
        final post = list[index];
        list[index] = post.copyWith(
          repliesCount: (post.repliesCount ?? 0) + 1,
        );
      }
    }
    notifyListeners();
  }

  /// Decrement repliesCount for a post (called after a reply is deleted).
  /// 计数不会减到负数。
  void decrementReplyCount(String postId) {
    for (final list in [_feedlist, _userPosts]) {
      if (list == null) continue;
      final index = list.indexWhere(
          (p) => p.id == postId || p.key == postId || p.postId == postId);
      if (index != -1) {
        final post = list[index];
        final current = post.repliesCount ?? 0;
        list[index] = post.copyWith(
          repliesCount: current > 0 ? current - 1 : 0,
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
          mediaList: updated.mediaList,
          // Edit-related fields
          isEdited: updated.isEdited,
          editCount: updated.editCount,
          lastEditTime: updated.lastEditTime,
          // Sensitive content fields
          isSensitive: updated.isSensitive,
          contentWarning: updated.contentWarning,
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
      final posts =
          await postService.getSavedPosts(page: page, pageSize: pageSize);
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
      _scheduledPosts =
          posts.map((apiPost) => _apiPostToModel(apiPost)).toList();
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
      developer.log('pinReply succeeded for replyId=$replyId',
          name: 'PostState');
    } catch (error) {
      developer.log('pinReply failed: $error', name: 'PostState');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> unpinReply(int replyId) async {
    try {
      await postService.unpinReply(replyId);
      developer.log('unpinReply succeeded for replyId=$replyId',
          name: 'PostState');
    } catch (error) {
      developer.log('unpinReply failed: $error', name: 'PostState');
      rethrow;
    }
    notifyListeners();
  }

  // ==================== 嵌套回复（Nested Replies）方法 ====================

  /// 首次加载某父回复的子回复列表。
  /// 若该父级已经展开过,会从缓存返回(避免重复请求);
  /// 若父级未展开或被收起过,则强制重新拉取。
  Future<void> loadChildReplies({
    required String postId,
    required String parentReplyId,
    int pageSize = 20,
    bool forceReload = false,
  }) async {
    // 防并发
    if (_childLoadingByParent[parentReplyId] == true) return;
    // 已展开且非强制刷新,直接展开即可
    if (!forceReload && _expandedParentIds.contains(parentReplyId)) {
      return;
    }

    _childLoadingByParent[parentReplyId] = true;
    notifyListeners();

    try {
      final parentIdInt = int.tryParse(parentReplyId);
      if (parentIdInt == null) {
        developer.log('loadChildReplies: invalid parentReplyId=$parentReplyId',
            name: 'PostState');
        return;
      }
      final list = await postService.getReplies(
        postId,
        page: 1,
        pageSize: pageSize,
        parentId: parentIdInt,
      );
      _childRepliesByParent[parentReplyId] = List<Reply>.from(list);
      _childPageByParent[parentReplyId] = 1;
      _childHasMoreByParent[parentReplyId] = list.length >= pageSize;
      _expandedParentIds.add(parentReplyId);
    } catch (error) {
      developer.log('loadChildReplies failed for parent=$parentReplyId: $error',
          name: 'PostState');
      rethrow;
    } finally {
      _childLoadingByParent[parentReplyId] = false;
      notifyListeners();
    }
  }

  /// 加载某父回复的子回复的下一页(分页)。
  Future<void> loadMoreChildReplies({
    required String postId,
    required String parentReplyId,
    int pageSize = 20,
  }) async {
    if (_childLoadingByParent[parentReplyId] == true) return;
    if (_childHasMoreByParent[parentReplyId] == false) return;
    // 未展开时不允许加载更多
    if (!_expandedParentIds.contains(parentReplyId)) return;

    _childLoadingByParent[parentReplyId] = true;
    notifyListeners();

    try {
      final next = (_childPageByParent[parentReplyId] ?? 1) + 1;
      final parentIdInt = int.tryParse(parentReplyId);
      if (parentIdInt == null) return;
      final list = await postService.getReplies(
        postId,
        page: next,
        pageSize: pageSize,
        parentId: parentIdInt,
      );
      final existing = _childRepliesByParent[parentReplyId] ?? <Reply>[];
      _childRepliesByParent[parentReplyId] = [...existing, ...list];
      _childPageByParent[parentReplyId] = next;
      _childHasMoreByParent[parentReplyId] = list.length >= pageSize;
    } catch (error) {
      developer.log(
          'loadMoreChildReplies failed for parent=$parentReplyId: $error',
          name: 'PostState');
    } finally {
      _childLoadingByParent[parentReplyId] = false;
      notifyListeners();
    }
  }

  /// 收起某父回复(仅关闭展开态,不清缓存,便于再次展开时快速恢复)。
  void collapseChildReplies(String parentReplyId) {
    if (!_expandedParentIds.remove(parentReplyId)) return;
    notifyListeners();
  }

  /// 创建一条嵌套(子)回复。
  /// 成功后将新回复乐观插入到对应父级的子回复列表,
  /// 同时父级 repliesCount +1,帖子总回复数 +1。
  /// 失败时返回 null,UI 层应捕获异常并提示用户。
  Future<Reply?> createChildReply({
    required String postId,
    required Reply parentReply,
    required String content,
  }) async {
    try {
      final parentIdInt = int.tryParse(parentReply.id);
      final newReply = await postService.createReply(
        postId: postId,
        content: content,
        parentId: parentIdInt,
      );
      // 1. 插入子回复列表(若父级未展开,先建立列表并展开)
      final children = _childRepliesByParent.putIfAbsent(
        parentReply.id,
        () => <Reply>[],
      );
      children.insert(0, newReply);
      _expandedParentIds.add(parentReply.id);
      _childPageByParent[parentReply.id] = 1;

      // 2. 父级 repliesCount +1
      _incrementParentRepliesCount(parentReply.id);

      // 3. 帖子总回复数 +1
      incrementReplyCount(postId);

      notifyListeners();
      return newReply;
    } catch (error) {
      developer.log('createChildReply failed: $error', name: 'PostState');
      rethrow;
    }
  }

  /// 在所有一级回复 map 中找到指定 parentReplyId 的父级并将其 repliesCount +1。
  /// 父级既可能在 _topRepliesByPostId 的某个列表里,也可能不在(由 PostDetailPage 持有)。
  /// 此处仅在 _topRepliesByPostId 命中时更新,detail 页持有的副本由其自身 setState 同步。
  void _incrementParentRepliesCount(String parentReplyId) {
    _topRepliesByPostId.forEach((_, replies) {
      final idx = replies.indexWhere((r) => r.id == parentReplyId);
      if (idx != -1) {
        final old = replies[idx];
        replies[idx] = old.copyWith(repliesCount: old.repliesCount + 1);
      }
    });
  }

  /// 局部更新 Reply(用于 like/pin 等只改 Reply 自身字段的操作)。
  /// 同时在 _topRepliesByPostId 和 _childRepliesByParent 两个 map 中按 id 替换。
  /// 不修改 _topRepliesByPostId 中未命中的列表(即 detail 页持有的副本由其自身同步)。
  void updateReplyInLists(Reply updated) {
    _replaceIn(_topRepliesByPostId, updated);
    _replaceIn(_childRepliesByParent, updated);
    notifyListeners();
  }

  void _replaceIn(Map<String, List<Reply>> map, Reply updated) {
    map.forEach((_, list) {
      final idx = list.indexWhere((r) => r.id == updated.id);
      if (idx != -1) list[idx] = updated;
    });
  }

  /// 清理某 reply 在所有嵌套回复缓存中的痕迹(删除时调用)。
  /// - 移除该 reply 的子回复缓存(包括分页 / 加载态 / 展开态)
  /// - 移除子回复列表中对该 reply 的引用(防止悬挂)
  /// - 移除一级缓存列表中的引用(若命中)
  void removeReply(String replyId) {
    // 1. 清理该 reply 自己的子回复缓存
    _childRepliesByParent.remove(replyId);
    _childPageByParent.remove(replyId);
    _childHasMoreByParent.remove(replyId);
    _childLoadingByParent.remove(replyId);
    _expandedParentIds.remove(replyId);

    // 2. 从子回复列表中移除(可能该 reply 自己是某父级的子)
    _childRepliesByParent.forEach((_, list) {
      list.removeWhere((r) => r.id == replyId);
    });

    // 3. 从一级回复列表中移除
    _topRepliesByPostId.forEach((_, list) {
      list.removeWhere((r) => r.id == replyId);
    });

    notifyListeners();
  }

  // ==================== 当前用户资料同步（AuthState → PostState）====================

  /// 当前用户资料变化时（EditProfilePage 提交头像 / 昵称 / 用户名后，
  /// 或登录 / 登出 / 换号场景），把所有缓存列表中 author = 当前用户的
  /// PostModel.user 字段同步到最新值，再 notifyListeners。
  ///
  /// 覆盖范围：
  ///   - `_feedlist`（首页 Feed）
  ///   - `_userPosts`（个人中心 Threads Tab）
  ///   - `_postDetailModelList`（帖子详情缓存）
  ///   - `_savedPosts`（已保存）
  ///   - `_scheduledPosts`（定时发布）
  ///   - `_postToReplyModel`（回复目标单帖）
  ///
  /// 每个 PostModel 内部还会递归处理 `quotePost`（引用帖作者也是自己）
  /// 与 `threadPosts`（Thread 链中的自己）。
  ///
  /// 不会循环：只写自己的字段，不修改 AuthState。
  /// 性能：feedlist 较大时遍历 O(n)，但 AuthState.notifyListeners 非高频
  /// （登录/登出/资料更新），且仅在值真正变化时才 notify。
  void _syncCurrentUserAcrossLists() {
    final me = _authState.userModel;
    if (me == null) return;
    final myUserId = me.userId;
    if (myUserId == null) return;

    final newPic = me.profilePic ?? '';
    final newName = me.userName ?? '';
    final newDisp = me.displayName ?? '';

    bool changed = false;

    bool syncList(List<PostModel>? list) {
      if (list == null) return false;
      bool listChanged = false;
      for (var i = 0; i < list.length; i++) {
        final updated = _syncPostUser(
          list[i], myUserId, newPic, newName, newDisp,
        );
        if (updated != null) {
          list[i] = updated;
          listChanged = true;
        }
      }
      return listChanged;
    }

    if (syncList(_feedlist)) changed = true;
    if (syncList(_userPosts)) changed = true;
    if (syncList(_postDetailModelList)) changed = true;
    if (syncList(_savedPosts)) changed = true;
    if (syncList(_scheduledPosts)) changed = true;

    // 单条回复目标
    if (_postToReplyModel != null) {
      final updated = _syncPostUser(
        _postToReplyModel!, myUserId, newPic, newName, newDisp,
      );
      if (updated != null) {
        _postToReplyModel = updated;
        changed = true;
      }
    }

    if (changed) {
      developer.log(
        '🔄 PostState._syncCurrentUserAcrossLists: '
        'feedlist=${_feedlist?.length ?? 0}, '
        'userPosts=${_userPosts?.length ?? 0}, '
        'postDetail=${_postDetailModelList?.length ?? 0}, '
        'saved=${_savedPosts.length}, '
        'scheduled=${_scheduledPosts.length}',
        name: 'PostState',
      );
      notifyListeners();
    }
  }

  /// 若 [post] 的作者 = 当前用户且其 profilePic/displayName/userName 与最新值不同，
  /// 返回替换了 user 字段的新 PostModel；否则返回 null（表示无需更新）。
  ///
  /// 递归处理 `quotePost` 与 `threadPosts`，覆盖「引用帖作者也是自己」
  /// / 「Thread 链中包含自己」的场景。
  PostModel? _syncPostUser(
    PostModel post,
    int myUserId,
    String newPic,
    String newName,
    String newDisp,
  ) {
    final user = post.user;
    bool needUpdate = false;
    UserModel? updatedUser;

    if (user != null && user.userId == myUserId) {
      final curPic = user.profilePic ?? '';
      final curName = user.userName ?? '';
      final curDisp = user.displayName ?? '';
      final picDiff = newPic.isNotEmpty && newPic != curPic;
      final nameDiff = newName.isNotEmpty && newName != curName;
      final dispDiff = newDisp.isNotEmpty && newDisp != curDisp;
      if (picDiff || nameDiff || dispDiff) {
        updatedUser = user.copyWith(
          profilePic: picDiff ? newPic : null,
          userName: nameDiff ? newName : null,
          displayName: dispDiff ? newDisp : null,
        );
        needUpdate = true;
      }
    }

    // 递归 quotePost（引用帖作者也可能是自己）
    PostModel? updatedQuote;
    if (post.quotePost != null) {
      updatedQuote = _syncPostUser(
        post.quotePost!, myUserId, newPic, newName, newDisp,
      );
      if (updatedQuote != null) needUpdate = true;
    }

    // 递归 threadPosts（Thread 链中也可能包含自己的帖子）
    List<PostModel>? updatedThreads;
    if (post.threadPosts != null && post.threadPosts!.isNotEmpty) {
      bool threadChanged = false;
      updatedThreads = List<PostModel>.from(post.threadPosts!);
      for (var i = 0; i < updatedThreads.length; i++) {
        final updated = _syncPostUser(
          updatedThreads[i], myUserId, newPic, newName, newDisp,
        );
        if (updated != null) {
          updatedThreads[i] = updated;
          threadChanged = true;
        }
      }
      if (!threadChanged) updatedThreads = null;
    }

    if (!needUpdate) return null;

    return post.copyWith(
      user: updatedUser, // null 时 copyWith 保留原值
      quotePost: updatedQuote, // null 时保留原值
      threadPosts: updatedThreads, // null 时保留原值
    );
  }

  @override
  void dispose() {
    if (_authStateUserListener != null) {
      _authState.removeListener(_authStateUserListener!);
      _authStateUserListener = null;
    }
    super.dispose();
  }
}
