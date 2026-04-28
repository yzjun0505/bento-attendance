import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../widgets/amap_webview.dart';
import '../../blocs/attendance/attendance_bloc.dart';
import '../../blocs/attendance/attendance_state.dart';
import '../../blocs/attendance/attendance_event.dart';
import '../../utils/coord_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 高德地图 Web JS API Key
const _kAmapWebKey = 'your_amap_web_key_here';

/// 地图看板 — Tab 1
/// 集成高德地图 + 围栏 + 打卡功能 + 多打卡类型 + 项目自动绑定
class MapDashboardScreen extends StatefulWidget {
  const MapDashboardScreen({super.key});

  @override
  State<MapDashboardScreen> createState() => _MapDashboardScreenState();
}

class _MapDashboardScreenState extends State<MapDashboardScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<_AMapWrapperState> _mapKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.colors;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    return Scaffold(
      backgroundColor: colors.background,
      body: BlocBuilder<AttendanceBloc, AttendanceState>(
        builder: (context, state) {
          return Column(
            children: [
              // 地图区域（占 60%）
              Expanded(
                flex: 6,
                child: Stack(
                  children: [
                    // 真实高德地图
                    _AMapWrapper(
                      key: _mapKey,
                      state: state,
                      isDarkMode: Theme.of(context).brightness == Brightness.dark,
                    ),
                    // 透明顶栏
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.only(
                          top: topPadding + 8,
                          left: BentoSpacing.space20,
                          right: BentoSpacing.space20,
                          bottom: BentoSpacing.space12,
                        ),
                        child: Row(
                          children: [
                            // 信息按钮 — 点击显示打卡信息面板
                            GestureDetector(
                              onTap: () => _showCheckinInfo(context, state),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.notifications_outlined, color: colors.textSecondary, size: 20),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '地图看板',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            // 定位按钮
                            GestureDetector(
                              onTap: () => _mapKey.currentState?.moveToMyLocation(state),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.my_location, color: colors.primary, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 底部操作面板
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(BentoRadius.lg),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 位置信息条（简化：不显示"定位中..."持续状态）
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: BentoSpacing.space20,
                        vertical: BentoSpacing.space12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(BentoRadius.lg),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: colors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showProjectSelector(context, state),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      state is AttendanceLoaded && state.currentAddress != null
                                          ? state.currentAddress!
                                          : '已获取位置',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (state is AttendanceLoaded && state.needsProjectConfirmation)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colors.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '选择项目',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colors.warning,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (state is AttendanceLoaded)
                            _buildGeofenceBadge(state, colors)
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                    // 项目绑定提示
                    if (state is AttendanceLoaded) ...[
                      _buildProjectBindBar(state, colors, theme),
                      if (state.checkinFeedback != null)
                        _buildCheckinFeedback(state, colors, theme),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        BentoSpacing.space20,
                        BentoSpacing.space16,
                        BentoSpacing.space20,
                        BentoSpacing.space8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '今日考勤',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (state is AttendanceLoaded && state.attendanceGroupName != null && state.attendanceGroupName!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    state.attendanceGroupName!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.primary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _buildCheckinCard(
                                  context: context,
                                  title: '上班',
                                  time: _getClockInTime(state),
                                  scheduledTime: state is AttendanceLoaded ? state.workStartTime : null,
                                  isCompleted: _isClockInCompleted(state),
                                  isSubmitting: state is AttendanceLoaded && state.isSubmitting,
                                  enabled: !_isClockInCompleted(state),
                                  colors: colors,
                                  theme: theme,
                                  onTap: () => _handleCheckin(context, 'clock_in'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              _buildBigPhotoButton(context, state, colors, theme),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildCheckinCard(
                                  context: context,
                                  title: '下班',
                                  time: _getClockOutTime(state),
                                  scheduledTime: state is AttendanceLoaded ? state.workEndTime : null,
                                  isCompleted: _isClockOutCompleted(state),
                                  isSubmitting: state is AttendanceLoaded && state.isSubmitting,
                                  enabled: _isClockInCompleted(state) && !_isClockOutCompleted(state),
                                  colors: colors,
                                  theme: theme,
                                  onTap: () => _handleCheckin(context, 'clock_out'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 底部安全区
                    SizedBox(height: mediaQuery.padding.bottom),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 项目绑定提示条
  Widget _buildProjectBindBar(AttendanceLoaded state, BentoColors colors, ThemeData theme) {
    String projectText;
    Color badgeColor;
    String badgeText;

    if (state.activeProjectId != null) {
      projectText = state.activeProjectName;
      badgeColor = state.isInsideGeofence ? colors.success : colors.warning;
      badgeText = state.isInsideGeofence ? '围栏内' : '围栏外';
    } else {
      projectText = '未关联项目';
      badgeColor = colors.textTertiary;
      badgeText = '未绑定';
    }

    return GestureDetector(
      onTap: () => _showProjectSelector(context, state),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(BentoRadius.sm),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 14, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                projectText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: badgeColor,
                  fontSize: 10,
                ),
              ),
            ),
            if (state.nearbyProjects.length > 1) ...[
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz, size: 14, color: colors.textTertiary),
            ],
          ],
        ),
      ),
    );
  }


  /// 打卡信息面板
  void _showCheckinInfo(BuildContext context, AttendanceState state) {
    if (state is! AttendanceLoaded) return;
    final colors = context.colors;
    final theme = Theme.of(context);
    final s = state;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
            top: 12,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '打卡信息',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('当前位置', s.currentAddress ?? '获取中...', colors, theme),
              _buildInfoRow(
                '坐标',
                s.currentLatitude != null
                    ? '${s.currentLatitude!.toStringAsFixed(6)}, ${s.currentLongitude!.toStringAsFixed(6)}'
                    : '获取中...',
                colors, theme,
              ),
              _buildInfoRow(
                '关联项目',
                s.activeProjectName.isNotEmpty ? s.activeProjectName : '未绑定',
                colors, theme,
              ),
              _buildInfoRow(
                '围栏状态',
                s.isInsideGeofence ? '围栏内 ✅' : '围栏外 ⚠️',
                colors, theme,
              ),
              if (s.workStartTime != null)
                _buildInfoRow(
                  '规定上班',
                  s.workStartTime!,
                  colors, theme,
                ),
              if (s.workEndTime != null)
                _buildInfoRow(
                  '规定下班',
                  s.workEndTime!,
                  colors, theme,
                ),
              _buildInfoRow(
                '今日上班',
                _getClockInTime(s) != '未打卡' ? _getClockInTime(s) : '未打卡',
                colors, theme,
              ),
              _buildInfoRow(
                '今日下班',
                _getClockOutTime(s) != '未打卡' ? _getClockOutTime(s) : '未打卡',
                colors, theme,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, BentoColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProjectSelector(BuildContext context, AttendanceState state) {
    if (state is! AttendanceLoaded) return;
    if (state.nearbyProjects.isEmpty && state.projects.isEmpty) return;

    final colors = context.colors;
    final theme = Theme.of(context);
    final displayProjects = state.nearbyProjects.isNotEmpty
        ? state.nearbyProjects
        : state.projects;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
            top: 12,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '选择关联项目',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (state.needsProjectConfirmation) ...[
                const SizedBox(height: 4),
                Text(
                  '检测到附近有多个项目，请确认本次打卡项目',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Divider(color: colors.divider, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: displayProjects.length,
                  itemBuilder: (context, index) {
                    final project = displayProjects[index];
                    final isActive = state.activeProjectId == project.id;
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (project.isInside == true ? colors.success : colors.primary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          project.isInside == true ? Icons.check_circle : Icons.folder_outlined,
                          color: project.isInside == true ? colors.success : colors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        project.name,
                        style: TextStyle(
                          color: isActive ? colors.primary : colors.textPrimary,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        project.distanceText.isNotEmpty
                            ? '${project.distanceText} · ${project.address}'
                            : project.address,
                        style: TextStyle(color: colors.textTertiary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isActive
                          ? Icon(Icons.check_circle, color: colors.primary, size: 20)
                          : null,
                      onTap: () {
                        context.read<AttendanceBloc>().add(SelectProject(projectId: project.id));
                        Navigator.pop(ctx);
                      },
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

  Widget _buildGeofenceBadge(AttendanceState state, BentoColors colors) {
    bool isInside = false;
    if (state is AttendanceLoaded) {
      isInside = state.isInsideGeofence;
    }
    if (isInside) {
      return const BentoBadge.success(text: '围栏内');
    }
    return const BentoBadge.warning(text: '围栏外');
  }


  String _getClockInTime(AttendanceState state) {
    if (state is AttendanceLoaded) {
      final today = DateTime.now();
      final clockIn = state.recentHistory
          .where((c) => c.type == 'clock_in' || c.type == 'in')
          .where((c) {
            final d = c.createdAt;
            return d.year == today.year && d.month == today.month && d.day == today.day;
          })
          .firstOrNull;
      if (clockIn != null) return clockIn.formattedTime;
    }
    return '未打卡';
  }

  String _getClockOutTime(AttendanceState state) {
    if (state is AttendanceLoaded) {
      final today = DateTime.now();
      final clockOut = state.recentHistory
          .where((c) => c.type == 'clock_out' || c.type == 'out')
          .where((c) {
            final d = c.createdAt;
            return d.year == today.year && d.month == today.month && d.day == today.day;
          })
          .firstOrNull;
      if (clockOut != null) return clockOut.formattedTime;
    }
    return '未打卡';
  }

  bool _isClockInCompleted(AttendanceState state) {
    if (state is AttendanceLoaded) {
      final today = DateTime.now();
      return state.recentHistory.any((c) =>
        (c.type == 'clock_in' || c.type == 'in') &&
        c.createdAt.year == today.year &&
        c.createdAt.month == today.month &&
        c.createdAt.day == today.day
      );
    }
    return false;
  }

  bool _isClockOutCompleted(AttendanceState state) {
    if (state is AttendanceLoaded) {
      final today = DateTime.now();
      return state.recentHistory.any((c) =>
        (c.type == 'clock_out' || c.type == 'out') &&
        c.createdAt.year == today.year &&
        c.createdAt.month == today.month &&
        c.createdAt.day == today.day
      );
    }
    return false;
  }

  Widget _buildCheckinCard({
    required BuildContext context,
    required String title,
    required String time,
    String? scheduledTime,
    required bool isCompleted,
    required BentoColors colors,
    required ThemeData theme,
    bool isSubmitting = false,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    // 判断是否迟到/早退
    bool isLate = false;
    if (isCompleted && scheduledTime != null) {
      isLate = time.compareTo(scheduledTime) > 0;
    }

    return BentoCard.interactive(
      onTap: (!enabled || isSubmitting) ? null : onTap,
      borderRadius: BentoRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space16,
        vertical: BentoSpacing.space16,
      ),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: BentoSpacing.space8),
          if (isSubmitting)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            )
          else
            Text(
              time == '未打卡' ? (scheduledTime ?? '--:--') : time,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: isCompleted
                    ? (isLate ? colors.warning : colors.success)
                    : colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          const SizedBox(height: BentoSpacing.space4),
          if (isSubmitting)
            Text(
              '提交中...',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.primary,
              ),
            )
          else if (isCompleted)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLate ? Icons.warning_amber_rounded : Icons.check_circle,
                  size: 14,
                  color: isLate ? colors.warning : colors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  isLate ? '迟到' : '已打卡',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isLate ? colors.warning : colors.success,
                  ),
                ),
              ],
            )
          else if (scheduledTime != null)
            Text(
              '规定 $scheduledTime',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.textTertiary,
              ),
            )
          else
            Text(
              '点击打卡',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.primary,
              ),
            ),
        ],
      ),
    );
  }

  /// 打卡反馈提示条
  Widget _buildCheckinFeedback(AttendanceLoaded state, BentoColors colors, ThemeData theme) {
    final feedback = state.checkinFeedback!;
    final isSuccess = feedback.contains('成功');
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space20,
        vertical: BentoSpacing.space4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (isSuccess ? colors.success : colors.error).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        border: Border.all(
          color: (isSuccess ? colors.success : colors.error).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: isSuccess ? colors.success : colors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feedback,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSuccess ? colors.success : colors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 大号水印拍照按钮
  Widget _buildBigPhotoButton(BuildContext context, AttendanceState state, BentoColors colors, ThemeData theme) {
    final isSubmitting = state is AttendanceLoaded && (state as AttendanceLoaded).isSubmitting;

    return GestureDetector(
      onTap: isSubmitting ? null : () {
        Navigator.of(context).pushNamed('/camera_checkin');
      },
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A90D9), Color(0xFF357ABD)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90D9).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: isSubmitting
            ? Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded, size: 32, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(
                    '水印拍照',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _handleCheckin(BuildContext context, String type) {
    final attendanceBloc = context.read<AttendanceBloc>();
    final state = attendanceBloc.state;

    if (state is AttendanceLoaded) {
      // 正在提交中，不重复触发
      if (state.isSubmitting) return;

      // 如果需要项目确认，先弹窗选择项目
      if (state.needsProjectConfirmation && state.activeProjectId == null) {
        _showProjectSelector(context, state);
        return;
      }

      attendanceBloc.add(SubmitCheckin(
        type: type,
        projectId: state.activeProjectId,
      ));
    }
  }
}

// ============================================================
// 地图 Wrapper — 管理地图状态同步
// ============================================================

class _AMapWrapper extends StatefulWidget {
  final AttendanceState state;
  final bool isDarkMode;

  const _AMapWrapper({
    super.key,
    required this.state,
    required this.isDarkMode,
  });

  @override
  State<_AMapWrapper> createState() => _AMapWrapperState();
}

class _AMapWrapperState extends State<_AMapWrapper> {
  final AMapController _mapController = AMapController();
  bool _hasSyncedLocation = false;

  // 缓存上一次 GPS 位置（设备级），用于地图初始中心点，避免默认显示天安门
  double? _cachedLat;
  double? _cachedLng;

  @override
  void initState() {
    super.initState();
    _loadLastKnownPosition();
  }

  /// 获取设备缓存的最后已知位置（几乎瞬间返回，无需等待 GPS 锁定）
  Future<void> _loadLastKnownPosition() async {
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        // GPS 原始坐标 WGS84 → GCJ02
        final gcj = CoordUtils.wgs84ToGcj02(lastPos.latitude, lastPos.longitude);
        setState(() {
          _cachedLat ??= gcj['latitude'];
          _cachedLng ??= gcj['longitude'];
        });
      }
    } catch (e) {
      debugPrint('获取最后已知位置失败: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _AMapWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAll();
  }

  void _syncAll() {
    if (!_mapController.isReady) return;
    if (widget.state is! AttendanceLoaded) return;
    final s = widget.state as AttendanceLoaded;

    // 同步用户位置
    if (s.currentLatitude != null && s.currentLongitude != null) {
      // 更新缓存位置
      _cachedLat = s.currentLatitude;
      _cachedLng = s.currentLongitude;
      _mapController.updateLocation(
        s.currentLongitude!,
        s.currentLatitude!,
        accuracy: 50,
      );
      if (!_hasSyncedLocation) {
        _mapController.moveToLocation(
          s.currentLongitude!,
          s.currentLatitude!,
          zoom: 15,
        );
        _hasSyncedLocation = true;
      }
    } else if (!_hasSyncedLocation && _cachedLat != null && _cachedLng != null) {
      // bloc 还没拿到 GPS，但设备有缓存位置 → 先用缓存位置移动地图
      _mapController.moveToLocation(_cachedLng!, _cachedLat!, zoom: 15);
    }

    // 同步项目围栏
    final allProjects = <Map<String, dynamic>>[];
    for (final p in s.nearbyProjects) {
      allProjects.add({
        'id': p.id,
        'name': p.name,
        'longitude': p.longitude,
        'latitude': p.latitude,
        'radius': p.radius,
        'isInside': p.isInside ?? false,
      });
    }
    // 补充不在 nearbyProjects 里的项目
    for (final p in s.projects) {
      if (!allProjects.any((ap) => ap['id'] == p.id)) {
        allProjects.add({
          'id': p.id,
          'name': p.name,
          'longitude': p.longitude,
          'latitude': p.latitude,
          'radius': p.radius,
          'isInside': p.isInside ?? false,
        });
      }
    }
    _mapController.updateProjects(allProjects);

    // 同步主题
    _mapController.setMapStyle(widget.isDarkMode);
  }

  /// 定位到当前位置
  void moveToMyLocation(AttendanceState state) {
    if (state is AttendanceLoaded &&
        state.currentLatitude != null &&
        state.currentLongitude != null) {
      _mapController.moveToLocation(
        state.currentLongitude!,
        state.currentLatitude!,
        zoom: 16,
      );
    } else {
      // 没有位置数据时，触发 BLoC 重新获取位置
      if (state is AttendanceLoaded) {
        // 尝试用 JS 端的 IP 定位结果
        _mapController.onIpLocation = (lng, lat) {
          _mapController.moveToLocation(lng, lat, zoom: 16);
        };
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double? initLng;
    double? initLat;
    if (widget.state is AttendanceLoaded) {
      final s = widget.state as AttendanceLoaded;
      initLng = s.currentLongitude;
      initLat = s.currentLatitude;
    }
    // 回退到设备缓存位置，避免地图默认显示天安门
    initLng ??= _cachedLng;
    initLat ??= _cachedLat;

    return AMapWebView(
      apiKey: _kAmapWebKey,
      controller: _mapController,
      initialLng: initLng,
      initialLat: initLat,
      initialZoom: 15,
      isDarkMode: widget.isDarkMode,
      onMapReady: () {
        _syncAll();
      },
      onAddressResolved: (address) {
        debugPrint('📍 逆地理编码: $address');
      },
    );
  }
}
