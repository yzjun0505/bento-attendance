import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

abstract class TrackingEvent extends Equatable {
  const TrackingEvent();

  @override
  List<Object?> get props => [];
}

class StartTracking extends TrackingEvent {}

class StopTracking extends TrackingEvent {}

class LocationUpdated extends TrackingEvent {
  final Position position;
  const LocationUpdated({required this.position});

  @override
  List<Object?> get props => [position];
}
