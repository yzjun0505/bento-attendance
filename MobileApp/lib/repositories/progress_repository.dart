import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../api/dio_client.dart';
import '../models/task_node_model.dart';
import '../models/progress_report_model.dart';
import '../models/project_progress_model.dart';

class ProgressRepository {
  final ApiClient apiClient;

  ProgressRepository({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getNodesByProject(
    int projectId, {
    int page = 1,
    int pageSize = 20,
    String? phase,
    String? status,
    int? assigneeId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (phase != null) queryParams['phase'] = phase;
      if (status != null) queryParams['status'] = status;
      if (assigneeId != null) queryParams['assignee_id'] = assigneeId;

      final response = await apiClient.dio.get(
        '/projects/$projectId/nodes',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final List<dynamic> list = data['list'];
        return {
          'list': list.map((json) => TaskNode.fromJson(json)).toList(),
          'total': data['total'],
          'page': data['page'],
          'pageSize': data['pageSize'],
        };
      }
      throw Exception(response.data['message'] ?? '获取任务节点列表失败');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('网络连接失败，请检查网络后重试');
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  Future<TaskNode> createNode(int projectId, Map<String, dynamic> data) async {
    try {
      final response = await apiClient.dio.post(
        '/projects/$projectId/nodes',
        data: data,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return TaskNode.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? '创建任务节点失败');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('网络连接失败，请检查网络后重试');
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  Future<void> updateNode(int nodeId, Map<String, dynamic> data) async {
    try {
      final response = await apiClient.dio.put('/nodes/$nodeId', data: data);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return;
      }
      throw Exception(response.data['message'] ?? '更新任务节点失败');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('网络连接失败，请检查网络后重试');
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  Future<void> deleteNode(int nodeId) async {
    try {
      final response = await apiClient.dio.delete('/nodes/$nodeId');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return;
      }
      throw Exception(response.data['message'] ?? '删除任务节点失败');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('网络连接失败，请检查网络后重试');
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  Future<Map<String, dynamic>> getReportsByNode(
    int nodeId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        '/nodes/$nodeId/reports',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final List<dynamic> list = data['list'];
        return {
          'list': list.map((json) => ProgressReport.fromJson(json)).toList(),
          'total': data['total'],
          'page': data['page'],
          'pageSize': data['pageSize'],
        };
      }
      throw Exception(response.data['message'] ?? '获取进度上报记录失败');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('网络连接失败，请检查网络后重试');
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  Future<ProgressReport> submitReport(
    int nodeId, {
    String? description,
    String? photo,
    required int progressPercent,
    String? riskNote,
    String? blockerNote,
    List<String>? photos,
  }) async {
    try {
      final data = <String, dynamic>{
        'progress_percent': progressPercent,
      };
      if (description != null) data['description'] = description;
      if (photo != null) data['photo'] = photo;
      if (riskNote != null) data['risk_note'] = riskNote;
      if (blockerNote != null) data['blocker_note'] = blockerNote;
      if (photos != null && photos.isNotEmpty) {
        data['photos'] = photos;
      }

      final response = await apiClient.dio.post(
        '/nodes/$nodeId/reports',
        data: data,
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ProgressReport.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? '提交进度上报失败');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('网络连接失败，请检查网络后重试');
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

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
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        debugPrint('上传照片失败: ${e.response!.data['message']}');
      } else {
        debugPrint('上传照片失败: 网络连接失败');
      }
      return null;
    } catch (e) {
      debugPrint('上传照片失败: $e');
      return null;
    }
  }

  Future<List<String>?> uploadPhotos(List<File> files) async {
    if (files.isEmpty) return null;

    final urls = <String>[];
    for (final file in files) {
      try {
        final fileName = file.path.split('/').last;
        final formData = FormData.fromMap({
          'photo': await MultipartFile.fromFile(file.path, filename: fileName),
        });
        final response =
            await apiClient.dio.post('/upload/photo', data: formData);
        if (response.statusCode == 200 && response.data['code'] == 200) {
          urls.add(response.data['data']['url']);
        }
      } on DioException catch (e) {
        if (e.response?.data != null && e.response?.data['message'] != null) {
          debugPrint('上传照片失败: ${e.response!.data['message']}');
        }
      } catch (e) {
        debugPrint('上传照片失败: $e');
      }
    }
    return urls.isEmpty ? null : urls;
  }

  Future<List<ProjectProgress>> getAuthorizedProjects() async {
    try {
      final response = await apiClient.dio.get('/projects/authorized');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final List<dynamic> items = response.data['data']['projects'];
        return items.map((e) => ProjectProgress.fromJson(e)).toList();
      }
      throw Exception(response.data['message'] ?? '获取项目列表失败');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('网络连接失败，请检查网络后重试');
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  Future<ProjectProgressSummary> getProjectProgressSummary(
      int projectId) async {
    try {
      final response =
          await apiClient.dio.get('/projects/$projectId/progress-summary');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ProjectProgressSummary.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? '获取项目摘要失败');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('网络连接失败，请检查网络后重试');
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }
}
