import 'package:equatable/equatable.dart';
import '../../models/checkin_type_model.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

class LoadAttendanceData extends AttendanceEvent {}

class SubmitCheckin extends AttendanceEvent {
  final String type;
  final int? projectId;
  final String? remark;
  final String? photoPath;
  final String? watermarkCode;

  const SubmitCheckin({
    required this.type,
    this.projectId,
    this.remark,
    this.photoPath,
    this.watermarkCode,
  });

  @override
  List<Object?> get props => [type, projectId, remark, photoPath, watermarkCode];
}

class UpdateCurrentLocation extends AttendanceEvent {
  final double latitude;
  final double longitude;
  final String? address;

  const UpdateCurrentLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  @override
  List<Object?> get props => [latitude, longitude, address];
}

/// 选择打卡类型
class SelectCheckinType extends AttendanceEvent {
  final CheckinType checkinType;

  const SelectCheckinType({required this.checkinType});

  @override
  List<Object?> get props => [checkinType];
}

/// 选择项目（多项目时用户手动选择）
class SelectProject extends AttendanceEvent {
  final int projectId;

  const SelectProject({required this.projectId});

  @override
  List<Object?> get props => [projectId];
}
