import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../repositories/app_update_repository.dart';

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

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  Timer? _speedTimer;
  bool _downloading = false;
  bool _downloaded = false;
  String? _filePath;
  String? _error;
  int _received = 0;
  int _total = 0;
  int _lastReceived = 0;
  double _speedBytesPerSecond = 0;

  double get _progress {
    if (_total <= 0) return 0;
    return (_received / _total).clamp(0, 1);
  }

  Duration? get _remaining {
    if (_speedBytesPerSecond <= 0 || _total <= 0 || _received <= 0) {
      return null;
    }
    final left = _total - _received;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / _speedBytesPerSecond).ceil());
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    final url = widget.update.downloadUrl;
    if (url.isEmpty) {
      setState(() => _error = '下载地址为空');
      return;
    }

    setState(() {
      _downloading = true;
      _downloaded = false;
      _error = null;
      _received = 0;
      _total = 0;
      _lastReceived = 0;
      _speedBytesPerSecond = 0;
    });

    _cancelToken = CancelToken();
    _speedTimer?.cancel();
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _speedBytesPerSecond = (_received - _lastReceived).toDouble();
        _lastReceived = _received;
      });
    });

    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'jingtu-${widget.update.latestVersionName}.apk';
      final path = '${dir.path}${Platform.pathSeparator}$fileName';
      await _dio.download(
        url,
        path,
        cancelToken: _cancelToken,
        deleteOnError: true,
        options: Options(
          receiveTimeout: Duration.zero,
          followRedirects: true,
        ),
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            if (total > 0) _total = total;
          });
        },
      );
      if (!mounted) return;
      _speedTimer?.cancel();
      setState(() {
        _filePath = path;
        _downloaded = true;
        _downloading = false;
        _received = _total > 0 ? _total : _received;
      });
      await _install();
    } on DioException catch (e) {
      if (!mounted) return;
      _speedTimer?.cancel();
      setState(() {
        _downloading = false;
        _error = CancelToken.isCancel(e) ? '下载已取消' : '下载失败：${e.message ?? e.type.name}';
      });
    } catch (e) {
      if (!mounted) return;
      _speedTimer?.cancel();
      setState(() {
        _downloading = false;
        _error = '下载失败：$e';
      });
    }
  }

  Future<void> _install() async {
    final path = _filePath;
    if (path == null) return;
    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    if (!mounted) return;
    if (result.type != ResultType.done) {
      setState(() => _error = result.message);
    }
  }

  void _cancel() {
    _cancelToken?.cancel();
    if (!widget.update.forceUpdate) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressText = _total > 0
        ? '${_formatBytes(_received)} / ${_formatBytes(_total)}'
        : _formatBytes(_received);
    final speedText = _speedBytesPerSecond > 0
        ? '${_formatBytes(_speedBytesPerSecond.round())}/s'
        : '--';
    final etaText = _remaining == null ? '--' : _formatDuration(_remaining!);

    return PopScope(
      canPop: !widget.update.forceUpdate && !_downloading,
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
            LinearProgressIndicator(value: _total > 0 ? _progress : null),
            const SizedBox(height: 10),
            _InfoRow(label: '进度', value: '${(_progress * 100).toStringAsFixed(1)}%'),
            _InfoRow(label: '大小', value: progressText),
            _InfoRow(label: '速度', value: speedText),
            _InfoRow(label: '预计剩余', value: etaText),
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
          if (!widget.update.forceUpdate && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后再说'),
            ),
          if (_downloading)
            TextButton(
              onPressed: widget.update.forceUpdate ? null : _cancel,
              child: const Text('取消'),
            ),
          FilledButton(
            onPressed: _downloading
                ? null
                : (_downloaded ? _install : _startDownload),
            child: Text(_downloaded ? '安装' : '立即更新'),
          ),
        ],
      ),
    );
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
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes <= 0) return '${seconds}秒';
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
