class Project {
  final int id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final int radius;
  final int userCount;
  final int? distance; // 距当前位置距离（米），附近项目查询时返回
  final bool? isInside; // 是否在围栏内

  Project({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    required this.radius,
    this.userCount = 0,
    this.distance,
    this.isInside,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      radius: json['radius'] ?? 500,
      userCount: json['user_count'] ?? 0,
      distance: json['distance']?.toInt(),
      isInside: json['isInside'] == true || json['is_inside'] == true || json['is_inside'] == 1 || json['isInside'] == 1,
    );
  }

  /// 距离描述文本
  String get distanceText {
    if (distance == null) return '';
    if (distance! < 1000) return '${distance}m';
    return '${(distance! / 1000).toStringAsFixed(1)}km';
  }
}
