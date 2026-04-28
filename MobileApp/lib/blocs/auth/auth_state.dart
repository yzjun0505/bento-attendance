import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final String token;
  final String? imToken;
  final bool imInitialized;
  final bool imConnecting;
  final bool isOffline;

  const AuthAuthenticated({
    required this.user,
    required this.token,
    this.imToken,
    this.imInitialized = false,
    this.imConnecting = false,
    this.isOffline = false,
  });

  AuthAuthenticated copyWith({
    User? user,
    String? token,
    String? imToken,
    bool? imInitialized,
    bool? imConnecting,
    bool? isOffline,
  }) {
    return AuthAuthenticated(
      user: user ?? this.user,
      token: token ?? this.token,
      imToken: imToken ?? this.imToken,
      imInitialized: imInitialized ?? this.imInitialized,
      imConnecting: imConnecting ?? this.imConnecting,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  @override
  List<Object?> get props => [user, token, imToken, imInitialized, imConnecting, isOffline];
}

class AuthUnauthenticated extends AuthState {
  final String? error;
  const AuthUnauthenticated({this.error});

  @override
  List<Object?> get props => [error];
}
