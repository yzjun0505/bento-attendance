import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Checkin {
  final int id;
  final int userId;
  final int? projectId;
  final String
      type; // 'clock_in', 'clock_out', 'site_visit', 'progress', 'safety', 'device', 'custom', etc.
  final double? latitude;
  final double? longitude;
  final String address;
  final String photo;
  final String remark;
  final bool isOutside;
  final double? distanceToFence;
  final DateTime createdAt;
  final String? projectName;
  final String? watermarkCode;
  final String? rawStatus;
  final String? attendanceStatus;

  Checkin({
    required this.id,
    required this.userId,
    this.projectId,
    required this.type,
    this.latitude,
    this.longitude,
    required this.address,
    required this.photo,
    required this.remark,
    required this.isOutside,
    this.distanceToFence,
    required this.createdAt,
    this.projectName,
    this.watermarkCode,
    this.rawStatus,
    this.attendanceStatus,
  });

  factory Checkin.fromJson(Map<String, dynamic> json) {
    String dateStr = json['created_at'];
    // 后端 dateStrings:true 返回本地时间字符串（如 "2026-04-29 23:26:29"）
    // 替换空格为T让DateTime.parse正确解析，不再加Z（之前加Z导致北京时间被当UTC再+8h偏移）
    // 如果已有时区标记（Z或+），保持原样解析后转本地；否则按本地时间直接解析
    if (dateStr.contains(' ')) {
      dateStr = dateStr.replaceAll(' ', 'T');
    }
    final hasTimezone = dateStr.endsWith('Z') || dateStr.contains('+');

    return Checkin(
      id: json['id'],
      userId: json['user_id'],
      projectId: json['project_id'],
      type: json['type'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      address: json['address'] ?? '',
      photo: json['photo'] ?? '',
      remark: json['remark'] ?? '',
      isOutside: json['is_outside'] == 1,
      distanceToFence: json['distance_to_fence']?.toDouble(),
      createdAt: hasTimezone
          ? DateTime.parse(dateStr).toLocal()
          : DateTime.parse(dateStr),
      projectName: json['project_name'],
      watermarkCode: json['watermark_code'],
      rawStatus: json['raw_status'],
      attendanceStatus: json['attendance_status'],
    );
  }

  String get formattedTime => DateFormat('HH:mm').format(createdAt);
  String get formattedDate => DateFormat('MM月dd日').format(createdAt);

  /// 类型中文名称
  String get typeName {
    switch (type) {
      case 'in':
      case 'clock_in':
        return '上班打卡';
      case 'out':
      case 'clock_out':
        return '下班打卡';
      case 'site_visit':
        return '实地考察';
      case 'progress':
        return '项目进度上报';
      case 'safety':
        return '安全检查';
      case 'device':
        return '设备位置上报';
      case 'custom':
        return '自定义';
      default:
        return type;
    }
  }

  /// 类型颜色
  Color get typeColor {
    switch (type) {
      case 'in':
      case 'clock_in':
        return const Color(0xFF22C55E);
      case 'out':
      case 'clock_out':
        return const Color(0xFFEF4444);
      case 'site_visit':
        return const Color(0xFF3B82F6);
      case 'progress':
        return const Color(0xFFF59E0B);
      case 'safety':
        return const Color(0xFFEF4444);
      case 'device':
        return const Color(0xFF8B5CF6);
      case 'custom':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  /// 类型图标
  IconData get typeIcon {
    switch (type) {
      case 'in':
      case 'clock_in':
        return Icons.login;
      case 'out':
      case 'clock_out':
        return Icons.logout;
      case 'site_visit':
        return Icons.explore;
      case 'progress':
        return Icons.trending_up;
      case 'safety':
        return Icons.security;
      case 'device':
        return Icons.devices;
      case 'custom':
        return Icons.edit;
      default:
        return Icons.label_outline;
    }
  }

  /// 是否为考勤类型（上下班）
  bool get isAttendanceType =>
      type == 'in' ||
      type == 'clock_in' ||
      type == 'out' ||
      type == 'clock_out';

  String? get statusText {
    switch (rawStatus) {
      case 'late':
        return '迟到';
      case 'early':
        return '早退';
      default:
        return null;
    }
  }

  bool get isAbnormal => rawStatus == 'late' || rawStatus == 'early';
}
