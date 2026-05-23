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
    int _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return ProjectProgress(
      id: _int(json['id']),
      name: json['name'] ?? '',
      address: json['address'],
      overallProgress: _int(json['overallProgress']),
      totalNodes: _int(json['totalNodes']),
      completedNodes: _int(json['completedNodes']),
      inProgressNodes: _int(json['inProgressNodes']),
      overdueNodes: _int(json['overdueNodes']),
      pausedNodes: _int(json['pausedNodes']),
      lastReportTime: json['lastReportTime'],
      assigneeCount: _int(json['assigneeCount']),
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
    int _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return ProjectProgressSummary(
      projectId: _int(json['projectId']),
      projectName: json['projectName'] ?? '',
      overallProgress: _int(json['overallProgress']),
      totalNodes: _int(json['totalNodes']),
      completedNodes: _int(json['completedNodes']),
      inProgressNodes: _int(json['inProgressNodes']),
      overdueNodes: _int(json['overdueNodes']),
      pausedNodes: _int(json['pausedNodes']),
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
    int _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return PhaseStat(
      phase: json['phase'] ?? '',
      label: json['label'] ?? '',
      nodeCount: _int(json['nodeCount']),
      completedCount: _int(json['completedCount']),
      completionRate: _int(json['completionRate']),
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
    int _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return RecentReport(
      id: _int(json['id']),
      nodeId: _int(json['nodeId']),
      description: json['description'],
      progressPercent: _int(json['progressPercent']),
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
