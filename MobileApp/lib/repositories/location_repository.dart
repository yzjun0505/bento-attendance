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
      debugPrint('位置上报请求: lat=$latitude, lng=$longitude → ${apiClient.dio.options.baseUrl}/location/report');
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
        debugPrint('⚠️ 位置上报连接失败！后端 API 地址可能不可达: ${apiClient.dio.options.baseUrl}');
      }
      return false;
    } catch (e) {
      debugPrint('位置上报失败: $e');
      return false;
    }
  }
}
