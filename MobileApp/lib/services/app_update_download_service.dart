import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/app_update_repository.dart';

enum AppUpdateDownloadState {
  idle,
  pending,
  running,
  paused,
  successful,
  failed,
  missing,
}

class AppUpdateDownloadSnapshot {
  final AppUpdateDownloadState state;
  final int? downloadId;
  final int downloadedBytes;
  final int totalBytes;
  final int reason;
  final String? localUri;

  const AppUpdateDownloadSnapshot({
    required this.state,
    this.downloadId,
    this.downloadedBytes = 0,
    this.totalBytes = -1,
    this.reason = 0,
    this.localUri,
  });

  const AppUpdateDownloadSnapshot.idle()
      : state = AppUpdateDownloadState.idle,
        downloadId = null,
        downloadedBytes = 0,
        totalBytes = -1,
        reason = 0,
        localUri = null;

  AppUpdateDownloadSnapshot copyWith({
    AppUpdateDownloadState? state,
    int? downloadId,
    int? downloadedBytes,
    int? totalBytes,
    int? reason,
    String? localUri,
  }) {
    return AppUpdateDownloadSnapshot(
      state: state ?? this.state,
      downloadId: downloadId ?? this.downloadId,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      reason: reason ?? this.reason,
      localUri: localUri ?? this.localUri,
    );
  }

  bool get isActive =>
      state == AppUpdateDownloadState.pending ||
      state == AppUpdateDownloadState.running ||
      state == AppUpdateDownloadState.paused;

  bool get canInstall => state == AppUpdateDownloadState.successful;

  bool get hasFailed =>
      state == AppUpdateDownloadState.failed ||
      state == AppUpdateDownloadState.missing;

  double get progress {
    if (totalBytes <= 0) return 0;
    return (downloadedBytes / totalBytes).clamp(0, 1);
  }
}

class AppUpdateDownloadService {
  AppUpdateDownloadService._();

  static final AppUpdateDownloadService instance = AppUpdateDownloadService._();
  static const MethodChannel _channel =
      MethodChannel('jingmap_app/update_download');

  static const _downloadIdKey = 'app_update_download_id';
  static const _urlKey = 'app_update_download_url';
  static const _versionCodeKey = 'app_update_download_version_code';
  static const _versionNameKey = 'app_update_download_version_name';
  static const _fileNameKey = 'app_update_download_file_name';

  Future<AppUpdateDownloadSnapshot> restore(AppUpdateInfo update) async {
    if (!Platform.isAndroid) return const AppUpdateDownloadSnapshot.idle();

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_downloadIdKey);
    if (id == null || !_matchesStoredUpdate(prefs, update)) {
      return const AppUpdateDownloadSnapshot.idle();
    }

    final snapshot = await query(id);
    if (snapshot.state == AppUpdateDownloadState.missing) {
      await clearStoredTask();
    }
    return snapshot;
  }

  Future<AppUpdateDownloadSnapshot> start(AppUpdateInfo update) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前后台更新下载仅支持 Android');
    }

    final existing = await restore(update);
    if (existing.isActive || existing.canInstall) return existing;

    final prefs = await SharedPreferences.getInstance();
    final oldId = prefs.getInt(_downloadIdKey);
    if (oldId != null) {
      await cancel(oldId, clear: false);
    }

    final fileName = _fileNameFor(update);
    final id = await _channel.invokeMethod<int>('enqueue', {
      'url': update.downloadUrl,
      'fileName': fileName,
      'title': '境图 ${update.latestVersionName}',
    });

    if (id == null) {
      throw Exception('系统下载任务创建失败');
    }

    await prefs.setInt(_downloadIdKey, id);
    await prefs.setString(_urlKey, update.downloadUrl);
    await prefs.setInt(_versionCodeKey, update.latestVersionCode);
    await prefs.setString(_versionNameKey, update.latestVersionName);
    await prefs.setString(_fileNameKey, fileName);

    return query(id);
  }

  Future<AppUpdateDownloadSnapshot> restart(AppUpdateInfo update) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前后台更新下载仅支持 Android');
    }

    final prefs = await SharedPreferences.getInstance();
    final oldId = prefs.getInt(_downloadIdKey);
    if (oldId != null) {
      await cancel(oldId, clear: false);
    }
    await clearStoredTask();
    return start(update);
  }

  Future<AppUpdateDownloadSnapshot> continueOrRestart(
      AppUpdateInfo update) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前后台更新下载仅支持 Android');
    }

    final existing = await restore(update);
    if (existing.isActive || existing.canInstall) return existing;
    return restart(update);
  }

  Future<AppUpdateDownloadSnapshot> query(int downloadId) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('query', {
      'downloadId': downloadId,
    });
    final data = raw ?? const <String, dynamic>{};
    final state = _stateFromName((data['status'] ?? 'missing').toString());
    return AppUpdateDownloadSnapshot(
      state: state,
      downloadId: downloadId,
      downloadedBytes: _toInt(data['downloadedBytes']),
      totalBytes: _toInt(data['totalBytes']),
      reason: _toInt(data['reason']),
      localUri: data['localUri']?.toString(),
    );
  }

  Future<void> cancel(int downloadId, {bool clear = true}) async {
    await _channel.invokeMethod<void>('cancel', {'downloadId': downloadId});
    if (clear) {
      await clearStoredTask();
    }
  }

  Future<void> install(int downloadId) async {
    await _channel.invokeMethod<void>('install', {'downloadId': downloadId});
  }

  Future<void> clearStoredTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_downloadIdKey);
    await prefs.remove(_urlKey);
    await prefs.remove(_versionCodeKey);
    await prefs.remove(_versionNameKey);
    await prefs.remove(_fileNameKey);
  }

  bool _matchesStoredUpdate(SharedPreferences prefs, AppUpdateInfo update) {
    return prefs.getString(_urlKey) == update.downloadUrl &&
        prefs.getInt(_versionCodeKey) == update.latestVersionCode &&
        prefs.getString(_versionNameKey) == update.latestVersionName;
  }

  String _fileNameFor(AppUpdateInfo update) {
    final version =
        update.latestVersionName.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    return 'jingtu-$version-${update.latestVersionCode}.apk';
  }

  AppUpdateDownloadState _stateFromName(String name) {
    switch (name) {
      case 'pending':
        return AppUpdateDownloadState.pending;
      case 'running':
        return AppUpdateDownloadState.running;
      case 'paused':
        return AppUpdateDownloadState.paused;
      case 'successful':
        return AppUpdateDownloadState.successful;
      case 'failed':
        return AppUpdateDownloadState.failed;
      case 'missing':
        return AppUpdateDownloadState.missing;
      default:
        return AppUpdateDownloadState.idle;
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
