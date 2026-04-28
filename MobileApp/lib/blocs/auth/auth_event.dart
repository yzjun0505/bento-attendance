import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class ConnectivityChanged extends AuthEvent {
  final bool isOnline;
  const ConnectivityChanged({required this.isOnline});

  @override
  List<Object?> get props => [isOnline];
}

class LoggedIn extends AuthEvent {
  final String username;
  final String password;

  const LoggedIn({required this.username, required this.password});

  @override
  List<Object?> get props => [username, password];
}

class LoggedOut extends AuthEvent {}

class UserUpdated extends AuthEvent {
  final User user;

  const UserUpdated({required this.user});

  @override
  List<Object?> get props => [user];
}

class IMLoginResult extends AuthEvent {
  final String userID;
  final bool success;
  final String? imToken;

  const IMLoginResult({required this.userID, required this.success, this.imToken});

  @override
  List<Object?> get props => [userID, success, imToken];
}
