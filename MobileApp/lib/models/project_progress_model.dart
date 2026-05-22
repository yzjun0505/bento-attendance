import 'dart:convert';

class ProjectProgress {
  final int id;
  final String name;
  final String? address;
  final int overallProgress;
  final int totalNodes;
  final int completedNodes;
  final int inProgressNodes;
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
    required this.overdueNodes,
    required this.pausedNodes,
    this.lastReportTime,
    required this.assigneeCount,
  });

  factory ProjectProgress.fromJson(Map<String, dynamic> json) {
    return ProjectProgress(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'],
      overallProgress: json['overallProgress'] ?? 0,
      totalNodes: json['totalNodes'] ?? 0,
      completedNodes: json['completedNodes'] ?? 0,
      inProgressNodes: json['inProgressNodes'] ?? 0,
      overdueNodes: json['overdueNodes'] ?? 0,
      pausedNodes: json['pausedNodes'] ?? 0,
      lastReportTime: json['lastReportTime'],
      assigneeCount: json['assigneeCount'] ?? 0,
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
    required this.overdueNodes,
    required this.pausedNodes,
    required this.phases,
    required this.recentReports,
  });

  factory ProjectProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProjectProgressSummary(
      projectId: json['projectId'] ?? 0,
      projectName: json['projectName'] ?? '',
      overallProgress: json['overallProgress'] ?? 0,
      totalNodes: json['totalNodes'] ?? 0,
      completedNodes: json['completedNodes'] ?? 0,
      inProgressNodes: json['inProgressNodes'] ?? 0,
      overdueNodes: json['overdueNodes'] ?? 0,
      pausedNodes: json['pausedNodes'] ?? 0,
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
    return PhaseStat(
      phase: json['phase'] ?? '',
      label: json['label'] ?? '',
      nodeCount: json['nodeCount'] ?? 0,
      completedCount: json['completedCount'] ?? 0,
      completionRate: json['completionRate'] ?? 0,
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
    return RecentReport(
      id: json['id'] ?? 0,
      nodeId: json['nodeId'] ?? 0,
      description: json['description'],
      progressPercent: json['progressPercent'] ?? 0,
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
