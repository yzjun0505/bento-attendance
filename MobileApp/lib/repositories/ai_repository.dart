import '../api/dio_client.dart';

class AiRepository {
  final ApiClient apiClient;

  AiRepository({required this.apiClient});

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? conversationId,
    Map<String, dynamic>? context,
  }) async {
    final response = await apiClient.dio.post('/ai/chat', data: {
      'message': message,
      'conversationId': conversationId,
      'context': context ?? {},
    });

    final data = response.data['data'];
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<String>> getSuggestions({Map<String, dynamic>? context}) async {
    final response = await apiClient.dio.get(
      '/ai/suggestions',
      queryParameters: context ?? {},
    );
    final data = response.data['data'];
    if (data is List) return data.map((e) => e.toString()).toList();
    return const [];
  }

  Future<Map<String, dynamic>> confirmAction(int actionId) async {
    final response = await apiClient.dio.post('/ai/actions/$actionId/confirm');
    final data = response.data['data'];
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(data as Map);
  }
}
