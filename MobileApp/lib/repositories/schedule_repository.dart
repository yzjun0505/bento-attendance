import 'package:dio/dio.dart';
import '../api/dio_client.dart';

class ScheduleRepository {
  final Dio _dio = ApiClient().dio;

  /// 获取今日排班
  Future<Map<String, dynamic>?> getTodaySchedule() async {
    try {
      final response = await _dio.get('/schedules/today');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 获取指定日期范围的排班
  Future<List<Map<String, dynamic>>> getSchedules({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _dio.get('/schedules', queryParameters: {
        'start_date': startDate,
        'end_date': endDate,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        if (data is Map && data['list'] != null) {
          return List<Map<String, dynamic>>.from(data['list']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 获取当月日历排班
  Future<Map<String, List<Map<String, dynamic>>>> getCalendarSchedules(String month) async {
    try {
      final response = await _dio.get('/schedules/calendar', queryParameters: {
        'date': month,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final map = <String, List<Map<String, dynamic>>>{};
        if (data is List) {
          for (final item in data) {
            final dateKey = item['date'] as String? ?? item['schedule_date'] as String?;
            if (dateKey != null) {
              map.putIfAbsent(dateKey, () => []);
              map[dateKey]!.add(Map<String, dynamic>.from(item));
            }
          }
        }
        return map;
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
