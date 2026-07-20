import 'dart:convert';

/// 内部测试 Bug 反馈工单的数据模型。
///
/// 由 [BugFeedbackSheet] 在用户提交时组装，交给 [BugReportService] 上报。
/// 云端接入方式待定 —— 当前 [BugReportService] 为 stub（写本地沙盒 + 打 log），
/// 故本模型同时承担 stub 落盘的 JSON 结构。
class BugReport {
  final String description;
  final String? screenshotPath;

  /// 自动采集的定位元信息（便于排查「谁、在哪、什么版本、什么机型」遇到的问题）。
  final String? appVersion;
  final String? buildNumber;
  final String? deviceModel;
  final String? osVersion;
  final String? currentRoute;
  final String? userId;

  /// 毫秒时间戳。
  final int createdAt;

  const BugReport({
    required this.description,
    required this.createdAt,
    this.screenshotPath,
    this.appVersion,
    this.buildNumber,
    this.deviceModel,
    this.osVersion,
    this.currentRoute,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'screenshot': screenshotPath,
        'metadata': {
          'appVersion': appVersion,
          'buildNumber': buildNumber,
          'deviceModel': deviceModel,
          'osVersion': osVersion,
          'currentRoute': currentRoute,
          'userId': userId,
        },
        'createdAt': createdAt,
      };

  @override
  String toString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
