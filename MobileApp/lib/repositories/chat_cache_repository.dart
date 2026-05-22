import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChatCachedMessage {
  final String id;
  final String? sendID;
  final String? senderNickname;
  final String text;
  final String? originalText;
  final String? quoteSenderNickname;
  final String? quoteText;
  final int? sendTime;
  final String status;

  const ChatCachedMessage({
    required this.id,
    required this.text,
    required this.status,
    this.sendID,
    this.senderNickname,
    this.originalText,
    this.quoteSenderNickname,
    this.quoteText,
    this.sendTime,
  });

  factory ChatCachedMessage.fromJson(Map<String, dynamic> json) {
    return ChatCachedMessage(
      id: (json['id'] as String?) ?? '',
      sendID: json['sendID'] as String?,
      senderNickname: json['senderNickname'] as String?,
      text: (json['text'] as String?) ?? '',
      originalText: json['originalText'] as String?,
      quoteSenderNickname: json['quoteSenderNickname'] as String?,
      quoteText: json['quoteText'] as String?,
      sendTime: json['sendTime'] as int?,
      status: (json['status'] as String?) ?? 'sent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sendID': sendID,
      'senderNickname': senderNickname,
      'text': text,
      'originalText': originalText,
      'quoteSenderNickname': quoteSenderNickname,
      'quoteText': quoteText,
      'sendTime': sendTime,
      'status': status,
    };
  }
}

class ChatCacheRepository {
  static const _prefix = 'chat_cache_v1_';
  static const _deletedPrefix = 'chat_deleted_v1_';
  static const _maxMessages = 200;

  String _key(String conversationId) => '$_prefix$conversationId';
  String _deletedKey(String conversationId) => '$_deletedPrefix$conversationId';

  Future<List<ChatCachedMessage>> readMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(conversationId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => ChatCachedMessage.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeMessages(
    String conversationId,
    List<ChatCachedMessage> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length > _maxMessages
        ? messages.sublist(messages.length - _maxMessages)
        : messages;
    final raw = jsonEncode(trimmed.map((e) => e.toJson()).toList());
    await prefs.setString(_key(conversationId), raw);
  }

  Future<void> removeMessage(String conversationId, String id) async {
    final existing = await readMessages(conversationId);
    final next = existing.where((m) => m.id != id).toList();
    await writeMessages(conversationId, next);
  }

  Future<Set<String>> readDeletedIds(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_deletedKey(conversationId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded.whereType<String>().where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> addDeletedId(String conversationId, String id) async {
    if (id.isEmpty) return;
    final existing = await readDeletedIds(conversationId);
    existing.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _deletedKey(conversationId), jsonEncode(existing.toList()));
  }

  Future<void> removeDeletedId(String conversationId, String id) async {
    final existing = await readDeletedIds(conversationId);
    existing.remove(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _deletedKey(conversationId), jsonEncode(existing.toList()));
  }

  Future<void> clear(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(conversationId));
    await prefs.remove(_deletedKey(conversationId));
  }
}
