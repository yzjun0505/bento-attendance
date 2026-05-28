import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:tuikit_atomic_x/atomicx.dart';
import 'package:tencent_chat_uikit/chat_page.dart';
import '../../api/dio_client.dart';
import '../../blocs/home/home_bloc.dart';
import '../../blocs/home/home_bloc_base.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../repositories/notification_repository.dart';
import '../../models/notification_model.dart';
import '../notifications/notification_screen.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final NotificationRepository _notificationRepository;
  late ConversationListStore _conversationListStore;
  int _unreadCount = 0;
  int _totalUnreadCount = 0;
  NotificationModel? _latestNotification;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _notificationRepository = NotificationRepository(apiClient: apiClient);
    _fetchUnreadCount();
    _timer =
        Timer.periodic(const Duration(minutes: 1), (_) => _fetchUnreadCount());

    _conversationListStore = ConversationListStore.create();
    _conversationListStore.addListener(_onUnreadCountChanged);
    _conversationListStore.getConversationTotalUnreadCount();
  }

  void _onUnreadCountChanged() {
    if (mounted) {
      setState(() {
        _totalUnreadCount =
            _conversationListStore.conversationListState.totalUnreadCount;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _conversationListStore.removeListener(_onUnreadCountChanged);
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    int? count;
    try {
      count = await _notificationRepository.getUnreadCount();
    } on Object catch (e) {
      debugPrint('获取未读通知数失败: $e');
    }

    List<NotificationModel>? latest;
    try {
      latest =
          await _notificationRepository.getNotifications(page: 1, pageSize: 1);
    } on Object catch (e) {
      debugPrint('获取最新通知失败: $e');
    }

    if (!mounted) return;
    setState(() {
      if (count != null) _unreadCount = count;
      if (latest != null && latest.isNotEmpty) {
        _latestNotification = latest.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final atomicLocale = AtomicLocalizations.of(context);
    final semanticColors = BaseThemeProvider.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, authState) {},
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeSummaryLoading) {
                return const BentoLoading.spinner();
              }
              if (state is HomeError) {
                return BentoEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: '数据加载失败',
                  description: state.message,
                  actionText: '重试',
                  onAction: () =>
                      context.read<HomeBloc>().add(const LoadHomeSummary()),
                );
              }
              if (state is HomeSummaryLoaded) {
                return RefreshIndicator(
                  color: colors.primary,
                  onRefresh: () async {
                    context
                        .read<HomeBloc>()
                        .add(const LoadHomeSummary(silent: true));
                    await _fetchUnreadCount();
                    _conversationListStore.getConversationTotalUnreadCount();
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: BentoSpacing.space20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopBar(context, state, colors, theme),
                              const SizedBox(height: BentoSpacing.space16),
                              if (_latestNotification != null)
                                _buildSystemNotificationItem(
                                    colors, theme, _latestNotification!),
                              const SizedBox(height: BentoSpacing.space16),
                            ],
                          ),
                        ),
                      ),
                      SliverFillRemaining(
                        child: Container(
                          decoration: BoxDecoration(
                            color: semanticColors.bgColorOperate,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Icons.chat_bubble_outline,
                                        color: semanticColors.textColorPrimary),
                                    const SizedBox(width: 8),
                                    Text(
                                      atomicLocale.chat,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        color: semanticColors.textColorPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_totalUnreadCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: semanticColors.textColorError,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _totalUnreadCount > 99
                                              ? '99+'
                                              : '$_totalUnreadCount',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                semanticColors.textColorButton,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ConversationList(
                                  onConversationClick: (conversation) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatPage(
                                            conversation: conversation),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, HomeSummaryLoaded state,
      BentoColors colors, ThemeData theme) {
    return Row(
      children: [
        BentoAvatar(
          size: 44,
          text: state.user.name,
          backgroundColor: colors.primaryLight,
          textColor: colors.primary,
        ),
        const SizedBox(width: BentoSpacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(DateTime.now()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (state.weatherInfo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(BentoRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wb_sunny_outlined, size: 16, color: colors.warning),
                const SizedBox(width: 4),
                Text(
                  '${state.weatherInfo!.temperature}° ${state.weatherInfo!.weather}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSystemNotificationItem(
      BentoColors colors, ThemeData theme, NotificationModel n) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationScreen()),
        ).then((_) => _fetchUnreadCount());
      },
      child: Container(
        padding: const EdgeInsets.all(BentoSpacing.space12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BentoRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primaryLight,
                borderRadius: BorderRadius.circular(BentoRadius.md),
              ),
              child: Icon(Icons.notifications_outlined,
                  color: colors.primary, size: 20),
            ),
            const SizedBox(width: BentoSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '系统通知',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(n.formattedTime,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: colors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title.isNotEmpty ? n.title : n.content,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (_unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: colors.error,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                              _unreadCount > 99 ? '99+' : '$_unreadCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 9) return '早上好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }
}
