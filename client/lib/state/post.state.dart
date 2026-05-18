import 'dart:async';
import 'dart:io';
import 'package:threads/helper/utility.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/post_service.dart';
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
  List<PostModel>? _postDetailModelList;

  List<PostModel>? get postDetailModel => _postDetailModelList;

  List<PostModel>? get feedlist {
    if (_feedlist == null) {
      return null;
    } else {
      return List.from(_feedlist!.reversed);
    }
  }

  PostService? _postService;

  PostService get postService {
    _postService ??= PostService(apiClient: getIt());
    return _postService!;
  }

  Future<String?> createPost(PostModel model, {File? imageFile}) async {
    try {
      isBusy = true;
      notifyListeners();

      String? imageUrl;
      if (imageFile != null) {
        // Upload image first - this would use UploadService
        // For now, we skip image upload as it requires UploadService
      }

      final post = await postService.createPost(
        content: model.bio ?? '',
        imageUrl: imageUrl ?? model.imagePath,
        replyToPostId: model.replyToPostId,
        replyToUserId: model.replyToUserId != null ? int.tryParse(model.replyToUserId!) : null,
      );

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
      );

      _feedlist ??= [];
      _feedlist!.add(newPost);

      isBusy = false;
      notifyListeners();
      return post.id;
    } catch (error) {
      isBusy = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> uploadFile(File file) async {
    // This would use UploadService - placeholder for now
    return null;
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
    if (userModel == null) {
      return null;
    }

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
      notifyListeners();

      final posts = await postService.getFeed();

      _feedlist = posts.map((apiPost) => PostModel(
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
      )).toList();

      // Sort by createdAt descending
      _feedlist!.sort((x, y) => DateTime.parse(y.createdAt)
          .compareTo(DateTime.parse(x.createdAt)));

      isBusy = false;
      notifyListeners();
    } catch (error) {
      _feedlist = null;
      isBusy = false;
      notifyListeners();
    }
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
      )).toList();
    } catch (error) {
      return [];
    }
  }

  Future<void> likePost(String postId) async {
    try {
      await postService.likePost(postId);
      // Update local state
      _updatePostLikeStatus(postId, true);
    } catch (error) {
      // Handle error
    }
  }

  Future<void> unlikePost(String postId) async {
    try {
      await postService.unlikePost(postId);
      // Update local state
      _updatePostLikeStatus(postId, false);
    } catch (error) {
      // Handle error
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
}