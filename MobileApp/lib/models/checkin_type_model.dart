import 'package:flutter/material.dart';

/// 打卡类型模型
class CheckinType {
  final int id;
  final String code;
  final String name;
  final String icon;
  final Color color;
  final String category; // attendance, business, inspection
  final bool countAsAttendance;
  final int sortOrder;
  final int status;

  CheckinType({
    required this.id,
    required this.code,
    required this.name,
    this.icon = '',
    this.color = const Color(0xFF3B82F6),
    this.category = 'business',
    this.countAsAttendance = false,
    this.sortOrder = 0,
    this.status = 1,
  });

  factory CheckinType.fromJson(Map<String, dynamic> json) {
    return CheckinType(
      id: json['id'],
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      color: _parseColor(json['color'] ?? '#3B82F6'),
      category: json['category'] ?? 'business',
      countAsAttendance: json['count_as_attendance'] == 1,
      sortOrder: json['sort_order'] ?? 0,
      status: json['status'] ?? 1,
    );
  }

  /// 类别中文标签
  String get categoryLabel {
    switch (category) {
      case 'attendance':
        return '考勤打卡';
      case 'business':
        return '业务打卡';
      case 'inspection':
        return '巡检打卡';
      default:
        return '其他';
    }
  }

  /// 类别图标
  IconData get categoryIcon {
    switch (category) {
      case 'attendance':
        return Icons.access_time;
      case 'business':
        return Icons.work_outline;
      case 'inspection':
        return Icons.fact_check_outlined;
      default:
        return Icons.label_outline;
    }
  }

  /// 对应的水印分类（用于自动匹配水印模板）
  String get watermarkCategory {
    switch (code) {
      case 'clock_in':
      case 'clock_out':
      case 'in':
      case 'out':
        return 'attendance';
      case 'site_visit':
        return 'engineering';
      case 'progress':
        return 'engineering';
      case 'safety':
        return 'safetyInspection';
      case 'device':
        return 'equipmentInspection';
      default:
        return 'general';
    }
  }

  static Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFF3B82F6);
  }
}
