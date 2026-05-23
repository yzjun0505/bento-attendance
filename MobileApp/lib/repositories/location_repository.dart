import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';

class LocationRepository {
  final ApiClient apiClient;

  LocationRepository({required this.apiClient});

  Future<bool> reportLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    String? address,
  }) async {
    try {
      debugPrint(
          '位置上报请求: lat=$latitude, lng=$longitude → ${apiClient.dio.options.baseUrl}/location/report');
      final response = await apiClient.dio.post('/location/report', data: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy ?? 0,
        'speed': speed ?? 0,
        'address': address ?? '',
      });
      debugPrint('位置上报成功: $latitude, $longitude, 状态: ${response.statusCode}');
      return true;
    } on DioException catch (e) {
      debugPrint('位置上报失败[DioException]: type=${e.type}, message=${e.message}');
      if (e.type == DioExceptionType.connectionError) {
        debugPrint(
            '⚠️ 位置上报连接失败！后端 API 地址可能不可达: ${apiClient.dio.options.baseUrl}');
      }
      return false;
    } catch (e) {
      debugPrint('位置上报失败: $e');
      return false;
    }
  }

  /// 获取团队位置（经理/管理员查看授权项目下工人的最新位置）
  Future<Map<String, dynamic>> getTeamLocations() async {
    try {
      final response = await apiClient.dio.get('/location/team-locations');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return {'locations': [], 'total': 0};
    } catch (e) {
      debugPrint('获取团队位置失败: $e');
      return {'locations': [], 'total': 0};
    }
  }
}
