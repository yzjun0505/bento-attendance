import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class WeatherService {
  static const String _baseUrl =
      'https://restapi.amap.com/v3/weather/weatherInfo';
  static const String _apiKey = String.fromEnvironment('AMAP_KEY',
      defaultValue: 'ae275848401da60cbf76669fdc22b450');

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
  ));

  static Future<WeatherInfo?> getWeatherByLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'key': _apiKey,
        'location':
            '${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}',
        'extensions': 'base',
        'output': 'json',
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['status'] == '1' &&
            data['lives'] != null &&
            (data['lives'] as List).isNotEmpty) {
          final live = data['lives'][0];
          return WeatherInfo(
            weather: live['weather'] ?? '暂无',
            temperature: live['temperature'] ?? '--',
            humidity: live['humidity'] ?? '--',
            windDirection: live['winddirection'] ?? '',
            windPower: live['windpower'] ?? '',
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('获取天气信息失败: $e');
      return null;
    }
  }
}

class WeatherInfo {
  final String weather;
  final String temperature;
  final String humidity;
  final String windDirection;
  final String windPower;

  WeatherInfo({
    required this.weather,
    required this.temperature,
    required this.humidity,
    required this.windDirection,
    required this.windPower,
  });

  String get display => '$weather $temperature℃ 湿度$humidity%';
}
