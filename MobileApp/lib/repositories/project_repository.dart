import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';
import '../models/project_model.dart';

class ProjectRepository {
  final ApiClient apiClient;

  ProjectRepository({required this.apiClient});

  Future<List<Project>> getAllProjects() async {
    try {
      final response = await apiClient.dio.get('/projects/all');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => Project.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Project?> getProjectById(int id) async {
    try {
      final response = await apiClient.dio.get('/projects/$id');
      if (response.statusCode == 200) {
        return Project.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// 查询附近项目
  /// [latitude] 纬度, [longitude] 经度, [radius] 搜索半径（米，默认2000）
  Future<List<Project>> getNearbyProjects({
    required double latitude,
    required double longitude,
    int radius = 2000,
  }) async {
    try {
      final response =
          await apiClient.dio.get('/projects/nearby', queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => Project.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('查询附近项目失败: $e');
      return [];
    }
  }
}
