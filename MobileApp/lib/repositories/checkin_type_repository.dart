import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';
import '../models/checkin_type_model.dart';

class CheckinTypeRepository {
  final ApiClient apiClient;

  CheckinTypeRepository({required this.apiClient});

  /// 获取所有启用的打卡类型
  Future<List<CheckinType>> getCheckinTypes() async {
    try {
      final response = await apiClient.dio.get('/checkin-types');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => CheckinType.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('获取打卡类型失败: $e');
      return _getDefaultTypes();
    }
  }

  /// 默认打卡类型（离线兜底）
  List<CheckinType> _getDefaultTypes() {
    return [
      CheckinType(
          id: 1,
          code: 'clock_in',
          name: '上班打卡',
          icon: 'login',
          color: const Color(0xFF22C55E),
          category: 'attendance',
          countAsAttendance: true,
          sortOrder: 1),
      CheckinType(
          id: 2,
          code: 'clock_out',
          name: '下班打卡',
          icon: 'logout',
          color: const Color(0xFFEF4444),
          category: 'attendance',
          countAsAttendance: true,
          sortOrder: 2),
      CheckinType(
          id: 3,
          code: 'site_visit',
          name: '实地考察',
          icon: 'explore',
          color: const Color(0xFF3B82F6),
          category: 'business',
          sortOrder: 3),
      CheckinType(
          id: 4,
          code: 'progress',
          name: '项目进度上报',
          icon: 'trending_up',
          color: const Color(0xFFF59E0B),
          category: 'business',
          sortOrder: 4),
      CheckinType(
          id: 5,
          code: 'safety',
          name: '安全检查',
          icon: 'security',
          color: const Color(0xFFEF4444),
          category: 'inspection',
          sortOrder: 5),
      CheckinType(
          id: 6,
          code: 'device',
          name: '设备位置上报',
          icon: 'devices',
          color: const Color(0xFF8B5CF6),
          category: 'inspection',
          sortOrder: 6),
      CheckinType(
          id: 99,
          code: 'custom',
          name: '自定义',
          icon: 'edit',
          color: const Color(0xFF6B7280),
          category: 'business',
          sortOrder: 99),
    ];
  }
}
