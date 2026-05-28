import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/task_node_model.dart';
import '../../models/progress_report_model.dart';
import '../../models/project_progress_model.dart';
import '../../repositories/progress_repository.dart';

abstract class ProgressEvent extends Equatable {
  const ProgressEvent();

  @override
  List<Object?> get props => [];
}

class LoadTaskNodes extends ProgressEvent {
  final int projectId;
  const LoadTaskNodes({required this.projectId});

  @override
  List<Object?> get props => [projectId];
}

class CreateTaskNode extends ProgressEvent {
  final int projectId;
  final Map<String, dynamic> data;
  const CreateTaskNode({required this.projectId, required this.data});

  @override
  List<Object?> get props => [projectId, data];
}

class UpdateTaskNode extends ProgressEvent {
  final int nodeId;
  final Map<String, dynamic> data;
  const UpdateTaskNode({required this.nodeId, required this.data});

  @override
  List<Object?> get props => [nodeId, data];
}

class DeleteTaskNode extends ProgressEvent {
  final int nodeId;
  final int projectId;
  const DeleteTaskNode({required this.nodeId, required this.projectId});

  @override
  List<Object?> get props => [nodeId, projectId];
}

class ReviewTaskNode extends ProgressEvent {
  final int nodeId;
  final String action;
  final String? remark;
  const ReviewTaskNode({
    required this.nodeId,
    required this.action,
    this.remark,
  });

  @override
  List<Object?> get props => [nodeId, action, remark];
}

class LoadProgressReports extends ProgressEvent {
  final int nodeId;
  const LoadProgressReports({required this.nodeId});

  @override
  List<Object?> get props => [nodeId];
}

class SubmitProgressReport extends ProgressEvent {
  final int nodeId;
  final String? description;
  final String? photo;
  final int progressPercent;
  final String? riskNote;
  final String? blockerNote;
  final List<String>? photos;
  final List<String>? watermarkCodes;
  const SubmitProgressReport({
    required this.nodeId,
    this.description,
    this.photo,
    required this.progressPercent,
    this.riskNote,
    this.blockerNote,
    this.photos,
    this.watermarkCodes,
  });

  @override
  List<Object?> get props => [
        nodeId,
        description,
        photo,
        progressPercent,
        riskNote,
        blockerNote,
        photos,
        watermarkCodes
      ];
}

class LoadAuthorizedProjects extends ProgressEvent {
  const LoadAuthorizedProjects();
}

class LoadProjectSummary extends ProgressEvent {
  final int projectId;
  const LoadProjectSummary({required this.projectId});

  @override
  List<Object?> get props => [projectId];
}

class DeleteTaskNodeAndRefresh extends ProgressEvent {
  final int nodeId;
  final int projectId;
  const DeleteTaskNodeAndRefresh(
      {required this.nodeId, required this.projectId});

  @override
  List<Object?> get props => [nodeId, projectId];
}

abstract class ProgressState extends Equatable {
  const ProgressState();

  @override
  List<Object?> get props => [];
}

class ProgressInitial extends ProgressState {}

class ProgressLoading extends ProgressState {}

class TaskNodesLoaded extends ProgressState {
  final List<TaskNode> nodes;
  final int total;
  final int page;
  final int pageSize;

  const TaskNodesLoaded({
    required this.nodes,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  @override
  List<Object?> get props => [nodes, total, page, pageSize];
}

class ProgressReportsLoaded extends ProgressState {
  final List<ProgressReport> reports;
  final int total;
  final int page;
  final int pageSize;

  const ProgressReportsLoaded({
    required this.reports,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  @override
  List<Object?> get props => [reports, total, page, pageSize];
}

class ProgressSubmitting extends ProgressState {}

class ProgressSubmitSuccess extends ProgressState {
  final String message;
  const ProgressSubmitSuccess({this.message = '提交成功'});

  @override
  List<Object?> get props => [message];
}

class ProgressError extends ProgressState {
  final String message;
  const ProgressError({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthorizedProjectsLoaded extends ProgressState {
  final List<ProjectProgress> projects;

  const AuthorizedProjectsLoaded({required this.projects});

  @override
  List<Object?> get props => [projects];
}

class ProjectSummaryLoaded extends ProgressState {
  final ProjectProgressSummary summary;

  const ProjectSummaryLoaded({required this.summary});

  @override
  List<Object?> get props => [summary];
}

class ProgressBloc extends Bloc<ProgressEvent, ProgressState> {
  final ProgressRepository repository;

  ProgressBloc({required this.repository}) : super(ProgressInitial()) {
    on<LoadTaskNodes>(_onLoadTaskNodes);
    on<CreateTaskNode>(_onCreateTaskNode);
    on<UpdateTaskNode>(_onUpdateTaskNode);
    on<DeleteTaskNode>(_onDeleteTaskNode);
    on<ReviewTaskNode>(_onReviewTaskNode);
    on<LoadProgressReports>(_onLoadProgressReports);
    on<SubmitProgressReport>(_onSubmitProgressReport);
    on<LoadAuthorizedProjects>(_onLoadAuthorizedProjects);
    on<LoadProjectSummary>(_onLoadProjectSummary);
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^DioException \[[^\]]+\]:\s*'), '')
        .trim();
  }

  Future<void> _onLoadTaskNodes(
      LoadTaskNodes event, Emitter<ProgressState> emit) async {
    emit(ProgressLoading());
    try {
      final result = await repository.getNodesByProject(event.projectId);
      emit(TaskNodesLoaded(
        nodes: result['list'],
        total: result['total'],
        page: result['page'],
        pageSize: result['pageSize'],
      ));
    } catch (e) {
      emit(ProgressError(message: '加载任务节点失败: ${_cleanError(e)}'));
    }
  }

  Future<void> _onCreateTaskNode(
      CreateTaskNode event, Emitter<ProgressState> emit) async {
    emit(ProgressLoading());
    try {
      await repository.createNode(event.projectId, event.data);
      add(LoadTaskNodes(projectId: event.projectId));
    } catch (e) {
      emit(ProgressError(message: '创建任务节点失败: ${_cleanError(e)}'));
    }
  }

  Future<void> _onUpdateTaskNode(
      UpdateTaskNode event, Emitter<ProgressState> emit) async {
    try {
      await repository.updateNode(event.nodeId, event.data);
    } catch (e) {
      debugPrint('更新任务节点失败: $e');
    }
  }

  Future<void> _onDeleteTaskNode(
      DeleteTaskNode event, Emitter<ProgressState> emit) async {
    try {
      await repository.deleteNode(event.nodeId);
      add(LoadTaskNodes(projectId: event.projectId));
    } catch (e) {
      emit(ProgressError(message: '删除任务节点失败: ${_cleanError(e)}'));
    }
  }

  Future<void> _onReviewTaskNode(
      ReviewTaskNode event, Emitter<ProgressState> emit) async {
    emit(ProgressSubmitting());
    try {
      await repository.reviewNode(
        event.nodeId,
        action: event.action,
        remark: event.remark,
      );
      emit(ProgressSubmitSuccess(
          message: event.action == 'approve' ? '验收通过' : '已驳回继续施工'));
    } catch (e) {
      emit(ProgressError(message: '验收失败: ${_cleanError(e)}'));
    }
  }

  Future<void> _onLoadProgressReports(
      LoadProgressReports event, Emitter<ProgressState> emit) async {
    emit(ProgressLoading());
    try {
      final result = await repository.getReportsByNode(event.nodeId);
      emit(ProgressReportsLoaded(
        reports: result['list'],
        total: result['total'],
        page: result['page'],
        pageSize: result['pageSize'],
      ));
    } catch (e) {
      emit(ProgressError(message: '加载进度记录失败: ${_cleanError(e)}'));
    }
  }

  Future<void> _onSubmitProgressReport(
      SubmitProgressReport event, Emitter<ProgressState> emit) async {
    emit(ProgressSubmitting());
    try {
      await repository.submitReport(
        event.nodeId,
        description: event.description,
        photo: event.photo,
        progressPercent: event.progressPercent,
        riskNote: event.riskNote,
        blockerNote: event.blockerNote,
        photos: event.photos,
        watermarkCodes: event.watermarkCodes,
      );
      emit(const ProgressSubmitSuccess());
    } catch (e) {
      emit(ProgressError(message: '提交进度失败: ${_cleanError(e)}'));
    }
  }

  Future<void> _onLoadAuthorizedProjects(
      LoadAuthorizedProjects event, Emitter<ProgressState> emit) async {
    emit(ProgressLoading());
    try {
      final projects = await repository.getAuthorizedProjects();
      emit(AuthorizedProjectsLoaded(projects: projects));
    } catch (e) {
      emit(ProgressError(message: _cleanError(e)));
    }
  }

  Future<void> _onLoadProjectSummary(
      LoadProjectSummary event, Emitter<ProgressState> emit) async {
    emit(ProgressLoading());
    try {
      final summary =
          await repository.getProjectProgressSummary(event.projectId);
      emit(ProjectSummaryLoaded(summary: summary));
    } catch (e) {
      emit(ProgressError(message: _cleanError(e)));
    }
  }
}
