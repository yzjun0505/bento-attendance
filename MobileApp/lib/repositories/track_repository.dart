import 'package:dio/dio.dart';
import '../api/dio_client.dart';

class TrackRepository {
  final Dio _dio = ApiClient().dio;

  /// 获取指定用户某天的轨迹数据
  Future<Map<String, dynamic>?> getTrack(int userId, String date) async {
    try {
      final response = await _dio.get('/tracks/$userId', queryParameters: {
        'date': date,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 获取自己的轨迹数据
  Future<Map<String, dynamic>?> getMyTrack(String date) async {
    try {
      final response = await _dio.get('/tracks/me', queryParameters: {
        'date': date,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
