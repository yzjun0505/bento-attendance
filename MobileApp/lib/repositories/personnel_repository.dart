import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';
import '../models/user_model.dart';

class PersonnelRepository {
  final ApiClient apiClient;

  PersonnelRepository({required this.apiClient});

  Future<Map<String, dynamic>> getUsers({
    String? keyword,
    String? role,
    int? projectId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
      if (role != null && role.isNotEmpty) params['role'] = role;
      if (projectId != null) params['project_id'] = projectId;

      final response =
          await apiClient.dio.get('/users', queryParameters: params);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final List<dynamic> list = data['list'] ?? [];
        final users = list
            .map((json) => User.fromJson(json as Map<String, dynamic>))
            .toList();
        return {
          'list': users,
          'total': data['total'] ?? 0,
        };
      }
      return {'list': <User>[], 'total': 0};
    } catch (e) {
      debugPrint('获取用户列表失败: $e');
      rethrow;
    }
  }

  Future<User> createUser({
    required String username,
    required String password,
    required String name,
    required String role,
    String? phone,
    int? projectId,
  }) async {
    try {
      final response = await apiClient.dio.post('/users', data: {
        'username': username,
        'password': password,
        'name': name,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (projectId != null) 'project_id': projectId,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return User.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? '创建用户失败');
    } catch (e) {
      rethrow;
    }
  }

  Future<User> updateUser(
    int id, {
    String? name,
    String? role,
    String? phone,
    int? projectId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (role != null) data['role'] = role;
      if (phone != null) data['phone'] = phone;
      if (projectId != null) data['project_id'] = projectId;

      final response = await apiClient.dio.put('/users/$id', data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return User.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? '更新用户失败');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      final response = await apiClient.dio.delete('/users/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return;
      }
      throw Exception(response.data['message'] ?? '删除用户失败');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(int id, String password) async {
    try {
      final response =
          await apiClient.dio.put('/users/$id/reset-password', data: {
        'password': password,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return;
      }
      throw Exception(response.data['message'] ?? '重置密码失败');
    } catch (e) {
      rethrow;
    }
  }
}
