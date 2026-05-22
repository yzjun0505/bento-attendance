import 'package:flutter/material.dart';

class Device {
  final int id;
  final String deviceId;
  final String name;
  final String type;
  final int? projectId;
  final String? projectName;
  final int status;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  Device({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.type,
    this.projectId,
    this.projectName,
    required this.status,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    String dateStr = json['created_at'] ?? '';
    if (dateStr.contains(' ')) {
      dateStr = dateStr.replaceAll(' ', 'T');
    }
    final hasTimezone = dateStr.endsWith('Z') || dateStr.contains('+');

    return Device(
      id: json['id'],
      deviceId: json['device_id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'checkpoint',
      projectId: json['project_id'],
      projectName: json['project_name'],
      status: json['status'] ?? 1,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      createdAt: hasTimezone
          ? DateTime.parse(dateStr).toLocal()
          : DateTime.parse(dateStr),
    );
  }

  bool get isActive => status == 1;

  String get statusText => status == 1 ? '正常' : '停用';

  String get typeName {
    switch (type) {
      case 'checkpoint':
        return '打卡点';
      case 'sensor':
        return '传感器';
      case 'camera':
        return '摄像头';
      default:
        return '其他';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'checkpoint':
        return Icons.location_on;
      case 'sensor':
        return Icons.sensors;
      case 'camera':
        return Icons.videocam;
      default:
        return Icons.devices_other;
    }
  }
}
