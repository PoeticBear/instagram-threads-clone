import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/profile.state.dart';
import 'profile.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 关键：必须用 listen: false。
    // 否则 AuthState 任何 notifyListeners()（例如下拉刷新后调 getProfileUser）
    // 都会导致 MyProfilePage 重建，ChangeNotifierProvider 会丢弃并重建 ProfileState，
    // 丢失已加载的数据。
    final authState = Provider.of<AuthState>(context, listen: false);
    final profileId = authState.userId.toString();

    if (profileId.isEmpty) {
      return const SizedBox.shrink();
    }

    return ChangeNotifierProvider(
      create: (_) => ProfileState(profileId),
      child: ProfilePage(
        profileId: profileId,
        isOwnProfileTab: true,
      ),
    );
  }
}
