import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'amap_geo_service.dart';
import 'coord_utils.dart';

class AppLocationFix {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final String? address;
  final bool isApproximate;

  const AppLocationFix({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.address,
    this.isApproximate = false,
  });

  Position toPosition() {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: accuracy ?? (isApproximate ? 5000 : 0),
      altitude: altitude ?? 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
      isMocked: false,
    );
  }
}

class AppLocationService {
  const AppLocationService._();

  static Future<AppLocationFix?> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 10),
    bool allowLastKnown = true,
    bool allowAmapIpFallback = true,
  }) async {
    final permission = await _ensurePermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        final fix = await _tryDeviceLocation(
          accuracy: accuracy,
          timeLimit: timeLimit,
        );
        if (fix != null) return fix;

        if (allowLastKnown) {
          final lastKnown = await _tryLastKnownLocation();
          if (lastKnown != null) return lastKnown;
        }
      }
    }

    if (allowAmapIpFallback) {
      return _tryAmapIpLocation();
    }
    return null;
  }

  static Future<LocationPermission> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  static Future<AppLocationFix?> _tryDeviceLocation({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        forceAndroidLocationManager:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
        timeLimit: timeLimit,
      );
      return _fromWgs84Position(pos);
    } catch (e) {
      debugPrint('设备定位失败: $e');
      return null;
    }
  }

  static Future<AppLocationFix?> _tryLastKnownLocation() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return _fromWgs84Position(pos);
    } catch (e) {
      debugPrint('最后已知定位失败: $e');
      return null;
    }
  }

  static AppLocationFix _fromWgs84Position(Position pos) {
    final gcj = CoordUtils.wgs84ToGcj02(pos.latitude, pos.longitude);
    return AppLocationFix(
      latitude: gcj['latitude']!,
      longitude: gcj['longitude']!,
      altitude: pos.altitude,
      accuracy: pos.accuracy,
    );
  }

  static Future<AppLocationFix?> _tryAmapIpLocation() async {
    final ipLocation = await AmapGeoService.locateByIp();
    if (ipLocation == null) return null;

    final address = ipLocation.address ??
        await AmapGeoService.reverseGeocode(
          latitude: ipLocation.latitude,
          longitude: ipLocation.longitude,
        );

    return AppLocationFix(
      latitude: ipLocation.latitude,
      longitude: ipLocation.longitude,
      address: address,
      isApproximate: true,
    );
  }
}
