import 'package:flutter/material.dart';

enum WatermarkCategory {
  general,
  engineering,
  decoration,
  safetyInspection,
  equipmentInspection,
  attendance,
  projectAcceptance,
  enterpriseArchive,
}

extension WatermarkCategoryExtension on WatermarkCategory {
  String get label {
    switch (this) {
      case WatermarkCategory.general:
        return '通用基础';
      case WatermarkCategory.engineering:
        return '工程施工';
      case WatermarkCategory.decoration:
        return '装修现场';
      case WatermarkCategory.safetyInspection:
        return '安全巡检';
      case WatermarkCategory.equipmentInspection:
        return '设备巡检';
      case WatermarkCategory.attendance:
        return '人员考勤';
      case WatermarkCategory.projectAcceptance:
        return '项目验收';
      case WatermarkCategory.enterpriseArchive:
        return '企业存档';
    }
  }

  IconData get icon {
    switch (this) {
      case WatermarkCategory.general:
        return Icons.label_outline;
      case WatermarkCategory.engineering:
        return Icons.construction;
      case WatermarkCategory.decoration:
        return Icons.home_repair_service;
      case WatermarkCategory.safetyInspection:
        return Icons.security;
      case WatermarkCategory.equipmentInspection:
        return Icons.precision_manufacturing;
      case WatermarkCategory.attendance:
        return Icons.badge_outlined;
      case WatermarkCategory.projectAcceptance:
        return Icons.assignment_turned_in;
      case WatermarkCategory.enterpriseArchive:
        return Icons.business_center;
    }
  }
}

enum WatermarkStyle {
  bottomLeft,
  bottomBar,
  topRight,
  fullScreenWatermark,
  qrCode,
}

extension WatermarkStyleExtension on WatermarkStyle {
  String get label {
    switch (this) {
      case WatermarkStyle.bottomLeft:
        return '左下半透明';
      case WatermarkStyle.bottomBar:
        return '底部通栏';
      case WatermarkStyle.topRight:
        return '右上角标签';
      case WatermarkStyle.fullScreenWatermark:
        return '全屏淡影';
      case WatermarkStyle.qrCode:
        return '二维码+文字';
    }
  }
}

enum WatermarkFieldType {
  timeFull,
  timeDate,
  timeOnly,
  projectName,
  projectNo,
  projectAddress,
  clientOrg,
  contractorOrg,
  supervisorOrg,
  manager,
  teamLeader,
  userName,
  position,
  workContent,
  taskDescription,
  inspectionContent,
  acceptanceContent,
  safetyStatus,
  deviceStatus,
  acceptanceResult,
  gpsLat,
  gpsLng,
  addressDetail,
  altitude,
  weather,
  temperature,
  humidity,
  companyName,
  companyLogo,
  antiFakeCode,
  antiTamperNotice,
  remark,
  homeowner,
  deviceNo,
  personCount,
  photoNo,
}

extension WatermarkFieldTypeExtension on WatermarkFieldType {
  String get label {
    switch (this) {
      case WatermarkFieldType.timeFull:
        return '完整时间';
      case WatermarkFieldType.timeDate:
        return '日期';
      case WatermarkFieldType.timeOnly:
        return '时分秒';
      case WatermarkFieldType.projectName:
        return '项目名称';
      case WatermarkFieldType.projectNo:
        return '项目编号';
      case WatermarkFieldType.projectAddress:
        return '项目地址';
      case WatermarkFieldType.clientOrg:
        return '建设单位';
      case WatermarkFieldType.contractorOrg:
        return '施工单位';
      case WatermarkFieldType.supervisorOrg:
        return '监理单位';
      case WatermarkFieldType.manager:
        return '项目负责人';
      case WatermarkFieldType.teamLeader:
        return '班组长';
      case WatermarkFieldType.userName:
        return '打卡人';
      case WatermarkFieldType.position:
        return '岗位/工种';
      case WatermarkFieldType.workContent:
        return '施工内容';
      case WatermarkFieldType.taskDescription:
        return '工作任务';
      case WatermarkFieldType.inspectionContent:
        return '巡检内容';
      case WatermarkFieldType.acceptanceContent:
        return '验收内容';
      case WatermarkFieldType.safetyStatus:
        return '安全状态';
      case WatermarkFieldType.deviceStatus:
        return '设备状态';
      case WatermarkFieldType.acceptanceResult:
        return '验收结果';
      case WatermarkFieldType.gpsLat:
        return '纬度';
      case WatermarkFieldType.gpsLng:
        return '经度';
      case WatermarkFieldType.addressDetail:
        return '详细地址';
      case WatermarkFieldType.altitude:
        return '海拔';
      case WatermarkFieldType.weather:
        return '天气';
      case WatermarkFieldType.temperature:
        return '温度';
      case WatermarkFieldType.humidity:
        return '湿度';
      case WatermarkFieldType.companyName:
        return '公司名称';
      case WatermarkFieldType.companyLogo:
        return '公司LOGO';
      case WatermarkFieldType.antiFakeCode:
        return '防伪码';
      case WatermarkFieldType.antiTamperNotice:
        return '防篡改提示';
      case WatermarkFieldType.remark:
        return '备注';
      case WatermarkFieldType.homeowner:
        return '户主姓名';
      case WatermarkFieldType.deviceNo:
        return '设备编号';
      case WatermarkFieldType.personCount:
        return '人员数量';
      case WatermarkFieldType.photoNo:
        return '照片编号';
    }
  }
}

class WatermarkSlot {
  final String id;
  final String label;
  final String? binding;
  final String? customText;
  final Map<String, dynamic>? style;

  WatermarkSlot({
    required this.id,
    required this.label,
    this.binding,
    this.customText,
    this.style,
  });

  WatermarkFieldType? get fieldType {
    if (binding != null && binding!.isNotEmpty) {
      return WatermarkTemplate.bindingToFieldType(binding);
    }
    if (label.isNotEmpty) {
      return WatermarkTemplate.labelToFieldType(label);
    }
    return null;
  }

  factory WatermarkSlot.fromJson(
      String id, Map<String, dynamic> json, String? label) {
    return WatermarkSlot(
      id: id,
      label: label ?? '',
      binding: json['binding'] as String?,
      customText: json['customText'] as String?,
      style: json['style'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'binding': binding,
      'customText': customText,
      'style': style,
    };
  }
}

class WatermarkTemplate {
  final String id;
  final String name;
  final String? title;
  final String description;
  final WatermarkCategory category;
  final WatermarkStyle defaultStyle;
  final List<WatermarkFieldType> fields;
  final Map<WatermarkFieldType, bool> fieldEnabled;
  final double opacity;
  final double fontSize;
  final Color textColor;
  final Color backgroundColor;
  final bool hasBorder;
  final String? icon;
  final String skeletonPreset;
  final Map<String, dynamic>? schemaJson;
  final WatermarkSlot? titleSlot;
  final WatermarkSlot? subtitleSlot;
  final List<WatermarkSlot> contentSlots;

  WatermarkTemplate({
    required this.id,
    required this.name,
    this.title,
    this.description = '',
    required this.category,
    this.defaultStyle = WatermarkStyle.bottomLeft,
    required this.fields,
    Map<WatermarkFieldType, bool>? fieldEnabled,
    this.opacity = 0.8,
    this.fontSize = 14.0,
    this.textColor = Colors.white,
    this.backgroundColor = const Color(0xCC000000),
    this.hasBorder = false,
    this.icon,
    this.skeletonPreset = 'default',
    this.schemaJson,
    this.titleSlot,
    this.subtitleSlot,
    this.contentSlots = const [],
  }) : fieldEnabled =
            fieldEnabled ?? Map.fromIterable(fields, value: (_) => true);

  String get displayTitle => title ?? name;

  WatermarkTemplate copyWith({
    String? id,
    String? name,
    String? title,
    String? description,
    WatermarkCategory? category,
    WatermarkStyle? defaultStyle,
    List<WatermarkFieldType>? fields,
    Map<WatermarkFieldType, bool>? fieldEnabled,
    double? opacity,
    double? fontSize,
    Color? textColor,
    Color? backgroundColor,
    bool? hasBorder,
    String? icon,
    String? skeletonPreset,
    Map<String, dynamic>? schemaJson,
    WatermarkSlot? titleSlot,
    WatermarkSlot? subtitleSlot,
    List<WatermarkSlot>? contentSlots,
  }) {
    return WatermarkTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      defaultStyle: defaultStyle ?? this.defaultStyle,
      fields: fields ?? this.fields,
      fieldEnabled: fieldEnabled ?? this.fieldEnabled,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      hasBorder: hasBorder ?? this.hasBorder,
      icon: icon ?? this.icon,
      skeletonPreset: skeletonPreset ?? this.skeletonPreset,
      schemaJson: schemaJson ?? this.schemaJson,
      titleSlot: titleSlot ?? this.titleSlot,
      subtitleSlot: subtitleSlot ?? this.subtitleSlot,
      contentSlots: contentSlots ?? this.contentSlots,
    );
  }

  List<WatermarkFieldType> get enabledFields =>
      fields.where((f) => fieldEnabled[f] ?? true).toList();

  static WatermarkFieldType? bindingToFieldType(String? binding) {
    if (binding == null || binding.isEmpty) return null;
    const bindingMap = {
      'project': WatermarkFieldType.projectName,
      'projectName': WatermarkFieldType.projectName,
      'name': WatermarkFieldType.userName,
      'user': WatermarkFieldType.userName,
      'userName': WatermarkFieldType.userName,
      'time': WatermarkFieldType.timeFull,
      'checkinTime': WatermarkFieldType.timeFull,
      'timeDate': WatermarkFieldType.timeDate,
      'timeOnly': WatermarkFieldType.timeOnly,
      'location': WatermarkFieldType.addressDetail,
      'address': WatermarkFieldType.addressDetail,
      'addressDetail': WatermarkFieldType.addressDetail,
      'gpsLat': WatermarkFieldType.gpsLat,
      'gpsLng': WatermarkFieldType.gpsLng,
      'altitude': WatermarkFieldType.altitude,
      'weather': WatermarkFieldType.weather,
      'temperature': WatermarkFieldType.temperature,
      'humidity': WatermarkFieldType.humidity,
      'deviceNo': WatermarkFieldType.deviceNo,
      'remark': WatermarkFieldType.remark,
      'position': WatermarkFieldType.position,
      'antiFakeCode': WatermarkFieldType.antiFakeCode,
      'custom_text': WatermarkFieldType.workContent,
    };
    return bindingMap[binding];
  }

  static WatermarkFieldType labelToFieldType(String label) {
    if (label.contains('施工') || label.contains('工作') || label.contains('进度')) {
      return WatermarkFieldType.workContent;
    } else if (label.contains('打卡')) {
      return WatermarkFieldType.userName;
    } else if (label.contains('位置') || label.contains('地点')) {
      return WatermarkFieldType.addressDetail;
    } else if (label.contains('天气')) {
      return WatermarkFieldType.weather;
    } else if (label.contains('时间')) {
      return WatermarkFieldType.timeFull;
    } else if (label.contains('海拔')) {
      return WatermarkFieldType.altitude;
    } else if (label.contains('备注')) {
      return WatermarkFieldType.remark;
    } else if (label.contains('项目')) {
      return WatermarkFieldType.projectName;
    }
    return WatermarkFieldType.remark;
  }

  factory WatermarkTemplate.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] ?? json['schema_json'] ?? {};
    final schemaMap =
        schema is Map<String, dynamic> ? schema : <String, dynamic>{};
    final slots = schemaMap['slots'] as Map<String, dynamic>? ?? {};
    final customSlots = schemaMap['customSlots'] as List<dynamic>? ?? [];

    WatermarkSlot? titleSlot;
    WatermarkSlot? subtitleSlot;
    final contentSlots = <WatermarkSlot>[];
    final extractedFields = <WatermarkFieldType>[];

    if (slots.containsKey('title')) {
      final titleData = slots['title'] as Map<String, dynamic>;
      final customText = titleData['customText'] as String?;
      titleSlot = WatermarkSlot(
        id: 'title',
        label: customText?.isNotEmpty == true ? customText! : '项目名称',
        binding: titleData['binding'] as String?,
        customText: customText,
        style: titleData['style'] as Map<String, dynamic>?,
      );
      final fieldType = bindingToFieldType(titleSlot.binding);
      if (fieldType != null) extractedFields.add(fieldType);
    }

    if (slots.containsKey('subtitle')) {
      final subData = slots['subtitle'] as Map<String, dynamic>;
      subtitleSlot = WatermarkSlot(
        id: 'subtitle',
        label: '打卡时间',
        binding: subData['binding'] as String?,
        style: subData['style'] as Map<String, dynamic>?,
      );
      final fieldType = bindingToFieldType(subtitleSlot.binding);
      if (fieldType != null) extractedFields.add(fieldType);
    }

    for (final customSlot in customSlots) {
      if (customSlot is! Map<String, dynamic>) continue;
      final slotId = customSlot['id']?.toString() ?? '';
      final label = customSlot['label'] as String? ?? '';
      final slotData = slots[slotId] as Map<String, dynamic>?;

      final slot = WatermarkSlot.fromJson(slotId, slotData ?? {}, label);
      contentSlots.add(slot);

      if (slot.binding != null && slot.binding!.isNotEmpty) {
        final fieldType = bindingToFieldType(slot.binding);
        if (fieldType != null && !extractedFields.contains(fieldType)) {
          extractedFields.add(fieldType);
        }
      } else if (label.isNotEmpty) {
        final fieldType = labelToFieldType(label);
        if (!extractedFields.contains(fieldType)) {
          extractedFields.add(fieldType);
        }
      }
    }

    if (!extractedFields.contains(WatermarkFieldType.antiFakeCode)) {
      extractedFields.add(WatermarkFieldType.antiFakeCode);
    }

    return WatermarkTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      title: json['title'],
      description: json['description'] ?? '',
      category: WatermarkCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => WatermarkCategory.general,
      ),
      defaultStyle: WatermarkStyle.values.firstWhere(
        (e) => e.name == json['defaultStyle'],
        orElse: () => WatermarkStyle.bottomLeft,
      ),
      fields: extractedFields,
      opacity: (json['opacity'] ?? 0.8).toDouble(),
      fontSize: (json['fontSize'] ?? 14.0).toDouble(),
      skeletonPreset:
          schemaMap['skeletonPreset'] ?? json['skeletonPreset'] ?? 'default',
      schemaJson:
          schemaMap.isNotEmpty ? Map<String, dynamic>.from(schemaMap) : null,
      titleSlot: titleSlot,
      subtitleSlot: subtitleSlot,
      contentSlots: contentSlots,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'description': description,
      'category': category.name,
      'defaultStyle': defaultStyle.name,
      'fields': fields.map((e) => e.name).toList(),
      'fieldEnabled': fieldEnabled.map((k, v) => MapEntry(k.name, v)),
      'opacity': opacity,
      'fontSize': fontSize,
      'skeletonPreset': skeletonPreset,
      if (schemaJson != null) 'schemaJson': schemaJson,
      if (titleSlot != null) 'titleSlot': titleSlot!.toJson(),
      if (subtitleSlot != null) 'subtitleSlot': subtitleSlot!.toJson(),
      'contentSlots': contentSlots.map((s) => s.toJson()).toList(),
    };
  }

  static WatermarkTemplate fromCachedJson(Map<String, dynamic> json) {
    List<WatermarkFieldType> fieldsList = [];
    if (json['fields'] != null) {
      fieldsList = (json['fields'] as List<dynamic>)
          .map((e) => WatermarkFieldType.values.firstWhere(
                (f) => f.name == e,
                orElse: () => WatermarkFieldType.timeFull,
              ))
          .toList();
    }

    Map<WatermarkFieldType, bool> enabledMap = {};
    if (json['fieldEnabled'] != null) {
      (json['fieldEnabled'] as Map<String, dynamic>).forEach((key, value) {
        final field = WatermarkFieldType.values.firstWhere(
          (f) => f.name == key,
          orElse: () => WatermarkFieldType.remark,
        );
        enabledMap[field] = value as bool;
      });
    } else {
      enabledMap = Map.fromIterable(fieldsList, value: (_) => true);
    }

    WatermarkSlot? titleSlot;
    if (json['titleSlot'] != null) {
      final ts = json['titleSlot'] as Map<String, dynamic>;
      titleSlot = WatermarkSlot.fromJson(ts['id'] ?? 'title', ts, ts['label']);
    }

    WatermarkSlot? subtitleSlot;
    if (json['subtitleSlot'] != null) {
      final ss = json['subtitleSlot'] as Map<String, dynamic>;
      subtitleSlot =
          WatermarkSlot.fromJson(ss['id'] ?? 'subtitle', ss, ss['label']);
    }

    List<WatermarkSlot> contentSlots = [];
    if (json['contentSlots'] != null) {
      contentSlots = (json['contentSlots'] as List<dynamic>)
          .map((s) => WatermarkSlot.fromJson(
              s['id'] ?? '', s as Map<String, dynamic>, s['label']))
          .toList();
    }

    return WatermarkTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      title: json['title'],
      description: json['description'] ?? '',
      category: WatermarkCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => WatermarkCategory.general,
      ),
      defaultStyle: WatermarkStyle.values.firstWhere(
        (e) => e.name == json['defaultStyle'],
        orElse: () => WatermarkStyle.bottomLeft,
      ),
      fields: fieldsList,
      fieldEnabled: enabledMap.isNotEmpty ? enabledMap : null,
      opacity: (json['opacity'] ?? 0.8).toDouble(),
      fontSize: (json['fontSize'] ?? 14.0).toDouble(),
      skeletonPreset: json['skeletonPreset'] ?? 'default',
      schemaJson: json['schemaJson'] as Map<String, dynamic>?,
      titleSlot: titleSlot,
      subtitleSlot: subtitleSlot,
      contentSlots: contentSlots,
    );
  }
}
