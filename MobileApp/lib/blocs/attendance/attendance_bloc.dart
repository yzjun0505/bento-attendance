import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../api/dio_client.dart';
import '../../models/project_model.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/checkin_repository.dart';
import '../../repositories/checkin_type_repository.dart';
import '../../repositories/schedule_repository.dart';
import '../../repositories/offline_checkin_repository.dart';
import '../../utils/amap_geo_service.dart';
import '../../utils/coord_utils.dart';
import '../../models/checkin_model.dart';
import '../../models/checkin_type_model.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

/// 考勤组简要信息（内部使用）
class _AttendanceGroupInfo {
  final String name;
  final String? startTime;
  final String? endTime;
  final int lateTolerance;
  const _AttendanceGroupInfo({
    required this.name,
    this.startTime,
    this.endTime,
    this.lateTolerance = 0,
  });
}

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final ProjectRepository projectRepository;
  final CheckinRepository checkinRepository;
  final CheckinTypeRepository checkinTypeRepository;
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final OfflineCheckinRepository _offlineRepository =
      OfflineCheckinRepository();
  final ApiClient _apiClient = ApiClient();

  AttendanceBloc({
    required this.projectRepository,
    required this.checkinRepository,
    required this.checkinTypeRepository,
  }) : super(AttendanceInitial()) {
    on<LoadAttendanceData>(_onLoadAttendanceData);
    on<UpdateCurrentLocation>(_onUpdateCurrentLocation);
    on<SubmitCheckin>(_onSubmitCheckin);
    on<SelectCheckinType>(_onSelectCheckinType);
    on<SelectProject>(_onSelectProject);
  }

  /// 获取当前用户所属考勤组
  Future<_AttendanceGroupInfo?> _fetchMyAttendanceGroup() async {
    try {
      final response = await _apiClient.dio.get('/attendance-groups/my');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data != null) {
          return _AttendanceGroupInfo(
            name: data['name'] as String? ?? '',
            startTime: _formatTime(data['start_time'] as String?),
            endTime: _formatTime(data['end_time'] as String?),
            lateTolerance: data['late_tolerance'] as int? ?? 0,
          );
        }
      }
    } catch (e) {
      debugPrint('获取考勤组失败: $e');
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

  Future<void> _onLoadAttendanceData(
      LoadAttendanceData event, Emitter<AttendanceState> emit) async {
    final bool isFirstLoad = state is! AttendanceLoaded;

    // 仅在首次加载或没有数据时显示 Loading
    if (isFirstLoad) {
      emit(AttendanceLoading());
    }

    try {
      // 并行执行所有基础 API 请求
      final results = await Future.wait([
        projectRepository.getAllProjects().catchError((e) {
          debugPrint('获取项目失败: $e');
          return <Project>[];
        }),
        checkinRepository.getMyCheckins(page: 1, pageSize: 5).catchError((e) {
          debugPrint('获取历史失败: $e');
          return <Checkin>[];
        }),
        checkinTypeRepository.getCheckinTypes().catchError((e) {
          debugPrint('获取类型失败: $e');
          return <CheckinType>[];
        }),
        _fetchMyAttendanceGroup().catchError((e) {
          debugPrint('获取考勤组失败: $e');
          return null;
        }),
        _scheduleRepository.getTodaySchedule().catchError((e) {
          debugPrint('获取今日排班失败: $e');
          return null;
        }),
        _offlineRepository.getCachedCount().catchError((e) {
          debugPrint('获取离线缓存数量失败: $e');
          return 0;
        }),
      ]);

      final projects = results[0] as List<Project>;
      final history = results[1] as List<Checkin>;
      final checkinTypes = results[2] as List<CheckinType>;
      final groupInfo = results[3] as _AttendanceGroupInfo?;
      final todaySchedule = results[4] as Map<String, dynamic>?;
      final offlineCount = results[5] as int? ?? 0;

      // 立即触发一次 Loaded 状态（哪怕还没拿到精确定位），让 UI 先显示出来
      // 如果已有旧坐标，先沿用
      double? lastLat;
      double? lastLng;
      String? lastAddr;
      if (state is AttendanceLoaded) {
        final s = state as AttendanceLoaded;
        lastLat = s.currentLatitude;
        lastLng = s.currentLongitude;
        lastAddr = s.currentAddress;
      }

      // 从今日排班中提取班次信息
      String? shiftName = todaySchedule?['shift_name'] as String?;
      String? shiftStart =
          _formatTime(todaySchedule?['start_time'] as String?) ??
              groupInfo?.startTime;
      String? shiftEnd = _formatTime(todaySchedule?['end_time'] as String?) ??
          groupInfo?.endTime;
      String? shiftColor = todaySchedule?['color'] as String?;

      emit(AttendanceLoaded(
        projects: projects,
        recentHistory: history,
        checkinTypes: checkinTypes,
        nearbyProjects: const [],
        currentLatitude: lastLat,
        currentLongitude: lastLng,
        currentAddress: lastAddr,
        workStartTime: shiftStart,
        workEndTime: shiftEnd,
        attendanceGroupName: shiftName ?? groupInfo?.name,
        lateTolerance: groupInfo?.lateTolerance ?? 0,
        todayShiftName: shiftName,
        todayShiftStart: shiftStart,
        todayShiftEnd: shiftEnd,
        todayShiftColor: shiftColor,
        offlinePendingCount: offlineCount,
      ));

      // 异步获取位置，不阻塞主流程
      _refreshLocation(projects, history, checkinTypes);
    } catch (e) {
      if (isFirstLoad) {
        emit(AttendanceError(message: '加载数据失败: $e'));
      }
    }
  }

  /// 异步更新位置信息并触发新的 Loaded 状态
  Future<void> _refreshLocation(List<Project> projects, List<Checkin> history,
      List<CheckinType> checkinTypes) async {
    Position? position;
    try {
      debugPrint('>>> [Async] 开始获取定位...');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // 使用较短的超时，如果拿不到精确定位就先不更新
        final rawPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          forceAndroidLocationManager: true,
          timeLimit: const Duration(seconds: 10),
        );
        final gcj = CoordUtils.wgs84ToGcj02(rawPos.latitude, rawPos.longitude);
        position = Position(
          latitude: gcj['latitude']!,
          longitude: gcj['longitude']!,
          timestamp: rawPos.timestamp,
          accuracy: rawPos.accuracy,
          altitude: rawPos.altitude,
          heading: rawPos.heading,
          speed: rawPos.speed,
          speedAccuracy: rawPos.speedAccuracy,
          altitudeAccuracy: rawPos.altitudeAccuracy,
          headingAccuracy: rawPos.headingAccuracy,
          isMocked: rawPos.isMocked,
        );
        debugPrint('>>> [Async] 定位获取成功');
      }
    } catch (e) {
      debugPrint('>>> [Async] 定位获取失败: $e');
    }

    if (position != null) {
      // 触发位置更新 Event
      add(UpdateCurrentLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      ));
    }
  }

  Future<void> _onUpdateCurrentLocation(
      UpdateCurrentLocation event, Emitter<AttendanceState> emit) async {
    if (state is AttendanceLoaded) {
      final currentState = state as AttendanceLoaded;

      List<Project> nearbyProjects = [];
      Project? nearest;
      double? distance;
      bool isInside = false;

      try {
        nearbyProjects = await projectRepository.getNearbyProjects(
          latitude: event.latitude,
          longitude: event.longitude,
          radius: 2000,
        );
      } catch (_) {
        nearbyProjects = _findNearbyProjectsFromCoords(
            event.latitude, event.longitude, currentState.projects);
      }

      final insideProjects =
          nearbyProjects.where((p) => p.isInside == true).toList();

      if (insideProjects.length == 1) {
        nearest = insideProjects.first;
        distance = nearest.distance?.toDouble();
        isInside = true;
      } else if (insideProjects.length > 1) {
        nearest = insideProjects.first;
        distance = nearest.distance?.toDouble();
        isInside = true;
      } else if (nearbyProjects.isNotEmpty) {
        nearest = nearbyProjects.first;
        distance = nearest.distance?.toDouble();
        isInside = false;
      }

      // 如果没有提供地址，通过逆地理编码获取
      String? address = event.address;
      if (address == null || address.isEmpty) {
        try {
          address = await AmapGeoService.reverseGeocode(
            latitude: event.latitude,
            longitude: event.longitude,
          );
        } catch (e) {
          debugPrint('逆地理编码失败: $e');
        }
      }

      emit(currentState.copyWith(
        currentLatitude: event.latitude,
        currentLongitude: event.longitude,
        currentAddress: address,
        nearbyProjects: nearbyProjects,
        nearestProject: nearest,
        distanceToNearest: distance,
        isInsideGeofence: isInside,
        needsProjectConfirmation: insideProjects.length > 1,
      ));
    }
  }

  Future<void> _onSubmitCheckin(
      SubmitCheckin event, Emitter<AttendanceState> emit) async {
    if (state is AttendanceLoaded) {
      final currentState = state as AttendanceLoaded;

      if (currentState.currentLatitude == null ||
          currentState.currentLongitude == null) {
        emit(currentState.copyWith(
          checkinFeedback: '无法获取当前位置，请开启GPS后重试',
        ));
        // 清除反馈
        await Future.delayed(const Duration(seconds: 2));
        if (state is AttendanceLoaded) {
          emit((state as AttendanceLoaded).copyWith(checkinFeedback: null));
        }
        return;
      }

      // 标记提交中
      emit(currentState.copyWith(isSubmitting: true, checkinFeedback: null));

      String? photoUrl;
      try {
        if (event.photoPath != null) {
          final photoFile = File(event.photoPath!);
          photoUrl = await checkinRepository.uploadPhoto(photoFile);
        }

        await checkinRepository.submitCheckin(
          type: event.type,
          latitude: currentState.currentLatitude!,
          longitude: currentState.currentLongitude!,
          address: currentState.currentAddress ?? '',
          projectId: event.projectId ??
              currentState.selectedProjectId ??
              currentState.nearestProject?.id,
          remark: event.remark,
          photo: photoUrl,
          watermarkCode: event.watermarkCode,
        );

        // 打卡成功反馈
        emit(currentState.copyWith(
          isSubmitting: false,
          checkinFeedback:
              !currentState.isInsideGeofence ? '打卡成功（围栏外）' : '打卡成功',
        ));

        // 2秒后清除反馈并重新加载数据
        await Future.delayed(const Duration(seconds: 2));
        add(LoadAttendanceData());
      } catch (e) {
        // 检查是否为网络异常，如果是则缓存离线打卡
        final isNetworkError = e is DioException &&
            (e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout);

        if (isNetworkError) {
          try {
            await _offlineRepository.cacheOfflineCheckin(
              _offlineRepository.buildOfflineData(
                type: event.type,
                latitude: currentState.currentLatitude!,
                longitude: currentState.currentLongitude!,
                address: currentState.currentAddress ?? '',
                photo: photoUrl,
                projectId: event.projectId ??
                    currentState.selectedProjectId ??
                    currentState.nearestProject?.id,
                remark: event.remark,
                watermarkCode: event.watermarkCode,
              ),
            );
            final newCount = await _offlineRepository.getCachedCount();
            emit(currentState.copyWith(
              isSubmitting: false,
              checkinFeedback: '网络异常，已缓存离线打卡',
              offlinePendingCount: newCount,
            ));
          } catch (cacheErr) {
            emit(currentState.copyWith(
              isSubmitting: false,
              checkinFeedback: '打卡失败: $e',
            ));
          }
        } else {
          // 打卡失败反馈，保持 AttendanceLoaded 状态
          emit(currentState.copyWith(
            isSubmitting: false,
            checkinFeedback: '打卡失败: $e',
          ));
        }
        // 3秒后清除失败反馈
        await Future.delayed(const Duration(seconds: 3));
        if (state is AttendanceLoaded) {
          emit((state as AttendanceLoaded).copyWith(checkinFeedback: null));
        }
      }
    }
  }

  Future<void> _onSelectCheckinType(
      SelectCheckinType event, Emitter<AttendanceState> emit) async {
    if (state is AttendanceLoaded) {
      final currentState = state as AttendanceLoaded;
      emit(currentState.copyWith(
        selectedCheckinType: event.checkinType,
      ));
    }
  }

  Future<void> _onSelectProject(
      SelectProject event, Emitter<AttendanceState> emit) async {
    if (state is AttendanceLoaded) {
      final currentState = state as AttendanceLoaded;
      emit(currentState.copyWith(
        selectedProjectId: event.projectId,
        needsProjectConfirmation: false,
      ));
    }
  }

  List<Project> _findNearbyProjectsFromCoords(
      double lat, double lng, List<Project> projects) {
    final nearby = <Project>[];
    for (final project in projects) {
      if (project.latitude != null && project.longitude != null) {
        final dist = Geolocator.distanceBetween(
            lat, lng, project.latitude!, project.longitude!);
        if (dist <= 2000) {
          nearby.add(Project(
            id: project.id,
            name: project.name,
            address: project.address,
            latitude: project.latitude,
            longitude: project.longitude,
            radius: project.radius,
            userCount: project.userCount,
            distance: dist.round(),
            isInside: dist <= project.radius,
          ));
        }
      }
    }
    nearby.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
    return nearby;
  }
}
