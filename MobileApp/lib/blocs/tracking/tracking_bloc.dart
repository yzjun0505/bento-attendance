import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../repositories/location_repository.dart';
import '../../utils/coord_utils.dart';
import 'tracking_event.dart';
import 'tracking_state.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final LocationRepository locationRepository;
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;

  TrackingBloc({required this.locationRepository}) : super(TrackingInitial()) {
    on<StartTracking>(_onStartTracking);
    on<StopTracking>(_onStopTracking);
    on<LocationUpdated>(_onLocationUpdated);
  }

  Future<void> _onStartTracking(StartTracking event, Emitter<TrackingState> emit) async {
    bool serviceEnabled;
    LocationPermission permission;

    debugPrint('=== TrackingBloc: StartTracking 触发 ===');

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('=== TrackingBloc: 定位服务未开启 ===');
      emit(const TrackingError(message: '定位服务未开启'));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('=== TrackingBloc: 定位权限被拒绝 ===');
        emit(const TrackingError(message: '定位权限被拒绝'));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('=== TrackingBloc: 定位权限被永久拒绝 ===');
      emit(const TrackingError(message: '定位权限被永久拒绝，请在设置中开启'));
      return;
    }

    debugPrint('=== TrackingBloc: 定位权限OK，开始跟踪 ===');
    emit(const TrackingActive());

    // 立即上报一次当前位置
    _reportNow();

    // 启动定时上报 (每30秒一次)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      _reportNow();
    });

    // 同时监听实时位置变化以便更新 UI
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 移动10米就触发
      ),
    ).listen((position) {
      debugPrint('位置流更新原始GPS: ${position.latitude}, ${position.longitude}');
      final gcj = CoordUtils.wgs84ToGcj02(position.latitude, position.longitude);
      final gcjPosition = Position(
        latitude: gcj['latitude']!,
        longitude: gcj['longitude']!,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        speedAccuracy: position.speedAccuracy,
        altitudeAccuracy: position.altitudeAccuracy,
        headingAccuracy: position.headingAccuracy,
        isMocked: position.isMocked,
      );
      add(LocationUpdated(position: gcjPosition));
    });
  }

  Future<void> _reportNow() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        forceAndroidLocationManager: true, // 强制使用 Android 原生定位
      );
      debugPrint('获取原始GPS: ${position.latitude}, ${position.longitude}');
      final gcj = CoordUtils.wgs84ToGcj02(position.latitude, position.longitude);
      final gcjPosition = Position(
        latitude: gcj['latitude']!,
        longitude: gcj['longitude']!,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        speedAccuracy: position.speedAccuracy,
        altitudeAccuracy: position.altitudeAccuracy,
        headingAccuracy: position.headingAccuracy,
        isMocked: position.isMocked,
      );
      add(LocationUpdated(position: gcjPosition));
    } catch (e) {
      debugPrint('⚠️ 获取当前位置失败: $e');
    }
  }

  Future<void> _onLocationUpdated(LocationUpdated event, Emitter<TrackingState> emit) async {
    if (state is TrackingActive) {
      emit(TrackingActive(lastPosition: event.position));
      
      // 上报到后端
      final success = await locationRepository.reportLocation(
        latitude: event.position.latitude,
        longitude: event.position.longitude,
        accuracy: event.position.accuracy,
        speed: event.position.speed,
      );
      if (!success) {
        debugPrint('⚠️ 位置上报到后端失败！请检查网络和后端地址');
      }
    }
  }

  Future<void> _onStopTracking(StopTracking event, Emitter<TrackingState> emit) async {
    _timer?.cancel();
    _positionSubscription?.cancel();
    emit(TrackingStopped());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    return super.close();
  }
}
