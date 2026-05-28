import 'package:flutter/material.dart' hide SearchBar;
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tuikit_atomic_x/atomicx.dart' hide IconButton;
import 'package:tuikit_atomic_x/contact_list/pages/start_c2c_chat.dart';
import 'package:tuikit_atomic_x/contact_list/pages/start_group_chat.dart';
import 'package:tuikit_atomic_x/search/search_bar.dart';
import 'package:tuikit_atomic_x/contact_list/pages/add_friend.dart';
import 'package:tuikit_atomic_x/contact_list/pages/add_group.dart';
import 'package:tencent_chat_uikit/chat_page.dart';
import '../../api/dio_client.dart';
import '../../models/user_model.dart' as app_user;
import '../../repositories/user_repository.dart';
import '../../services/tencent_im_service.dart';

const String _startC2CChatMenuValue = 'startC2CChat';
const String _startGroupChatMenuValue = 'startGroupChat';
const String _addFriendMenuValue = 'addFriend';
const String _addGroupMenuValue = 'addGroup';

class TUIKitChatScreen extends StatelessWidget {
  final ConversationInfo conversation;
  final MessageInfo? message;

  TUIKitChatScreen({
    super.key,
    required String conversationID,
    required String title,
    bool isGroup = false,
    String? avatarURL,
  })  : conversation = ConversationInfo(
          conversationID: conversationID,
          title: title,
          avatarURL: avatarURL,
          type: isGroup ? ConversationType.group : ConversationType.c2c,
        ),
        message = null;

  const TUIKitChatScreen.conversation({
    super.key,
    required this.conversation,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ChatPage(conversation: conversation, message: message);
  }
}

class TUIKitConversationsScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const TUIKitConversationsScreen({
    super.key,
    this.onBackPressed,
  });

  @override
  State<TUIKitConversationsScreen> createState() =>
      _TUIKitConversationsScreenState();
}

class _TUIKitConversationsScreenState extends State<TUIKitConversationsScreen> {
  void _openChat(ConversationInfo conversation, {MessageInfo? message}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversation: conversation,
          message: message,
        ),
      ),
    );
  }

  void _startC2CChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StartC2CChat(
          onSelect: (AZOrderedListItem item) {
            final contactInfo = item.extraData as ContactInfo;
            _openChat(
              ConversationInfo(
                conversationID: 'c2c_${contactInfo.contactID}',
                title: contactInfo.title,
                avatarURL: contactInfo.avatarURL,
                type: ConversationType.c2c,
              ),
            );
          },
        ),
      ),
    );
  }

  void _startGroupChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StartGroupChat(
          onGroupCreated: (String groupID, String groupName, String? avatar) {
            _openChat(
              ConversationInfo(
                conversationID: 'group_$groupID',
                title: groupName,
                avatarURL: avatar,
                type: ConversationType.group,
              ),
            );
          },
        ),
      ),
    );
  }

  void _onSelectContact(FriendSearchInfo friendSearchInfo) {
    final displayName = friendSearchInfo.friendRemark?.isNotEmpty == true
        ? friendSearchInfo.friendRemark!
        : (friendSearchInfo.userInfo?.nickname?.isNotEmpty == true
            ? friendSearchInfo.userInfo!.nickname!
            : friendSearchInfo.userID);

    _openChat(
      ConversationInfo(
        conversationID: 'c2c_${friendSearchInfo.userID}',
        title: displayName,
        avatarURL: friendSearchInfo.userInfo?.avatarURL,
        type: ConversationType.c2c,
      ),
    );
  }

  void _onSelectGroup(GroupSearchInfo groupSearchInfo) {
    _openChat(
      ConversationInfo(
        conversationID: 'group_${groupSearchInfo.groupID}',
        title: groupSearchInfo.groupName.isNotEmpty
            ? groupSearchInfo.groupName
            : groupSearchInfo.groupID,
        avatarURL: groupSearchInfo.groupAvatarURL,
        type: ConversationType.group,
      ),
    );
  }

  void _onSelectConversation(MessageSearchResultItem result) {
    _openChat(
      ConversationInfo(
        conversationID: result.conversationID,
        title: result.conversationShowName,
        avatarURL: result.conversationAvatarURL,
        type: result.conversationID.startsWith('c2c_')
            ? ConversationType.c2c
            : ConversationType.group,
      ),
    );
  }

  Future<void> _onSelectMessage(MessageInfo messageInfo) async {
    final conversationID =
        messageInfo.groupID != null && messageInfo.groupID!.isNotEmpty
            ? 'group_${messageInfo.groupID}'
            : 'c2c_${messageInfo.receiver ?? messageInfo.sender.userID}';

    final conversationListStore = ConversationListStore.create();
    await conversationListStore.fetchConversationInfo(
        conversationID: conversationID);

    final conversation =
        conversationListStore.conversationListState.conversationList.firstWhere(
      (item) => item.conversationID == conversationID,
      orElse: () => ConversationInfo(
        conversationID: conversationID,
        title: messageInfo.sender.nickname ?? messageInfo.sender.userID,
        avatarURL: messageInfo.sender.avatarURL,
        type: conversationID.startsWith('c2c_')
            ? ConversationType.c2c
            : ConversationType.group,
      ),
    );

    if (!mounted) return;
    _openChat(conversation, message: messageInfo);
  }

  @override
  Widget build(BuildContext context) {
    final colorsTheme = BaseThemeProvider.colorsOf(context);
    final atomicLocale = AtomicLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorsTheme.bgColorOperate,
      appBar: AppBar(
        backgroundColor: colorsTheme.bgColorOperate,
        automaticallyImplyLeading: false,
        leading: widget.onBackPressed == null
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: colorsTheme.buttonColorPrimaryDefault),
                onPressed: widget.onBackPressed,
              ),
        title: Text(
          atomicLocale.chat,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            color: colorsTheme.textColorPrimary,
          ),
        ),
        centerTitle: false,
        scrolledUnderElevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.add, color: colorsTheme.buttonColorPrimaryDefault),
            offset: const Offset(0, 40),
            padding: EdgeInsets.zero,
            color: colorsTheme.bgColorDialog,
            onSelected: (value) {
              switch (value) {
                case _startC2CChatMenuValue:
                  _startC2CChat();
                  break;
                case _startGroupChatMenuValue:
                  _startGroupChat();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: _startC2CChatMenuValue,
                child: Row(
                  children: [
                    Icon(Icons.chat_outlined,
                        color: colorsTheme.textColorPrimary),
                    const SizedBox(width: 8),
                    Text(
                      atomicLocale.startConversation,
                      style: TextStyle(color: colorsTheme.textColorPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: _startGroupChatMenuValue,
                child: Row(
                  children: [
                    Icon(Icons.group_add_outlined,
                        color: colorsTheme.textColorPrimary),
                    const SizedBox(width: 8),
                    Text(
                      atomicLocale.createGroupChat,
                      style: TextStyle(color: colorsTheme.textColorPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!AppBuilder.getInstance().searchConfig.hideSearch)
            SearchBar(
              onContactSelect: _onSelectContact,
              onGroupSelect: _onSelectGroup,
              onConversationSelect: _onSelectConversation,
              onMessageSelect: _onSelectMessage,
            ),
          Expanded(
            child: ConversationList(
              onConversationClick: _openChat,
            ),
          ),
        ],
      ),
    );
  }
}

class TUIKitContactsScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const TUIKitContactsScreen({
    super.key,
    this.onBackPressed,
  });

  @override
  State<TUIKitContactsScreen> createState() => _TUIKitContactsScreenState();
}

class _TUIKitContactsScreenState extends State<TUIKitContactsScreen> {
  final _imService = TencentIMService();
  final _userRepository = UserRepository(apiClient: ApiClient());
  final Map<String, app_user.User?> _userCache = {};
  List<V2TimFriendInfo> _friends = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final friends = await _imService.getFriendList();
      final lookups = await Future.wait(
        friends.map((friend) async {
          try {
            final user = await _userRepository.lookupUser(query: friend.userID);
            return MapEntry(friend.userID, user);
          } catch (_) {
            return MapEntry(friend.userID, null);
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _userCache
          ..clear()
          ..addEntries(lookups);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '通讯录加载失败，请稍后重试';
      });
    }
  }

  String _displayName(V2TimFriendInfo friend) {
    final remark = friend.friendRemark?.trim();
    if (remark != null && remark.isNotEmpty) return remark;

    final user = _userCache[friend.userID];
    if (user != null && user.name.trim().isNotEmpty) return user.name.trim();

    final nick = friend.userProfile?.nickName?.trim();
    if (nick != null && nick.isNotEmpty) {
      return nick.replaceFirst(RegExp(r'\s*·\s*(管理员|项目经理|工人)$'), '');
    }

    return friend.userID;
  }

  String? _roleLabel(String userID) {
    switch (_userCache[userID]?.role) {
      case 'admin':
        return '管理员';
      case 'manager':
        return '项目经理';
      default:
        return null;
    }
  }

  Color _roleColor(String role, SemanticColorScheme colors) {
    if (role == '管理员') return const Color(0xFF10B981);
    return colors.buttonColorPrimaryDefault;
  }

  void _openChat(String userID, String title, String? avatarURL) async {
    final conversationID = '$c2cConversationIDPrefix$userID';
    final conversationListStore = ConversationListStore.create();
    await conversationListStore.fetchConversationInfo(
      conversationID: conversationID,
    );
    final conversation =
        conversationListStore.conversationListState.conversationList.firstWhere(
      (item) => item.conversationID == conversationID,
      orElse: () => ConversationInfo(
        conversationID: conversationID,
        title: title,
        avatarURL: avatarURL,
        type: ConversationType.c2c,
      ),
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(conversation: conversation),
      ),
    );
  }

  void _openContactSetting(V2TimFriendInfo friend) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => C2CChatSetting(
              userID: friend.userID,
              onSendMessageClick: ({String? userID, String? groupID}) {
                final id = userID ?? friend.userID;
                _openChat(
                  id,
                  _displayName(friend),
                  friend.userProfile?.faceUrl,
                );
              },
            ),
          ),
        )
        .then((_) => _loadFriends());
  }

  void _openAddFriend() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFriend()),
    ).then((_) => _loadFriends());
  }

  void _openAddGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddGroup()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final atomicLocale = AtomicLocalizations.of(context);
    final colors = BaseThemeProvider.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.bgColorOperate,
      appBar: AppBar(
        backgroundColor: colors.bgColorOperate,
        automaticallyImplyLeading: false,
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: colors.buttonColorPrimaryDefault,
                ),
                onPressed: widget.onBackPressed,
              )
            : null,
        title: Text(
          atomicLocale.contact,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            color: colors.textColorPrimary,
          ),
        ),
        centerTitle: false,
        scrolledUnderElevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.add, color: colors.textColorPrimary),
            offset: const Offset(0, 40),
            color: colors.bgColorDialog,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (value) {
              if (value == _addFriendMenuValue) _openAddFriend();
              if (value == _addGroupMenuValue) _openAddGroup();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: _addFriendMenuValue,
                child: Row(
                  children: [
                    Icon(Icons.person_add, color: colors.textColorPrimary),
                    const SizedBox(width: 8),
                    Text(
                      atomicLocale.addFriend,
                      style: TextStyle(color: colors.textColorPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: _addGroupMenuValue,
                child: Row(
                  children: [
                    Icon(Icons.group_add, color: colors.textColorPrimary),
                    const SizedBox(width: 8),
                    Text(
                      atomicLocale.addGroup,
                      style: TextStyle(color: colors.textColorPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFriends,
        child: _buildBody(colors),
      ),
    );
  }

  Widget _buildBody(SemanticColorScheme colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 160),
          Icon(Icons.error_outline, color: colors.textColorError, size: 42),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _error!,
              style: TextStyle(color: colors.textColorSecondary),
            ),
          ),
        ],
      );
    }

    if (_friends.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 160),
          Icon(Icons.people_outline,
              color: colors.textColorSecondary, size: 42),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '暂无联系人',
              style: TextStyle(color: colors.textColorSecondary),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _friends.length,
      separatorBuilder: (_, __) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 72),
        color: colors.strokeColorPrimary,
      ),
      itemBuilder: (context, index) =>
          _buildFriendTile(_friends[index], colors),
    );
  }

  Widget _buildFriendTile(V2TimFriendInfo friend, SemanticColorScheme colors) {
    final name = _displayName(friend);
    final role = _roleLabel(friend.userID);
    final avatarURL = friend.userProfile?.faceUrl;

    return InkWell(
      onTap: () => _openContactSetting(friend),
      child: Container(
        color: colors.listColorDefault,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Avatar.image(name: name, url: avatarURL),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textColorPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (role != null) ...[
                    const SizedBox(width: 8),
                    _RoleBadge(
                      label: role,
                      color: _roleColor(role, colors),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.scrollbarColorHover),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RoleBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}
