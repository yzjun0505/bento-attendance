import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/app_update_repository.dart';
import '../services/app_update_download_service.dart';

class AppUpdateDialog {
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo update,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !update.forceUpdate,
      builder: (_) => _AppUpdateDialog(update: update),
    );
  }
}

class _AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo update;

  const _AppUpdateDialog({required this.update});

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog>
    with WidgetsBindingObserver {
  final AppUpdateDownloadService _downloadService =
      AppUpdateDownloadService.instance;

  Timer? _pollTimer;
  AppUpdateDownloadSnapshot _snapshot = const AppUpdateDownloadSnapshot.idle();
  String? _error;
  int _lastReceived = 0;
  double _speedBytesPerSecond = 0;
  DateTime? _lastProgressAt;
  int _lastKnownTotalBytes = -1;

  bool get _downloading => _snapshot.isActive;
  bool get _downloaded => _snapshot.canInstall;

  double get _progress => _snapshot.progress;

  Duration? get _remaining {
    final total = _snapshot.totalBytes;
    final received = _snapshot.downloadedBytes;
    if (_speedBytesPerSecond <= 0 || total <= 0 || received <= 0) {
      return null;
    }
    final left = total - received;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / _speedBytesPerSecond).ceil());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreDownload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreDownload());
    }
  }

  Future<void> _restoreDownload() async {
    try {
      final snapshot = await _downloadService.restore(widget.update);
      if (!mounted) return;
      setState(() {
        _snapshot = _mergeSnapshot(snapshot);
        _lastReceived = snapshot.downloadedBytes;
        if (snapshot.totalBytes > 0) {
          _lastKnownTotalBytes = snapshot.totalBytes;
        }
      });
      if (snapshot.isActive) {
        _startPolling();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '读取下载状态失败：$e');
    }
  }

  Future<void> _startDownload() async {
    final url = widget.update.downloadUrl;
    if (url.isEmpty) {
      setState(() => _error = '下载地址为空');
      return;
    }

    setState(() {
      _error = null;
      _speedBytesPerSecond = 0;
      _lastReceived = 0;
      _lastProgressAt = null;
    });

    try {
      final snapshot = await _downloadService.start(widget.update);
      if (!mounted) return;
      setState(() {
        _snapshot = _mergeSnapshot(snapshot);
        _lastReceived = snapshot.downloadedBytes;
        if (snapshot.totalBytes > 0) {
          _lastKnownTotalBytes = snapshot.totalBytes;
        }
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '启动后台下载失败：$e');
    }
  }

  Future<void> _continueDownload() async {
    setState(() {
      _error = null;
      _speedBytesPerSecond = 0;
      _lastProgressAt = null;
    });

    try {
      final snapshot = await _downloadService.continueOrRestart(widget.update);
      if (!mounted) return;
      setState(() {
        _snapshot = _mergeSnapshot(snapshot);
        _lastReceived = snapshot.downloadedBytes;
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '继续下载失败：$e');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollDownload());
    });
    unawaited(_pollDownload());
  }

  Future<void> _pollDownload() async {
    final id = _snapshot.downloadId;
    if (id == null) return;

    try {
      final snapshot = await _downloadService.query(id);
      if (!mounted) return;
      final merged = _mergeSnapshot(snapshot);
      final delta = merged.downloadedBytes - _lastReceived;
      final now = DateTime.now();
      setState(() {
        _snapshot = merged;
        if (delta > 0) {
          final instantSpeed = delta.toDouble();
          _speedBytesPerSecond = _speedBytesPerSecond > 0
              ? (_speedBytesPerSecond * 0.55 + instantSpeed * 0.45)
              : instantSpeed;
          _lastProgressAt = now;
        } else if (!merged.isActive ||
            (_lastProgressAt != null &&
                now.difference(_lastProgressAt!) >
                    const Duration(seconds: 5))) {
          _speedBytesPerSecond = 0;
        }
        _lastReceived = merged.downloadedBytes;
        if (merged.canInstall) {
          _error = null;
        } else if (merged.hasFailed) {
          _error = '下载失败，请重新下载';
        } else if (merged.state == AppUpdateDownloadState.paused) {
          _error = '下载已暂停，可点“继续更新”重新连接下载';
        }
      });
      if (!merged.isActive) {
        _pollTimer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '读取下载进度失败：$e');
    }
  }

  AppUpdateDownloadSnapshot _mergeSnapshot(AppUpdateDownloadSnapshot snapshot) {
    final total = snapshot.totalBytes > 0
        ? snapshot.totalBytes
        : (_lastKnownTotalBytes > 0
            ? _lastKnownTotalBytes
            : snapshot.totalBytes);
    final downloaded = snapshot.downloadId == _snapshot.downloadId
        ? snapshot.downloadedBytes
            .clamp(_snapshot.downloadedBytes, 1 << 62)
            .toInt()
        : snapshot.downloadedBytes;
    if (total > 0) {
      _lastKnownTotalBytes = total;
    }
    return snapshot.copyWith(
      downloadedBytes: downloaded,
      totalBytes: total,
    );
  }

  Future<void> _install() async {
    final id = _snapshot.downloadId;
    if (id == null) return;
    try {
      await _downloadService.install(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '打开安装器失败：$e');
    }
  }

  Future<void> _cancelDownload() async {
    final id = _snapshot.downloadId;
    if (id == null) return;
    await _downloadService.cancel(id);
    if (!mounted) return;
    if (widget.update.forceUpdate) {
      setState(() {
        _snapshot = const AppUpdateDownloadSnapshot.idle();
        _error = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _dismissToBackground() {
    if (!widget.update.forceUpdate) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _snapshot.totalBytes;
    final received = _snapshot.downloadedBytes;
    final progressText = total > 0
        ? '${_formatBytes(received)} / ${_formatBytes(total)}'
        : _formatBytes(received);
    final speedText = _speedBytesPerSecond > 0
        ? '${_formatBytes(_speedBytesPerSecond.round())}/s'
        : '--';
    final etaText = _remaining == null ? '--' : _formatDuration(_remaining!);
    final hasProgress = total > 0;
    final canContinue = _snapshot.state == AppUpdateDownloadState.paused ||
        _snapshot.state == AppUpdateDownloadState.failed ||
        _snapshot.state == AppUpdateDownloadState.missing;

    return PopScope(
      canPop: !widget.update.forceUpdate,
      child: AlertDialog(
        title: Text(widget.update.forceUpdate ? '需要更新后继续使用' : '发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最新版本：${widget.update.latestVersionName}'),
            if (widget.update.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(widget.update.releaseNotes),
            ],
            const SizedBox(height: 16),
            LinearProgressIndicator(value: hasProgress ? _progress : null),
            const SizedBox(height: 10),
            _InfoRow(label: '状态', value: _statusText()),
            _InfoRow(
              label: '进度',
              value: hasProgress
                  ? '${(_progress * 100).toStringAsFixed(1)}%'
                  : '--',
            ),
            _InfoRow(label: '大小', value: progressText),
            _InfoRow(label: '速度', value: speedText),
            _InfoRow(label: '预计剩余', value: etaText),
            if (_downloading) ...[
              const SizedBox(height: 8),
              Text(
                '可返回后台继续下载，下载完成后再打开安装。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.update.forceUpdate)
            TextButton(
              onPressed: _dismissToBackground,
              child: Text(_downloading ? '后台下载' : '稍后再说'),
            ),
          if (_downloading && !widget.update.forceUpdate)
            TextButton(
              onPressed: _cancelDownload,
              child: const Text('取消下载'),
            ),
          FilledButton(
            onPressed: _downloaded
                ? _install
                : (canContinue
                    ? _continueDownload
                    : (_downloading ? null : _startDownload)),
            child: Text(_downloaded ? '安装' : (canContinue ? '继续更新' : '立即更新')),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    switch (_snapshot.state) {
      case AppUpdateDownloadState.idle:
        return '待下载';
      case AppUpdateDownloadState.pending:
        return '等待系统下载';
      case AppUpdateDownloadState.running:
        return '下载中';
      case AppUpdateDownloadState.paused:
        return '已暂停';
      case AppUpdateDownloadState.successful:
        return '下载完成';
      case AppUpdateDownloadState.failed:
        return '下载失败';
      case AppUpdateDownloadState.missing:
        return '任务不存在';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final digits = unit == 0 ? 0 : 1;
    return '${size.toStringAsFixed(digits)} ${units[unit]}';
  }

  String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) return '即将完成';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '$hours小时${minutes.toString().padLeft(2, '0')}分';
    }
    if (minutes <= 0) return '$seconds秒';
    return '$minutes分${seconds.toString().padLeft(2, '0')}秒';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
