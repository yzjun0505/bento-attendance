import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../blocs/progress/progress_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/project_progress_model.dart';
import '../../models/task_node_model.dart';
import '../../widgets/bento_card.dart';
import '../../widgets/bento_loading.dart';
import 'node_detail_screen.dart';
import 'submit_progress_screen.dart';

class ProjectProgressScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ProjectProgressScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectProgressScreen> createState() => _ProjectProgressScreenState();
}

class _ProjectProgressScreenState extends State<ProjectProgressScreen> {
  ProjectProgressSummary? _summary;
  List<TaskNode>? _nodes;
  bool _isLoading = true;
  String? _error;

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
    _loadData();
  }

  void _loadData() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    context
        .read<ProgressBloc>()
        .add(LoadProjectSummary(projectId: widget.projectId));
    context
        .read<ProgressBloc>()
        .add(LoadTaskNodes(projectId: widget.projectId));
  }

  Future<void> _onRefresh() async {
    _loadData();
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
        title: Text(widget.projectName),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: BlocListener<ProgressBloc, ProgressState>(
        listener: (context, state) {
          if (state is ProjectSummaryLoaded) {
            setState(() {
              _summary = state.summary;
              _isLoading = false;
            });
          } else if (state is TaskNodesLoaded) {
            setState(() {
              _nodes = state.nodes;
              _isLoading = false;
            });
          } else if (state is ProgressError) {
            setState(() {
              _error = state.message;
              _isLoading = false;
            });
          }
        },
        child: _buildBody(),
      ),
      floatingActionButton: _canManageProgress
          ? FloatingActionButton(
              onPressed: () async {
                final created = await Navigator.pushNamed(
                  context,
                  '/create_node',
                  arguments: {
                    'projectId': widget.projectId,
                    'projectName': widget.projectName,
                  },
                );
                if (created == true && mounted) {
                  _loadData();
                }
              },
              backgroundColor: colors.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _summary == null && _nodes == null) {
      return const BentoLoading.spinner();
    }

    if (_error != null && _summary == null && _nodes == null) {
      final colors = context.colors;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: colors.error)),
            const SizedBox(height: BentoSpacing.space16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: context.colors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildDashboard(),
          ),
          SliverToBoxAdapter(
            child: _buildPhaseView(),
          ),
          if (_nodes != null && _nodes!.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildNodeList(),
            ),
          if (_summary != null && _summary!.recentReports.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildRecentActivity(),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final colors = context.colors;
    final summary = _summary;

    if (summary == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BentoSpacing.space16,
        BentoSpacing.space16,
        BentoSpacing.space16,
        BentoSpacing.space8,
      ),
      child: BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: BentoSpacing.space8),
                Text(
                  '驾驶舱',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: BentoSpacing.space20),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                          value: summary.overallProgress / 100,
                          strokeWidth: 8,
                          backgroundColor: colors.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors.primary,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${summary.overallProgress}%',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '整体进度',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.textTertiary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BentoSpacing.space20),
                Expanded(
                  child: Wrap(
                    spacing: BentoSpacing.space8,
                    runSpacing: BentoSpacing.space8,
                    children: [
                      _buildStatChip(
                        label: '总数',
                        value: '${summary.totalNodes}',
                        color: colors.textPrimary,
                        bgColor: colors.surfaceVariant,
                      ),
                      _buildStatChip(
                        label: '已完成',
                        value: '${summary.completedNodes}',
                        color: colors.success,
                        bgColor: colors.successLight,
                      ),
                      _buildStatChip(
                        label: '进行中',
                        value: '${summary.inProgressNodes}',
                        color: colors.primary,
                        bgColor: colors.primaryLight,
                      ),
                      _buildStatChip(
                        label: '待验收',
                        value: '${summary.pendingReviewNodes}',
                        color: colors.warning,
                        bgColor: colors.warningLight,
                      ),
                      _buildStatChip(
                        label: '逾期',
                        value: '${summary.overdueNodes}',
                        color: colors.error,
                        bgColor: colors.errorLight,
                      ),
                      _buildStatChip(
                        label: '暂停',
                        value: '${summary.pausedNodes}',
                        color: colors.warning,
                        bgColor: colors.warningLight,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space10,
        vertical: BentoSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(BentoRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.7),
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseView() {
    final colors = context.colors;
    final summary = _summary;

    if (summary == null || summary.phases.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space16,
        vertical: BentoSpacing.space8,
      ),
      child: BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.secondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: BentoSpacing.space8),
                Text(
                  '阶段视图',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: BentoSpacing.space16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: summary.phases.length,
                itemBuilder: (context, index) {
                  final phase = summary.phases[index];
                  return _buildPhaseCard(phase);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseCard(PhaseStat phase) {
    final colors = context.colors;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: BentoSpacing.space12),
      padding: const EdgeInsets.all(BentoSpacing.space12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            phase.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: BentoSpacing.space4),
          Text(
            '${phase.completedCount}/${phase.nodeCount} 节点',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: BentoSpacing.space8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: phase.completionRate / 100,
              backgroundColor: colors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: BentoSpacing.space4),
          Text(
            '${phase.completionRate}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeList() {
    final colors = context.colors;
    final nodes = _nodes;

    if (nodes == null || nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final grouped = <String, List<TaskNode>>{};
    for (final node in nodes) {
      final phase = node.phase ?? 'construction';
      grouped.putIfAbsent(phase, () => []).add(node);
    }

    final phaseOrder = [
      'preparation',
      'construction',
      'inspection',
      'rectification',
      'delivery'
    ];
    final sortedPhases = grouped.keys.toList()
      ..sort((a, b) {
        final indexA = phaseOrder.indexOf(a);
        final indexB = phaseOrder.indexOf(b);
        if (indexA == -1 && indexB == -1) return a.compareTo(b);
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space16,
        vertical: BentoSpacing.space8,
      ),
      child: BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.success,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: BentoSpacing.space8),
                Text(
                  '任务节点',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: BentoSpacing.space16),
            for (final phase in sortedPhases) ...[
              _buildSectionHeader(phase, grouped[phase]!.length),
              const SizedBox(height: BentoSpacing.space8),
              for (final node in grouped[phase]!) _buildNodeCard(node),
              const SizedBox(height: BentoSpacing.space8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String phase, int count) {
    final colors = context.colors;

    String phaseLabel;
    switch (phase) {
      case 'preparation':
        phaseLabel = '准备阶段';
        break;
      case 'construction':
        phaseLabel = '施工阶段';
        break;
      case 'inspection':
        phaseLabel = '验收阶段';
        break;
      case 'rectification':
        phaseLabel = '整改阶段';
        break;
      case 'delivery':
        phaseLabel = '交付阶段';
        break;
      default:
        phaseLabel = phase;
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: BentoSpacing.space8),
        Text(
          phaseLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: BentoSpacing.space8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BentoSpacing.space8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: colors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildNodeCard(TaskNode node) {
    final colors = context.colors;
    final isOverdue = node.isOverdue;

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space8),
      child: BentoCard.filled(
        onTap: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<ProgressBloc>(),
                child: NodeDetailScreen(node: node),
              ),
            ),
          );
          if (changed == true && mounted) _loadData();
        },
        customBgColor: colors.surfaceVariant,
        padding: const EdgeInsets.all(BentoSpacing.space12),
        borderRadius: BentoRadius.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    node.title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                  ),
                ),
                const SizedBox(width: BentoSpacing.space8),
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BentoSpacing.space4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.errorLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 12, color: colors.error),
                        const SizedBox(width: 2),
                        Text(
                          '逾期',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: BentoSpacing.space4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BentoSpacing.space8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBgColor(node.status, colors),
                    borderRadius: BorderRadius.circular(4),
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
            const SizedBox(height: BentoSpacing.space10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: node.progressPercent / 100,
                      backgroundColor: colors.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _statusColor(node.status, colors),
                      ),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: BentoSpacing.space8),
                Text(
                  '${node.progressPercent}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    size: 12, color: colors.textTertiary),
                const SizedBox(width: 3),
                Text(
                  node.assigneeName ?? '未指派',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                ),
                if (node.plannedDate != null) ...[
                  const SizedBox(width: BentoSpacing.space10),
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: colors.textTertiary),
                  const SizedBox(width: 3),
                  Text(
                    node.plannedDate!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: BentoSpacing.space8),
            Row(
              children: [
                if (!_canManageProgress && !_isClient)
                  _buildMiniAction(
                    colors,
                    label: '上报',
                    icon: Icons.upload,
                    color: colors.primary,
                    onTap: () => _openSubmit(node),
                  )
                else ...[
                  _buildMiniAction(
                    colors,
                    label: '详情',
                    icon: Icons.info_outline,
                    color: colors.primary,
                    onTap: () async {
                      final changed = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ProgressBloc>(),
                            child: NodeDetailScreen(node: node),
                          ),
                        ),
                      );
                      if (changed == true && mounted) _loadData();
                    },
                  ),
                  if (_canManageProgress &&
                      node.status == 'pending_review') ...[
                    const SizedBox(width: 8),
                    _buildMiniAction(
                      colors,
                      label: '验收',
                      icon: Icons.verified_outlined,
                      color: colors.success,
                      onTap: () => _reviewNode(node, 'approve'),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAction(
    BentoColors colors, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BentoRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(BentoRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmit(TaskNode node) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ProgressBloc>(),
          child: SubmitProgressScreen(node: node),
        ),
      ),
    );
    if (result == true && mounted) _loadData();
  }

  void _reviewNode(TaskNode node, String action) {
    context
        .read<ProgressBloc>()
        .add(ReviewTaskNode(nodeId: node.id, action: action));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _loadData();
    });
  }

  Widget _buildRecentActivity() {
    final colors = context.colors;
    final summary = _summary;

    if (summary == null || summary.recentReports.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space16,
        vertical: BentoSpacing.space8,
      ),
      child: BentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.warning,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: BentoSpacing.space8),
                Text(
                  '最近动态',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: BentoSpacing.space16),
            for (int i = 0; i < summary.recentReports.length; i++)
              _buildActivityItem(summary.recentReports[i], i == 0),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(RecentReport report, bool isFirst) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: isFirst ? colors.primary : colors.border,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BentoSpacing.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      report.reporterName ?? '未知用户',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: BentoSpacing.space4),
                    Text(
                      '上报了',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(width: BentoSpacing.space4),
                    Flexible(
                      child: Text(
                        report.nodeTitle ?? '任务',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BentoSpacing.space4),
                Row(
                  children: [
                    Text(
                      '进度 ${report.progressPercent}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(width: BentoSpacing.space8),
                    Text(
                      report.createdAt,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
