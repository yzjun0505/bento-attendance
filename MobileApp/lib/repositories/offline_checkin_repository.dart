import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../api/dio_client.dart';

class OfflineCheckinRepository {
  final Dio _dio = ApiClient().dio;
  static const _cacheKey = 'offline_checkins';

  /// 缓存离线打卡到本地
  Future<void> cacheOfflineCheckin(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_cacheKey) ?? [];
    list.add(jsonEncode(data));
    await prefs.setStringList(_cacheKey, list);
  }

  /// 获取本地缓存的离线打卡数量
  Future<int> getCachedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_cacheKey) ?? [];
    return list.length;
  }

  /// 获取本地缓存的离线打卡列表
  Future<List<Map<String, dynamic>>> getCachedCheckins() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_cacheKey) ?? [];
    return list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  /// 同步离线打卡到服务器
  Future<int> syncCheckins() async {
    final cached = await getCachedCheckins();
    if (cached.isEmpty) return 0;

    try {
      final response = await _dio.post('/offline-checkins/sync', data: {
        'checkins': cached,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        // 同步成功后清空本地缓存
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cacheKey);
        return response.data['data']?['synced_count'] as int? ?? cached.length;
      }
      throw Exception('同步失败');
    } catch (e) {
      rethrow;
    }
  }

  /// 生成离线打卡缓存数据
  Map<String, dynamic> buildOfflineData({
    required String type,
    required double latitude,
    required double longitude,
    required String address,
    String? photo,
    int? projectId,
  }) {
    return {
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'photo': photo,
      'project_id': projectId,
      'local_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    };
  }
}
