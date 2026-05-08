import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/attendance/attendance_bloc.dart';
import '../../blocs/attendance/attendance_state.dart';
import '../../blocs/attendance/attendance_event.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/home/home_bloc.dart';
import '../../blocs/home/home_bloc_base.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../models/checkin_model.dart';
import '../track/track_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _dateLabel {
    final d = _selectedDate;
    if (d == null) return '筛选';
    return DateFormat('MM月dd日').format(d);
  }

  bool get _hasActiveFilter => _query.isNotEmpty || _selectedDate != null;

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
                        context.read<AuthBloc>().add(LoggedOut());
                      },
                    );
                  }
                  // 已登录：显示明细列表
                  return Column(
                    children: [
                      if (_hasActiveFilter)
                        _buildFilterSummary(context, colors, theme),
                      Expanded(
                          child: _buildHistoryList(context, colors, theme)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶栏
  Widget _buildAppBar(
      BuildContext context, BentoColors colors, ThemeData theme) {
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
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: colors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _dateLabel,
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
            onTap: () => _showSearchSheet(context),
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
  Widget _buildHistoryList(
      BuildContext context, BentoColors colors, ThemeData theme) {
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
            onAction: () =>
                context.read<AttendanceBloc>().add(LoadAttendanceData()),
          );
        }
        if (state is AttendanceLoaded) {
          final history = _filterHistory(state.recentHistory);
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
                          padding: const EdgeInsets.symmetric(
                              vertical: BentoSpacing.space32),
                          child: BentoEmptyState(
                            icon: Icons.history,
                            title: _hasActiveFilter ? '没有匹配记录' : '暂无历史记录',
                            description:
                                _hasActiveFilter ? '换个关键词或日期再试试' : '还没有打卡记录',
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: BentoSpacing.space20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = history[index];
                              return _buildHistoryItem(
                                  context, item, colors, theme);
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

  Widget _buildFilterSummary(
      BuildContext context, BentoColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          BentoSpacing.space20, 0, BentoSpacing.space20, BentoSpacing.space8),
      child: Row(
        children: [
          if (_selectedDate != null)
            _buildFilterChip(
              icon: Icons.calendar_today_outlined,
              label: DateFormat('yyyy-MM-dd').format(_selectedDate!),
              colors: colors,
              onDeleted: () => setState(() => _selectedDate = null),
            ),
          if (_query.isNotEmpty) ...[
            if (_selectedDate != null) const SizedBox(width: 8),
            Expanded(
              child: _buildFilterChip(
                icon: Icons.search,
                label: _query,
                colors: colors,
                onDeleted: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
            ),
          ],
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _query = '';
                _selectedDate = null;
              });
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required BentoColors colors,
    required VoidCallback onDeleted,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 14, color: colors.textTertiary),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            onPressed: onDeleted,
          ),
        ],
      ),
    );
  }

  List<Checkin> _filterHistory(List<Checkin> history) {
    return history.where((item) {
      final selected = _selectedDate;
      if (selected != null) {
        final created = item.createdAt;
        if (created.year != selected.year ||
            created.month != selected.month ||
            created.day != selected.day) {
          return false;
        }
      }

      if (_query.isEmpty) return true;
      final haystack = [
        item.type,
        item.typeName,
        item.address,
        item.remark,
        item.projectName ?? '',
        item.watermarkCode ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList();
  }

  Future<void> _showSearchSheet(BuildContext context) async {
    final colors = context.colors;
    _searchController.text = _query;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: BentoSpacing.space20,
            right: BentoSpacing.space20,
            top: BentoSpacing.space20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                BentoSpacing.space20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                            Navigator.pop(sheetContext);
                          },
                        ),
                  hintText: '搜索类型、项目、地点、备注或防伪码',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BentoRadius.sm)),
                ),
                onSubmitted: (value) {
                  setState(() => _query = value.trim());
                  Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: BentoSpacing.space16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _query = _searchController.text.trim());
                  Navigator.pop(sheetContext);
                },
                child: const Text('搜索'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 今日动态区域
  Widget _buildTodayTimeline(
      BuildContext context, BentoColors colors, ThemeData theme) {
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
                    onTap: () => context
                        .read<HomeBloc>()
                        .add(const LoadHomeSummary(silent: true)),
                    child: Icon(Icons.refresh,
                        size: 20, color: colors.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: BentoSpacing.space12),
              // 动态列表
              if (timelineItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: BentoSpacing.space16),
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
                ...timelineItems
                    .map((item) => _buildTimelineItem(item, colors, theme)),
            ],
          ),
        );
      },
    );
  }

  /// 时间线项
  Widget _buildTimelineItem(
      TimelineItem item, BentoColors colors, ThemeData theme) {
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
  Widget _buildHistoryItem(
      BuildContext context, Checkin item, BentoColors colors, ThemeData theme) {
    final type = item.type;
    final isOutside = item.isOutside;

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
                        item.formattedTime,
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
                            color: isOutside
                                ? colors.warning
                                : colors.textSecondary,
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
            if (isOutside) const BentoBadge.warning(text: '围栏外'),
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
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() => _selectedDate = picked);
    }
  }
}
