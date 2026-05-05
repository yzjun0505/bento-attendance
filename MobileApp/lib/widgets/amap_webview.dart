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
  Future<void> updateLocation(double lng, double lat, {double? accuracy}) async {
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
    this.isDarkMode = false,
  });

  @override
  State<AMapWebView> createState() => _AMapWebViewState();
}

class _AMapWebViewState extends State<AMapWebView> {
  late WebViewController _webViewController;

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
          onPageFinished: (_) => _onPageFinished(),
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
      String html = await rootBundle.loadString('assets/amap.html');
      // 替换 Key 占位符
      html = html.replaceAll('__AMAP_WEB_KEY__', widget.apiKey);
      // baseUrl 设为高德域名，确保瓦片资源请求不受跨域限制
      await _webViewController.loadHtmlString(html, baseUrl: 'https://webapi.amap.com');
    } catch (e) {
      debugPrint('❌ 加载高德地图 HTML 失败: $e');
    }
  }

  Future<void> _onPageFinished() async {
    // 只有有初始坐标时才初始化地图中心，否则让 JS 端使用 IP 定位
    await _webViewController.runJavaScript('''
      if (typeof initMap === 'function') {
        initMap(
          ${widget.initialLng ?? 'null'},
          ${widget.initialLat ?? 'null'},
          ${widget.initialZoom ?? 15}
        );
      }
    ''');

    if (widget.isDarkMode) {
      await widget.controller.setMapStyle(true);
    }

    widget.controller.markReady();
    widget.onMapReady?.call();
  }

  void _handleJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'mapReady':
          widget.controller.markReady();
          widget.onMapReady?.call();
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
    return WebViewWidget(controller: _webViewController);
  }
}
