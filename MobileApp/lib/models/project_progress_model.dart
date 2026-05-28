import 'dart:convert';

class ProjectProgress {
  final int id;
  final String name;
  final String? address;
  final int overallProgress;
  final int totalNodes;
  final int completedNodes;
  final int inProgressNodes;
  final int pendingReviewNodes;
  final int overdueNodes;
  final int pausedNodes;
  final String? lastReportTime;
  final int assigneeCount;

  const ProjectProgress({
    required this.id,
    required this.name,
    this.address,
    required this.overallProgress,
    required this.totalNodes,
    required this.completedNodes,
    required this.inProgressNodes,
    required this.pendingReviewNodes,
    required this.overdueNodes,
    required this.pausedNodes,
    this.lastReportTime,
    required this.assigneeCount,
  });

  factory ProjectProgress.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return ProjectProgress(
      id: asInt(json['id']),
      name: json['name'] ?? '',
      address: json['address'],
      overallProgress: asInt(json['overallProgress']),
      totalNodes: asInt(json['totalNodes']),
      completedNodes: asInt(json['completedNodes']),
      inProgressNodes: asInt(json['inProgressNodes']),
      pendingReviewNodes: asInt(json['pendingReviewNodes']),
      overdueNodes: asInt(json['overdueNodes']),
      pausedNodes: asInt(json['pausedNodes']),
      lastReportTime: json['lastReportTime'],
      assigneeCount: asInt(json['assigneeCount']),
    );
  }
}

class ProjectProgressSummary {
  final int projectId;
  final String projectName;
  final int overallProgress;
  final int totalNodes;
  final int completedNodes;
  final int inProgressNodes;
  final int pendingReviewNodes;
  final int overdueNodes;
  final int pausedNodes;
  final List<PhaseStat> phases;
  final List<RecentReport> recentReports;

  const ProjectProgressSummary({
    required this.projectId,
    required this.projectName,
    required this.overallProgress,
    required this.totalNodes,
    required this.completedNodes,
    required this.inProgressNodes,
    required this.pendingReviewNodes,
    required this.overdueNodes,
    required this.pausedNodes,
    required this.phases,
    required this.recentReports,
  });

  factory ProjectProgressSummary.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return ProjectProgressSummary(
      projectId: asInt(json['projectId']),
      projectName: json['projectName'] ?? '',
      overallProgress: asInt(json['overallProgress']),
      totalNodes: asInt(json['totalNodes']),
      completedNodes: asInt(json['completedNodes']),
      inProgressNodes: asInt(json['inProgressNodes']),
      pendingReviewNodes: asInt(json['pendingReviewNodes']),
      overdueNodes: asInt(json['overdueNodes']),
      pausedNodes: asInt(json['pausedNodes']),
      phases: json['phases'] != null
          ? (json['phases'] as List)
              .map((e) => PhaseStat.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      recentReports: json['recentReports'] != null
          ? (json['recentReports'] as List)
              .map((e) => RecentReport.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

class PhaseStat {
  final String phase;
  final String label;
  final int nodeCount;
  final int completedCount;
  final int completionRate;

  const PhaseStat({
    required this.phase,
    required this.label,
    required this.nodeCount,
    required this.completedCount,
    required this.completionRate,
  });

  factory PhaseStat.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return PhaseStat(
      phase: json['phase'] ?? '',
      label: json['label'] ?? '',
      nodeCount: asInt(json['nodeCount']),
      completedCount: asInt(json['completedCount']),
      completionRate: asInt(json['completionRate']),
    );
  }
}

class RecentReport {
  final int id;
  final int nodeId;
  final String? description;
  final int progressPercent;
  final String? riskNote;
  final String? blockerNote;
  final String? reporterName;
  final String? nodeTitle;
  final String createdAt;
  final String? photo;
  final List<String>? photos;

  const RecentReport({
    required this.id,
    required this.nodeId,
    this.description,
    required this.progressPercent,
    this.riskNote,
    this.blockerNote,
    this.reporterName,
    this.nodeTitle,
    required this.createdAt,
    this.photo,
    this.photos,
  });

  factory RecentReport.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return RecentReport(
      id: asInt(json['id']),
      nodeId: asInt(json['nodeId']),
      description: json['description'],
      progressPercent: asInt(json['progressPercent']),
      riskNote: json['riskNote'],
      blockerNote: json['blockerNote'],
      reporterName: json['reporterName'],
      nodeTitle: json['nodeTitle'],
      createdAt: json['createdAt'] ?? '',
      photo: json['photo'],
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] is String
              ? (jsonDecode(json['photos']) as List).map((e) => e.toString())
              : (json['photos'] as List).map((e) => e.toString()))
          : null,
    );
  }
}
