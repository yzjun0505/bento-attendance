import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../models/checkin_model.dart';
import '../../models/user_model.dart';
import '../../utils/weather_service.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadHomeSummary extends HomeEvent {
  final bool silent;
  const LoadHomeSummary({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeSummaryLoading extends HomeState {}

class TimelineItem extends Equatable {
  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int? sourceId;
  final String sourceType; // 'checkin' | 'notification' | 'approval'

  const TimelineItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.sourceId,
    this.sourceType = 'checkin',
  });

  @override
  List<Object?> get props => [time, title, subtitle, sourceId, sourceType];
}

class HomeSummaryLoaded extends HomeState {
  final User user;
  final Checkin? lastCheckinIn;
  final Checkin? lastCheckinOut;
  final int totalCheckinsThisMonth;
  final WeatherInfo? weatherInfo;
  final List<TimelineItem> timelineItems;

  // 考勤组时间设置
  final String? workStartTime; // 规定上班时间
  final String? workEndTime; // 规定下班时间
  final String? attendanceGroupName; // 考勤组名称

  const HomeSummaryLoaded({
    required this.user,
    this.lastCheckinIn,
    this.lastCheckinOut,
    required this.totalCheckinsThisMonth,
    this.weatherInfo,
    this.timelineItems = const [],
    this.workStartTime,
    this.workEndTime,
    this.attendanceGroupName,
  });

  @override
  List<Object?> get props => [
        user,
        lastCheckinIn,
        lastCheckinOut,
        totalCheckinsThisMonth,
        weatherInfo,
        timelineItems,
        workStartTime,
        workEndTime,
        attendanceGroupName
      ];
}

class HomeError extends HomeState {
  final String message;
  const HomeError({required this.message});

  @override
  List<Object?> get props => [message];
}
