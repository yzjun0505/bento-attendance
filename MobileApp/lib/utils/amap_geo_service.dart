import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// 高德地图逆地理编码服务
/// 使用 Web API（HTTP 请求），不依赖额外原生插件
class AmapGeoService {
  static const String _baseUrl = 'https://restapi.amap.com/v3/geocode/regeo';
  static const String _placeAroundUrl =
      'https://restapi.amap.com/v3/place/around';

  /// 高德 Web 服务 Key（REST API 必须使用「Web服务」类型的 Key）
  /// 注意：Android/iOS SDK Key 不能用于 REST API（会返回 USERKEY_PLAT_NOMATCH）
  /// 请在运行时通过 --dart-define=AMAP_KEY=your_key 传入
  static const String _apiKey = String.fromEnvironment('AMAP_KEY', defaultValue: 'ae275848401da60cbf76669fdc22b450');

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// 逆地理编码：经纬度 → 中文地址
  /// 返回格式化地址字符串，失败时返回 null
  static Future<String?> reverseGeocode({
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
        if (data['status'] == '1' && data['regeocode'] != null) {
          final address = data['regeocode']['formatted_address'];
          if (address != null && address is String && address.isNotEmpty) {
            return address;
          }
        } else if (data['infocode'] == '10009') {
          // 如果高德 API Key 类型不匹配（使用了 Android Key 而非 Web 服务 Key），则回退到 OSM 逆地理编码
          return _fallbackReverseGeocode(latitude, longitude);
        }
      }
      return null;
    } catch (e) {
      debugPrint('高德逆地理编码失败: $e');
      return _fallbackReverseGeocode(latitude, longitude);
    }
  }

  /// 备用逆地理编码：OpenStreetMap Nominatim
  static Future<String?> _fallbackReverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat.toString(),
          'lon': lng.toString(),
          'format': 'json',
          'accept-language': 'zh-CN',
        },
        options: Options(
          headers: {'User-Agent': 'FlutterAttendanceApp/1.0'},
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        final address = response.data['display_name'];
        if (address != null && address is String && address.isNotEmpty) {
          // OSM 的 display_name 通常是由小到大（街道, 城市, 国家），截取前半部分
          final parts = address.split(', ');
          if (parts.length >= 3) {
            final end = parts.length > 4 ? 4 : parts.length;
            return '${parts.reversed.toList().sublist(1, end).join('')}${parts[0]}';
          }
          return address;
        }
      }
    } catch (e) {
      debugPrint('OSM 逆地理编码失败: $e');
    }
    return null;
  }

  /// 逆地理编码 (详细)：返回省/市/区/街道等结构化信息
  static Future<AmapAddressDetail?> reverseGeocodeDetail({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'key': _apiKey,
        'location':
            '${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}',
        'extensions': 'all',
        'output': 'json',
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['status'] == '1' && data['regeocode'] != null) {
          final regeo = data['regeocode'];
          final component = regeo['addressComponent'];
          return AmapAddressDetail(
            formattedAddress: regeo['formatted_address'] ?? '',
            province: component?['province'] ?? '',
            city: _parseField(component?['city']),
            district: component?['district'] ?? '',
            street: component?['streetNumber']?['street'] ?? '',
            number: component?['streetNumber']?['number'] ?? '',
            township: component?['township'] ?? '',
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('高德逆地理编码失败(详细)失败: $e');
      return null;
    }
  }

  /// 高德 API 某些字段可能返回空数组而非字符串
  static String _parseField(dynamic field) {
    if (field == null) return '';
    if (field is String) return field;
    if (field is List && field.isEmpty) return '';
    return field.toString();
  }

  /// 获取当前位置周边地点候选
  static Future<List<AmapNearbyPlace>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    String keywords = '',
    int radius = 1500,
    int offset = 20,
  }) async {
    try {
      debugPrint('🔍 高德周边搜索: lat=$latitude, lng=$longitude, keywords=$keywords');
      final response = await _dio.get(_placeAroundUrl, queryParameters: {
        'key': _apiKey,
        'location':
            '${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}',
        'keywords': keywords,
        'radius': radius,
        'offset': offset,
        'page': 1,
        'sortrule': 'distance',
        'extensions': 'base',
        'output': 'json',
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        debugPrint('🔍 高德周边搜索响应: status=${data['status']}, info=${data['info']}, pois数量=${data['pois']?.length ?? 0}');
        if (data['status'] == '1' && data['pois'] is List) {
          final places = (data['pois'] as List)
              .whereType<Map<String, dynamic>>()
              .map(AmapNearbyPlace.fromJson)
              .where((place) => place.name.isNotEmpty)
              .toList();
          debugPrint('🔍 解析到 ${places.length} 个地点');
          return places;
        } else if (data['status'] != '1') {
          debugPrint('🔍 高德API错误: ${data['info']}');
        }
      }
      return const [];
    } catch (e) {
      debugPrint('高德周边地点检索失败: $e');
      return const [];
    }
  }
}

/// 结构化地址信息
class AmapAddressDetail {
  final String formattedAddress;
  final String province;
  final String city;
  final String district;
  final String street;
  final String number;
  final String township;

  AmapAddressDetail({
    required this.formattedAddress,
    required this.province,
    required this.city,
    required this.district,
    required this.street,
    required this.number,
    required this.township,
  });

  /// 简短地址（区 + 街道 + 门牌号）
  String get shortAddress {
    final parts = <String>[];
    if (district.isNotEmpty) parts.add(district);
    if (street.isNotEmpty) parts.add(street);
    if (number.isNotEmpty) parts.add(number);
    if (parts.isEmpty && township.isNotEmpty) parts.add(township);
    return parts.isNotEmpty ? parts.join('') : formattedAddress;
  }
}

class AmapNearbyPlace {
  final String id;
  final String name;
  final String address;
  final String cityName;
  final String adName;
  final String distance;
  final String location;

  const AmapNearbyPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.cityName,
    required this.adName,
    required this.distance,
    required this.location,
  });

  factory AmapNearbyPlace.fromJson(Map<String, dynamic> json) {
    return AmapNearbyPlace(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      cityName: json['cityname']?.toString() ?? '',
      adName: json['adname']?.toString() ?? '',
      distance: json['distance']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
    );
  }

  String get displayText {
    if (address.isEmpty) return name;
    return '$name · $address';
  }

  String get subtitle {
    final parts = <String>[];
    if (distance.isNotEmpty) {
      final parsed = double.tryParse(distance);
      if (parsed != null && parsed >= 1000) {
        parts.add('${(parsed / 1000).toStringAsFixed(1)}公里');
      } else {
        parts.add('${parsed?.round() ?? distance}米');
      }
    }
    final region = [cityName, adName].where((e) => e.isNotEmpty).join(' ');
    if (region.isNotEmpty) {
      parts.add(region);
    }
    if (address.isNotEmpty) {
      parts.add(address);
    }
    return parts.join(' · ');
  }
}
