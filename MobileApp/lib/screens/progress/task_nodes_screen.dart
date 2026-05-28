import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../blocs/progress/progress_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/task_node_model.dart';
import '../../widgets/bento_card.dart';
import '../../widgets/bento_empty_state.dart';
import '../../widgets/bento_loading.dart';
import 'node_detail_screen.dart';
import 'submit_progress_screen.dart';

class TaskNodesScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const TaskNodesScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<TaskNodesScreen> createState() => _TaskNodesScreenState();
}

class _TaskNodesScreenState extends State<TaskNodesScreen> {
  bool get _isClient {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated && authState.user.role == 'client';
  }

  @override
  void initState() {
    super.initState();
    context
        .read<ProgressBloc>()
        .add(LoadTaskNodes(projectId: widget.projectId));
  }

  Color _statusColor(String status, BentoColors colors) {
    switch (status) {
      case 'pending':
        return colors.textTertiary;
      case 'in_progress':
        return colors.primary;
      case 'completed':
        return colors.success;
      case 'paused':
        return colors.warning;
      default:
        return colors.textTertiary;
    }
  }

  Color _statusBgColor(String status, BentoColors colors) {
    switch (status) {
      case 'pending':
        return colors.surfaceVariant;
      case 'in_progress':
        return colors.primaryLight;
      case 'completed':
        return colors.successLight;
      case 'paused':
        return colors.warningLight;
      default:
        return colors.surfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(widget.projectName),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: BlocBuilder<ProgressBloc, ProgressState>(
        builder: (context, state) {
          if (state is ProgressLoading) {
            return const BentoLoading.spinner();
          }

          if (state is TaskNodesLoaded) {
            if (state.nodes.isEmpty) {
              return const BentoEmptyState(
                icon: Icons.assignment_outlined,
                title: '暂无任务节点',
                description: '点击右下角按钮添加任务',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<ProgressBloc>()
                    .add(LoadTaskNodes(projectId: widget.projectId));
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(BentoSpacing.space16),
                itemCount: state.nodes.length,
                itemBuilder: (context, index) {
                  final node = state.nodes[index];
                  return _buildNodeCard(context, node, colors);
                },
              ),
            );
          }

          if (state is ProgressError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message, style: TextStyle(color: colors.error)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<ProgressBloc>()
                        .add(LoadTaskNodes(projectId: widget.projectId)),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: _isClient
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateDialog(context, colors),
              backgroundColor: colors.primary,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildNodeCard(
      BuildContext context, TaskNode node, BentoColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space12),
      child: BentoCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<ProgressBloc>(),
                child: NodeDetailScreen(node: node),
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colors.textPrimary,
                                ),
                      ),
                      if (node.description != null &&
                          node.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          node.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BentoSpacing.space10,
                    vertical: BentoSpacing.space4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBgColor(node.status, colors),
                    borderRadius: BorderRadius.circular(BentoRadius.sm),
                  ),
                  child: Text(
                    node.statusText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _statusColor(node.status, colors),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BentoSpacing.space12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: node.progressPercent / 100,
                      backgroundColor: colors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _statusColor(node.status, colors),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: BentoSpacing.space8),
                Text(
                  '${node.progressPercent}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _statusColor(node.status, colors),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: BentoSpacing.space8),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: colors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  node.assigneeName ?? '未指派',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                ),
                if (node.plannedDate != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today,
                      size: 14, color: colors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    node.plannedDate!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                  ),
                ],
                const Spacer(),
                if (!_isClient)
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ProgressBloc>(),
                            child: SubmitProgressScreen(node: node),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BentoSpacing.space10,
                        vertical: BentoSpacing.space4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryLight,
                        borderRadius: BorderRadius.circular(BentoRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upload, size: 14, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '上报',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, BentoColors colors) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('添加任务节点', style: TextStyle(color: colors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: '任务标题',
                  labelStyle: TextStyle(color: colors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
                style: TextStyle(color: colors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: '描述（可选）',
                  labelStyle: TextStyle(color: colors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
                style: TextStyle(color: colors.textPrimary),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(dialogContext);
                context.read<ProgressBloc>().add(CreateTaskNode(
                      projectId: widget.projectId,
                      data: {
                        'title': title,
                        'description': descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                      },
                    ));
              },
              child: Text('创建', style: TextStyle(color: colors.primary)),
            ),
          ],
        );
      },
    );
  }
}
