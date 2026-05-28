import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService with WidgetsBindingObserver {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  static const _chatChannelId = 'chat_messages';
  static const _chatChannelName = '聊天消息';
  static const _attendanceChannelId = 'attendance_reminders';
  static const _attendanceChannelName = '打卡提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _inForeground = true;

  bool get inForeground => _inForeground;

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(initSettings);

    if (!kIsWeb && Platform.isAndroid) {
      await _ensureAndroidChannel();
      await _ensureAttendanceChannel();
    }
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermission();
    });
  }

  Future<void> _ensureAndroidChannel() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;
    await impl.deleteNotificationChannel('chat_messages_v2');
    await impl.createNotificationChannel(
      const AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: '聊天消息提醒',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
  }

  Future<void> _ensureAttendanceChannel() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;
    await impl.createNotificationChannel(
      const AndroidNotificationChannel(
        _attendanceChannelId,
        _attendanceChannelName,
        description: '打卡提醒（围栏进入、迟到、下班）',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
    }
    if (Platform.isIOS) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await impl?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showChatMessage({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    await _ensurePermissionForShow();

    const androidDetails = AndroidNotificationDetails(
      _chatChannelId,
      _chatChannelName,
      channelDescription: '聊天消息提醒',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      category: AndroidNotificationCategory.message,
    );
    const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true);

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _plugin.show(
          DateTime.now().millisecondsSinceEpoch, title, body, details,
          payload: payload);
    }
  }

  Future<void> _ensurePermissionForShow() async {
    if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await impl?.areNotificationsEnabled();
      if (enabled == false) {
        await impl?.requestNotificationsPermission();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (_inForeground) {
      clearAll();
    }
  }

  /// 打卡提醒通知
  Future<void> showAttendanceReminder({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    await _ensurePermissionForShow();

    const androidDetails = AndroidNotificationDetails(
      _attendanceChannelId,
      _attendanceChannelName,
      channelDescription: '打卡提醒',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true);

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _plugin.show(
          DateTime.now().millisecondsSinceEpoch, title, body, details,
          payload: payload);
    }
  }

  Future<void> clearAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    // 清除推送角标逻辑
  }
}
