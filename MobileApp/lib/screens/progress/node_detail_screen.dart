import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../blocs/progress/progress_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/task_node_model.dart';
import '../../models/progress_report_model.dart';
import '../../widgets/bento_card.dart';
import '../../widgets/bento_empty_state.dart';
import '../../widgets/bento_loading.dart';
import '../../api/dio_client.dart';
import 'submit_progress_screen.dart';

class NodeDetailScreen extends StatefulWidget {
  final TaskNode node;

  const NodeDetailScreen({super.key, required this.node});

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  bool get _canManageProgress {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return false;
    return authState.user.role == 'admin' || authState.user.role == 'manager';
  }

  bool get _isClient {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated && authState.user.role == 'client';
  }

  @override
  void initState() {
    super.initState();
    context
        .read<ProgressBloc>()
        .add(LoadProgressReports(nodeId: widget.node.id));
  }

  Color _statusColor(String status, BentoColors colors) {
    switch (status) {
      case 'pending':
        return colors.textTertiary;
      case 'in_progress':
        return colors.primary;
      case 'pending_review':
        return colors.warning;
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
      case 'pending_review':
        return colors.warningLight;
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
        title: Text(widget.node.title,
            style: TextStyle(color: colors.textPrimary)),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: _isClient
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProgressBloc>(),
                      child: SubmitProgressScreen(node: widget.node),
                    ),
                  ),
                );
                if (!context.mounted) return;
                if (result == true) {
                  context
                      .read<ProgressBloc>()
                      .add(LoadProgressReports(nodeId: widget.node.id));
                }
              },
              icon: const Icon(Icons.upload),
              label: const Text('上报进度'),
            ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNodeInfo(colors),
            _buildActions(colors),
            const SizedBox(height: 4),
            _buildProgressHeader(colors),
            BlocBuilder<ProgressBloc, ProgressState>(
              builder: (context, state) {
                if (state is ProgressLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: BentoLoading.spinner(),
                  );
                }

                if (state is ProgressReportsLoaded) {
                  if (state.reports.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: BentoEmptyState(
                        icon: Icons.history,
                        title: '暂无进度记录',
                        description: '尚未提交任何进度',
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(BentoSpacing.space16),
                    itemCount: state.reports.length,
                    itemBuilder: (context, index) {
                      return _buildReportItem(
                          context, state.reports[index], colors);
                    },
                  );
                }

                if (state is ProgressError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(state.message,
                        style: TextStyle(color: colors.error)),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeInfo(BentoColors colors) {
    final node = widget.node;

    return BentoCard(
      margin: const EdgeInsets.all(BentoSpacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              const Spacer(),
              Text(
                '${node.progressPercent}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _statusColor(node.status, colors),
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: BentoSpacing.space12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: node.progressPercent / 100,
              backgroundColor: colors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                _statusColor(node.status, colors),
              ),
              minHeight: 8,
            ),
          ),
          if (node.description != null && node.description!.isNotEmpty) ...[
            const SizedBox(height: BentoSpacing.space12),
            Text(
              node.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ],
          const SizedBox(height: BentoSpacing.space12),
          Row(
            children: [
              _buildTag(
                node.phaseText,
                colors.primary,
                colors.primaryLight,
                Icons.layers,
              ),
              const SizedBox(width: 8),
              _buildTag(
                node.priorityText,
                node.priorityColor,
                node.priorityColor.withValues(alpha: 0.12),
                Icons.flag,
              ),
            ],
          ),
          const SizedBox(height: BentoSpacing.space12),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: colors.textTertiary),
              const SizedBox(width: 4),
              Text(
                node.assigneeName ?? '未指派',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today, size: 16, color: colors.textTertiary),
              const SizedBox(width: 4),
              Text(
                _buildDateRange(node),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
              ),
              if (node.isOverdue) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.errorLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '⚠ 已逾期',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space8,
        vertical: BentoSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(BentoRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  String _buildDateRange(TaskNode node) {
    if (node.planStartDate != null && node.planEndDate != null) {
      return '${node.planStartDate} ~ ${node.planEndDate}';
    }
    return node.plannedDate ?? '';
  }

  Widget _buildActions(BentoColors colors) {
    final node = widget.node;
    if (!_canManageProgress) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space16,
        vertical: BentoSpacing.space4,
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildActionButton(
            icon: Icons.edit_outlined,
            label: '编辑',
            color: colors.primary,
            bgColor: colors.primaryLight,
            onTap: () => _showEditDialog(colors),
          )),
          const SizedBox(width: BentoSpacing.space8),
          Expanded(
              child: _buildActionButton(
            icon: node.status == 'paused' ? Icons.play_arrow : Icons.pause,
            label: node.status == 'paused' ? '恢复' : '暂停',
            color: colors.warning,
            bgColor: colors.warningLight,
            onTap: () => _togglePauseResume(),
          )),
          const SizedBox(width: BentoSpacing.space8),
          Expanded(
              child: _buildActionButton(
            icon: node.status == 'pending_review'
                ? Icons.verified_outlined
                : Icons.check_circle_outline,
            label: node.status == 'pending_review' ? '验收' : '完成',
            color: colors.success,
            bgColor: colors.successLight,
            onTap: () => node.status == 'pending_review'
                ? _reviewNode('approve')
                : _markComplete(),
          )),
          if (node.status == 'pending_review') ...[
            const SizedBox(width: BentoSpacing.space8),
            Expanded(
                child: _buildActionButton(
              icon: Icons.undo,
              label: '驳回',
              color: colors.error,
              bgColor: colors.errorLight,
              onTap: () => _reviewNode('reject'),
            )),
          ],
          const SizedBox(width: BentoSpacing.space8),
          Expanded(
              child: _buildActionButton(
            icon: Icons.delete_outline,
            label: '删除',
            color: colors.error,
            bgColor: colors.errorLight,
            onTap: () => _confirmDelete(colors),
          )),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: BentoSpacing.space10,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(BentoRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BentoColors colors) {
    final titleCtrl = TextEditingController(text: widget.node.title);
    final descCtrl = TextEditingController(text: widget.node.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('编辑节点', style: TextStyle(color: colors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: '标题',
                  labelStyle: TextStyle(color: colors.textTertiary),
                ),
                style: TextStyle(color: colors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '描述',
                  labelStyle: TextStyle(color: colors.textTertiary),
                ),
                style: TextStyle(color: colors.textPrimary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                context.read<ProgressBloc>().add(UpdateTaskNode(
                      nodeId: widget.node.id,
                      data: {
                        'title': title,
                        'description': descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                      },
                    ));
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: Text('保存', style: TextStyle(color: colors.primary)),
            ),
          ],
        );
      },
    );
  }

  void _togglePauseResume() {
    final newNodeStatus =
        widget.node.status == 'paused' ? 'in_progress' : 'paused';
    context.read<ProgressBloc>().add(UpdateTaskNode(
          nodeId: widget.node.id,
          data: {'status': newNodeStatus},
        ));
    Navigator.pop(context, true);
  }

  void _markComplete() {
    context.read<ProgressBloc>().add(UpdateTaskNode(
          nodeId: widget.node.id,
          data: const {
            'status': 'completed',
            'progress_percent': 100,
          },
        ));
    Navigator.pop(context, true);
  }

  void _reviewNode(String action) {
    context.read<ProgressBloc>().add(ReviewTaskNode(
          nodeId: widget.node.id,
          action: action,
        ));
    Navigator.pop(context, true);
  }

  void _confirmDelete(BentoColors colors) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('确认删除', style: TextStyle(color: colors.textPrimary)),
          content: Text(
            '确定要删除「${widget.node.title}」吗？此操作不可撤销。',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                context.read<ProgressBloc>().add(DeleteTaskNode(
                      nodeId: widget.node.id,
                      projectId: widget.node.projectId,
                    ));
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text('删除', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressHeader(BentoColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space16,
        vertical: BentoSpacing.space8,
      ),
      child: Text(
        '进度记录',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildReportItem(
      BuildContext context, ProgressReport report, BentoColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space12),
      child: BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colors.primaryLight,
                  child: Text(
                    (report.reporterName ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.reporterName ?? '未知用户',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        _formatTime(report.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BentoSpacing.space8,
                    vertical: BentoSpacing.space4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryLight,
                    borderRadius: BorderRadius.circular(BentoRadius.sm),
                  ),
                  child: Text(
                    '${report.progressPercent}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            if (report.description != null &&
                report.description!.isNotEmpty) ...[
              const SizedBox(height: BentoSpacing.space8),
              Text(
                report.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
            ],
            if (report.riskNote != null && report.riskNote!.isNotEmpty) ...[
              const SizedBox(height: BentoSpacing.space8),
              Container(
                padding: const EdgeInsets.all(BentoSpacing.space10),
                decoration: BoxDecoration(
                  color: colors.warningLight,
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                  border: Border.all(
                    color: colors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: colors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        report.riskNote!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.warning,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (report.blockerNote != null &&
                report.blockerNote!.isNotEmpty) ...[
              const SizedBox(height: BentoSpacing.space8),
              Container(
                padding: const EdgeInsets.all(BentoSpacing.space10),
                decoration: BoxDecoration(
                  color: colors.errorLight,
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.block, size: 16, color: colors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        report.blockerNote!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.error,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (report.photos != null && report.photos!.isNotEmpty) ...[
              const SizedBox(height: BentoSpacing.space8),
              _buildPhotoGrid(report.photos!, colors),
            ] else if (report.photo != null && report.photo!.isNotEmpty) ...[
              const SizedBox(height: BentoSpacing.space8),
              _buildSinglePhoto(report.photo!, colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePhoto(String photo, BentoColors colors) {
    return GestureDetector(
      onTap: () => _showFullScreenPhoto(photo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        child: Image.network(
          ApiClient.resolveFileUrl(photo),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 160,
              color: colors.surfaceVariant,
              child: Center(
                child: Icon(Icons.broken_image, color: colors.textTertiary),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> photos, BentoColors colors) {
    final crossAxisCount =
        photos.length == 1 ? 1 : (photos.length == 2 ? 2 : 3);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showFullScreenPhoto(photos[index]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BentoRadius.sm),
            child: Image.network(
              ApiClient.resolveFileUrl(photos[index]),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: colors.surfaceVariant,
                  child: Center(
                    child: Icon(Icons.broken_image,
                        size: 20, color: colors.textTertiary),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenPhoto(String photo) {
    showDialog(
      context: context,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: InteractiveViewer(
              child: Image.network(
                ApiClient.resolveFileUrl(photo),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child:
                        Icon(Icons.broken_image, color: Colors.white, size: 48),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timeStr;
    }
  }
}
