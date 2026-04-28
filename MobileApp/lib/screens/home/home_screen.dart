import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../api/dio_client.dart';
import '../../blocs/home/home_bloc.dart';
import '../../blocs/home/home_bloc_base.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../repositories/notification_repository.dart';
import '../../models/notification_model.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/contact_remark_repository.dart';
import '../../services/openim_service.dart' as im_service;
import '../notifications/notification_screen.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final NotificationRepository _notificationRepository;
  late final UserRepository _userRepository;
  final _imService = im_service.OpenIMService();
  final _remarkRepo = ContactRemarkRepository();
  final GlobalKey _createButtonKey = GlobalKey();
  int _unreadCount = 0;
  int _imUnreadCount = 0;
  NotificationModel? _latestNotification;
  final ValueNotifier<String?> _openSwipe = ValueNotifier<String?>(null);
  List<dynamic> _recentConversations = [];
  List<dynamic> _friends = [];
  List<dynamic> _groups = [];
  Map<String, String> _remarks = {};
  int _imTab = 0; // 0=聊天, 1=联系人, 2=群组
  int _unhandledFriendCount = 0; // 未处理的好友申请数量
  Timer? _timer;
  Timer? _imDebounceTimer;
  late final AnimationController _pulseController;
  StreamSubscription? _convSubscription;
  StreamSubscription? _msgSubscription;
  StreamSubscription<int>? _imUnreadSubscription;

  /// 防抖加载 IM 数据（避免 stream 频繁触发多次刷新）
  void _debouncedLoadIMData() {
    _imDebounceTimer?.cancel();
    _imDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadIMData();
    });
  }

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _notificationRepository = NotificationRepository(apiClient: apiClient);
    _userRepository = UserRepository(apiClient: apiClient);
    _fetchUnreadCount();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchUnreadCount());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadRemarks();

    // 监听会话变化，刷新聊天列表（防抖：避免频繁刷新）
    _convSubscription = _imService.conversationStream.listen((_) {
      _debouncedLoadIMData();
    });

    // 监听新消息，刷新聊天列表和未读数
    _msgSubscription = _imService.messageStream.listen((_) {
      _debouncedLoadIMData();
    });

    _imUnreadSubscription = _imService.totalUnreadStream.listen((count) {
      if (!mounted) return;
      setState(() => _imUnreadCount = count);
    });

    // 监听 IM 连接状态，连接成功后延迟加载数据（SDK 需要时间同步）
    _imService.connectionStream.listen((state) {
      if (state == im_service.ConnectionState.connected) {
        // SDK 连接成功后需要一点时间同步数据，延迟加载
        Future.delayed(const Duration(seconds: 2), () => _loadIMData());
        // 5 秒后再刷一次确保数据完整
        Future.delayed(const Duration(seconds: 5), () => _loadIMData());
      }
    });
    // 如果已登录则立即加载
    Future.delayed(const Duration(seconds: 1), () => _loadIMData());
  }

  Future<void> _loadRemarks() async {
    final m = await _remarkRepo.readAll();
    if (!mounted) return;
    setState(() => _remarks = m);
  }

  String _remarkKey({required bool isGroup, required String? userId, required String? groupId}) {
    return isGroup ? 'g_${groupId ?? ''}' : 'u_${userId ?? ''}';
  }

  Future<void> _loadIMData() async {
    try {
      print('=== _loadIMData 开始 (isLoggedIn=${_imService.isLoggedIn}, userID=${_imService.currentUserID}) ===');
      final conversations = await _imService.getAllConversations();
      final totalUnread = await _imService.getTotalUnreadMsgCount();
      final friends = await _imService.getFriendList();
      final groups = await _imService.getJoinedGroupList();
      final unhandledCount = await _imService.getUnhandledFriendApplicationCount();
      print('=== _loadIMData 结果: conversations=${conversations.length}, friends=${friends.length}, groups=${groups.length}, unhandledCount=$unhandledCount ===');
      conversations.sort((a, b) {
        final ap = (a.isPinned ?? false) ? 1 : 0;
        final bp = (b.isPinned ?? false) ? 1 : 0;
        if (ap != bp) return bp - ap;
        final at = a.latestMsgSendTime ?? 0;
        final bt = b.latestMsgSendTime ?? 0;
        return bt.compareTo(at);
      });
      if (mounted) {
        setState(() {
          _recentConversations = conversations;
          _imUnreadCount = totalUnread;
          _friends = friends;
          _groups = groups;
          _unhandledFriendCount = unhandledCount;
        });
      }
    } catch (e) {
      debugPrint('加载IM数据失败: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _imDebounceTimer?.cancel();
    _convSubscription?.cancel();
    _msgSubscription?.cancel();
    _imUnreadSubscription?.cancel();
    _pulseController.dispose();
    _openSwipe.dispose();
    super.dispose();
  }

  Future<void> _showCreateMenu(BentoColors colors, ThemeData theme) async {
    final ctx = _createButtonKey.currentContext;
    if (ctx == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = ctx.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, box.size.height);

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          value: 'add_friend',
          enabled: _imService.isLoggedIn,
          child: const Text('添加好友'),
        ),
        PopupMenuItem(
          value: 'create_group',
          enabled: _imService.isLoggedIn,
          child: const Text('创建群组'),
        ),
      ],
    );

    if (!mounted) return;
    if (value == null) return;
    if (!_imService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络连接中，请稍候')));
      return;
    }

    if (value == 'add_friend') {
      _showAddFriendDialog(colors, theme);
    } else if (value == 'create_group') {
      _showCreateGroupDialog(colors);
    }
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
      latest = await _notificationRepository.getNotifications(page: 1, pageSize: 1);
    } on Object catch (e) {
      debugPrint('获取最新通知失败: $e');
    }

    if (!mounted) return;
    setState(() {
      if (count != null) _unreadCount = count;
      if (latest != null && latest.isNotEmpty) _latestNotification = latest.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, authState) {
            // 当 IM 初始化完成时，刷新数据
            if (authState is AuthAuthenticated && authState.imInitialized) {
              _loadIMData();
            }
          },
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
                  onAction: () => context.read<HomeBloc>().add(LoadHomeSummary()),
                );
              }
              if (state is HomeSummaryLoaded) {
                return RefreshIndicator(
                  color: colors.primary,
                  onRefresh: () async {
                    context.read<HomeBloc>().add(const LoadHomeSummary(silent: true));
                    await _fetchUnreadCount();
                    await _loadIMData();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: mediaQuery.padding.bottom + 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顶栏
                        _buildTopBar(context, state, colors, theme),
                        const SizedBox(height: BentoSpacing.space24),
                        // 消息中心
                        _buildChatSection(context, colors, theme),
                      ],
                    ),
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

  /// 顶栏：问候 + 天气 + 新建
  Widget _buildTopBar(BuildContext context, HomeSummaryLoaded state, BentoColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
      child: Row(
        children: [
          // 头像
          BentoAvatar(
            size: 44,
            text: state.user.name,
            backgroundColor: colors.primaryLight,
            textColor: colors.primary,
          ),
          const SizedBox(width: BentoSpacing.space12),
          // 问候 + 日期
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
          // 天气
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
          const SizedBox(width: BentoSpacing.space8),
          GestureDetector(
            key: _createButtonKey,
            onTap: () => _showCreateMenu(colors, theme),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: colors.primary, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  /// 消息中心区域 — 直接嵌入聊天/联系人/群组
  Widget _buildChatSection(BuildContext context, BentoColors colors, ThemeData theme) {
    final imReady = _imService.isInitialized;
    final imLoggedIn = _imService.isLoggedIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab 栏
        if (imReady)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(BentoRadius.lg),
              ),
              child: Row(
                children: [
                  _buildImTabItem('聊天', 0, colors, theme, badge: _imUnreadCount),
                  _buildImTabItem('联系人', 1, colors, theme, badge: _unhandledFriendCount),
                  _buildImTabItem('群组', 2, colors, theme),
                ],
              ),
            ),
          ),
        const SizedBox(height: BentoSpacing.space12),
        // IM 未登录提示
        if (!imReady)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
            child: Container(
              padding: const EdgeInsets.all(BentoSpacing.space20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(BentoRadius.xl),
                border: Border.all(color: colors.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  BentoLoading.spinner(size: 24),
                  const SizedBox(height: 12),
                  Text(
                    '即时通讯连接中...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '正在同步消息与联系人，请稍候',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (imReady && !imLoggedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(BentoSpacing.space20, 0, BentoSpacing.space20, BentoSpacing.space12),
            child: Text(
              '离线模式 · 消息仅可查看',
              style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary),
            ),
          ),
        // Tab 内容
        if (imReady) ...[
          if (_imTab == 0) _buildConversationList(colors, theme),
          if (_imTab == 1) _buildContactList(colors, theme),
          if (_imTab == 2) _buildGroupList(colors, theme),
        ],
      ],
    );
  }

  /// IM Tab 项
  Widget _buildImTabItem(String label, int index, BentoColors colors, ThemeData theme, {int badge = 0}) {
    final isSelected = _imTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _imTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(BentoRadius.md),
            boxShadow: isSelected
                ? [BoxShadow(color: colors.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? colors.primary : colors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text(
                    '$badge',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 聊天列表
  Widget _buildConversationList(BentoColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
      child: Column(
        children: [
          if (_latestNotification != null)
            _buildSystemNotificationItem(colors, theme, _latestNotification!),
          if (_recentConversations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: BentoSpacing.space24),
              child: BentoEmptyState(
                icon: Icons.chat_outlined,
                title: '暂无会话',
                description: '开始和同事聊天吧',
              ),
            )
          else
            ..._recentConversations.map((conv) {
              final isGroup = conv.groupID != null && conv.groupID!.isNotEmpty;
              final key = _remarkKey(isGroup: isGroup, userId: conv.userID, groupId: conv.groupID);
              final baseName = conv.showName ?? (isGroup ? '群聊' : '用户');
              final name = _remarks[key]?.isNotEmpty == true ? _remarks[key]! : baseName;
              String? faceUrl;
              try {
                faceUrl = conv.faceURL as String?;
              } catch (_) {
                faceUrl = null;
              }
              final lastMsg = _imService.getMessageDigest(conv.latestMsg);
              final unreadCount = conv.unreadCount ?? 0;
              final time = conv.latestMsgSendTime != null ? _formatConvTime(conv.latestMsgSendTime) : '';

              final pinned = conv.isPinned == true;

              return Padding(
                padding: const EdgeInsets.only(bottom: BentoSpacing.space8),
                child: _SwipeActionTile(
                  id: conv.conversationID,
                  controller: _openSwipe,
                  actions: [
                    _SwipeAction(
                      label: pinned ? '取消置顶' : '置顶',
                      color: colors.primary,
                      onTap: () async {
                        await _imService.pinConversation(conversationID: conv.conversationID, pinned: !pinned);
                        await _loadIMData();
                      },
                    ),
                    _SwipeAction(
                      label: '删除',
                      color: colors.error,
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('删除会话'),
                            content: Text('确认删除与“$name”的会话及本地消息？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await _imService.deleteConversation(conversationID: conv.conversationID);
                          await _loadIMData();
                        }
                      },
                    ),
                  ],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          conversationId: conv.conversationID,
                          name: name,
                          isGroup: isGroup,
                          receiverId: isGroup ? conv.groupID : conv.userID,
                          faceUrl: faceUrl,
                        ),
                      ),
                    ).then((_) => _loadIMData());
                  },
                  child: Container(
                    padding: const EdgeInsets.all(BentoSpacing.space12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(BentoRadius.lg),
                    ),
                    child: Row(
                      children: [
                        BentoAvatar(
                          size: 40,
                          imageUrl: faceUrl,
                          text: name,
                          backgroundColor: isGroup ? colors.secondaryLight : colors.primaryLight,
                          textColor: isGroup ? colors.secondary : colors.primary,
                        ),
                        const SizedBox(width: BentoSpacing.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: theme.textTheme.bodyMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (pinned) ...[
                                          const SizedBox(width: 6),
                                          Icon(Icons.push_pin, size: 14, color: colors.textTertiary),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(time, style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(child: Text(lastMsg, style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary), overflow: TextOverflow.ellipsis, maxLines: 1)),
                                  if (unreadCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: colors.error, borderRadius: BorderRadius.circular(10)),
                                      child: Text(unreadCount > 99 ? '99+' : '$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildSystemNotificationItem(BentoColors colors, ThemeData theme, NotificationModel n) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationScreen()),
        ).then((_) => _fetchUnreadCount());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: BentoSpacing.space8),
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
              child: Icon(Icons.notifications_outlined, color: colors.primary, size: 20),
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
                      Text(n.formattedTime, style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title.isNotEmpty ? n.title : n.content,
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (_unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: colors.error, borderRadius: BorderRadius.circular(10)),
                          child: Text(_unreadCount > 99 ? '99+' : '$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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

  /// 联系人列表
  Widget _buildContactList(BentoColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
      child: Column(
        children: [
          // 好友申请入口
          if (_unhandledFriendCount > 0)
            GestureDetector(
              onTap: () => _showFriendApplicationsDialog(colors, theme),
              child: Container(
                margin: const EdgeInsets.only(bottom: BentoSpacing.space8),
                padding: const EdgeInsets.all(BentoSpacing.space12),
                decoration: BoxDecoration(
                  color: colors.primaryLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(BentoRadius.lg),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
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
                      child: Icon(Icons.person_add, color: colors.primary, size: 20),
                    ),
                    const SizedBox(width: BentoSpacing.space12),
                    Expanded(
                      child: Text(
                        '$_unhandledFriendCount 条好友申请待处理',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_unhandledFriendCount',
                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: colors.primary),
                  ],
                ),
              ),
            ),
          // 联系人列表
          if (_friends.isEmpty)
            const BentoEmptyState(
              icon: Icons.person_outline,
              title: '暂无联系人',
              description: '添加好友开始聊天',
            )
          else
            ..._friends.map((friend) {
              final baseName = friend.nickname ?? friend.userID ?? '用户';
              final key = _remarkKey(isGroup: false, userId: friend.userID, groupId: null);
              final name = _remarks[key]?.isNotEmpty == true ? _remarks[key]! : baseName;
              String? faceUrl;
              try {
                faceUrl = friend.faceURL as String?;
              } catch (_) {
                faceUrl = null;
              }
              return GestureDetector(
                onTap: () {
                  () async {
                    final conversationID = await _imService.getOrCreateSingleConversationID(friend.userID);
                    if (!context.mounted || conversationID == null || conversationID.isEmpty) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          conversationId: conversationID,
                          name: name,
                          isGroup: false,
                          receiverId: friend.userID,
                          faceUrl: faceUrl,
                        ),
                      ),
                    );
                    _loadIMData();
                  }();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: BentoSpacing.space8),
                  padding: const EdgeInsets.all(BentoSpacing.space12),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(BentoRadius.lg)),
                  child: Row(
                    children: [
                      BentoAvatar(size: 40, imageUrl: faceUrl, text: name, backgroundColor: colors.primaryLight, textColor: colors.primary),
                      const SizedBox(width: BentoSpacing.space12),
                      Expanded(child: Text(name, style: theme.textTheme.bodyMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600))),
                      Icon(Icons.chat_bubble_outline, color: colors.textTertiary, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  /// 群组列表
  Widget _buildGroupList(BentoColors colors, ThemeData theme) {
    if (_groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
        child: const BentoEmptyState(
          icon: Icons.group_outlined,
          title: '暂无群组',
          description: '创建或加入群组',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space20),
      child: Column(
        children: _groups.map((group) {
          final baseName = group.groupName ?? '群聊';
          final key = _remarkKey(isGroup: true, userId: null, groupId: group.groupID);
          final name = _remarks[key]?.isNotEmpty == true ? _remarks[key]! : baseName;
          String? faceUrl;
          try {
            faceUrl = group.faceURL as String?;
          } catch (_) {
            faceUrl = null;
          }
          final memberCount = group.memberCount ?? 0;
          return GestureDetector(
            onTap: () {
              () async {
                    final conversationID = await _imService.getOrCreateGroupConversationID(
                      group.groupID,
                      sessionType: group.sessionType,
                    );
                if (!context.mounted || conversationID == null || conversationID.isEmpty) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      conversationId: conversationID,
                      name: name,
                      isGroup: true,
                      receiverId: group.groupID,
                      faceUrl: faceUrl,
                    ),
                  ),
                );
                _loadIMData();
              }();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: BentoSpacing.space8),
              padding: const EdgeInsets.all(BentoSpacing.space12),
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(BentoRadius.lg)),
              child: Row(
                children: [
                  BentoAvatar(size: 40, imageUrl: faceUrl, text: name, backgroundColor: colors.secondaryLight, textColor: colors.secondary),
                  const SizedBox(width: BentoSpacing.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.bodyMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('$memberCount人', style: theme.textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textTertiary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 添加好友对话框
  void _showAddFriendDialog(BentoColors colors, ThemeData theme) {
    final userIdController = TextEditingController();
    final reasonController = TextEditingController();
    bool isSending = false;
    String? searchResult; // 搜索结果提示
    bool? userFound; // 用户是否找到
    String? resolvedUserId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.person_add, color: colors.primary),
              const SizedBox(width: 8),
              Text('添加好友', style: TextStyle(color: colors.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userIdController,
                decoration: InputDecoration(
                  labelText: '用户ID / 手机号',
                  hintText: '输入用户ID（如 1）或手机号（如 138xxxx）',
                  prefixIcon: Icon(Icons.badge, color: colors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: colors.primary),
                    onPressed: () async {
                      final input = userIdController.text.trim();
                      if (input.isEmpty) return;
                      setDialogState(() => searchResult = '搜索中...');
                      final user = await _userRepository.lookupUser(query: input);
                      setDialogState(() {
                        if (user != null) {
                          userFound = true;
                          resolvedUserId = user.id.toString();
                          final title = user.name.isNotEmpty ? user.name : user.username;
                          final extra = (user.phone != null && user.phone!.isNotEmpty) ? ' · ${user.phone}' : '';
                          searchResult = '找到用户: $title (ID: ${user.id})$extra';
                        } else {
                          userFound = false;
                          resolvedUserId = null;
                          searchResult = '未找到该用户，请检查ID';
                        }
                      });
                    },
                  ),
                ),
              ),
              if (searchResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    searchResult!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: userFound == true ? (colors.success ?? Colors.green) : colors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: '验证消息',
                  hintText: '我是...',
                  prefixIcon: Icon(Icons.message_outlined, color: colors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text('支持按用户ID或手机号搜索', style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final input = userIdController.text.trim();
                      if (input.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入用户ID或手机号')));
                        return;
                      }
                      setDialogState(() => isSending = true);
                      try {
                        String? userId = resolvedUserId;
                        if (userId == null) {
                          final user = await _userRepository.lookupUser(query: input);
                          if (user == null) {
                            throw Exception('用户不存在，请检查ID/手机号是否正确');
                          }
                          userId = user.id.toString();
                          resolvedUserId = userId;
                        }
                        await _imService.addFriend(userID: userId, reason: reasonController.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('好友申请已发送')));
                        _loadIMData();
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        // 提取更友好的错误信息
                        String errorMsg = e.toString();
                        if (errorMsg.contains('RecordNotFoundError') || errorMsg.contains('user not found')) {
                          errorMsg = '用户不存在，请检查ID是否正确';
                        } else if (errorMsg.contains('不能添加自己')) {
                          errorMsg = '不能添加自己为好友';
                        } else if (errorMsg.contains('RegisteredAlreadyError') || errorMsg.contains('already friends')) {
                          errorMsg = '你们已经是好友了';
                        }
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: isSending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('发送申请'),
            ),
          ],
        ),
      ),
    );
  }

  /// 创建群组对话框
  void _showCreateGroupDialog(BentoColors colors) {
    final groupNameController = TextEditingController();
    final noticeController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.group_add, color: colors.secondary),
              const SizedBox(width: 8),
              Text('创建群组', style: TextStyle(color: colors.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupNameController,
                decoration: InputDecoration(
                  labelText: '群名称',
                  hintText: '输入群组名称',
                  prefixIcon: Icon(Icons.group, color: colors.secondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noticeController,
                decoration: InputDecoration(
                  labelText: '群公告',
                  hintText: '群公告（可选）',
                  prefixIcon: Icon(Icons.campaign_outlined, color: colors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final groupName = groupNameController.text.trim();
                      if (groupName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入群名称')));
                        return;
                      }
                      setDialogState(() => isCreating = true);
                      try {
                        await _imService.createGroup(groupName: groupName, notification: noticeController.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('群组创建成功')));
                        _loadIMData();
                      } catch (e) {
                        setDialogState(() => isCreating = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: colors.secondary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: isCreating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  /// 好友申请列表对话框
  void _showFriendApplicationsDialog(BentoColors colors, ThemeData theme) {
    bool isLoading = true;
    List<dynamic> receivedApps = [];
    List<dynamic> sentApps = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (isLoading) {
            _loadFriendApplications().then((data) {
              setDialogState(() {
                receivedApps = data['received'] ?? [];
                sentApps = data['sent'] ?? [];
                isLoading = false;
              });
            });
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.person_add, color: colors.primary),
                  const SizedBox(width: 8),
                  Text('好友申请', style: TextStyle(color: colors.textPrimary)),
                ],
              ),
              content: const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            );
          }

          return AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.person_add, color: colors.primary),
                const SizedBox(width: 8),
                Text('好友申请', style: TextStyle(color: colors.textPrimary)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: receivedApps.isEmpty && sentApps.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('暂无好友申请')),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (receivedApps.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('收到的申请', style: theme.textTheme.titleSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
                            ),
                            ...receivedApps.map((app) => _buildFriendAppItem(app, true, colors, theme, () {
                              setDialogState(() => isLoading = true);
                            })),
                            const SizedBox(height: 12),
                          ],
                          if (sentApps.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('发出的申请', style: theme.textTheme.titleSmall?.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w600)),
                            ),
                            ...sentApps.map((app) => _buildFriendAppItem(app, false, colors, theme, null)),
                          ],
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadIMData(); // 刷新角标
                },
                child: Text('关闭', style: TextStyle(color: colors.textSecondary)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建单个好友申请项
  Widget _buildFriendAppItem(dynamic app, bool isReceived, BentoColors colors, ThemeData theme, VoidCallback? onHandled) {
    final nickname = isReceived ? (app.fromNickname ?? app.fromUserID ?? '用户') : (app.toNickname ?? app.toUserID ?? '用户');
    final userID = isReceived ? (app.fromUserID ?? '') : (app.toUserID ?? '');
    final reqMsg = app.reqMsg ?? '';
    final handleResult = app.handleResult ?? 0;
    final time = app.createTime != null ? _formatConvTime(app.createTime!) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoAvatar(size: 36, text: nickname, backgroundColor: colors.primaryLight, textColor: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname, style: theme.textTheme.bodyMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                    Text('ID: $userID', style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary)),
                  ],
                ),
              ),
              Text(time, style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary)),
            ],
          ),
          if (reqMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 44),
              child: Text(reqMsg, style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
            ),
          const SizedBox(height: 8),
          if (isReceived) ...[
            if (handleResult == 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await _imService.refuseFriendApplication(userID: userID);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已拒绝')));
                        onHandled?.call();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
                    child: const Text('拒绝'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _imService.acceptFriendApplication(userID: userID);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已添加好友')));
                        onHandled?.call();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('同意'),
                  ),
                ],
              )
            else if (handleResult == 1)
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Text('已同意', style: theme.textTheme.bodySmall?.copyWith(color: colors.success ?? Colors.green)),
              )
            else if (handleResult == -1)
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Text('已拒绝', style: theme.textTheme.bodySmall?.copyWith(color: colors.error)),
              ),
          ] else ...[
            // 发出的申请
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                handleResult == 1 ? '对方已同意' : (handleResult == -1 ? '对方已拒绝' : '等待对方确认'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: handleResult == 1 ? (colors.success ?? Colors.green) : (handleResult == -1 ? colors.error : colors.textTertiary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 加载好友申请数据
  Future<Map<String, List<dynamic>>> _loadFriendApplications() async {
    try {
      final received = await _imService.getReceivedFriendApplications();
      final sent = await _imService.getSentFriendApplications();
      return {'received': received, 'sent': sent};
    } catch (e) {
      debugPrint('加载好友申请失败: $e');
      return {'received': [], 'sent': []};
    }
  }

  /// 格式化会话时间
  String _formatConvTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  /// 根据时间获取问候语
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

class _SwipeAction {
  final String label;
  final Color color;
  final Future<void> Function() onTap;

  const _SwipeAction({
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _SwipeActionTile extends StatefulWidget {
  final String id;
  final ValueNotifier<String?> controller;
  final List<_SwipeAction> actions;
  final VoidCallback onTap;
  final Widget child;
  final double actionWidth;

  const _SwipeActionTile({
    required this.id,
    required this.controller,
    required this.actions,
    required this.onTap,
    required this.child,
    this.actionWidth = 84,
  });

  @override
  State<_SwipeActionTile> createState() => _SwipeActionTileState();
}

class _SwipeActionTileState extends State<_SwipeActionTile> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  bool _busy = false;

  double get _maxOffset => widget.actionWidth * widget.actions.length;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _SwipeActionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (widget.controller.value != widget.id && _anim.value != 0) _close();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _anim.dispose();
    super.dispose();
  }

  void _open() {
    widget.controller.value = widget.id;
    _anim.animateTo(1, curve: Curves.easeOut);
  }

  void _close() {
    if (widget.controller.value == widget.id) {
      widget.controller.value = null;
    }
    _anim.animateTo(0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    final actionRow = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: widget.actions.map((a) {
        return SizedBox(
          width: widget.actionWidth,
          child: Material(
            color: a.color,
            child: InkWell(
              onTap: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await a.onTap();
                      } finally {
                        if (mounted) setState(() => _busy = false);
                        _close();
                      }
                    },
              child: Center(
                child: Text(
                  a.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(BentoRadius.lg),
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: colors.surfaceVariant, child: actionRow)),
          AnimatedBuilder(
            animation: _anim,
            child: widget.child,
            builder: (context, child) {
              final dx = -_maxOffset * _anim.value;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    if (_busy) return;
                    _anim.stop();
                    widget.controller.value = widget.id;
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_busy) return;
                    final currentDx = -_maxOffset * _anim.value;
                    final nextDx = (currentDx + details.delta.dx).clamp(-_maxOffset, 0.0);
                    _anim.value = (-nextDx / _maxOffset);
                  },
                  onHorizontalDragEnd: (details) {
                    if (_busy) return;
                    final v = details.primaryVelocity ?? 0;
                    if (v < -200) {
                      _open();
                      return;
                    }
                    if (v > 200) {
                      _close();
                      return;
                    }
                    if (_anim.value >= 0.5) {
                      _open();
                    } else {
                      _close();
                    }
                  },
                  onTap: () {
                    if (_busy) return;
                    if (_anim.value != 0) {
                      _close();
                      return;
                    }
                    widget.onTap();
                  },
                  child: child,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
