import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/profile.state.dart';
import 'profile.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 只跟踪 AuthState.userId 这一个字段：
    //   - userId 从空字符串变成真实 ID 时（登录完成 / Splash 恢复会话）触发一次重建，
    //     从而进入下面的 ChangeNotifierProvider 分支，创建 ProfileState 并加载资料。
    //   - userId 不变时 Selector 不会通知，ProfileState 实例被保留，
    //     避免下拉刷新等场景因 AuthState.notifyListeners 把已加载数据丢掉。
    //   - 用 ValueKey(profileId) 让 userId 真正切换（如登出再换号登录）时
    //     ChangeNotifierProvider 被识别为新节点，重新 create 出干净的 ProfileState。
    return Selector<AuthState, String>(
      selector: (_, auth) => auth.userId,
      builder: (context, profileId, _) {
        if (profileId.isEmpty) {
          // 尚未拿到 userId（未登录 / 登录中 / 拉取用户信息失败）
          // 给一个轻量占位，等 userId 就绪后会自动重建。
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(child: CupertinoActivityIndicator()),
          );
        }

        return ChangeNotifierProvider(
          key: ValueKey(profileId),
          // 把当前登录用户的 ID 显式传给 ProfileState，
          // 让 isMyProfile 优先用 AuthState.userId 而不是只依赖缓存里的 userId。
          // 修复登录后第一次打开个人中心显示"关注"按钮的 bug。
          create: (_) => ProfileState(profileId, currentUserId: profileId),
          child: ProfilePage(
            profileId: profileId,
            isOwnProfileTab: true,
          ),
        );
      },
    );
  }
}
