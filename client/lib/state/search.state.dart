import 'package:threads/helper/enum.dart';
import 'package:threads/helper/utility.dart';
import 'package:threads/model/user.module.dart';
import 'package:threads/services/search_service.dart';
import 'package:threads/state/app.state.dart';
import 'package:threads/common/locator.dart';

class SearchState extends AppStates {
  bool isBusy = false;
  SortUser sortBy = SortUser.MAX_FOLLOWER;
  List<UserModel>? _userFilterlist;
  List<UserModel>? _userlist;

  List<UserModel>? get userlist {
    if (_userFilterlist == null) {
      return null;
    } else {
      return List.from(_userFilterlist!);
    }
  }

  SearchService? _searchService;

  SearchService get searchService {
    _searchService ??= SearchService(apiClient: getIt());
    return _searchService!;
  }

  Future<void> getDataFromDatabase() async {
    try {
      isBusy = true;
      notifyListeners();

      // Use search API to get all users
      final result = await searchService.search(query: '', pageSize: 100);

      _userlist = result.users.map((info) => UserModel(
        userId: info.userId,
        userName: info.username,
        displayName: info.displayName,
        bio: info.bio,
        profilePic: info.profilePic,
        followersCount: info.followersCount,
        followingCount: info.followingCount,
      )).toList();

      _userFilterlist = List.from(_userlist!);

      isBusy = false;
      notifyListeners();
    } catch (error) {
      _userlist = null;
      _userFilterlist = null;
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      _userFilterlist = List.from(_userlist!);
      notifyListeners();
      return;
    }

    try {
      isBusy = true;
      notifyListeners();

      final result = await searchService.search(query: query);

      _userFilterlist = result.users.map((info) => UserModel(
        userId: info.userId,
        userName: info.username,
        displayName: info.displayName,
        bio: info.bio,
        profilePic: info.profilePic,
        followersCount: info.followersCount,
        followingCount: info.followingCount,
      )).toList();

      isBusy = false;
      notifyListeners();
    } catch (error) {
      isBusy = false;
      notifyListeners();
    }
  }

  void filterByUsername(String? name) {
    if (name != null &&
        name.isEmpty &&
        _userlist != null &&
        _userlist!.length != _userFilterlist!.length) {
      _userFilterlist = List.from(_userlist!);
    }
    if (_userlist == null || _userlist!.isEmpty) {
      print("User list is empty");
      return;
    } else if (name != null) {
      _userFilterlist = _userlist!
          .where((x) =>
              x.userName != null &&
              x.userName!.toLowerCase().contains(name.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  String get selectedFilter {
    switch (sortBy) {
      case SortUser.ALPHABETICALY:
        _userFilterlist!.sort((x, y) => (x.displayName ?? '').compareTo(y.displayName ?? ''));
        return "ALPHABETICALY";

      case SortUser.MAX_FOLLOWER:
        _userFilterlist!.sort((x, y) => (y.followersCount ?? 0).compareTo(x.followersCount ?? 0));
        return "Popular";

      case SortUser.NEWEST:
        _userFilterlist!.sort((x, y) =>
            DateTime.parse(y.createAt ?? DateTime.now().toIso8601String())
                .compareTo(DateTime.parse(x.createAt ?? DateTime.now().toIso8601String())));
        return "NEWEST user";

      case SortUser.OLDEST:
        _userFilterlist!.sort((x, y) =>
            DateTime.parse(x.createAt ?? DateTime.now().toIso8601String())
                .compareTo(DateTime.parse(y.createAt ?? DateTime.now().toIso8601String())));
        return "OLDEST user";

      case SortUser.VERIFIED:
        return "VERIFIED user";

      default:
        return "Unknown";
    }
  }

  List<UserModel> userList = [];

  List<UserModel> getuserDetail(List<String> userIds) {
    if (_userlist == null) return [];

    final list = _userlist!.where((x) {
      if (userIds.contains(x.userId?.toString()) || userIds.contains(x.key)) {
        return true;
      } else {
        return false;
      }
    }).toList();
    return list;
  }
}