import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/profile.state.dart';
import 'profile.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
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
