import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:threads/helper/enum.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/pages/profile/profile.dart';
import 'package:threads/state/auth.state.dart';
import 'package:provider/provider.dart';

class DeepLinkService {
  static DeepLinkService? _instance;
  static DeepLinkService get instance => _instance ??= DeepLinkService._();

  DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  Uri? _pendingLink;

  void init() {
    // Check initial link (cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleLink(uri);
      }
    }).catchError((e) {
      debugPrint('DeepLinkService.getInitialLink error: $e');
    });

    // Listen for incoming links (warm start / resume)
    _sub = _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (e) {
        debugPrint('DeepLinkService.uriLinkStream error: $e');
      },
    );
  }

  void dispose() {
    _sub?.cancel();
  }

  void _handleLink(Uri uri) {
    debugPrint('DeepLinkService._handleLink: $uri');

    if (uri.scheme != 'threads') return;

    final context = navigatorKey.currentContext;
    if (context == null) {
      _pendingLink = uri;
      return;
    }

    // Wait until user is logged in
    final authState = Provider.of<AuthState>(context, listen: false);
    if (authState.authStatus != AuthStatus.LOGGED_IN) {
      _pendingLink = uri;
      return;
    }

    _navigateFromUri(uri);
  }

  /// Called after login completes to process any pending deep link
  void processPendingLink() {
    if (_pendingLink != null) {
      final link = _pendingLink;
      _pendingLink = null;
      _navigateFromUri(link!);
    }
  }

  void _navigateFromUri(Uri uri) {
    // Expected format: threads://user/{userId}
    if (uri.host == 'user' && uri.pathSegments.isNotEmpty) {
      final userId = uri.pathSegments.first;
      if (userId.isNotEmpty) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          Navigator.of(context).push(ProfilePage.getRoute(profileId: userId));
        }
      }
    }
  }
}
