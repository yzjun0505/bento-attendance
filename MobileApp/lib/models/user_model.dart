import 'package:equatable/equatable.dart';
import '../api/dio_client.dart';

class User extends Equatable {
  final int id;
  final String username;
  final String name;
  final String role;
  final String? phone;
  final String? email;
  final String? avatar;
  final int? projectId;
  final String? projectName;

  const User({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.phone,
    this.email,
    this.avatar,
    this.projectId,
    this.projectName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      name: json['name'],
      role: json['role'],
      phone: json['phone'],
      email: json['email'],
      avatar: ApiClient.resolveFileUrl(json['avatar']?.toString()),
      projectId: json['project_id'],
      projectName: json['project_name'],
    );
  }

  User copyWith({
    int? id,
    String? username,
    String? name,
    String? role,
    String? phone,
    String? email,
    String? avatar,
    int? projectId,
    String? projectName,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
    );
  }

  @override
  List<Object?> get props =>
      [id, username, name, role, phone, email, avatar, projectId, projectName];
}
