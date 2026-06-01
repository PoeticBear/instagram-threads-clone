import 'package:flutter/material.dart';
import '../model/draft.module.dart';
import '../services/post_service.dart';
import '../common/locator.dart';

class DraftState extends ChangeNotifier {
  PostService? _postService;
  PostService get postService {
    _postService ??= PostService(apiClient: getIt());
    return _postService!;
  }

  List<DraftInfo> _drafts = [];
  List<DraftInfo> get drafts => _drafts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadDrafts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _drafts = await postService.getDrafts();
    } catch (_) {
      _drafts = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<DraftInfo?> saveDraft({
    required String content,
    List<String>? mediaUrls,
    List<String>? pollOptions,
    int? topicId,
    int? replyType,
    String? location,
  }) async {
    try {
      final draft = await postService.saveDraft(
        content: content,
        mediaUrls: mediaUrls,
        pollOptions: pollOptions,
        topicId: topicId,
        replyType: replyType,
        location: location,
      );
      _drafts.insert(0, draft);
      notifyListeners();
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteDraft(int draftId) async {
    try {
      await postService.deleteDraft(draftId);
      _drafts.removeWhere((d) => d.id == draftId);
      notifyListeners();
    } catch (_) {}
  }

  Future<DraftInfo?> loadDraftForEditing(int draftId) async {
    try {
      return await postService.getDraftDetail(draftId);
    } catch (_) {
      return null;
    }
  }
}
