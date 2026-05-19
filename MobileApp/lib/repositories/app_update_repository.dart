import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/dio_client.dart';

class AppUpdateInfo {
  final String platform;
  final String latestVersionName;
  final int latestVersionCode;
  final int minSupportedVersionCode;
  final bool hasUpdate;
  final bool forceUpdate;
  final String downloadUrl;
  final String releaseNotes;

  const AppUpdateInfo({
    required this.platform,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.minSupportedVersionCode,
    required this.hasUpdate,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      platform: (json['platform'] ?? 'android').toString(),
      latestVersionName: (json['latestVersionName'] ?? '').toString(),
      latestVersionCode: _toInt(json['latestVersionCode']),
      minSupportedVersionCode: _toInt(json['minSupportedVersionCode']),
      hasUpdate: json['hasUpdate'] == true,
      forceUpdate: json['forceUpdate'] == true,
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      releaseNotes: (json['releaseNotes'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AppUpdateRepository {
  final ApiClient apiClient;

  AppUpdateRepository({required this.apiClient});

  Future<AppUpdateInfo> checkLatest() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final versionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    final platform = _platformName();

    final response = await apiClient.dio.get('/app/version', queryParameters: {
      'platform': platform,
      'versionName': packageInfo.version,
      'versionCode': versionCode,
    });

    if (response.statusCode == 200 && response.data['code'] == 200) {
      final data = Map<String, dynamic>.from(response.data['data'] ?? {});
      return AppUpdateInfo.fromJson(data);
    }

    throw Exception(response.data['message'] ?? '检查更新失败');
  }

  static String _platformName() {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }
}
