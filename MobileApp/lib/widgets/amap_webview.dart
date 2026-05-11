import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 高德地图 WebView 控制器
/// 通过 JS Bridge 与 HTML 中的高德 JS API 通信
class AMapController {
  WebViewController? _webViewController;
  bool _mapReady = false;

  bool get isReady => _mapReady;

  /// JS 端 IP 定位回调（当 Flutter 没有传入初始坐标时使用）
  void Function(double lng, double lat)? onIpLocation;

  void attach(WebViewController controller) {
    _webViewController = controller;
  }

  void markReady() {
    _mapReady = true;
  }

  /// 更新用户位置（蓝点 + 精度圈）
  Future<void> updateLocation(double lng, double lat,
      {double? accuracy}) async {
    _mapReady = true;
    await _webViewController?.runJavaScript('''
      if (typeof updateLocation === 'function') {
        updateLocation($lng, $lat, ${accuracy ?? 50});
      }
    ''');
  }

  /// 移动到位置
  Future<void> moveToLocation(double lng, double lat, {double? zoom}) async {
    await _webViewController?.runJavaScript('''
      if (typeof moveToLocation === 'function') {
        moveToLocation($lng, $lat, ${zoom ?? 15});
      }
    ''');
  }

  /// 更新项目围栏
  Future<void> updateProjects(List<Map<String, dynamic>> projects) async {
    final jsonStr = jsonEncode(projects).replaceAll("'", "\\'");
    await _webViewController?.runJavaScript('''
      if (typeof updateProjects === 'function') {
        updateProjects('$jsonStr');
      }
    ''');
  }

  /// 逆地理编码
  Future<void> reverseGeocode(double lng, double lat) async {
    await _webViewController?.runJavaScript('''
      if (typeof reverseGeocode === 'function') {
        reverseGeocode($lng, $lat);
      }
    ''');
  }

  /// 设置地图主题
  Future<void> setMapStyle(bool isDark) async {
    await _webViewController?.runJavaScript('''
      if (typeof setMapStyle === 'function') {
        setMapStyle('${isDark ? 'dark' : 'light'}');
      }
    ''');
  }

  /// 绘制轨迹线
  Future<void> drawTrack(List<Map<String, dynamic>> path) async {
    final jsonStr = jsonEncode(path).replaceAll("'", "\\'");
    await _webViewController?.runJavaScript('''
      if (typeof drawTrack === 'function') {
        drawTrack('$jsonStr');
      }
    ''');
  }

  /// 清除轨迹
  Future<void> clearTrack() async {
    await _webViewController?.runJavaScript('''
      if (typeof clearTrack === 'function') {
        clearTrack();
      }
    ''');
  }
}

/// 高德地图 WebView 组件
class AMapWebView extends StatefulWidget {
  /// 高德 Web JS API Key
  final String apiKey;

  /// 地图控制器
  final AMapController controller;

  /// 初始经度
  final double? initialLng;

  /// 初始纬度
  final double? initialLat;

  /// 初始缩放级别
  final double? initialZoom;

  /// 地图就绪回调
  final VoidCallback? onMapReady;

  /// 地址解析回调
  final ValueChanged<String>? onAddressResolved;

  /// 地图加载错误回调
  final ValueChanged<String>? onMapError;

  /// 是否暗色主题
  final bool isDarkMode;

  const AMapWebView({
    super.key,
    required this.apiKey,
    required this.controller,
    this.initialLng,
    this.initialLat,
    this.initialZoom,
    this.onMapReady,
    this.onAddressResolved,
    this.onMapError,
    this.isDarkMode = false,
  });

  @override
  State<AMapWebView> createState() => _AMapWebViewState();
}

class _AMapWebViewState extends State<AMapWebView> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  bool get _hasValidApiKey =>
      widget.apiKey.trim().isNotEmpty &&
      widget.apiKey != 'your_amap_web_key_here';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (_) => _onPageFinished(),
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            _showError('地图资源加载失败：${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: _handleJsMessage,
      );

    // 将 controller 绑定到 WebViewController
    widget.controller.attach(_webViewController);

    _loadHtmlFromAssets();
  }

  Future<void> _loadHtmlFromAssets() async {
    try {
      if (!_hasValidApiKey) {
        _showError('缺少高德 Web JS Key，请通过 --dart-define=AMAP_WEB_KEY=你的Key 启动应用');
        return;
      }
      String html = await rootBundle.loadString('assets/amap.html');
      // 替换 Key 占位符
      html = html.replaceAll('__AMAP_WEB_KEY__', widget.apiKey);
      // baseUrl 设为高德域名，确保瓦片资源请求不受跨域限制
      await _webViewController.loadHtmlString(html,
          baseUrl: 'https://webapi.amap.com');
    } catch (e) {
      debugPrint('❌ 加载高德地图 HTML 失败: $e');
      _showError('加载地图页面失败：$e');
    }
  }

  Future<void> _onPageFinished() async {
    if (!_hasValidApiKey) return;
    // 只有有初始坐标时才初始化地图中心，否则让 JS 端使用 IP 定位
    await _webViewController.runJavaScript('''
	      if (typeof initMap === 'function') {
	        initMap(
	          ${widget.initialLng ?? 'null'},
          ${widget.initialLat ?? 'null'},
          ${widget.initialZoom ?? 15}
	        );
	      } else {
	        FlutterChannel.postMessage(JSON.stringify({
	          type: 'mapError',
	          message: '地图初始化脚本未加载'
	        }));
	      }
	    ''');

    if (widget.isDarkMode) {
      await widget.controller.setMapStyle(true);
    }
  }

  void _showError(String message) {
    debugPrint('❌ 高德地图错误: $message');
    widget.onMapError?.call(message);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  void _markReady() {
    widget.controller.markReady();
    widget.onMapReady?.call();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });
  }

  void _handleJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'mapReady':
          _markReady();
          break;
        case 'mapError':
          _showError(data['message'] as String? ?? '地图加载失败');
          break;
        case 'address':
          final address = data['address'] as String? ?? '';
          widget.onAddressResolved?.call(address);
          break;
        case 'ipLocation':
          final lng = (data['longitude'] as num?)?.toDouble();
          final lat = (data['latitude'] as num?)?.toDouble();
          if (lng != null && lat != null) {
            widget.controller.onIpLocation?.call(lng, lat);
          }
          break;
      }
    } catch (e) {
      debugPrint('❌ 解析 JS 消息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_hasValidApiKey) WebViewWidget(controller: _webViewController),
        if (_isLoading && _errorMessage == null)
          const Center(child: CircularProgressIndicator()),
        if (_errorMessage != null)
          _MapErrorView(
            message: _errorMessage!,
            onRetry: _loadHtmlFromAssets,
          ),
      ],
    );
  }
}

class _MapErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MapErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 42,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                '地图加载失败',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
