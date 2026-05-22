import 'package:flutter/material.dart';

class TaskNode {
  final int id;
  final int projectId;
  final String title;
  final String? description;
  final String? plannedDate;
  final int? assigneeId;
  final String? assigneeName;
  final String status;
  final int progressPercent;
  final String createdAt;
  final String updatedAt;
  final String? phase;
  final String? planStartDate;
  final String? planEndDate;
  final String? priority;
  final int sortOrder;

  TaskNode({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    this.plannedDate,
    this.assigneeId,
    this.assigneeName,
    required this.status,
    required this.progressPercent,
    required this.createdAt,
    required this.updatedAt,
    this.phase,
    this.planStartDate,
    this.planEndDate,
    this.priority,
    this.sortOrder = 0,
  });

  factory TaskNode.fromJson(Map<String, dynamic> json) {
    return TaskNode(
      id: json['id'],
      projectId: json['project_id'],
      title: json['title'] ?? '',
      description: json['description'],
      plannedDate: json['planned_date'],
      assigneeId: json['assignee_id'],
      assigneeName: json['assignee_name'],
      status: json['status'] ?? 'pending',
      progressPercent: json['progress_percent'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      phase: json['phase'],
      planStartDate: json['plan_start_date'],
      planEndDate: json['plan_end_date'],
      priority: json['priority'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'planned_date': plannedDate,
      'assignee_id': assigneeId,
      'status': status,
      'progress_percent': progressPercent,
      'phase': phase,
      'plan_start_date': planStartDate,
      'plan_end_date': planEndDate,
      'priority': priority,
      'sort_order': sortOrder,
    };
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return '待开始';
      case 'in_progress':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'paused':
        return '已暂停';
      default:
        return '未知';
    }
  }

  String get phaseText {
    switch (phase) {
      case 'preparation':
        return '准备阶段';
      case 'construction':
        return '施工阶段';
      case 'inspection':
        return '验收阶段';
      case 'rectification':
        return '整改阶段';
      case 'delivery':
        return '交付阶段';
      default:
        return '施工阶段';
    }
  }

  String get priorityText {
    switch (priority) {
      case 'low':
        return '低';
      case 'medium':
        return '中';
      case 'high':
        return '高';
      case 'urgent':
        return '紧急';
      default:
        return '中';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'low':
        return Colors.grey;
      case 'medium':
        return Colors.blue;
      case 'high':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  bool get isOverdue {
    if (planEndDate == null || status == 'completed') return false;
    final endDate = DateTime.tryParse(planEndDate!);
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate);
  }
}
