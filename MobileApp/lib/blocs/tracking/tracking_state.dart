import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

abstract class TrackingState extends Equatable {
  const TrackingState();

  @override
  List<Object?> get props => [];
}

class TrackingInitial extends TrackingState {}

class TrackingActive extends TrackingState {
  final Position? lastPosition;
  const TrackingActive({this.lastPosition});

  @override
  List<Object?> get props => [lastPosition];
}

class TrackingStopped extends TrackingState {}

class TrackingError extends TrackingState {
  final String message;
  const TrackingError({required this.message});

  @override
  List<Object?> get props => [message];
}
