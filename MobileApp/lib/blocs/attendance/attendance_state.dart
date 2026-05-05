import 'package:equatable/equatable.dart';
import '../../models/project_model.dart';
import '../../models/checkin_model.dart';
import '../../models/checkin_type_model.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoading extends AttendanceState {}

class AttendanceLoaded extends AttendanceState {
  final List<Project> projects;
  final List<Project> nearbyProjects; // 附近项目（含距离信息）
  final List<Checkin> recentHistory;
  final List<CheckinType> checkinTypes; // 打卡类型列表
  final double? currentLatitude;
  final double? currentLongitude;
  final String? currentAddress;
  final Project? nearestProject;
  final double? distanceToNearest;
  final bool isInsideGeofence;
  final bool needsProjectConfirmation; // 是否需要用户确认项目（多项目围栏内）
  final CheckinType? selectedCheckinType; // 当前选中的打卡类型
  final int? selectedProjectId; // 用户手动选择的项目ID
  final bool isSubmitting; // 是否正在提交打卡
  final String? checkinFeedback; // 打卡反馈信息（成功/失败）

  // 考勤组时间设置
  final String? workStartTime; // 规定上班时间 (如 "09:00")
  final String? workEndTime; // 规定下班时间 (如 "18:00")
  final String? attendanceGroupName; // 考勤组名称
  final int lateTolerance; // 迟到容忍分钟数

  // 今日排班信息（从 /schedules/today 获取）
  final String? todayShiftName; // 今日班次名称（如"白班"）
  final String? todayShiftStart; // 今日上班时间
  final String? todayShiftEnd; // 今日下班时间
  final String? todayShiftColor; // 今日班次颜色

  // 离线打卡待同步数量
  final int offlinePendingCount;

  const AttendanceLoaded({
    required this.projects,
    this.nearbyProjects = const [],
    required this.recentHistory,
    this.checkinTypes = const [],
    this.currentLatitude,
    this.currentLongitude,
    this.currentAddress,
    this.nearestProject,
    this.distanceToNearest,
    this.isInsideGeofence = false,
    this.needsProjectConfirmation = false,
    this.selectedCheckinType,
    this.selectedProjectId,
    this.isSubmitting = false,
    this.checkinFeedback,
    this.workStartTime,
    this.workEndTime,
    this.attendanceGroupName,
    this.lateTolerance = 0,
    this.todayShiftName,
    this.todayShiftStart,
    this.todayShiftEnd,
    this.todayShiftColor,
    this.offlinePendingCount = 0,
  });

  /// 当前有效的项目ID（优先用户手动选择，其次最近项目）
  int? get activeProjectId => selectedProjectId ?? nearestProject?.id;

  /// 当前有效的项目名称
  String get activeProjectName {
    if (selectedProjectId != null) {
      final project = nearbyProjects.where((p) => p.id == selectedProjectId).firstOrNull ??
          projects.where((p) => p.id == selectedProjectId).firstOrNull;
      return project?.name ?? '未知项目';
    }
    return nearestProject?.name ?? '未关联项目';
  }

  /// 考勤类型的打卡类型（上下班）
  List<CheckinType> get attendanceTypes =>
      checkinTypes.where((t) => t.category == 'attendance').toList();

  /// 业务类型的打卡类型
  List<CheckinType> get businessTypes =>
      checkinTypes.where((t) => t.category == 'business').toList();

  /// 巡检类型的打卡类型
  List<CheckinType> get inspectionTypes =>
      checkinTypes.where((t) => t.category == 'inspection').toList();

  AttendanceLoaded copyWith({
    List<Project>? projects,
    List<Project>? nearbyProjects,
    List<Checkin>? recentHistory,
    List<CheckinType>? checkinTypes,
    double? currentLatitude,
    double? currentLongitude,
    String? currentAddress,
    Project? nearestProject,
    double? distanceToNearest,
    bool? isInsideGeofence,
    bool? needsProjectConfirmation,
    CheckinType? selectedCheckinType,
    int? selectedProjectId,
    bool? isSubmitting,
    String? checkinFeedback,
    String? workStartTime,
    String? workEndTime,
    String? attendanceGroupName,
    int? lateTolerance,
    String? todayShiftName,
    String? todayShiftStart,
    String? todayShiftEnd,
    String? todayShiftColor,
    int? offlinePendingCount,
  }) {
    return AttendanceLoaded(
      projects: projects ?? this.projects,
      nearbyProjects: nearbyProjects ?? this.nearbyProjects,
      recentHistory: recentHistory ?? this.recentHistory,
      checkinTypes: checkinTypes ?? this.checkinTypes,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      currentAddress: currentAddress ?? this.currentAddress,
      nearestProject: nearestProject ?? this.nearestProject,
      distanceToNearest: distanceToNearest ?? this.distanceToNearest,
      isInsideGeofence: isInsideGeofence ?? this.isInsideGeofence,
      needsProjectConfirmation: needsProjectConfirmation ?? this.needsProjectConfirmation,
      selectedCheckinType: selectedCheckinType ?? this.selectedCheckinType,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      checkinFeedback: checkinFeedback,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      attendanceGroupName: attendanceGroupName ?? this.attendanceGroupName,
      lateTolerance: lateTolerance ?? this.lateTolerance,
      todayShiftName: todayShiftName ?? this.todayShiftName,
      todayShiftStart: todayShiftStart ?? this.todayShiftStart,
      todayShiftEnd: todayShiftEnd ?? this.todayShiftEnd,
      todayShiftColor: todayShiftColor ?? this.todayShiftColor,
      offlinePendingCount: offlinePendingCount ?? this.offlinePendingCount,
    );
  }

  @override
  List<Object?> get props => [
        projects,
        nearbyProjects,
        recentHistory,
        checkinTypes,
        currentLatitude,
        currentLongitude,
        currentAddress,
        nearestProject,
        distanceToNearest,
        isInsideGeofence,
        needsProjectConfirmation,
        selectedCheckinType,
        selectedProjectId,
        isSubmitting,
        checkinFeedback,
        workStartTime,
        workEndTime,
        attendanceGroupName,
        lateTolerance,
        todayShiftName,
        todayShiftStart,
        todayShiftEnd,
        todayShiftColor,
        offlinePendingCount,
      ];
}

class CheckinSubmissionInProgress extends AttendanceState {}

class AttendanceError extends AttendanceState {
  final String message;
  const AttendanceError({required this.message});

  @override
  List<Object?> get props => [message];
}

class CheckinSuccess extends AttendanceState {
  final bool isOutside;
  const CheckinSuccess({required this.isOutside});

  @override
  List<Object?> get props => [isOutside];
}
