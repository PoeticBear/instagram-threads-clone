import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:threads/model/bug_report.dart';

/// Bug 反馈工单上报服务。
///
/// ⚠️ 云端接入方式待定 —— 当前为 **stub**：把工单（描述 + 截图 + 元信息）
/// 写进应用沙盒临时目录并打印 log，使「截屏 → 弹表单 → 提交 → 反馈」
/// 全链路在客户端可测。
///
/// 云端方案确定后，**只需替换 [_writeStub] 的方法体**（写本地 → 上传云端），
/// 调用方（[BugFeedbackSheet]）与数据契约（[BugReport]）零改动。
class BugReportService {
  BugReportService._();
  static final BugReportService instance = BugReportService._();

  /// 组装工单并上报。
  ///
  /// - [description]：用户填写的描述（必填）。
  /// - [screenshotPath]：截图本地路径，可空（取相册失败时）。
  /// - [userId] / [currentRoute]：由 UI 层（持有 BuildContext）传入。
  ///
  /// 返回 true 表示 stub 写盘成功。
  Future<bool> submit({
    required String description,
    String? screenshotPath,
    String? userId,
    String? currentRoute,
  }) async {
    try {
      final meta = await _collectMeta();
      final report = BugReport(
        description: description,
        screenshotPath: screenshotPath,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        currentRoute: currentRoute,
        appVersion: meta.appVersion,
        buildNumber: meta.buildNumber,
        deviceModel: meta.deviceModel,
        osVersion: meta.osVersion,
      );
      return await _writeStub(report);
    } catch (e, st) {
      debugPrint('[BugReport] submit failed: $e\n$st');
      return false;
    }
  }

  /// 采集 app 版本 / 机型 / 系统版本等静态元信息。
  /// 各步独立 try/catch：单项失败不阻断整单上报。
  Future<_MetaBundle> _collectMeta() async {
    String? appVersion, buildNumber, deviceModel, osVersion;
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = pkg.version;
      buildNumber = pkg.buildNumber;
    } catch (e) {
      debugPrint('[BugReport] PackageInfo failed: $e');
    }
    try {
      if (Platform.isIOS) {
        final ios = await DeviceInfoPlugin().iosInfo;
        // utsname.machine 形如 "iPhone14,2"，比 .model ("iPhone") 更利于定位机型。
        deviceModel = ios.utsname.machine;
        osVersion = ios.systemVersion;
      }
    } catch (e) {
      debugPrint('[BugReport] DeviceInfo failed: $e');
    }
    return _MetaBundle(
      appVersion: appVersion,
      buildNumber: buildNumber,
      deviceModel: deviceModel,
      osVersion: osVersion,
    );
  }

  /// STUB：写本地沙盒 + 打 log。
  /// 云端确定后，把这里的「写盘」换成「上传」即可，签名不变。
  Future<bool> _writeStub(BugReport report) async {
    final dir = await getTemporaryDirectory();
    final bugDir = Directory('${dir.path}/bug_reports');
    if (!await bugDir.exists()) {
      await bugDir.create(recursive: true);
    }

    String? savedShotPath;
    if (report.screenshotPath != null) {
      final src = File(report.screenshotPath!);
      if (await src.exists()) {
        savedShotPath = '${bugDir.path}/screenshot_${report.createdAt}.png';
        await src.copy(savedShotPath);
      }
    }

    final json = report.toJson();
    if (savedShotPath != null) json['screenshot'] = savedShotPath;
    final metaFile = File('${bugDir.path}/report_${report.createdAt}.json');
    await metaFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );

    debugPrint('[BugReport] STUB saved → ${metaFile.path}');
    debugPrint('[BugReport] $report');
    return true;
  }
}

class _MetaBundle {
  final String? appVersion;
  final String? buildNumber;
  final String? deviceModel;
  final String? osVersion;
  const _MetaBundle({
    this.appVersion,
    this.buildNumber,
    this.deviceModel,
    this.osVersion,
  });
}
