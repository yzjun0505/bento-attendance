import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/dio_client.dart';
import '../models/checkin_model.dart';
import '../models/watermark_template.dart';

class CheckinRepository {
  final ApiClient apiClient;
  static const _cacheKey = 'cached_watermark_templates';

  CheckinRepository({required this.apiClient});

  Future<String?> uploadPhoto(File photoFile) async {
    try {
      final fileName = photoFile.path.split('/').last;
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          photoFile.path,
          filename: fileName,
        ),
      });

      final response = await apiClient.dio.post(
        '/upload/photo',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        return response.data['data']['url'];
      }
      return null;
    } catch (e) {
      debugPrint('上传照片失败: $e');
      return null;
    }
  }

  Future<void> submitCheckin({
    required String type,
    required double latitude,
    required double longitude,
    required String address,
    int? projectId,
    String? remark,
    String? photo,
    String? watermarkCode,
  }) async {
    try {
      await apiClient.dio.post('/checkin', data: {
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'project_id': projectId,
        'remark': remark,
        'photo': photo,
        'watermark_code': watermarkCode,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<String> reserveWatermarkCode() async {
    try {
      final response = await apiClient.dio.get('/checkin/reserve-code');
      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data']['watermark_code'] as String;
      }
      throw Exception('生成防伪码失败');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<WatermarkTemplate>> fetchWatermarkTemplates() async {
    try {
      final response = await apiClient.dio.get('/watermarks/templates');
      if (response.statusCode == 200) {
        final dynamic rawData = response.data['data'];
        if (rawData is List && rawData.isNotEmpty) {
          final templates = rawData.map((json) => WatermarkTemplate.fromJson(json as Map<String, dynamic>)).toList();
          await _cacheTemplates(templates);
          return templates;
        }
      }
    } catch (e) {
      debugPrint('网络获取水印模板失败，尝试读取本地缓存: $e');
    }

    return _loadCachedTemplates();
  }

  Future<void> _cacheTemplates(List<WatermarkTemplate> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = templates.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_cacheKey, jsonList);
      debugPrint('已缓存 ${templates.length} 个水印模板到本地');
    } catch (e) {
      debugPrint('缓存水印模板失败: $e');
    }
  }

  Future<List<WatermarkTemplate>> _loadCachedTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_cacheKey);
      if (jsonList == null || jsonList.isEmpty) {
        debugPrint('本地无缓存的水印模板');
        return [];
      }
      final templates = jsonList
          .map((str) => WatermarkTemplate.fromCachedJson(jsonDecode(str) as Map<String, dynamic>))
          .toList();
      debugPrint('从本地缓存加载了 ${templates.length} 个水印模板');
      return templates;
    } catch (e) {
      debugPrint('读取本地缓存水印模板失败: $e');
      return [];
    }
  }

  Future<List<Checkin>> getMyCheckins({int page = 1, int pageSize = 20}) async {
    try {
      final response = await apiClient.dio.get('/checkin', queryParameters: {
        'page': page,
        'pageSize': pageSize,
      });
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data']['list'];
        return data.map((json) => Checkin.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Checkin>> getTodayCheckins() async {
    try {
      final now = DateTime.now();
      final dateStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final dateEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      final response = await apiClient.dio.get('/checkin', queryParameters: {
        'date_start': dateStart,
        'date_end': dateEnd,
      });
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data']['list'];
        return data.map((json) => Checkin.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}
