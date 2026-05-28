import 'dart:math' as math;

class CoordUtils {
  static const double a = 6378245.0; // WGS 长轴半径
  static const double ee = 0.00669342162296594323; // WGS 偏心率的平方

  /// 将 WGS-84 (GPS原始坐标) 转换为 GCJ-02 (高德/国内火星坐标)
  /// 如果在国外，则直接返回原始坐标
  static Map<String, double> wgs84ToGcj02(double lat, double lng) {
    if (_outOfChina(lat, lng)) {
      return {'latitude': lat, 'longitude': lng};
    }
    double dLat = _transformLat(lng - 105.0, lat - 35.0);
    double dLng = _transformLng(lng - 105.0, lat - 35.0);
    double radLat = lat / 180.0 * math.pi;
    double magic = math.sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
    dLng = (dLng * 180.0) / (a / sqrtMagic * math.cos(radLat) * math.pi);
    return {'latitude': lat + dLat, 'longitude': lng + dLng};
  }

  static bool _outOfChina(double lat, double lng) {
    // 粗略判断是否在中国境内
    if (lng < 72.004 || lng > 137.8347) return true;
    if (lat < 0.8293 || lat > 55.8271) return true;
    return false;
  }

  static double _transformLat(double x, double y) {
    double ret = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) +
            320 * math.sin(y * math.pi / 30.0)) *
        2.0 /
        3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    double ret = 300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (150.0 * math.sin(x / 12.0 * math.pi) +
            300.0 * math.sin(x / 30.0 * math.pi)) *
        2.0 /
        3.0;
    return ret;
  }
}
