import 'package:flutter/material.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../services/tencent_im_service.dart' as im_service;
import 'chat_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  int _currentTab = 0;
  final _imService = im_service.TencentIMService();

  List<dynamic> _conversations = [];
  List<dynamic> _friends = [];
  List<dynamic> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();

    // 监听 IM 登陆状态变化
    _imService.connectionStream.listen((state) {
      if (state == im_service.ConnectionState.connected && mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    // 等待 IM 初始化和登陆完成
    int retries = 0;
    while (!_imService.isLoggedIn && retries < 30) {
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }

    setState(() {
      _isLoading = false;
    });

    if (!_imService.isLoggedIn) {
      debugPrint('IM 未登陆，请重新登陆');
      return;
    }

    try {
      final conversations = await _imService.getAllConversations();
      final friends = await _imService.getFriendList();
      final groups = await _imService.getJoinedGroupList();

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _friends = friends;
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载数据失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          '消息',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: colors.primary),
            onPressed: () => _showCreateOptions(context),
          ),
        ],
      ),
      body: StreamBuilder<im_service.ConnectionState>(
        stream: _imService.connectionStream,
        initialData: _imService.isLoggedIn
            ? im_service.ConnectionState.connected
            : im_service.ConnectionState.disconnected,
        builder: (context, snapshot) {
          return Column(
            children: [
              _buildTabBar(colors, theme),
              Expanded(
                child: _isLoading
                    ? const BentoLoading.spinner()
                    : _buildContent(colors, theme),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BentoColors colors, ThemeData theme) {
    if (!_imService.isLoggedIn) {
      return const BentoEmptyState(
        icon: Icons.chat_bubble_outline,
        title: '未登录 IM',
        description: '请先登录以使用聊天功能',
      );
    }

    return IndexedStack(
      index: _currentTab,
      children: [
        _buildConversationList(colors, theme),
        _buildContactList(colors, theme),
        _buildGroupList(colors, theme),
      ],
    );
  }

  Widget _buildTabBar(BentoColors colors, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(BentoSpacing.space16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(BentoRadius.lg),
      ),
      child: Row(
        children: [
          _buildTabItem('聊天', 0, colors, theme),
          _buildTabItem('联系人', 1, colors, theme),
          _buildTabItem('群组', 2, colors, theme),
        ],
      ),
    );
  }

  Widget _buildTabItem(
      String label, int index, BentoColors colors, ThemeData theme) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(BentoRadius.md),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected ? colors.primary : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList(BentoColors colors, ThemeData theme) {
    if (_conversations.isEmpty) {
      return const BentoEmptyState(
        icon: Icons.chat_bubble_outline,
        title: '暂无会话',
        description: '开始和同事聊天吧',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return _buildConversationItem(conv, colors, theme);
      },
    );
  }

  Widget _buildConversationItem(
      dynamic conv, BentoColors colors, ThemeData theme) {
    final isGroup = conv.groupID != null && conv.groupID!.isNotEmpty;
    final name = conv.showName ?? (isGroup ? '群聊' : '用户');
    final lastMsg = _imService.getMessageDigest(conv.lastMessage);
    final unreadCount = conv.unreadCount ?? 0;
    final timestamp = conv.lastMessage?.timestamp;
    final time = timestamp != null ? _formatTime(timestamp * 1000) : '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conv.conversationID,
              name: name,
              isGroup: isGroup,
              receiverId: isGroup ? conv.groupID : conv.userID,
            ),
          ),
        ).then((_) => _loadData());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: BentoSpacing.space8),
        padding: const EdgeInsets.all(BentoSpacing.space12),
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
        child: Row(
          children: [
            BentoAvatar(
              size: 48,
              text: name,
              backgroundColor:
                  isGroup ? colors.secondaryLight : colors.primaryLight,
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
                        child: Text(
                          name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
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

  Widget _buildContactList(BentoColors colors, ThemeData theme) {
    if (_friends.isEmpty) {
      return const BentoEmptyState(
        icon: Icons.person_outline,
        title: '暂无联系人',
        description: '添加好友开始聊天',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space16),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _buildContactItem(friend, colors, theme);
      },
    );
  }

  Widget _buildContactItem(
      dynamic friend, BentoColors colors, ThemeData theme) {
    final name = friend.friendRemark ??
        friend.userProfile?.nickName ??
        friend.userID ??
        '用户';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: 'single_${friend.userID}',
              name: name,
              isGroup: false,
              receiverId: friend.userID,
            ),
          ),
        ).then((_) => _loadData());
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
            BentoAvatar(
              size: 44,
              text: name,
              backgroundColor: colors.primaryLight,
              textColor: colors.primary,
            ),
            const SizedBox(width: BentoSpacing.space12),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chat_bubble_outline,
              color: colors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupList(BentoColors colors, ThemeData theme) {
    if (_groups.isEmpty) {
      return const BentoEmptyState(
        icon: Icons.group_outlined,
        title: '暂无群组',
        description: '创建或加入群组',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space16),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return _buildGroupItem(group, colors, theme);
      },
    );
  }

  Widget _buildGroupItem(dynamic group, BentoColors colors, ThemeData theme) {
    final name = group.groupName ?? '群聊';
    final memberCount = group.memberCount ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: 'group_${group.groupID}',
              name: name,
              isGroup: true,
              receiverId: group.groupID,
            ),
          ),
        ).then((_) => _loadData());
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.secondaryLight,
                borderRadius: BorderRadius.circular(BentoRadius.md),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group, color: colors.secondary, size: 20),
                  Text(
                    '$memberCount人',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.secondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: BentoSpacing.space12),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
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

  void _showCreateOptions(BuildContext context) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(BentoSpacing.space20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_add, color: colors.primary),
              ),
              title: const Text('添加好友'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.secondaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.group_add, color: colors.secondary),
              ),
              title: const Text('创建群组'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
