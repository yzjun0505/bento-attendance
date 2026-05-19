import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../api/dio_client.dart';
import '../../core/bento_colors.dart';
import '../../widgets/bento_card.dart';

class EnvironmentDiagnosticsScreen extends StatefulWidget {
  const EnvironmentDiagnosticsScreen({super.key});

  @override
  State<EnvironmentDiagnosticsScreen> createState() =>
      _EnvironmentDiagnosticsScreenState();
}

class _EnvironmentDiagnosticsScreenState
    extends State<EnvironmentDiagnosticsScreen> {
  bool _checking = true;
  _CheckResult? _apiResult;
  _CheckResult? _openIMResult;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() => _checking = true);
    final api = await _checkApi();
    final openIM = await _checkOpenIM();
    if (!mounted) return;
    setState(() {
      _apiResult = api;
      _openIMResult = openIM;
      _checking = false;
    });
  }

  Future<_CheckResult> _checkApi() async {
    try {
      final resp = await ApiClient()
          .dio
          .get('/health')
          .timeout(const Duration(seconds: 5));
      final ok = resp.statusCode == 200 &&
          (resp.data['code'] == 200 || resp.data['message'] == 'OK');
      return _CheckResult(ok: ok, message: ok ? '后端服务正常' : '后端依赖异常');
    } on DioException catch (e) {
      return _CheckResult(ok: false, message: _networkMessage(e));
    } catch (e) {
      return _CheckResult(ok: false, message: '检查失败：$e');
    }
  }

  Future<_CheckResult> _checkOpenIM() async {
    try {
      final resp = await Dio(BaseOptions(
        validateStatus: (status) => status != null && status < 500,
      ))
          .get(ApiClient.openIMApiUrl)
          .timeout(const Duration(seconds: 5));
      final ok = resp.statusCode != null &&
          resp.statusCode! >= 200 &&
          resp.statusCode! < 500;
      final message = resp.statusCode == 404
          ? 'OpenIM HTTP 可访问（根路径无路由）'
          : (ok ? 'OpenIM HTTP 可访问' : 'OpenIM 状态异常');
      return _CheckResult(
          ok: ok, message: message);
    } on DioException catch (e) {
      return _CheckResult(ok: false, message: _networkMessage(e));
    } catch (e) {
      return _CheckResult(ok: false, message: '检查失败：$e');
    }
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时';
      case DioExceptionType.connectionError:
        return '无法连接';
      case DioExceptionType.badResponse:
        return 'HTTP ${e.response?.statusCode}';
      default:
        return e.message ?? '网络错误';
    }
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('环境诊断'),
        actions: [
          IconButton(
            tooltip: '重新检查',
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _checking ? null : _runChecks,
          ),
        ],
      ),
      body: Container(
        color: colors.background,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前配置',
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildConfigRow('平台', _platformName, Icons.devices, colors),
                  const Divider(height: 24),
                  _buildConfigRow('API', ApiClient.baseUrl, Icons.api, colors),
                  const Divider(height: 24),
                  _buildConfigRow('OpenIM API', ApiClient.openIMApiUrl,
                      Icons.chat_bubble_outline, colors),
                  const Divider(height: 24),
                  _buildConfigRow(
                      'OpenIM WS', ApiClient.openIMWsUrl, Icons.cable, colors),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('连通状态',
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildCheckRow('后端 API', _apiResult, colors),
                  const Divider(height: 24),
                  _buildCheckRow('OpenIM HTTP', _openIMResult, colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(
      String title, String value, IconData icon, BentoColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              SelectableText(value,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckRow(
      String title, _CheckResult? result, BentoColors colors) {
    final ok = result?.ok;
    final color = ok == null
        ? colors.textTertiary
        : ok
            ? colors.success
            : colors.error;
    final icon = ok == null
        ? Icons.hourglass_empty
        : ok
            ? Icons.check_circle
            : Icons.cancel;
    final message = result?.message ?? '检查中';
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(message,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckResult {
  final bool ok;
  final String message;

  const _CheckResult({required this.ok, required this.message});
}
