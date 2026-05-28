import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/attendance/attendance_bloc.dart';
import '../../blocs/attendance/attendance_state.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../models/project_model.dart';
import '../../repositories/checkin_repository.dart';
import '../../utils/amap_geo_service.dart';
import '../../utils/app_location_service.dart';
import '../../utils/weather_service.dart';
import '../../utils/watermark_service.dart';
import '../../utils/watermark_renderer.dart';
import '../../utils/local_album_service.dart';
import '../../models/watermark_template.dart';
import 'local_album_screen.dart';

/// 预览水印构建器，与 WatermarkService 的渲染逻辑保持一致
class WatermarkPreviewBuilder {
  final WatermarkTemplate template;
  final Map<String, String> data;
  final bool isDragging;

  const WatermarkPreviewBuilder({
    required this.template,
    required this.data,
    this.isDragging = false,
  });

  String _getSlotValue(WatermarkSlot slot) {
    // 1) 优先从 data（用户编辑后的动态数据）中通过 binding 获取
    if (slot.binding != null && slot.binding!.isNotEmpty) {
      final fieldType = WatermarkTemplate.bindingToFieldType(slot.binding);
      if (fieldType != null) {
        final value =
            _CameraCheckinScreenState._getFieldValueFromData(fieldType, data);
        if (value.isNotEmpty) return value;
      }
    }
    // 2) binding/data 为空时，使用用户自定义文本（如手动编辑的打卡名称）
    if (slot.customText != null && slot.customText!.isNotEmpty) {
      return slot.customText!;
    }
    // 3) 最后通过 label 匹配 fieldType 回退到 data
    if (slot.label.isNotEmpty) {
      final fieldType = WatermarkTemplate.labelToFieldType(slot.label);
      final value =
          _CameraCheckinScreenState._getFieldValueFromData(fieldType, data);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _getSlotDisplayText(WatermarkSlot slot) {
    final value = _getSlotValue(slot);
    if (value.isEmpty) return '';
    if (slot.id == 'title' || slot.id == 'subtitle') {
      return value;
    }
    return '${slot.label}：$value';
  }

  List<WatermarkPreviewLine> get _displayLines {
    final lines = <WatermarkPreviewLine>[];

    if (template.titleSlot != null) {
      final ft = template.titleSlot!.fieldType;
      final enabled = ft == null || (template.fieldEnabled[ft] ?? true);
      if (enabled) {
        final value = _getSlotValue(template.titleSlot!);
        if (value.isNotEmpty) {
          lines.add(WatermarkPreviewLine(text: value, isTitle: true));
        }
      }
    }

    if (template.subtitleSlot != null) {
      final ft = template.subtitleSlot!.fieldType;
      final enabled = ft == null || (template.fieldEnabled[ft] ?? true);
      if (enabled) {
        final value = _getSlotValue(template.subtitleSlot!);
        if (value.isNotEmpty) {
          lines.add(WatermarkPreviewLine(text: value, isSubtitle: true));
        }
      }
    }

    for (final slot in template.contentSlots) {
      final ft = slot.fieldType;
      final enabled = ft == null || (template.fieldEnabled[ft] ?? true);
      if (!enabled) continue;
      final text = _getSlotDisplayText(slot);
      if (text.isNotEmpty) {
        lines.add(WatermarkPreviewLine(text: text));
      }
    }

    if (lines.isEmpty) {
      final fields = template.enabledFields;
      for (final f in fields) {
        final val = _CameraCheckinScreenState._getFieldValueFromData(f, data);
        if (val.isNotEmpty) {
          lines.add(WatermarkPreviewLine(text: val));
        }
      }
    }

    return lines;
  }

  Widget build(BuildContext context) {
    final style = template.defaultStyle;
    final lines = _displayLines;

    if (lines.isEmpty) return const SizedBox.shrink();

    if (style == WatermarkStyle.fullScreenWatermark) {
      return _buildFullScreenPreview(lines);
    } else if (style == WatermarkStyle.qrCode) {
      return _buildQrCodePreview(lines);
    } else {
      return _buildStyledPreview(style, lines);
    }
  }

  Widget _buildStyledPreview(
      WatermarkStyle style, List<WatermarkPreviewLine> lines) {
    final baseFontSize = template.fontSize;
    final textColor = template.textColor;
    final bgColor = template.backgroundColor;
    const padding = 16.0;
    final cardWidth =
        (style == WatermarkStyle.bottomBar) ? double.infinity : 280.0;

    Widget content = Container(
      width: cardWidth,
      padding: const EdgeInsets.all(padding),
      decoration: _buildBoxDecoration(style, bgColor, padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: lines.map((line) {
          final fontSize = line.isTitle ? baseFontSize * 1.3 : baseFontSize;
          final fontWeight = line.isTitle ? FontWeight.bold : FontWeight.w500;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line.text,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 2,
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );

    if (template.skeletonPreset == 'glass') {
      content = ClipRRect(
        borderRadius: _getBorderRadius(style, padding),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: content,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: content,
    );
  }

  BoxDecoration _buildBoxDecoration(
      WatermarkStyle style, Color bgColor, double padding) {
    if (style == WatermarkStyle.bottomBar) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [bgColor, bgColor.withValues(alpha: 0.0)],
        ),
      );
    }

    final baseDecoration = BoxDecoration(
      color: bgColor,
      borderRadius: _getBorderRadius(style, padding),
    );

    if (template.skeletonPreset == 'glass') {
      return baseDecoration.copyWith(
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      );
    } else if (template.skeletonPreset == 'clean') {
      return const BoxDecoration();
    } else if (template.skeletonPreset == 'compact') {
      return BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      );
    }

    return baseDecoration;
  }

  BorderRadius _getBorderRadius(WatermarkStyle style, double padding) {
    if (template.skeletonPreset == 'glass') {
      return BorderRadius.circular(12);
    } else if (template.skeletonPreset == 'compact') {
      return BorderRadius.circular(4);
    }
    return BorderRadius.circular(8);
  }

  Widget _buildFullScreenPreview(List<WatermarkPreviewLine> lines) {
    final companyName = data['companyName'] ?? '';
    final projectName = data['projectName'] ?? '';
    final text = '$companyName $projectName'.trim();
    final alpha = (template.opacity * 255).clamp(0, 255).toInt();

    return Stack(
      children: [
        if (text.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -15 * 3.14159 / 180,
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: alpha / 255),
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (lines.isNotEmpty)
          Positioned(
            left: 8,
            bottom: 8,
            child: _buildStyledPreview(WatermarkStyle.bottomLeft, lines),
          ),
      ],
    );
  }

  Widget _buildQrCodePreview(List<WatermarkPreviewLine> lines) {
    const qrSize = 60.0;
    const padding = 12.0;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: qrSize,
            height: qrSize,
            color: Colors.white,
            child: CustomPaint(
              size: const Size(qrSize, qrSize),
              painter: PreviewQrCodePainter(data['antiFakeCode'] ?? ''),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: lines.map((line) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class WatermarkPreviewLine {
  final String text;
  final bool isTitle;
  final bool isSubtitle;

  WatermarkPreviewLine(
      {required this.text, this.isTitle = false, this.isSubtitle = false});
}

/// 模拟 QR 码绘制
class PreviewQrCodePainter extends CustomPainter {
  final String code;

  PreviewQrCodePainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 21;
    final cellSize = size.width / grid;
    for (int i = 0; i < grid; i++) {
      for (int j = 0; j < grid; j++) {
        if ((code.hashCode + i * 31 + j * 17) % 3 != 0) {
          canvas.drawRect(
            Rect.fromLTWH(i * cellSize, j * cellSize, cellSize, cellSize),
            Paint()..color = Colors.black,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CameraCheckinScreen extends StatefulWidget {
  const CameraCheckinScreen({super.key});

  @override
  State<CameraCheckinScreen> createState() => _CameraCheckinScreenState();
}

class _CameraCheckinScreenState extends State<CameraCheckinScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;

  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  double? _latitude;
  double? _longitude;
  double? _altitude;
  String? _currentAddress;
  String _weather = '暂无';
  String _temperature = '--';
  String _humidity = '--';

  int? _selectedProjectId;
  List<Project> _projects = [];

  String _customCheckinName = '常规打卡';
  String _watermarkTitle = '常规打卡';
  String _activeCheckinTypeCode = 'clock_in';
  List<WatermarkTemplate> _templates = [];
  WatermarkTemplate? _selectedTemplate;
  File? _localLogoFile;
  Offset _normalizedOffset = const Offset(0.05, 0.50);
  bool _isDragging = false;
  double _watermarkScale = 1.0;
  double _baseWatermarkScale = 1.0;
  int _watermarkRotationTurns = 0;
  AmapNearbyPlace? _selectedNearbyPlace;
  bool _isLoadingNearbyPlaces = false;
  bool _isOpeningLocationPicker = false;
  List<AmapNearbyPlace> _nearbyPlaces = [];
  final Map<WatermarkFieldType, String> _fieldCustomValues = {};

  FlashMode _flashMode = FlashMode.auto;
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _templates = [];
    _selectedTemplate = null;
    _initGeo();
    _initCamera();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });

    // Fetch watermark templates from the backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTemplates();
    });
  }

  Future<void> _fetchTemplates() async {
    final repo = context.read<CheckinRepository>();
    final templates = await repo.fetchWatermarkTemplates();
    if (mounted && templates.isNotEmpty) {
      setState(() {
        _templates = templates;
        _selectedTemplate = templates.first;
        _syncTemplateState();
        // 同步水印标题到模板 titleSlot
        _syncTitleToTemplate();
      });
    }
  }

  /// 将 _watermarkTitle 同步到当前模板的 titleSlot
  /// 用户手动设置打卡名称后，清空 binding 让 customText 直接生效，
  /// 避免 binding 指向的 projectName 覆盖用户自定义标题
  void _syncTitleToTemplate() {
    if (_selectedTemplate?.titleSlot == null) return;
    final old = _selectedTemplate!.titleSlot!;
    _selectedTemplate = _selectedTemplate!.copyWith(
      titleSlot: WatermarkSlot(
        id: old.id,
        label: _watermarkTitle,
        binding: null,
        customText: _watermarkTitle,
        style: old.style,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initGeo() async {
    // 第一步：尝试获取精确 GPS 定位
    final location = await AppLocationService.getCurrentLocation(
      timeLimit: const Duration(seconds: 15),
    );

    if (location != null && mounted) {
      setState(() {
        _latitude = location.latitude;
        _longitude = location.longitude;
        _altitude = location.altitude;
        _currentAddress = location.address ?? _currentAddress;
      });
      _resolveAddress(location.latitude, location.longitude);
      _syncProjectFromAttendance();
    } else if (mounted) {
      // GPS 和缓存位置都失败，从 AttendanceBloc 回退
      _syncProjectFromAttendance();
      // 如果 bloc 有位置，也做逆地理编码
      if (_latitude != null && _longitude != null) {
        _resolveAddress(_latitude!, _longitude!);
      } else {
        // 完全没有位置数据，尝试低精度定位
        _retryLowAccuracyGeo();
      }
    }
  }

  /// 低精度定位回退（仅在前面的定位方式都失败时调用）
  Future<void> _retryLowAccuracyGeo() async {
    try {
      final location = await AppLocationService.getCurrentLocation(
        accuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted && location != null) {
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
          _altitude = location.altitude;
          _currentAddress = location.address ?? _currentAddress;
        });
        _resolveAddress(location.latitude, location.longitude);
      }
    } catch (_) {
      // 最终回退失败，用户可以手动点击重试
    }
  }

  /// 从 AttendanceBloc 同步项目信息和水印标题
  void _syncProjectFromAttendance() {
    final attendanceState = context.read<AttendanceBloc>().state;
    if (attendanceState is AttendanceLoaded) {
      if (mounted) {
        setState(() {
          _latitude ??= attendanceState.currentLatitude;
          _longitude ??= attendanceState.currentLongitude;
          _currentAddress ??= attendanceState.currentAddress;
          _projects = attendanceState.projects;
          if (attendanceState.nearestProject != null &&
              _selectedProjectId == null) {
            _selectedProjectId = attendanceState.nearestProject!.id;
            _customCheckinName = attendanceState.nearestProject!.name;
            // 首次自动绑定项目时，同步更新水印标题
            _watermarkTitle = attendanceState.nearestProject!.name;
            _syncTitleToTemplate();
          }
        });
      }
    }
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    try {
      final address = await AmapGeoService.reverseGeocode(
        latitude: lat,
        longitude: lng,
      );
      if (mounted && address != null) {
        setState(() => _currentAddress = address);
      }
    } catch (e) {
      debugPrint('逆地理编码失败: $e');
    }
    try {
      final weather = await WeatherService.getWeatherByLocation(
        latitude: lat,
        longitude: lng,
      );
      if (mounted && weather != null) {
        setState(() {
          _weather = weather.weather;
          _temperature = weather.temperature;
          _humidity = weather.humidity;
        });
      }
    } catch (e) {
      debugPrint('获取天气失败: $e');
    }
    await _loadNearbyPlaces();
  }

  Future<void> _loadNearbyPlaces({String keywords = ''}) async {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) return;

    if (mounted) {
      setState(() => _isLoadingNearbyPlaces = true);
    }

    try {
      final places = await AmapGeoService.searchNearbyPlaces(
        latitude: lat,
        longitude: lng,
        keywords: keywords,
      );
      if (!mounted) return;
      setState(() {
        _isLoadingNearbyPlaces = false;
        _nearbyPlaces = places;
        if (_selectedNearbyPlace != null && places.isNotEmpty) {
          final matched =
              places.where((place) => place.id == _selectedNearbyPlace!.id);
          if (matched.isNotEmpty) {
            _selectedNearbyPlace = matched.first;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingNearbyPlaces = false;
        _nearbyPlaces = [];
      });
    }
  }

  void _syncTemplateState() {
    final template = _selectedTemplate;
    if (template == null) return;
    final nextEnabled = <WatermarkFieldType, bool>{};
    for (final field in template.fields) {
      nextEnabled[field] = template.fieldEnabled[field] ?? true;
      _fieldCustomValues.putIfAbsent(field, () => _defaultEditableValue(field));
    }
    _selectedTemplate = template.copyWith(fieldEnabled: nextEnabled);
  }

  String get _selectedProjectName {
    if (_selectedProjectId != null && _projects.isNotEmpty) {
      try {
        return _projects.firstWhere((p) => p.id == _selectedProjectId).name;
      } catch (e) {
        debugPrint('查找项目名称失败: $e');
      }
    }
    return '';
  }

  String _defaultEditableValue(WatermarkFieldType field) {
    switch (field) {
      case WatermarkFieldType.workContent:
      case WatermarkFieldType.taskDescription:
      case WatermarkFieldType.inspectionContent:
      case WatermarkFieldType.acceptanceContent:
        return '';
      case WatermarkFieldType.projectName:
        return _selectedProjectName;
      case WatermarkFieldType.position:
        return '现场作业';
      case WatermarkFieldType.remark:
        return '';
      default:
        return '';
    }
  }

  String _fieldTitle(WatermarkFieldType field) {
    switch (field) {
      case WatermarkFieldType.timeFull:
      case WatermarkFieldType.timeDate:
      case WatermarkFieldType.timeOnly:
        return '拍摄时间';
      case WatermarkFieldType.addressDetail:
      case WatermarkFieldType.projectAddress:
        return '地点';
      case WatermarkFieldType.projectName:
        return '施工区域';
      case WatermarkFieldType.workContent:
        return '施工内容';
      case WatermarkFieldType.manager:
        return '施工负责人';
      case WatermarkFieldType.teamLeader:
        return '监理负责人';
      case WatermarkFieldType.userName:
        return '打卡人';
      case WatermarkFieldType.weather:
        return '天气';
      case WatermarkFieldType.temperature:
        return '温度';
      case WatermarkFieldType.humidity:
        return '湿度';
      case WatermarkFieldType.altitude:
        return '海拔';
      default:
        return field.label;
    }
  }

  bool _fieldSupportsEdit(WatermarkFieldType field) {
    switch (field) {
      case WatermarkFieldType.projectName:
      case WatermarkFieldType.workContent:
      case WatermarkFieldType.taskDescription:
      case WatermarkFieldType.inspectionContent:
      case WatermarkFieldType.acceptanceContent:
      case WatermarkFieldType.manager:
      case WatermarkFieldType.teamLeader:
      case WatermarkFieldType.position:
      case WatermarkFieldType.remark:
      case WatermarkFieldType.addressDetail:
      case WatermarkFieldType.projectAddress:
      case WatermarkFieldType.companyName:
      case WatermarkFieldType.contractorOrg:
      case WatermarkFieldType.supervisorOrg:
      case WatermarkFieldType.clientOrg:
        return true;
      default:
        return false;
    }
  }

  bool _fieldSupportsToggle(WatermarkFieldType field) {
    return field != WatermarkFieldType.antiFakeCode;
  }

  /// 构建水印数据Map，用于统一预览和实际照片的水印内容
  Map<String, String> _buildWatermarkData({String? antiFakeCode}) {
    final authState = context.read<AuthBloc>().state;
    final userName = authState is AuthAuthenticated ? authState.user.name : '-';

    // 地址处理：优先使用选择的位置，其次是自定义地址，然后是解析的地址
    String locationText;
    if (_selectedNearbyPlace != null) {
      locationText = _selectedNearbyPlace!.displayText;
    } else if (_fieldCustomValues[WatermarkFieldType.addressDetail]
            ?.trim()
            .isNotEmpty ==
        true) {
      locationText = _fieldCustomValues[WatermarkFieldType.addressDetail]!;
    } else if (_currentAddress != null &&
        _currentAddress!.isNotEmpty &&
        !_currentAddress!.contains(',')) {
      locationText = _currentAddress!;
    } else {
      locationText = '定位中...';
    }

    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_currentTime);
    final dateStr = DateFormat('yyyy-MM-dd').format(_currentTime);
    final timeOnlyStr = DateFormat('HH:mm:ss').format(_currentTime);
    const days = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final weekdayStr = days[_currentTime.weekday - 1];

    return {
      'timeFull': timeStr,
      'timeDate': '$dateStr  $weekdayStr',
      'timeOnly': timeOnlyStr,
      'projectName': _fieldCustomValues[WatermarkFieldType.projectName]
                  ?.trim()
                  .isNotEmpty ==
              true
          ? _fieldCustomValues[WatermarkFieldType.projectName]!
          : _selectedProjectName,
      'addressDetail': locationText,
      'userName': userName,
      'gpsLat':
          _latitude == null ? '--' : '纬度: ${_latitude!.toStringAsFixed(6)}',
      'gpsLng':
          _longitude == null ? '--' : '经度: ${_longitude!.toStringAsFixed(6)}',
      'weather': _weather == '暂无' ? '已隐藏' : _weather,
      'temperature': (_temperature != '--') ? '温度: $_temperature℃' : '',
      'humidity': (_humidity != '--') ? '湿度: $_humidity%' : '',
      'altitude':
          _altitude == null ? '' : '海拔: ${_altitude!.toStringAsFixed(1)}m',
      'antiFakeCode': antiFakeCode ?? '',
      'workContent': _fieldCustomValues[WatermarkFieldType.workContent] ??
          _fieldCustomValues[WatermarkFieldType.taskDescription] ??
          _fieldCustomValues[WatermarkFieldType.inspectionContent] ??
          _fieldCustomValues[WatermarkFieldType.acceptanceContent] ??
          '',
      'manager': _fieldCustomValues[WatermarkFieldType.manager] ?? '',
      'teamLeader': _fieldCustomValues[WatermarkFieldType.teamLeader] ?? '',
      'position': _fieldCustomValues[WatermarkFieldType.position] ?? '',
      'remark': _fieldCustomValues[WatermarkFieldType.remark] ?? '',
      'companyName': _fieldCustomValues[WatermarkFieldType.companyName] ?? '',
      'contractorOrg':
          _fieldCustomValues[WatermarkFieldType.contractorOrg] ?? '',
      'supervisorOrg':
          _fieldCustomValues[WatermarkFieldType.supervisorOrg] ?? '',
      'clientOrg': _fieldCustomValues[WatermarkFieldType.clientOrg] ?? '',
      'homeowner': _fieldCustomValues[WatermarkFieldType.homeowner] ?? '',
      'deviceNo': _fieldCustomValues[WatermarkFieldType.deviceNo] ?? '',
      'safetyStatus':
          _fieldCustomValues[WatermarkFieldType.safetyStatus] ?? '正常',
      'deviceStatus':
          _fieldCustomValues[WatermarkFieldType.deviceStatus] ?? '正常',
      'acceptanceResult':
          _fieldCustomValues[WatermarkFieldType.acceptanceResult] ?? '合格',
      'personCount': _fieldCustomValues[WatermarkFieldType.personCount] ?? '',
      'photoNo': _fieldCustomValues[WatermarkFieldType.photoNo] ?? '',
    };
  }

  String _fieldValue(WatermarkFieldType field) {
    final data = _buildWatermarkData();
    return _getFieldValueFromData(field, data);
  }

  /// 从 slot 获取当前应显示的数值，与水印预览的 _getSlotValue 逻辑保持一致
  String _getSlotDisplayValue(WatermarkSlot slot) {
    final data = _buildWatermarkData();
    // 1) binding → data
    if (slot.binding != null && slot.binding!.isNotEmpty) {
      final fieldType = WatermarkTemplate.bindingToFieldType(slot.binding);
      if (fieldType != null) {
        final value = _getFieldValueFromData(fieldType, data);
        if (value.isNotEmpty) return value;
      }
    }
    // 2) customText
    if (slot.customText != null && slot.customText!.isNotEmpty) {
      return slot.customText!;
    }
    // 3) label → data
    if (slot.label.isNotEmpty) {
      final fieldType = WatermarkTemplate.labelToFieldType(slot.label);
      final value = _getFieldValueFromData(fieldType, data);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// 从数据Map中获取字段值（静态方法，供预览和实际照片共用）
  static String _getFieldValueFromData(
      WatermarkFieldType field, Map<String, String> data) {
    switch (field) {
      case WatermarkFieldType.timeFull:
        return data['timeFull'] ?? '';
      case WatermarkFieldType.timeDate:
        return data['timeDate'] ?? '';
      case WatermarkFieldType.timeOnly:
        return data['timeOnly'] ?? '';
      case WatermarkFieldType.projectName:
        return data['projectName'] ?? '未关联项目';
      case WatermarkFieldType.projectAddress:
      case WatermarkFieldType.addressDetail:
        return data['addressDetail'] ?? '';
      case WatermarkFieldType.userName:
        return data['userName'] ?? '-';
      case WatermarkFieldType.weather:
        return data['weather'] ?? '已隐藏';
      case WatermarkFieldType.temperature:
        return data['temperature'] ?? '';
      case WatermarkFieldType.humidity:
        return data['humidity'] ?? '';
      case WatermarkFieldType.altitude:
        return data['altitude'] ?? '';
      case WatermarkFieldType.gpsLat:
        return data['gpsLat'] ?? '--';
      case WatermarkFieldType.gpsLng:
        return data['gpsLng'] ?? '--';
      case WatermarkFieldType.workContent:
      case WatermarkFieldType.taskDescription:
      case WatermarkFieldType.inspectionContent:
      case WatermarkFieldType.acceptanceContent:
        return data['workContent'] ?? '点击编辑本条内容';
      case WatermarkFieldType.manager:
        return data['manager'] ?? '';
      case WatermarkFieldType.teamLeader:
        return data['teamLeader'] ?? '';
      case WatermarkFieldType.position:
        return data['position'] ?? '';
      case WatermarkFieldType.remark:
        return data['remark'] ?? '';
      case WatermarkFieldType.companyName:
        return data['companyName'] ?? '';
      case WatermarkFieldType.contractorOrg:
        return data['contractorOrg'] ?? '';
      case WatermarkFieldType.supervisorOrg:
        return data['supervisorOrg'] ?? '';
      case WatermarkFieldType.clientOrg:
        return data['clientOrg'] ?? '';
      case WatermarkFieldType.homeowner:
        return data['homeowner'] ?? '';
      case WatermarkFieldType.deviceNo:
        return data['deviceNo'] ?? '';
      case WatermarkFieldType.safetyStatus:
        return data['safetyStatus'] ?? '正常';
      case WatermarkFieldType.deviceStatus:
        return data['deviceStatus'] ?? '正常';
      case WatermarkFieldType.acceptanceResult:
        return data['acceptanceResult'] ?? '合格';
      case WatermarkFieldType.personCount:
        return data['personCount'] ?? '';
      case WatermarkFieldType.photoNo:
        return data['photoNo'] ?? '';
      case WatermarkFieldType.antiFakeCode:
        return data['antiFakeCode'] ?? '';
      case WatermarkFieldType.antiTamperNotice:
        return '本照片为现场真实记录，禁止篡改';
      default:
        return data[field.name] ?? field.label;
    }
  }

  void _toggleTemplateField(WatermarkFieldType field, bool enabled) {
    final template = _selectedTemplate;
    if (template == null) return;
    final next = Map<WatermarkFieldType, bool>.from(template.fieldEnabled);
    next[field] = enabled;
    setState(() {
      _selectedTemplate = template.copyWith(fieldEnabled: next);
    });
  }

  Future<void> _editTemplateField(WatermarkFieldType field) async {
    if (field == WatermarkFieldType.addressDetail ||
        field == WatermarkFieldType.projectAddress) {
      await _openLocationPicker();
      return;
    }

    final currentValue =
        _fieldCustomValues[field] ?? _defaultEditableValue(field);
    await _editTextfield(
      title: '编辑${_fieldTitle(field)}',
      initialValue: currentValue,
      onSave: (val) {
        setState(() {
          _fieldCustomValues[field] = val;
          if (field == WatermarkFieldType.projectName &&
              val.trim().isNotEmpty) {
            _customCheckinName = val;
          }
        });
      },
    );
  }

  Future<void> _openLocationPicker() async {
    if (_isOpeningLocationPicker) return;

    setState(() => _isOpeningLocationPicker = true);

    try {
      var lat = _latitude;
      var lng = _longitude;

      // 如果还没有坐标，先尝试重新定位
      if (lat == null || lng == null) {
        await _retryLowAccuracyGeo();
        lat = _latitude;
        lng = _longitude;
      }

      // 仍然没有坐标，提示用户
      if (lat == null || lng == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取位置，请检查定位权限和GPS开关')),
          );
        }
        return;
      }

      if (!mounted) return;
      final selected = await Navigator.of(context).push<AmapNearbyPlace>(
        MaterialPageRoute(
          builder: (_) => _LocationPickerScreen(
            latitude: lat!,
            longitude: lng!,
            currentAddress: _currentAddress,
            selectedPlace: _selectedNearbyPlace,
            preloadedPlaces: _nearbyPlaces,
          ),
        ),
      );

      if (!mounted || selected == null) return;
      setState(() {
        _selectedNearbyPlace = selected;
        _fieldCustomValues[WatermarkFieldType.addressDetail] =
            selected.displayText;
        _fieldCustomValues[WatermarkFieldType.projectAddress] =
            selected.displayText;
      });
    } finally {
      if (mounted) {
        setState(() => _isOpeningLocationPicker = false);
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        _minZoomLevel = await _cameraController!.getMinZoomLevel();
        _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
        await _cameraController!.setFlashMode(_flashMode);
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      }
    } catch (e) {
      debugPrint('Camera Error: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final XFile photo = await _cameraController!.takePicture();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已拍摄，正在为您生成带防伪码的高清水印照片...'),
          duration: Duration(seconds: 2),
        ),
      );
      await _processAndSavePhotoLocally(File(photo.path));
      if (mounted) {
        _showUploadReminder();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍摄失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _processAndSavePhotoLocally(File rawFile) async {
    final repo = context.read<CheckinRepository>();
    final authState = context.read<AuthBloc>().state;
    String userName =
        authState is AuthAuthenticated ? authState.user.name : 'Unknown';
    String prjName = '未关联项目';
    if (_selectedProjectId != null && _projects.isNotEmpty) {
      try {
        prjName = _projects.firstWhere((p) => p.id == _selectedProjectId).name;
      } catch (e) {
        debugPrint('查找项目名称失败: $e');
      }
    }
    String code;
    try {
      if (!mounted) return;
      code = await repo.reserveWatermarkCode();
    } catch (e) {
      code = const Uuid().v4().substring(0, 16).toUpperCase();
    }
    if (!mounted) return;
    try {
      // 使用与预览相同的水印数据构建逻辑
      final watermarkData = _buildWatermarkData(antiFakeCode: code);

      final watermarkedFile = await WatermarkService.addWatermark(
        imageFile: rawFile,
        userName: userName,
        projectName: prjName,
        latitude: _latitude ?? 0.0,
        longitude: _longitude ?? 0.0,
        timestamp: _currentTime,
        watermarkCode: code,
        address: _selectedNearbyPlace?.displayText ?? _currentAddress,
        customName: _customCheckinName,
        localLogoFile: _localLogoFile,
        template: _selectedTemplate,
        normalizedOffset: _normalizedOffset,
        scale: _watermarkScale,
        rotationTurns: _watermarkRotationTurns,
        weather: _weather != '暂无' ? _weather : '暂无天气',
        temperature: _temperature,
        humidity: _humidity,
        altitude: _altitude,
        manager: _fieldCustomValues[WatermarkFieldType.manager],
        teamLeader: _fieldCustomValues[WatermarkFieldType.teamLeader],
        workContent: _fieldCustomValues[WatermarkFieldType.workContent] ??
            _fieldCustomValues[WatermarkFieldType.taskDescription] ??
            _fieldCustomValues[WatermarkFieldType.inspectionContent] ??
            _fieldCustomValues[WatermarkFieldType.acceptanceContent],
        position: _fieldCustomValues[WatermarkFieldType.position],
        remark: _fieldCustomValues[WatermarkFieldType.remark],
        companyName: _fieldCustomValues[WatermarkFieldType.companyName],
        contractorOrg: _fieldCustomValues[WatermarkFieldType.contractorOrg],
        watermarkData: watermarkData,
      );
      final record = LocalPhotoRecord(
        id: const Uuid().v4(),
        path: watermarkedFile.path,
        watermarkCode: code,
        createdTime: DateFormat('yyyy/MM/dd HH:mm').format(_currentTime),
        checkinType: _activeCheckinTypeCode,
        customCheckinName: _customCheckinName,
        projectId: _selectedProjectId,
        latitude: _latitude ?? 0.0,
        longitude: _longitude ?? 0.0,
        address: _selectedNearbyPlace?.displayText ?? _currentAddress ?? '',
        remark: '',
      );
      await LocalAlbumService.savePhoto(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('水印相片已成功保存至本地相册！需上传请点击左下角相册'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 180, left: 16, right: 16),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('水印合成失败或保存出错: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showWatermarkEditPanel() {
    final colors = context.colors;
    final template = _selectedTemplate;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
                top: 16,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '水印信息设置',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        _buildWatermarkSettingRow(
                          label: '打卡类型',
                          value: context.read<AttendanceBloc>().state
                                  is AttendanceLoaded
                              ? (context.read<AttendanceBloc>().state
                                      as AttendanceLoaded)
                                  .checkinTypes
                                  .firstWhere(
                                    (t) => t.code == _activeCheckinTypeCode,
                                    orElse: () => (context
                                            .read<AttendanceBloc>()
                                            .state as AttendanceLoaded)
                                        .checkinTypes
                                        .first,
                                  )
                                  .name
                              : '默认打卡',
                          enabled: true,
                          showSwitch: false,
                          onTap: () =>
                              _showCheckinTypeSelector(context, setModalState),
                        ),
                        _buildWatermarkSettingRow(
                          label: '打卡名称',
                          value: _watermarkTitle,
                          enabled: true,
                          showSwitch: false,
                          onTap: () async {
                            await _editTextfield(
                              title: '编辑打卡名称',
                              initialValue: _watermarkTitle,
                              onSave: (val) {
                                setModalState(() => _watermarkTitle = val);
                                setState(() {
                                  _watermarkTitle = val;
                                  // 同步更新模板 titleSlot，清空 binding 让自定义标题直接生效
                                  _syncTitleToTemplate();
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Text(
                            '当前模板字段',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // 副标题插槽（如时间）
                        if (template?.subtitleSlot != null)
                          _buildWatermarkSettingRowForSlot(
                            template!.subtitleSlot!,
                            setModalState,
                          ),
                        // 内容插槽 — 与水印预览的 contentSlots 一一对应
                        ...?template?.contentSlots.map((slot) {
                          return _buildWatermarkSettingRowForSlot(
                            slot,
                            setModalState,
                          );
                        }),
                        // 如果模板没有任何插槽，兜底显示默认字段
                        if (template == null ||
                            (template.contentSlots.isEmpty &&
                                template.subtitleSlot == null))
                          ..._buildDefaultWatermarkSettingRows(setModalState),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 基于 WatermarkSlot 构建设置行，label/value 与水印预览完全一致
  Widget _buildWatermarkSettingRowForSlot(
    WatermarkSlot slot,
    StateSetter setModalState,
  ) {
    final ft = slot.fieldType;
    final template = _selectedTemplate;
    final enabled = ft == null || (template?.fieldEnabled[ft] ?? true);

    String? trailingHint;
    if (ft == WatermarkFieldType.addressDetail ||
        ft == WatermarkFieldType.projectAddress) {
      trailingHint = _isLoadingNearbyPlaces ? '定位中...' : '周边可选';
    }

    return _buildWatermarkSettingRow(
      label: slot.label,
      value: _getSlotDisplayValue(slot),
      enabled: enabled,
      showSwitch: ft != null && _fieldSupportsToggle(ft),
      onChanged: ft != null && _fieldSupportsToggle(ft)
          ? (value) {
              setModalState(() {});
              _toggleTemplateField(ft, value);
            }
          : null,
      onTap: ft != null && _fieldSupportsEdit(ft)
          ? () async {
              await _editTemplateField(ft);
              if (context.mounted) {
                setModalState(() {});
              }
            }
          : null,
      trailingHint: trailingHint,
    );
  }

  /// 兜底：模板未加载时显示的默认字段
  List<Widget> _buildDefaultWatermarkSettingRows(StateSetter setModalState) {
    const defaults = [
      WatermarkFieldType.projectName,
      WatermarkFieldType.workContent,
      WatermarkFieldType.userName,
      WatermarkFieldType.timeFull,
      WatermarkFieldType.weather,
      WatermarkFieldType.addressDetail,
    ];
    return defaults.map((field) {
      final enabled = _selectedTemplate?.fieldEnabled[field] ?? true;
      return _buildWatermarkSettingRow(
        label: _fieldTitle(field),
        value: _fieldValue(field),
        enabled: enabled,
        showSwitch: _fieldSupportsToggle(field),
        onChanged: _fieldSupportsToggle(field)
            ? (value) {
                setModalState(() {});
                _toggleTemplateField(field, value);
              }
            : null,
        onTap: _fieldSupportsEdit(field)
            ? () async {
                await _editTemplateField(field);
                if (context.mounted) {
                  setModalState(() {});
                }
              }
            : null,
        trailingHint: field == WatermarkFieldType.addressDetail ||
                field == WatermarkFieldType.projectAddress
            ? (_isLoadingNearbyPlaces ? '定位中...' : '周边可选')
            : null,
      );
    }).toList();
  }

  void _showCheckinTypeSelector(BuildContext ctx, StateSetter parentSetState) {
    final colors = context.colors;
    final state = context.read<AttendanceBloc>().state;
    if (state is! AttendanceLoaded) return;

    final types = state.checkinTypes;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
      ),
      builder: (bottomCtx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomCtx).padding.bottom,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '选择打卡类型',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: types.length,
                  itemBuilder: (context, index) {
                    final type = types[index];
                    final isSelected = _activeCheckinTypeCode == type.code;
                    return ListTile(
                      leading: Icon(
                        type.categoryIcon,
                        color:
                            isSelected ? colors.primary : colors.textTertiary,
                      ),
                      title: Text(
                        type.name,
                        style: TextStyle(
                          color:
                              isSelected ? colors.primary : colors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: colors.primary)
                          : null,
                      onTap: () {
                        _activeCheckinTypeCode = type.code;
                        // 切换打卡类型时同步更新水印主标题
                        _watermarkTitle = type.name;
                        _syncTitleToTemplate();
                        parentSetState(() {});
                        setState(() {});
                        Navigator.pop(bottomCtx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWatermarkSettingRow({
    required String label,
    required String value,
    required bool enabled,
    bool showSwitch = true,
    String? trailingHint,
    ValueChanged<bool>? onChanged,
    VoidCallback? onTap,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BentoRadius.md),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(BentoRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSwitch) ...[
                Switch(
                  value: enabled,
                  onChanged: onChanged,
                  activeThumbColor: colors.success,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      enabled ? value : '已隐藏',
                      style: TextStyle(
                        color: enabled
                            ? colors.textSecondary
                            : colors.textTertiary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (trailingHint != null)
                    Text(
                      trailingHint,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (onTap != null)
                    Padding(
                      padding:
                          EdgeInsets.only(top: trailingHint != null ? 8 : 0),
                      child:
                          Icon(Icons.chevron_right, color: colors.textTertiary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editTextfield({
    required String title,
    required String initialValue,
    required Function(String) onSave,
  }) async {
    final colors = context.colors;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: initialValue)
          ..selection = TextSelection.collapsed(offset: initialValue.length);
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(title, style: TextStyle(color: colors.textPrimary)),
          content: TextField(
            controller: ctrl,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.border),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text('保存', style: TextStyle(color: colors.primary)),
            ),
          ],
        );
      },
    );
    if (result != null) {
      onSave(result);
    }
  }

  void _showUploadReminder() {
    final colors = context.colors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BentoRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.primaryLight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline,
                    color: colors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                '水印照片已保存！',
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '请记得前往本地图库将水印照片上传打卡，以完成本次考勤记录。',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(BentoRadius.md)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('稍后上传',
                          style: TextStyle(color: colors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LocalAlbumScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(BentoRadius.md)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('立即上传',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFlash() async {
    if (_cameraController == null) return;
    if (_flashMode == FlashMode.auto) {
      _flashMode = FlashMode.always;
    } else if (_flashMode == FlashMode.always) {
      _flashMode = FlashMode.off;
    } else {
      _flashMode = FlashMode.auto;
    }
    await _cameraController!.setFlashMode(_flashMode);
    setState(() {});
  }

  void _setZoomLevel(double zoom) async {
    if (_cameraController == null) return;
    _currentZoomLevel = zoom.clamp(_minZoomLevel, _maxZoomLevel);
    await _cameraController!.setZoomLevel(_currentZoomLevel);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!_isInitialized || _cameraController == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    final boxWidth = screenWidth;
    final boxHeight = screenWidth * _cameraController!.value.aspectRatio;

    return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned(
                top: topPadding,
                left: 0,
                right: 0,
                child: SizedBox(
                    width: boxWidth,
                    height: boxHeight,
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showWatermarkEditPanel(),
                        onScaleStart: (_) {
                          setState(() {
                            _isDragging = true;
                            _baseWatermarkScale = _watermarkScale;
                          });
                        },
                        onScaleEnd: (_) => setState(() => _isDragging = false),
                        onScaleUpdate: (details) {
                          setState(() {
                            if (details.pointerCount >= 2) {
                              _watermarkScale =
                                  (_baseWatermarkScale * details.scale)
                                      .clamp(0.5, 2.5);
                            } else {
                              final dx = details.focalPointDelta.dx;
                              final dy = details.focalPointDelta.dy;
                              _normalizedOffset += Offset(
                                dx / boxWidth,
                                dy / boxHeight,
                              );

                              _normalizedOffset = Offset(
                                _normalizedOffset.dx.clamp(0.0, 1.0),
                                _normalizedOffset.dy.clamp(0.0, 1.0),
                              );
                            }
                          });
                        },
                        child: Stack(fit: StackFit.expand, children: [
                          CameraPreview(_cameraController!),
                          _buildDraggableWatermarkOverlay(),
                          _buildCameraTopBar(),
                          _buildZoomControls(colors),
                        ])))),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topPadding,
              child: Container(color: colors.background),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControlBar(colors),
            )
          ],
        ));
  }

  Widget _buildZoomControls(BentoColors colors) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildZoomButton('1x', 1.0, colors),
              const SizedBox(width: 16),
              _buildZoomButton('2x', 2.0, colors),
              const SizedBox(width: 16),
              _buildZoomButton('3x', 3.0, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomButton(String label, double zoomValue, BentoColors colors) {
    final safeZoom = zoomValue.clamp(_minZoomLevel, _maxZoomLevel);
    final isSelected = (_currentZoomLevel - safeZoom).abs() < 0.1;

    return GestureDetector(
      onTap: () => _setZoomLevel(safeZoom),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? colors.primary : Colors.white24,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableWatermarkOverlay() {
    final template = _selectedTemplate;
    if (template == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: WatermarkPainter(
            template: template,
            data: _buildWatermarkData(),
            normalizedOffset: _normalizedOffset,
            scale: _watermarkScale,
            rotationTurns: _watermarkRotationTurns,
            drawSelection: _isDragging,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.rotate_right, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _watermarkRotationTurns = (_watermarkRotationTurns + 1) % 4;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  _flashMode == FlashMode.auto
                      ? Icons.flash_auto
                      : _flashMode == FlashMode.always
                          ? Icons.flash_on
                          : Icons.flash_off,
                  color:
                      _flashMode != FlashMode.off ? Colors.amber : Colors.white,
                ),
                onPressed: _toggleFlash,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '拖拽/缩放/点击编辑水印',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
            onPressed: () async {
              if (_cameras!.length > 1) {
                final currDesc = _cameraController!.description;
                final newDesc = _cameras!.firstWhere((c) => c != currDesc);
                await _cameraController!.dispose();
                _cameraController = CameraController(
                  newDesc,
                  ResolutionPreset.high,
                  enableAudio: false,
                );
                await _cameraController!.initialize();
                if (mounted) setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlBar(BentoColors colors) {
    // 当前选中的项目名称
    String selectedProjectName = '选择项目';
    if (_selectedProjectId != null && _projects.isNotEmpty) {
      try {
        selectedProjectName =
            _projects.firstWhere((p) => p.id == _selectedProjectId).name;
      } catch (e) {
        debugPrint('查找项目名称失败: $e');
      }
    }

    return Container(
      color: colors.background,
      padding: const EdgeInsets.only(top: 12, bottom: 40, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 项目选择行
          GestureDetector(
            onTap: _showProjectPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    selectedProjectName,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.swap_horiz, size: 16, color: colors.textTertiary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LocalAlbumScreen()),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.photo_library_outlined,
                        color: colors.textPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '本地图库',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _isCapturing ? null : _takePhoto,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border, width: 4),
                    color: colors.background,
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                      child: _isCapturing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const SizedBox(),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showWatermarkSettings,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.branding_watermark,
                        color: colors.textPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '水印模版',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWatermarkSettings() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            top: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.72,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '水印模版',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ..._templates.map((template) {
                      final isActive = _selectedTemplate?.id == template.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(BentoRadius.md),
                          border: Border.all(
                            color: isActive ? colors.primary : colors.border,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(BentoRadius.md),
                          onTap: () {
                            setState(() {
                              _selectedTemplate = template;
                              _syncTemplateState();
                            });
                            Navigator.of(ctx).pop();
                            _showWatermarkEditPanel();
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(BentoRadius.md),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF4A6FA5),
                                        Color(0xFF2C3E50),
                                        Color(0xFF1A1A2E),
                                      ],
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 12,
                                        bottom: 12,
                                        right: 12,
                                        height: 120,
                                        child: CustomPaint(
                                          painter: WatermarkPainter(
                                            template: template,
                                            data: _buildWatermarkData(),
                                            normalizedOffset:
                                                const Offset(0.02, 0.28),
                                            scale: 0.62,
                                          ),
                                        ),
                                      ),
                                      if (isActive)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              '使用中',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            template.displayTitle,
                                            style: TextStyle(
                                              color: isActive
                                                  ? colors.primary
                                                  : colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${template.skeletonPreset == "glass" ? "毛玻璃" : template.skeletonPreset == "clean" ? "极简无底" : template.skeletonPreset == "compact" ? "紧凑" : "经典"} · ${template.contentSlots.length}个字段 · ${template.category.label}',
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isActive
                                          ? Icons.check_circle
                                          : Icons.chevron_right,
                                      color: isActive
                                          ? colors.primary
                                          : colors.textTertiary,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (_templates.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(BentoRadius.md),
                        ),
                        child: Text(
                          '暂未加载到后台模板，点击画面区域仍可编辑当前水印内容。',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showWatermarkEditPanel();
                      },
                      icon: const Icon(Icons.tune),
                      label: const Text('编辑当前模板字段'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示项目选择弹窗
  void _showProjectPicker() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
            top: 12,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '选择关联项目',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: colors.divider, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    final isActive = _selectedProjectId == project.id;
                    return ListTile(
                      leading: Icon(
                        isActive ? Icons.check_circle : Icons.folder_outlined,
                        color: isActive ? colors.primary : colors.textTertiary,
                        size: 22,
                      ),
                      title: Text(
                        project.name,
                        style: TextStyle(
                          color: isActive ? colors.primary : colors.textPrimary,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: project.address.isNotEmpty
                          ? Text(
                              project.address,
                              style: TextStyle(
                                  color: colors.textTertiary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: isActive
                          ? Icon(Icons.check_circle,
                              color: colors.primary, size: 20)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedProjectId = project.id;
                          _customCheckinName = project.name;
                          // 手动选择项目时同步更新水印主标题
                          _watermarkTitle = project.name;
                          _syncTitleToTemplate();
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationPickerScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? currentAddress;
  final AmapNearbyPlace? selectedPlace;
  final List<AmapNearbyPlace> preloadedPlaces;

  const _LocationPickerScreen({
    required this.latitude,
    required this.longitude,
    this.currentAddress,
    this.selectedPlace,
    this.preloadedPlaces = const [],
  });

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<AmapNearbyPlace> _places;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 如果传入了预加载的地址列表，直接使用；否则从网络加载
    if (widget.preloadedPlaces.isNotEmpty) {
      _places = List.from(widget.preloadedPlaces);
      _isLoading = false;
    } else {
      _places = [];
      _loadPlaces();
    }
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);
    final places = await AmapGeoService.searchNearbyPlaces(
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
    if (!mounted) return;
    setState(() {
      _places = places;
      _isLoading = false;
    });
  }

  List<AmapNearbyPlace> get _filteredPlaces {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return _places;
    return _places.where((place) {
      return place.name.toLowerCase().contains(keyword) ||
          place.address.toLowerCase().contains(keyword) ||
          place.adName.toLowerCase().contains(keyword);
    }).toList();
  }

  Future<void> _editCustomLocation() async {
    String text = widget.currentAddress ?? '';
    final colors = context.colors;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('自定义位置', style: TextStyle(color: colors.textPrimary)),
        content: TextField(
          controller: TextEditingController(text: text)
            ..selection = TextSelection.collapsed(offset: text.length),
          onChanged: (value) => text = value,
          decoration: const InputDecoration(
            hintText: '输入你想展示的位置',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(
                AmapNearbyPlace(
                  id: 'custom',
                  name: text.trim(),
                  address: text.trim(),
                  cityName: '',
                  adName: '',
                  distance: '',
                  location:
                      '${widget.longitude.toStringAsFixed(6)},${widget.latitude.toStringAsFixed(6)}',
                ),
              );
            },
            child: Text('确定', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filteredPlaces = _filteredPlaces;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('位置'),
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(color: colors.primary)),
        ),
        leadingWidth: 72,
        actions: [
          TextButton.icon(
            onPressed: _loadPlaces,
            icon: Icon(Icons.refresh, color: colors.primary),
            label: Text('刷新', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(color: colors.divider),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.currentAddress ?? '当前位置',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '自动列出当前定位周边地址，也可以手动修改',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '搜索或筛选周边位置',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _editCustomLocation,
                      child:
                          Text('修改', style: TextStyle(color: colors.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                : filteredPlaces.isEmpty
                    ? Center(
                        child: Text(
                          '附近暂无地点，可点右上角刷新或手动修改',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: filteredPlaces.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                          color: colors.divider,
                        ),
                        itemBuilder: (context, index) {
                          final place = filteredPlaces[index];
                          final isSelected =
                              widget.selectedPlace?.id == place.id;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 6),
                            title: Text(
                              place.name,
                              style: TextStyle(
                                color: isSelected
                                    ? colors.primary
                                    : colors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                place.subtitle,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: colors.primary)
                                : Icon(Icons.chevron_right,
                                    color: colors.textTertiary),
                            onTap: () => Navigator.of(context).pop(place),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
