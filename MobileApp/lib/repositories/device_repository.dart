import '../api/dio_client.dart';
import '../models/device_model.dart';

class DeviceRepository {
  final ApiClient apiClient;

  DeviceRepository({required this.apiClient});

  Future<Map<String, dynamic>> getDevices({
    String? keyword,
    int? status,
    String? type,
    int? projectId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (keyword != null && keyword.isNotEmpty) {
        params['keyword'] = keyword;
      }
      if (status != null) {
        params['status'] = status;
      }
      if (type != null && type.isNotEmpty) {
        params['type'] = type;
      }
      if (projectId != null) {
        params['project_id'] = projectId;
      }

      final response =
          await apiClient.dio.get('/devices', queryParameters: params);
      if (response.statusCode == 200) {
        final data = response.data['data'];
        final List<dynamic> list = data['list'];
        final devices = list
            .map((json) => Device.fromJson(json as Map<String, dynamic>))
            .toList();
        return {
          'list': devices,
          'total': data['total'] as int,
          'page': data['page'],
          'pageSize': data['pageSize'],
        };
      }
      return {
        'list': <Device>[],
        'total': 0,
        'page': page,
        'pageSize': pageSize
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<Device?> createDevice({
    required String deviceId,
    required String name,
    String type = 'checkpoint',
    int? projectId,
    int status = 1,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await apiClient.dio.post('/devices', data: {
        'device_id': deviceId,
        'name': name,
        'type': type,
        'project_id': projectId,
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
      });
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return null;
      }
      throw Exception(response.data['message'] ?? '创建设备失败');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDevice(
    int id, {
    String? deviceId,
    String? name,
    String? type,
    int? projectId,
    int? status,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (deviceId != null) data['device_id'] = deviceId;
      if (name != null) data['name'] = name;
      if (type != null) data['type'] = type;
      if (projectId != null) data['project_id'] = projectId;
      if (status != null) data['status'] = status;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;

      await apiClient.dio.put('/devices/$id', data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDevice(int id) async {
    try {
      await apiClient.dio.delete('/devices/$id');
    } catch (e) {
      rethrow;
    }
  }
}
