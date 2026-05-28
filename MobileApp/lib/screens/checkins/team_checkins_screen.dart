import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/dio_client.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../models/checkin_model.dart';

class TeamCheckinGroup {
  final int userId;
  final String userName;
  final String? userAvatar;
  final String role;
  final String roleLabel;
  final List<Checkin> checkins;

  const TeamCheckinGroup({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.role,
    required this.roleLabel,
    required this.checkins,
  });
}

class TeamCheckinsScreen extends StatefulWidget {
  const TeamCheckinsScreen({super.key});

  @override
  State<TeamCheckinsScreen> createState() => _TeamCheckinsScreenState();
}

class _TeamCheckinsScreenState extends State<TeamCheckinsScreen> {
  final ApiClient _apiClient = ApiClient();
  DateTime _selectedDate = DateTime.now();
  List<TeamCheckinGroup> _groups = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  String get _dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (selected == today) return '今天';
    return DateFormat('MM月dd日').format(_selectedDate);
  }

  @override
  void initState() {
    super.initState();
    _loadTeamCheckins();
  }

  Future<void> _loadTeamCheckins() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final dateStart =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
              .toIso8601String();
      final dateEnd = DateTime(_selectedDate.year, _selectedDate.month,
              _selectedDate.day, 23, 59, 59)
          .toIso8601String();

      final response = await _apiClient.dio.get('/checkin', queryParameters: {
        'scope': 'team',
        'date_start': dateStart,
        'date_end': dateEnd,
      });

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final List<dynamic> data = response.data['data']['list'];
        final List<Checkin> checkins = data
            .map((json) => Checkin.fromJson(json as Map<String, dynamic>))
            .toList();

        final Map<int, TeamCheckinGroup> groupMap = {};
        for (int i = 0; i < checkins.length; i++) {
          final json = data[i] as Map<String, dynamic>;
          final checkin = checkins[i];
          final uid = checkin.userId;

          if (!groupMap.containsKey(uid)) {
            groupMap[uid] = TeamCheckinGroup(
              userId: uid,
              userName: json['user_name'] ?? json['name'] ?? '未知用户',
              userAvatar: json['user_avatar'] ?? json['avatar'],
              role: json['role'] ?? 'worker',
              roleLabel: _roleLabel(json['role'] ?? 'worker'),
              checkins: [],
            );
          }
          groupMap[uid]!.checkins.add(checkin);
        }

        final groups = groupMap.values.toList()
          ..sort((a, b) => a.userName.compareTo(b.userName));

        if (!mounted) return;
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
      } else {
        throw Exception(response.data['message'] ?? '请求失败');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return '管理员';
      case 'manager':
        return '经理';
      case 'worker':
        return '工人';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('团队打卡'),
        centerTitle: true,
        actions: [
          _buildDateSelector(colors, theme),
        ],
      ),
      body: _buildBody(colors, theme),
    );
  }

  Widget _buildDateSelector(BentoColors colors, ThemeData theme) {
    return GestureDetector(
      onTap: () => _showDatePicker(),
      child: Container(
        margin: const EdgeInsets.only(right: BentoSpacing.space16),
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
    );
  }

  Widget _buildBody(BentoColors colors, ThemeData theme) {
    if (_isLoading) {
      return const BentoLoading.spinner();
    }

    if (_hasError) {
      return BentoEmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        description: _errorMessage,
        actionText: '重试',
        onAction: _loadTeamCheckins,
      );
    }

    if (_groups.isEmpty) {
      return BentoEmptyState(
        icon: Icons.groups_outlined,
        title: '暂无团队打卡记录',
        description: '$_dateLabel没有团队成员打卡',
      );
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _loadTeamCheckins,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: BentoSpacing.space20,
          vertical: BentoSpacing.space12,
        ),
        itemCount: _groups.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: BentoSpacing.space12),
        itemBuilder: (context, index) {
          return _buildGroupCard(_groups[index], colors, theme);
        },
      ),
    );
  }

  Widget _buildGroupCard(
      TeamCheckinGroup group, BentoColors colors, ThemeData theme) {
    return BentoCard(
      padding: EdgeInsets.zero,
      borderRadius: BentoRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserHeader(group, colors, theme),
          ...group.checkins.map((c) => _buildCheckinItem(c, colors, theme)),
        ],
      ),
    );
  }

  Widget _buildUserHeader(
      TeamCheckinGroup group, BentoColors colors, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        BentoSpacing.space16,
        BentoSpacing.space12,
        BentoSpacing.space16,
        BentoSpacing.space12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.divider),
        ),
      ),
      child: Row(
        children: [
          BentoAvatar(
            size: 40,
            imageUrl: group.userAvatar,
            text: group.userName,
            backgroundColor: colors.primaryLight,
            textColor: colors.primary,
          ),
          const SizedBox(width: BentoSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.userName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  group.roleLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${group.checkins.length} 条记录',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinItem(
      Checkin checkin, BentoColors colors, ThemeData theme) {
    final isOutside = checkin.isOutside;
    final statusText = checkin.statusText;
    final typeIcon = checkin.typeIcon;
    final typeColor = checkin.typeColor;
    final iconColor = isOutside ? colors.warning : typeColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space16,
        vertical: BentoSpacing.space10,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BentoRadius.sm),
            ),
            child: Icon(typeIcon, color: iconColor, size: 18),
          ),
          const SizedBox(width: BentoSpacing.space10),
          Text(
            checkin.formattedTime,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: BentoSpacing.space8),
          Expanded(
            child: Text(
              checkin.typeName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          if (isOutside)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.warningLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '围栏外',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: colors.warning,
                ),
              ),
            ),
          if (statusText != null)
            BentoBadge.error(text: statusText, fontSize: 10)
          else
            _buildLocationTag(checkin, colors),
        ],
      ),
    );
  }

  Widget _buildLocationTag(Checkin checkin, BentoColors colors) {
    if (checkin.isOutside) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.successLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '围栏内',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colors.success,
        ),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadTeamCheckins();
    }
  }
}
