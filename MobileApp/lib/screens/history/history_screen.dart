import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/attendance/attendance_bloc.dart';
import '../../blocs/attendance/attendance_state.dart';
import '../../blocs/attendance/attendance_event.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/home/home_bloc.dart';
import '../../blocs/home/home_bloc_base.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../models/checkin_model.dart';
import '../track/track_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏
            _buildAppBar(context, colors, theme),
            // 内容区
            Expanded(
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  // 访客模式：显示登录引导
                  if (authState is! AuthAuthenticated) {
                    return BentoEmptyState(
                      icon: Icons.lock_outline,
                      title: '需要登录',
                      description: '登录后即可查看打卡明细',
                      actionText: '立即登录',
                      onAction: () {
                        // TODO: 触发登录流程
                      },
                    );
                  }
                  // 已登录：显示明细列表
                  return _buildHistoryList(context, colors, theme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶栏
  Widget _buildAppBar(BuildContext context, BentoColors colors, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        BentoSpacing.space20,
        BentoSpacing.space16,
        BentoSpacing.space20,
        BentoSpacing.space12,
      ),
      child: Row(
        children: [
          Text(
            '打卡明细',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const Spacer(),
          // 日期筛选
          GestureDetector(
            onTap: () => _showDatePicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(BentoRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: colors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '筛选',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: BentoSpacing.space8),
          // 搜索
          GestureDetector(
            onTap: () {
              // TODO: 搜索功能
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(BentoRadius.sm),
              ),
              child: Icon(Icons.search, size: 20, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// 明细列表
  Widget _buildHistoryList(BuildContext context, BentoColors colors, ThemeData theme) {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        if (state is AttendanceLoading || state is AttendanceInitial) {
          return const BentoLoading.spinner();
        }
        if (state is AttendanceError) {
          return BentoEmptyState(
            icon: Icons.error_outline,
            title: '加载失败',
            description: state.message,
            actionText: '重试',
            onAction: () => context.read<AttendanceBloc>().add(LoadAttendanceData()),
          );
        }
        if (state is AttendanceLoaded) {
          final history = state.recentHistory;
          return RefreshIndicator(
            color: colors.primary,
            onRefresh: () async {
              context.read<AttendanceBloc>().add(LoadAttendanceData());
              context.read<HomeBloc>().add(const LoadHomeSummary(silent: true));
            },
            child: CustomScrollView(
              slivers: [
                // 今日动态区域
                SliverToBoxAdapter(
                  child: _buildTodayTimeline(context, colors, theme),
                ),
                // 历史记录标题
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      BentoSpacing.space20,
                      BentoSpacing.space16,
                      BentoSpacing.space20,
                      BentoSpacing.space8,
                    ),
                    child: Text(
                      '历史记录',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // 历史记录列表
                history.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: BentoSpacing.space32),
                          child: const BentoEmptyState(
                            icon: Icons.history,
                            title: '暂无历史记录',
                            description: '还没有打卡记录',
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = history[index];
                              return _buildHistoryItem(context, item, colors, theme);
                            },
                            childCount: history.length,
                          ),
                        ),
                      ),
                // 底部间距
                const SliverToBoxAdapter(
                  child: SizedBox(height: BentoSpacing.space24),
                ),
              ],
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  /// 今日动态区域
  Widget _buildTodayTimeline(BuildContext context, BentoColors colors, ThemeData theme) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        if (state is! HomeSummaryLoaded) {
          return const SizedBox();
        }

        final timelineItems = state.timelineItems;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
          padding: const EdgeInsets.all(BentoSpacing.space16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(BentoRadius.lg),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: BentoSpacing.space8),
                  Text(
                    '今日动态',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.read<HomeBloc>().add(const LoadHomeSummary(silent: true)),
                    child: Icon(Icons.refresh, size: 20, color: colors.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: BentoSpacing.space12),
              // 动态列表
              if (timelineItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: BentoSpacing.space16),
                  child: Center(
                    child: Text(
                      '今天还没有打卡记录',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                )
              else
                ...timelineItems.map((item) => _buildTimelineItem(item, colors, theme)),
            ],
          ),
        );
      },
    );
  }

  /// 时间线项
  Widget _buildTimelineItem(TimelineItem item, BentoColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space8),
      child: Row(
        children: [
          // 时间
          SizedBox(
            width: 48,
            child: Text(
              item.time,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: BentoSpacing.space8),
          // 图标
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: BentoSpacing.space12),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 明细列表项
  Widget _buildHistoryItem(BuildContext context, Checkin item, BentoColors colors, ThemeData theme) {
    final type = item.type ?? '';
    final isOutside = item.isOutside == true;

    // 获取类型信息
    final IconData typeIcon;
    final Color typeColor;
    final String typeName;

    switch (type) {
      case 'in':
      case 'clock_in':
        typeIcon = Icons.login;
        typeColor = colors.primary;
        typeName = '上班打卡';
        break;
      case 'out':
      case 'clock_out':
        typeIcon = Icons.logout;
        typeColor = colors.success;
        typeName = '下班打卡';
        break;
      case 'site_visit':
        typeIcon = Icons.explore;
        typeColor = const Color(0xFF3B82F6);
        typeName = '实地考察';
        break;
      case 'progress':
        typeIcon = Icons.trending_up;
        typeColor = const Color(0xFFF59E0B);
        typeName = '项目进度上报';
        break;
      case 'safety':
        typeIcon = Icons.security;
        typeColor = const Color(0xFFEF4444);
        typeName = '安全检查';
        break;
      case 'device':
        typeIcon = Icons.devices;
        typeColor = const Color(0xFF8B5CF6);
        typeName = '设备位置上报';
        break;
      default:
        typeIcon = Icons.label_outline;
        typeColor = colors.textTertiary;
        typeName = type.isNotEmpty ? type : '打卡';
    }

    final iconColor = isOutside ? colors.warning : typeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space8),
      child: BentoCard(
        padding: const EdgeInsets.all(BentoSpacing.space12),
        child: Row(
          children: [
            // 类型图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(BentoRadius.sm),
              ),
              child: Icon(
                typeIcon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: BentoSpacing.space12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        typeName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.formattedTime ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isOutside ? Icons.warning_amber : Icons.location_on,
                        size: 12,
                        color: iconColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isOutside
                              ? '距围栏中心 ${item.distanceToFence ?? '-'}m · 异常'
                              : (item.projectName ?? typeName),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isOutside ? colors.warning : colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: BentoSpacing.space4),
            // 围栏外标记
            if (isOutside)
              const BentoBadge.warning(text: '围栏外'),
            // 查看轨迹按钮
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                final date = item.createdAt.toIso8601String().split('T')[0];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrackScreen(initialDate: date),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.route, size: 16, color: colors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 日期选择器
  void _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      // TODO: 按日期筛选
    }
  }
}
