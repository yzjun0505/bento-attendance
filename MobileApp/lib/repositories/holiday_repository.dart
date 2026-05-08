import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../api/dio_client.dart';

class HolidayRepository {
  final Dio _dio = ApiClient().dio;

  /// 检查某天是否为节假日
  Future<bool> isHoliday(DateTime date) async {
    try {
      final response = await _dio.get('/holidays/check', queryParameters: {
        'date': DateFormat('yyyy-MM-dd').format(date),
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return response.data['data']?['is_holiday'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 获取指定年份的节假日列表
  Future<List<Map<String, dynamic>>> getHolidays(int year) async {
    try {
      final response = await _dio.get('/holidays', queryParameters: {
        'year': year.toString(),
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

  /// 获取某月节假日Map，key为日期字符串
  Future<Map<String, Map<String, dynamic>>> getMonthHolidays(
      DateTime month) async {
    final list = await getHolidays(month.year);
    final map = <String, Map<String, dynamic>>{};
    for (final h in list) {
      final rawDate = h['date']?.toString();
      final dateStr = rawDate != null && rawDate.length >= 10
          ? rawDate.substring(0, 10)
          : rawDate;
      if (dateStr != null) {
        map[dateStr] = h;
      }
    }
    return map;
  }
}
