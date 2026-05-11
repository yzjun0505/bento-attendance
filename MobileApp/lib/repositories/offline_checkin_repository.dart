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
        final data = response.data['data'] as Map<String, dynamic>? ?? {};
        final synced =
            data['synced_count'] as int? ?? data['synced'] as int? ?? 0;
        final failed = data['failed'] as int? ?? 0;
        if (synced < cached.length || failed > 0) {
          throw Exception('同步未完成：成功 $synced 条，失败 $failed 条');
        }

        // 只有后端确认本机缓存全部入库后才清空本地缓存，避免误删待同步数据。
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cacheKey);
        return synced;
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
    String? remark,
    String? watermarkCode,
  }) {
    return {
      'local_id': DateTime.now().microsecondsSinceEpoch.toString(),
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'photo': photo,
      'project_id': projectId,
      'remark': remark,
      'watermark_code': watermarkCode,
      'local_timestamp':
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    };
  }
}
