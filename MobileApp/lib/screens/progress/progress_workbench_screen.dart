import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/progress/progress_bloc.dart';
import '../../models/project_progress_model.dart';
import '../../widgets/bento_card.dart';
import '../../widgets/bento_empty_state.dart';
import '../../widgets/bento_loading.dart';
import 'project_progress_screen.dart';

class ProgressWorkbenchScreen extends StatefulWidget {
  const ProgressWorkbenchScreen({super.key});

  @override
  State<ProgressWorkbenchScreen> createState() =>
      _ProgressWorkbenchScreenState();
}

class _ProgressWorkbenchScreenState extends State<ProgressWorkbenchScreen> {
  bool get _isClient {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated && authState.user.role == 'client';
  }

  @override
  void initState() {
    super.initState();
    context.read<ProgressBloc>().add(const LoadAuthorizedProjects());
  }

  String _statusLabel(ProjectProgress project) {
    if (project.overallProgress >= 100) return '已完成';
    if (project.pendingReviewNodes > 0) return '待验收';
    if (project.inProgressNodes > 0) return '进行中';
    if (project.completedNodes >= project.totalNodes &&
        project.totalNodes > 0) {
      return '已完成';
    }
    return '待开始';
  }

  Color _statusColor(String status, BentoColors colors) {
    switch (status) {
      case '进行中':
        return colors.primary;
      case '待验收':
        return colors.warning;
      case '已完成':
        return colors.success;
      case '待开始':
        return colors.textTertiary;
      default:
        return colors.textTertiary;
    }
  }

  Color _statusBgColor(String status, BentoColors colors) {
    switch (status) {
      case '进行中':
        return colors.primaryLight;
      case '待验收':
        return colors.warningLight;
      case '已完成':
        return colors.successLight;
      case '待开始':
        return colors.surfaceVariant;
      default:
        return colors.surfaceVariant;
    }
  }

  String _formatReportTime(String? time) {
    if (time == null || time.isEmpty) return '暂无上报';
    return time;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('项目进度'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<ProgressBloc, ProgressState>(
        builder: (context, state) {
          if (state is ProgressLoading) {
            return const BentoLoading.spinner();
          }

          if (state is AuthorizedProjectsLoaded) {
            if (state.projects.isEmpty) {
              return BentoEmptyState(
                icon: Icons.folder_open_outlined,
                title: _isClient ? '暂无可查看项目' : '暂无可管理项目',
                description: '请联系管理员分配项目',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<ProgressBloc>()
                    .add(const LoadAuthorizedProjects());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(BentoSpacing.space16),
                itemCount: state.projects.length,
                itemBuilder: (context, index) {
                  final project = state.projects[index];
                  return _buildProjectCard(context, project, colors);
                },
              ),
            );
          }

          if (state is ProgressError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colors.error),
                  const SizedBox(height: BentoSpacing.space16),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.error,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: BentoSpacing.space16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<ProgressBloc>()
                        .add(const LoadAuthorizedProjects()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.textOnPrimary,
                    ),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildProjectCard(
      BuildContext context, ProjectProgress project, BentoColors colors) {
    final status = _statusLabel(project);
    final progressBloc = context.read<ProgressBloc>();

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space12),
      child: BentoCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: progressBloc,
                child: ProjectProgressScreen(
                  projectId: project.id,
                  projectName: project.name,
                ),
              ),
            ),
          ).then((_) {
            // 返回时重新加载项目列表，避免子页面的事件覆盖了项目列表状态
            if (mounted) {
              progressBloc.add(const LoadAuthorizedProjects());
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                  ),
                ),
                const SizedBox(width: BentoSpacing.space8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BentoSpacing.space10,
                    vertical: BentoSpacing.space4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBgColor(status, colors),
                    borderRadius: BorderRadius.circular(BentoRadius.sm),
                  ),
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _statusColor(status, colors),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BentoSpacing.space16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: project.overallProgress / 100,
                      backgroundColor: colors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        project.overallProgress >= 100
                            ? colors.success
                            : colors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: BentoSpacing.space8),
                Text(
                  '${project.overallProgress}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: project.overallProgress >= 100
                            ? colors.success
                            : colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: BentoSpacing.space12),
            Wrap(
              spacing: BentoSpacing.space8,
              runSpacing: BentoSpacing.space8,
              children: [
                _buildStatChip(
                  context,
                  colors,
                  '进行中 ${project.inProgressNodes}',
                  colors.primary,
                  colors.primaryLight,
                ),
                _buildStatChip(
                  context,
                  colors,
                  '已完成 ${project.completedNodes}',
                  colors.success,
                  colors.successLight,
                ),
                _buildStatChip(
                  context,
                  colors,
                  '待验收 ${project.pendingReviewNodes}',
                  colors.warning,
                  colors.warningLight,
                ),
                _buildStatChip(
                  context,
                  colors,
                  '逾期 ${project.overdueNodes}',
                  colors.error,
                  colors.errorLight,
                ),
              ],
            ),
            const SizedBox(height: BentoSpacing.space12),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: colors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '最近上报: ${_formatReportTime(project.lastReportTime)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                ),
                const Spacer(),
                Icon(Icons.people_outline,
                    size: 14, color: colors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${project.assigneeCount}人',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    BentoColors colors,
    String label,
    Color textColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space10,
        vertical: BentoSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(BentoRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
