import 'package:dio/dio.dart';
import '../api/dio_client.dart';

class ApprovalRepository {
  final Dio _dio = ApiClient().dio;

  Future<List<Map<String, dynamic>>> getMyApprovals({String? token}) async {
    try {
      final response = await _dio.get('/approvals/mine');
      return List<Map<String, dynamic>>.from(response.data['data']?['list'] ?? []);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllApprovals({String? token}) async {
    try {
      final response = await _dio.get('/approvals/all');
      return List<Map<String, dynamic>>.from(response.data['data']?['list'] ?? []);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingApprovals({String? token}) async {
    try {
      final response = await _dio.get('/approvals/pending');
      return List<Map<String, dynamic>>.from(response.data['data']?['list'] ?? []);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createApproval({
    required String type,
    required String reason,
    required String startDate,
    String? endDate,
    String? token,
  }) async {
    try {
      await _dio.post('/approvals', data: {
        'type': type,
        'reason': reason,
        'start_date': startDate,
        'end_date': endDate,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> approve(int approvalId, {String? token}) async {
    try {
      await _dio.put('/approvals/$approvalId/approve');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reject(int approvalId, {String? remark, String? token}) async {
    try {
      await _dio.put('/approvals/$approvalId/reject', data: {
        'remark': remark,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteApproval(int approvalId, {String? token}) async {
    try {
      await _dio.delete('/approvals/$approvalId');
    } catch (e) {
      rethrow;
    }
  }
}
