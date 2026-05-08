import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/dio_client.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/home/home_bloc.dart';
import '../../blocs/home/home_bloc_base.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../repositories/notification_repository.dart';
import '../notifications/notification_screen.dart';
import '../settings/settings_screen.dart';
import 'edit_profile_screen.dart';
import '../offline/offline_checkins_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final NotificationRepository _notificationRepository;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _notificationRepository = NotificationRepository(apiClient: ApiClient());
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final count = await _notificationRepository.getUnreadCount();
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    } on Object catch (e) {
      debugPrint('获取未读通知数失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final isGuest = authState is! AuthAuthenticated;
            final user = isGuest ? null : authState.user;

            return RefreshIndicator(
              color: colors.primary,
              onRefresh: () async {
                await _fetchUnreadCount();
                if (!isGuest) {
                  context
                      .read<HomeBloc>()
                      .add(const LoadHomeSummary(silent: true));
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(BentoSpacing.space20),
                child: Column(
                  children: [
                    const SizedBox(height: BentoSpacing.space24),
                    _buildAvatarSection(
                      context: context,
                      colors: colors,
                      theme: theme,
                      isGuest: isGuest,
                      user: user,
                    ),
                    const SizedBox(height: BentoSpacing.space24),
                    if (isGuest) ...[
                      _buildGuestLoginCard(colors, theme),
                      const SizedBox(height: BentoSpacing.space16),
                    ],
                    if (!isGuest) ...[
                      BlocBuilder<HomeBloc, HomeState>(
                        builder: (context, homeState) {
                          final loaded =
                              homeState is HomeSummaryLoaded ? homeState : null;
                          return _buildAttendanceSummaryCard(
                              colors, theme, loaded);
                        },
                      ),
                      const SizedBox(height: BentoSpacing.space16),
                      _buildInfoCard(context, colors, theme, user!),
                      const SizedBox(height: BentoSpacing.space16),
                    ],
                    _buildMenuCard(context, colors, theme, isGuest),
                    const SizedBox(height: BentoSpacing.space24),
                    if (!isGuest)
                      BentoButton.danger(
                        text: '退出登录',
                        size: BentoButtonSize.medium,
                        fullWidth: true,
                        onPressed: () {
                          _showLogoutConfirm(context);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 头像区域
  Widget _buildAvatarSection({
    required BuildContext context,
    required BentoColors colors,
    required ThemeData theme,
    required bool isGuest,
    required dynamic user,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: isGuest
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditProfileScreen()),
                  );
                },
          child: BentoAvatar.large(
            imageUrl: isGuest ? null : user.avatar,
            text: isGuest ? null : user.name,
            icon: isGuest ? Icons.person_outline : null,
            backgroundColor: colors.primaryLight,
            textColor: colors.primary,
          ),
        ),
        const SizedBox(height: BentoSpacing.space12),
        Text(
          isGuest ? '访客用户' : user.name,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: BentoSpacing.space4),
        if (!isGuest)
          Text(
            '@${user.username}',
            style:
                theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        if (!isGuest && (user.projectName?.isNotEmpty == true))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              user.projectName!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.textTertiary),
            ),
          ),
        if (!isGuest && user.role != null)
          BentoBadge.primary(text: _getRoleLabel(user.role)),
        if (isGuest)
          Text(
            '登录后即可使用完整功能',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
      ],
    );
  }

  /// 访客登录引导卡片
  Widget _buildGuestLoginCard(BentoColors colors, ThemeData theme) {
    return BentoCard(
      padding: const EdgeInsets.all(BentoSpacing.space20),
      child: Column(
        children: [
          Icon(Icons.lock_outline, size: 40, color: colors.textTertiary),
          const SizedBox(height: BentoSpacing.space12),
          Text(
            '登录后即可使用考勤打卡',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '查看考勤记录等功能',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BentoSpacing.space16),
          BentoButton.primary(
            text: '立即登录',
            size: BentoButtonSize.medium,
            fullWidth: true,
            onPressed: () {
              context.read<AuthBloc>().add(LoggedOut());
            },
          ),
        ],
      ),
    );
  }

  /// 考勤摘要卡片
  Widget _buildAttendanceSummaryCard(
      BentoColors colors, ThemeData theme, HomeSummaryLoaded? summary) {
    return BentoCard(
      padding: const EdgeInsets.all(BentoSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本月考勤',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: BentoSpacing.space16),
          Row(
            children: [
              Expanded(
                child: _buildKeyValue(
                  label: '出勤',
                  value: summary != null
                      ? '${summary.totalCheckinsThisMonth} 天'
                      : '—',
                  colors: colors,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKeyValue(
                  label: '考勤组',
                  value: summary?.attendanceGroupName?.isNotEmpty == true
                      ? summary!.attendanceGroupName!
                      : '—',
                  colors: colors,
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKeyValue(
                  label: '上班时间',
                  value: summary?.workStartTime?.isNotEmpty == true
                      ? summary!.workStartTime!
                      : '—',
                  colors: colors,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKeyValue(
                  label: '下班时间',
                  value: summary?.workEndTime?.isNotEmpty == true
                      ? summary!.workEndTime!
                      : '—',
                  colors: colors,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValue({
    required String label,
    required String value,
    required BentoColors colors,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.textTertiary)),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// 信息列表卡片（合并为单卡片）
  Widget _buildInfoCard(
      BuildContext context, BentoColors colors, ThemeData theme, dynamic user) {
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          BentoListTile(
            leading:
                Icon(Icons.badge_outlined, size: 22, color: colors.primary),
            title: '用户ID',
            trailing: Text(
              user.id.toString(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            showDivider: true,
          ),
          BentoListTile(
            leading: Icon(Icons.account_circle_outlined,
                size: 22, color: colors.primary),
            title: '账号',
            trailing: Text(
              user.username,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            showDivider: true,
          ),
          BentoListTile(
            leading:
                Icon(Icons.apartment_outlined, size: 22, color: colors.primary),
            title: '项目',
            trailing: Text(
              user.projectName ?? '未关联',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            showDivider: true,
          ),
          BentoListTile(
            leading: Icon(Icons.phone, size: 22, color: colors.primary),
            title: '手机号',
            trailing: Text(
              user.phone ?? '未绑定',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            showDivider: true,
          ),
          BentoListTile(
            leading:
                Icon(Icons.email_outlined, size: 22, color: colors.primary),
            title: '邮箱',
            trailing: Text(
              user.email ?? '未绑定',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            showDivider: true,
          ),
          BentoListTile(
            leading: Icon(Icons.security, size: 22, color: colors.primary),
            title: '安全设置',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '修改密码',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EditProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 功能菜单卡片
  Widget _buildMenuCard(
      BuildContext context, BentoColors colors, ThemeData theme, bool isGuest) {
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          BentoListTile(
            leading: Icon(Icons.notifications_outlined,
                size: 22, color: colors.primary),
            title: '消息中心',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_unreadCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationScreen()),
              ).then((_) => _fetchUnreadCount());
            },
            showDivider: true,
          ),
          BentoListTile(
            leading:
                Icon(Icons.palette_outlined, size: 22, color: colors.primary),
            title: '外观设置',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Theme.of(context).brightness == Brightness.dark
                      ? '深色模式'
                      : '浅色模式',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
              ],
            ),
            onTap: () {
              // 切换主题
              context.read<ThemeBloc>().add(ToggleTheme());
            },
            showDivider: true,
          ),
          BentoListTile(
            leading:
                Icon(Icons.cloud_off_outlined, size: 22, color: colors.warning),
            title: '离线打卡记录',
            trailing:
                Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const OfflineCheckinsScreen()),
              );
            },
            showDivider: true,
          ),
          BentoListTile(
            leading:
                Icon(Icons.settings_outlined, size: 22, color: colors.primary),
            title: '设置',
            trailing:
                Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 退出登录确认弹窗
  void _showLogoutConfirm(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出后需要重新登录才能使用考勤功能'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(LoggedOut());
            },
            child: Text('确认退出', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }

  /// 获取角色标签
  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin':
        return '系统管理员';
      case 'office':
        return '办公室文员';
      case 'construction':
        return '施工人员';
      case 'designer':
        return '设计师';
      case 'inspector':
        return '驻场监理';
      default:
        return '项目作业员';
    }
  }
}
