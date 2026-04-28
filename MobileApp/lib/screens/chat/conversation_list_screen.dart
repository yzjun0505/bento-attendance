import 'package:flutter/material.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../services/openim_service.dart' as im_service;
import '../../repositories/contact_remark_repository.dart';
import 'chat_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  int _currentTab = 0;
  final _imService = im_service.OpenIMService();
  final _remarkRepo = ContactRemarkRepository();

  List<dynamic> _conversations = [];
  List<dynamic> _friends = [];
  List<dynamic> _groups = [];
  bool _isLoading = true;
  Map<String, String> _remarks = {};
  Map<String, String> _customAvatars = {};

  @override
  void initState() {
    super.initState();
    _loadRemarksAndAvatars();
    _loadData();

    // 监听 IM 登陆状态变化
    _imService.connectionStream.listen((state) {
      if (state == im_service.ConnectionState.connected && mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    // 立即清除 loading 状态，如果未登录直接返回
    if (!mounted) return;
    
    // 如果 IM 还没有初始化完成，我们不用死等，先结束 loading 渲染一个空列表或骨架屏
    // 当 _imService.connectionStream 回调 connected 时会自动再调一次 _loadData()
    if (!_imService.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 并发请求
      final results = await Future.wait([
        _imService.getAllConversations(),
        _imService.getFriendList(),
        _imService.getJoinedGroupList(),
      ]);

      if (mounted) {
        setState(() {
          _conversations = results[0] as List<dynamic>;
          _friends = results[1] as List<dynamic>;
          _groups = results[2] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('加载数据失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRemarksAndAvatars() async {
    final m = await _remarkRepo.readAll();
    final a = await _remarkRepo.readAllAvatars();
    if (!mounted) return;
    setState(() {
      _remarks = m;
      _customAvatars = a;
    });
  }

  String _remarkKey({required bool isGroup, required String? userId, required String? groupId}) {
    return isGroup ? 'g_${groupId ?? ''}' : 'u_${userId ?? ''}';
  }

  Future<void> _editRemark({required String key, required String currentName}) async {
    final controller = TextEditingController(text: _remarks[key] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('设置备注', style: theme.textTheme.titleMedium),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '请输入备注'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        );
      },
    );
    if (ok != true) return;
    await _remarkRepo.setRemark(key, controller.text);
    await _loadRemarksAndAvatars();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存：${controller.text.trim().isEmpty ? currentName : controller.text.trim()}')));
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
      return BentoEmptyState(
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
    final key = _remarkKey(isGroup: isGroup, userId: conv.userID, groupId: conv.groupID);
    final baseName = conv.showName ?? (isGroup ? '群聊' : '用户');
    final name = _remarks[key]?.isNotEmpty == true ? _remarks[key]! : baseName;
    String? faceUrl;
    try {
      faceUrl = _customAvatars[key]?.isNotEmpty == true ? _customAvatars[key] : conv.faceURL as String?;
    } catch (_) {
      faceUrl = null;
    }
    final lastMsg = _imService.getMessageDigest(conv.latestMsg);
    final unreadCount = conv.unreadCount ?? 0;
    final time = conv.latestMsgSendTime != null
        ? _formatTime(conv.latestMsgSendTime)
        : '';

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
              faceUrl: faceUrl,
            ),
          ),
        ).then((_) => _loadData());
      },
      onLongPressStart: (d) {
        final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        final size = overlay.size;
        final x = d.globalPosition.dx;
        final y = d.globalPosition.dy;
        final position = RelativeRect.fromLTRB(x, y, size.width - x, size.height - y);
        showMenu<String>(
          context: context,
          position: position,
          color: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          items: const [
            PopupMenuItem(value: 'remark', child: Text('设置备注')),
            PopupMenuItem(value: 'clear', child: Text('清除备注')),
          ],
        ).then((action) async {
          if (!mounted || action == null) return;
          if (action == 'remark') {
            await _editRemark(key: key, currentName: baseName);
          } else if (action == 'clear') {
            await _remarkRepo.setRemark(key, '');
            await _loadRemarksAndAvatars();
          }
        });
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
              imageUrl: faceUrl,
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
    final baseName = friend.nickname ?? friend.userID ?? '用户';
    final key = _remarkKey(isGroup: false, userId: friend.userID, groupId: null);
    final name = _remarks[key]?.isNotEmpty == true ? _remarks[key]! : baseName;
    String? faceUrl;
    try {
      faceUrl = _customAvatars[key]?.isNotEmpty == true ? _customAvatars[key] : friend.faceURL as String?;
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
          _loadData();
        }();
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
              imageUrl: faceUrl,
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
    final baseName = group.groupName ?? '群聊';
    final key = _remarkKey(isGroup: true, userId: null, groupId: group.groupID);
    final name = _remarks[key]?.isNotEmpty == true ? _remarks[key]! : baseName;
    String? faceUrl;
    try {
      faceUrl = _customAvatars[key]?.isNotEmpty == true ? _customAvatars[key] : group.faceURL as String?;
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
          _loadData();
        }();
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
              size: 48,
              imageUrl: faceUrl,
              text: name,
              backgroundColor: colors.secondaryLight,
              textColor: colors.secondary,
            ),
            const SizedBox(width: BentoSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$memberCount人',
                    style: theme.textTheme.labelSmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
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
