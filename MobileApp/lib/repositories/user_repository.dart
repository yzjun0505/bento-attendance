import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';
import '../models/user_model.dart';

class UserRepository {
  final ApiClient apiClient;

  UserRepository({required this.apiClient});

  Future<User?> lookupUser({required String query}) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    try {
      final response =
          await apiClient.dio.get('/users/lookup', queryParameters: {'q': q});
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return User.fromJson(data);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final response = await apiClient.dio.get('/users/me');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return User.fromJson(data);
        }
      }
      throw Exception('获取用户信息失败');
    } catch (e) {
      rethrow;
    }
  }

  Future<User> updateProfile({
    required String name,
    String? phone,
    String? email,
    String? avatar,
  }) async {
    try {
      final response = await apiClient.dio.put('/users/me', data: {
        'name': name,
        'phone': phone,
        'email': email,
        if (avatar != null) 'avatar': avatar,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return User.fromJson(data);
        }
        return getCurrentUser();
      }
      throw Exception(response.data['message'] ?? '更新用户信息失败');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await apiClient.dio.put(
        '/users/me/password',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('修改密码失败');
      }

      if (response.data['code'] != 200) {
        throw Exception(response.data['message'] ?? '修改密码失败');
      }
    } catch (e) {
      debugPrint('修改密码失败: $e');
      rethrow;
    }
  }
}
