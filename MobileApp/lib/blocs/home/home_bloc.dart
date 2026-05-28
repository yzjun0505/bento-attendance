import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../api/dio_client.dart';
import '../../models/checkin_model.dart';
import '../../models/notification_model.dart';
import '../../repositories/checkin_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../utils/weather_service.dart';
import 'home_bloc_base.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final CheckinRepository checkinRepository;
  final NotificationRepository notificationRepository;
  final AuthBloc authBloc;
  final ApiClient _apiClient = ApiClient();

  HomeBloc({
    required this.checkinRepository,
    required this.notificationRepository,
    required this.authBloc,
  }) : super(HomeInitial()) {
    on<LoadHomeSummary>(_onLoadHomeSummary);
  }

  /// 获取当前用户所属考勤组的时间设置
  Future<Map<String, String?>?> _fetchMyAttendanceGroup() async {
    try {
      final response = await _apiClient.dio.get('/attendance-groups/my');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data != null) {
          return {
            'name': data['name'] as String? ?? '',
            'startTime': _formatTime(data['start_time'] as String?),
            'endTime': _formatTime(data['end_time'] as String?),
          };
        }
      }
    } catch (e) {
      debugPrint('获取考勤组信息失败: $e');
    }
    return null;
  }

  /// 将 "18:00:11" 格式化成 "18:00"
  String? _formatTime(String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  Future<void> _onLoadHomeSummary(
      LoadHomeSummary event, Emitter<HomeState> emit) async {
    final authState = authBloc.state;
    if (authState is! AuthAuthenticated) {
      emit(const HomeError(message: '用户未登录'));
      return;
    }

    final prevState = state;
    final shouldShowLoading = !event.silent && prevState is! HomeSummaryLoaded;
    if (shouldShowLoading) {
      // 立即使用本地缓存的用户信息渲染骨架，避免白屏转圈
      emit(HomeSummaryLoaded(
        user: authState.user,
        lastCheckinIn: null,
        lastCheckinOut: null,
        totalCheckinsThisMonth: 0,
        timelineItems: const [],
      ));
    }

    try {
      // 并行获取所有数据，极大减少等待时间
      final weatherFuture = WeatherService.getWeatherByLocation(
              latitude: 39.9042, longitude: 116.4074)
          .catchError((_) => null);
      final notifFuture = notificationRepository
          .getNotifications(page: 1, pageSize: 10)
          .catchError((_) => <NotificationModel>[]);

      final results = await Future.wait([
        checkinRepository.getTodayCheckins().catchError((_) => <Checkin>[]),
        checkinRepository
            .getMyCheckins(page: 1, pageSize: 100)
            .catchError((_) => <Checkin>[]),
        _fetchMyAttendanceGroup().catchError((_) => null),
        weatherFuture,
        notifFuture,
      ]);

      final todayCheckins = results[0] as List<Checkin>? ?? [];
      final allCheckins = results[1] as List<Checkin>? ?? [];
      final groupInfo = results[2] as Map<String, String?>?;
      final weatherInfo = results[3] as WeatherInfo?;
      final notifications = results[4] as List<NotificationModel>? ?? [];

      final inCheckin = todayCheckins
          .where((c) => c.type == 'in' || c.type == 'clock_in')
          .firstOrNull;
      final outCheckin = todayCheckins
          .where((c) => c.type == 'out' || c.type == 'clock_out')
          .firstOrNull;

      final now = DateTime.now();
      final monthCheckins = allCheckins
          .where((c) =>
              c.createdAt.year == now.year && c.createdAt.month == now.month)
          .toList();
      final daySet = monthCheckins.map((c) => c.createdAt.day).toSet();

      final timelineItems = _buildTimelineItems(todayCheckins, notifications);

      emit(HomeSummaryLoaded(
        user: authState.user,
        lastCheckinIn: inCheckin,
        lastCheckinOut: outCheckin,
        totalCheckinsThisMonth: daySet.length,
        weatherInfo: weatherInfo,
        timelineItems: timelineItems,
        workStartTime: groupInfo?['startTime'],
        workEndTime: groupInfo?['endTime'],
        attendanceGroupName: groupInfo?['name'],
      ));
    } catch (e) {
      final currentAuth = authBloc.state;
      if (currentAuth is AuthAuthenticated && currentAuth.isOffline) {
        emit(HomeSummaryLoaded(
          user: currentAuth.user,
          lastCheckinIn: null,
          lastCheckinOut: null,
          totalCheckinsThisMonth: 0,
          weatherInfo: null,
          timelineItems: const [],
          workStartTime: null,
          workEndTime: null,
          attendanceGroupName: null,
        ));
        return;
      }
      if (event.silent && prevState is HomeSummaryLoaded) {
        emit(prevState);
        return;
      }
      emit(HomeError(message: '获取汇总数据失败: $e'));
    }
  }

  List<TimelineItem> _buildTimelineItems(
      List<Checkin> checkins, List<NotificationModel> notifications) {
    final items = <TimelineItem>[];

    for (final c in checkins) {
      final isIn = c.type == 'in' || c.type == 'clock_in';
      items.add(TimelineItem(
        time: DateFormat('HH:mm').format(c.createdAt),
        title: isIn ? '上班打卡' : '下班打卡',
        subtitle: c.address.isNotEmpty ? c.address : (c.projectName ?? '打卡成功'),
        icon: isIn ? Icons.login_rounded : Icons.logout_rounded,
        color: isIn ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
        sourceId: c.id,
        sourceType: 'checkin',
      ));
    }

    for (final n in notifications) {
      items.add(TimelineItem(
        time: DateFormat('HH:mm').format(n.createdAt),
        title: n.title,
        subtitle: n.content,
        icon: n.type == 'approval'
            ? Icons.check_circle_outline
            : Icons.notifications_outlined,
        color: n.type == 'approval'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF8B5CF6),
        sourceId: n.id,
        sourceType: n.type == 'approval' ? 'approval' : 'notification',
      ));
    }

    items.sort((a, b) => b.time.compareTo(a.time));

    return items;
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
