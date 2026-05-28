import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalPhotoRecord {
  final String id;
  final String path;
  final String watermarkCode;
  final String createdTime;
  final String checkinType; // 'in' / 'out' / 'custom'
  final String customCheckinName; // e.g. "例行巡检"
  final int? projectId;
  final double latitude;
  final double longitude;
  final String address;
  final String? remark;

  LocalPhotoRecord({
    required this.id,
    required this.path,
    required this.watermarkCode,
    required this.createdTime,
    required this.checkinType,
    required this.customCheckinName,
    this.projectId,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.remark,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'watermarkCode': watermarkCode,
      'createdTime': createdTime,
      'checkinType': checkinType,
      'customCheckinName': customCheckinName,
      'projectId': projectId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'remark': remark,
    };
  }

  factory LocalPhotoRecord.fromJson(Map<String, dynamic> json) {
    return LocalPhotoRecord(
      id: json['id'],
      path: json['path'],
      watermarkCode: json['watermarkCode'],
      createdTime: json['createdTime'],
      checkinType: json['checkinType'],
      customCheckinName:
          json['customCheckinName'] ?? json['CustomCheckinName'] ?? '打卡',
      projectId: json['projectId'],
      latitude: json['latitude'] ?? 0.0,
      longitude: json['longitude'] ?? 0.0,
      address: json['address'] ?? '',
      remark: json['remark'],
    );
  }
}

class LocalAlbumService {
  static const String _storageKey = 'local_watermark_photos_v1';

  static Future<List<LocalPhotoRecord>> getPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? items = prefs.getStringList(_storageKey);
    if (items == null) return [];

    try {
      return items
          .map((e) => LocalPhotoRecord.fromJson(jsonDecode(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePhoto(LocalPhotoRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> items = prefs.getStringList(_storageKey) ?? [];
    items.insert(0, jsonEncode(record.toJson())); // latest first
    await prefs.setStringList(_storageKey, items);
  }

  static Future<void> removePhoto(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> items = prefs.getStringList(_storageKey) ?? [];

    final updated = items.where((str) {
      try {
        final decoded = jsonDecode(str);
        return decoded['id'] != id;
      } catch (_) {
        return true;
      }
    }).toList();

    await prefs.setStringList(_storageKey, updated);
  }
}
