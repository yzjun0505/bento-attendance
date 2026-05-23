import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/home/home_bloc.dart';
import '../../blocs/home/home_bloc_base.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';

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
                        child: _buildContent(context, colors, theme, authState),
                      ),
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

  Widget _buildContent(BuildContext context, BentoColors colors,
      ThemeData theme, AuthAuthenticated authState) {
    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () async {
        context.read<HomeBloc>().add(const LoadHomeSummary(silent: true));
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildTodayTimeline(context, colors, theme),
          ),
          SliverToBoxAdapter(
            child: _buildFeatureGrid(context, colors, theme, authState),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: BentoSpacing.space24),
          ),
        ],
      ),
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
        const maxVisible = 2;
        final visibleItems = timelineItems.length > maxVisible
            ? timelineItems.sublist(0, maxVisible)
            : timelineItems;

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
              // 动态列表（最多显示2条）
              if (visibleItems.isEmpty)
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
              else ...[
                ...visibleItems
                    .map((item) => GestureDetector(
                          onTap: () => _openTimelineDetail(context, item),
                          child:
                              _buildTimelineItem(item, colors, theme),
                        )),
                // 查看全部按钮
                if (timelineItems.length > maxVisible)
                  GestureDetector(
                    onTap: () => _openAllTimeline(context, timelineItems, colors, theme),
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '查看全部 ${timelineItems.length} 条动态',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openTimelineDetail(BuildContext context, TimelineItem item) {
    if (item.sourceType == 'checkin' && item.sourceId != null) {
      Navigator.pushNamed(context, '/my_checkins');
    } else if (item.sourceType == 'notification' && item.sourceId != null) {
      Navigator.pushNamed(context, '/notifications');
    } else if (item.sourceType == 'approval' && item.sourceId != null) {
      Navigator.pushNamed(context, '/approval');
    }
  }

  void _openAllTimeline(BuildContext context, List<TimelineItem> items,
      BentoColors colors, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '今日动态 (${items.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _openTimelineDetail(context, item);
                      },
                      child: _buildTimelineItem(item, colors, theme),
                    );
                  },
                ),
              ),
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

  Widget _buildFeatureGrid(BuildContext context, BentoColors colors,
      ThemeData theme, AuthAuthenticated authState) {
    final role = authState.user.role;

    final features = <Map<String, dynamic>>[];
    features.add({
      'icon': Icons.fact_check_outlined,
      'title': '我的打卡',
      'description': '查看个人打卡记录',
      'color': const Color(0xFF3B82F6),
      'route': '/my_checkins',
    });

    // 请假入口 — 所有人可见
    features.add({
      'icon': Icons.beach_access_outlined,
      'title': '申请请假',
      'description': '提交请假审批',
      'color': const Color(0xFF06B6D4),
      'route': '/approval/create?type=请假',
    });

    if (role == 'worker') {
      features.add({
        'icon': Icons.trending_up_outlined,
        'title': '项目进度',
        'description': '上报项目施工进度',
        'color': const Color(0xFFF59E0B),
        'route': null,
      });
    }

    if (role == 'manager' || role == 'admin') {
      features.addAll([
        {
          'icon': Icons.group_outlined,
          'title': '团队打卡',
          'description': '查看团队打卡情况',
          'color': const Color(0xFF10B981),
          'route': '/team_checkins',
        },
        {
          'icon': Icons.people_outline,
          'title': '人员管理',
          'description': '管理团队成员信息',
          'color': const Color(0xFFF97316),
          'route': '/personnel',
        },
        {
          'icon': Icons.devices_other_outlined,
          'title': '设备管理',
          'description': '查看和管理设备',
          'color': const Color(0xFF8B5CF6),
          'route': '/devices',
        },
        {
          'icon': Icons.trending_up_outlined,
          'title': '项目进度',
          'description': '查看项目施工进度',
          'color': const Color(0xFFF59E0B),
          'route': null,
        },
      ]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: BentoSpacing.space16),
          Text(
            '功能入口',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: BentoSpacing.space12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: BentoSpacing.space12,
              crossAxisSpacing: BentoSpacing.space12,
              childAspectRatio: 1.4,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              final icon = feature['icon'] as IconData;
              final title = feature['title'] as String;
              final description = feature['description'] as String;
              final color = feature['color'] as Color;
              final route = feature['route'] as String?;

              return BentoCard(
                onTap: () {
                  if (title == '项目进度') {
                    Navigator.pushNamed(context, '/progress_workbench');
                  } else if (title == '申请请假') {
                    Navigator.pushNamed(context, '/approval/create',
                        arguments: {'type': '请假'});
                  } else if (route != null) {
                    Navigator.pushNamed(context, route);
                  }
                },
                padding: const EdgeInsets.all(BentoSpacing.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(BentoRadius.sm),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
