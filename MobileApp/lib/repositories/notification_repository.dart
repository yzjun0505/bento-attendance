import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/dio_client.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final ApiClient apiClient;
  final _storage = const FlutterSecureStorage();

  NotificationRepository({required this.apiClient});

  Future<List<NotificationModel>> getNotifications({
    int page = 1,
    int pageSize = 20,
    bool? unreadOnly,
  }) async {
    final cacheKey = unreadOnly == true
        ? 'cached_notifications_unread_page1'
        : 'cached_notifications_page1';
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };

      if (unreadOnly != null) {
        queryParams['unread_only'] = unreadOnly;
      }

      final response = await apiClient.dio.get(
        '/notifications',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final List<dynamic> data = response.data['data']['list'];
        final list =
            data.map((json) => NotificationModel.fromJson(json)).toList();
        if (page == 1) {
          await _storage.write(key: cacheKey, value: jsonEncode(data));
        }
        return list;
      }
      return [];
    } catch (e) {
      debugPrint('获取消息列表失败: $e');
      if (page == 1) {
        final cached = await _storage.read(key: cacheKey);
        if (cached != null && cached.isNotEmpty) {
          try {
            final raw = jsonDecode(cached) as List<dynamic>;
            return raw
                .map((j) =>
                    NotificationModel.fromJson(j as Map<String, dynamic>))
                .toList();
          } catch (e) {
            debugPrint('解析缓存通知失败: $e');
          }
        }
      }
      return [];
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await apiClient.dio.put(
        '/notifications/$notificationId/read',
      );

      final ok = response.statusCode == 200 && response.data['code'] == 200;
      if (ok) {
        final cached =
            await _storage.read(key: 'cached_notifications_unread_count');
        final v = int.tryParse(cached ?? '');
        if (v != null) {
          final next = v - 1;
          await _storage.write(
              key: 'cached_notifications_unread_count',
              value: (next > 0 ? next : 0).toString());
        } else {
          await _storage.delete(key: 'cached_notifications_unread_count');
        }
      }
      return ok;
    } catch (e) {
      debugPrint('标记已读失败: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await apiClient.dio.put('/notifications/read-all');
      final ok = response.statusCode == 200 && response.data['code'] == 200;
      if (ok) {
        await _storage.write(
            key: 'cached_notifications_unread_count', value: '0');
      }
      return ok;
    } catch (e) {
      debugPrint('全部标记已读失败: $e');
      return false;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await apiClient.dio.get('/notifications/unread-count');

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final count = response.data['data']['count'] ?? 0;
        await _storage.write(
            key: 'cached_notifications_unread_count', value: count.toString());
        return count;
      }
      return 0;
    } catch (e) {
      debugPrint('获取未读数失败: $e');
      final cached =
          await _storage.read(key: 'cached_notifications_unread_count');
      final v = int.tryParse(cached ?? '');
      return v ?? 0;
    }
  }

  Future<bool> deleteNotification(int notificationId) async {
    try {
      final response = await apiClient.dio.delete(
        '/notifications/$notificationId',
      );

      final ok = response.statusCode == 200 && response.data['code'] == 200;
      if (ok) {
        await _storage.delete(key: 'cached_notifications_unread_count');
      }
      return ok;
    } catch (e) {
      debugPrint('删除消息失败: $e');
      return false;
    }
  }
}
