import 'dart:convert';

class ProgressReport {
  final int id;
  final int nodeId;
  final int reporterId;
  final String? reporterName;
  final String? description;
  final String? photo;
  final int progressPercent;
  final String createdAt;
  final String? riskNote;
  final String? blockerNote;
  final List<String>? photos;

  ProgressReport({
    required this.id,
    required this.nodeId,
    required this.reporterId,
    this.reporterName,
    this.description,
    this.photo,
    required this.progressPercent,
    required this.createdAt,
    this.riskNote,
    this.blockerNote,
    this.photos,
  });

  factory ProgressReport.fromJson(Map<String, dynamic> json) {
    return ProgressReport(
      id: json['id'],
      nodeId: json['node_id'],
      reporterId: json['reporter_id'],
      reporterName: json['reporter_name'],
      description: json['description'],
      photo: json['photo'],
      progressPercent: json['progress_percent'] ?? 0,
      createdAt: json['created_at'] ?? '',
      riskNote: json['risk_note'],
      blockerNote: json['blocker_note'],
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] is String
              ? (jsonDecode(json['photos']) as List).map((e) => e.toString())
              : (json['photos'] as List).map((e) => e.toString()))
          : null,
    );
  }
}
