import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:threads/model/bug_report.dart';

/// 把 Bug 工单投递到专用 GitHub private repo（Issue + 截图附件）。
///
/// 认证：编译期注入的 fine-grained PAT（仅授权本 repo 的 Contents / Issues
/// 读写）。token 经 `--dart-define=BUG_GITHUB_TOKEN` 注入，值来自发版机的
/// 环境变量（**不进 git**）。
///
/// 数据流：
///   ① PUT  /repos/{owner}/{repo}/contents/screenshots/{ts}.png  （截图 base64）
///        → 得到 raw.githubusercontent.com URL
///   ② POST /repos/{owner}/{repo}/issues                          （建 Issue，body 引用 raw URL）
///
/// 仅 TestFlight 构建生效（App Store 包 `FEEDBACK_ENABLED=false`，本类连同
/// 整个反馈模块被 tree-shake）。即便如此，PAT 仍限定单 repo 权限，进一步
/// 收窄 token 泄露的爆炸半径。
class GitHubBugClient {
  GitHubBugClient._();

  /// fine-grained PAT。空 → 未配置 → 调用方走本地 stub fallback。
  static const _token = String.fromEnvironment('BUG_GITHUB_TOKEN');

  static const _repo = String.fromEnvironment(
    'BUG_GITHUB_REPO',
    defaultValue: 'PoeticBear/app-bug-reports',
  );

  static const _apiBase = 'https://api.github.com';

  static bool get isConfigured =>
      _token.isNotEmpty && _repo.contains('/');

  static String get _owner => _repo.split('/').first;

  static String get _repoName => _repo.split('/').last;

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  /// 推截图到 repo 的 `screenshots/` 目录，返回可被 Issue body 引用的 raw URL。
  /// 失败返回 null（调用方仍可建无图 Issue）。
  static Future<String?> uploadScreenshot(File image) async {
    if (!isConfigured) return null;
    try {
      final bytes = await image.readAsBytes();
      final content = base64Encode(bytes);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'screenshots/$ts.png';

      final res = await http.put(
        Uri.parse('$_apiBase/repos/$_owner/$_repoName/contents/$path'),
        headers: _headers,
        body: jsonEncode({
          'message': 'chore: bug screenshot $ts',
          'content': content,
        }),
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        debugPrint(
            '[GitHubBug] uploadScreenshot failed: ${res.statusCode} ${res.body}');
        return null;
      }
      return 'https://raw.githubusercontent.com/$_owner/$_repoName/main/$path';
    } catch (e) {
      debugPrint('[GitHubBug] uploadScreenshot error: $e');
      return null;
    }
  }

  /// 创建 Issue。返回 issue 编号（>0 成功），失败返回 null。
  static Future<int?> createIssue({
    required String description,
    String? screenshotRawUrl,
    required BugReport meta,
  }) async {
    if (!isConfigured) return null;
    try {
      final body = _buildIssueBody(description, screenshotRawUrl, meta);
      final title = description.length > 50
          ? '[Bug] ${description.substring(0, 50)}…'
          : '[Bug] $description';

      final res = await http.post(
        Uri.parse('$_apiBase/repos/$_owner/$_repoName/issues'),
        headers: _headers,
        body: jsonEncode({
          'title': title,
          'body': body,
          'labels': const ['from-app'],
        }),
      );
      if (res.statusCode != 201) {
        debugPrint(
            '[GitHubBug] createIssue failed: ${res.statusCode} ${res.body}');
        return null;
      }
      return (jsonDecode(res.body) as Map<String, dynamic>)['number'] as int?;
    } catch (e) {
      debugPrint('[GitHubBug] createIssue error: $e');
      return null;
    }
  }

  static String _buildIssueBody(
    String description,
    String? screenshotRawUrl,
    BugReport meta,
  ) {
    final b = StringBuffer()
      ..writeln('## 描述')
      ..writeln(description)
      ..writeln();
    if (screenshotRawUrl != null) {
      b
        ..writeln('## 截图')
        ..writeln('![]($screenshotRawUrl)')
        ..writeln();
    }
    b
      ..writeln('## 环境')
      ..writeln('- 版本：${meta.appVersion ?? '-'}+${meta.buildNumber ?? '-'}')
      ..writeln('- 机型：${meta.deviceModel ?? '-'}')
      ..writeln('- 系统：iOS ${meta.osVersion ?? '-'}')
      ..writeln('- 用户：${meta.userId ?? '-'}')
      ..writeln('- 页面：${meta.currentRoute ?? '-'}')
      ..writeln('- 时间：${DateTime.fromMillisecondsSinceEpoch(meta.createdAt)}');
    return b.toString();
  }
}
