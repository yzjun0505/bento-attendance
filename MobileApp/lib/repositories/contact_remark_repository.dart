import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ContactRemarkRepository {
  static const _key = 'contact_remarks_v1';
  static const _avatarKey = 'contact_avatars_v1';

  Future<Map<String, String>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')).cast<String, String>()
        ..removeWhere((k, v) => v.trim().isEmpty);
    } catch (_) {
      return {};
    }
  }

  Future<String?> getRemark(String id) async {
    final all = await readAll();
    final v = all[id];
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  Future<void> setRemark(String id, String remark) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await readAll();
    final v = remark.trim();
    if (v.isEmpty) {
      all.remove(id);
    } else {
      all[id] = v;
    }
    await prefs.setString(_key, jsonEncode(all));
  }

  Future<Map<String, String>> readAllAvatars() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_avatarKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')).cast<String, String>()
        ..removeWhere((k, v) => v.trim().isEmpty);
    } catch (_) {
      return {};
    }
  }

  Future<String?> getCustomAvatar(String id) async {
    final all = await readAllAvatars();
    final v = all[id];
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  Future<void> setCustomAvatar(String id, String avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await readAllAvatars();
    final v = avatarUrl.trim();
    if (v.isEmpty) {
      all.remove(id);
    } else {
      all[id] = v;
    }
    await prefs.setString(_avatarKey, jsonEncode(all));
  }
}

