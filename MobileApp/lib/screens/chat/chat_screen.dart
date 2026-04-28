import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../blocs/chat_settings/chat_settings_cubit.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../models/chat_quote_codec.dart';
import '../../repositories/chat_cache_repository.dart';
import '../../repositories/contact_remark_repository.dart';
import '../../widgets/bento_widgets.dart';
import '../../services/openim_service.dart' as im_service;

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String name;
  final bool isGroup;
  final String? receiverId;
  final String? faceUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.name,
    this.isGroup = false,
    this.receiverId,
    this.faceUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final _imService = im_service.OpenIMService();
  final _cacheRepo = ChatCacheRepository();
  final _remarkRepo = ContactRemarkRepository();
  String? _remarkName;
  String? _customAvatar;

  bool _showEmoji = false;
  bool _showMore = false;
  List<_ChatListItem> _messages = [];
  bool _isLoading = true;
  StreamSubscription? _messageSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription? _imConnectionSubscription;
  Timer? _markReadTimer;
  final Map<String, Timer> _sendTimeoutTimers = {};
  final Map<String, Timer> _sendRetryTimers = {};
  final Set<String> _sendingIds = {};
  Timer? _cacheDebounce;
  bool _deleteMenuOpen = false;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  _ChatListItem? _quotedMessage;
  String? _replyDragId;
  double _replyDragDx = 0;
  String? _toastText;
  Timer? _toastTimer;
  Set<String> _deletedIds = {};

  void _sortMessages() {
    _messages.sort((a, b) {
      final at = a.sendTime ?? 0;
      final bt = b.sendTime ?? 0;
      if (at != bt) return at.compareTo(bt);
      return a.id.compareTo(b.id);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadRemark();
    _loadMessages();
    _listenNewMessages();
    _listenConnectivity();
    _scheduleMarkAsRead();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_handleFocusChange);
  }

  String _remarkKey() => widget.isGroup ? 'g_${widget.receiverId ?? ''}' : 'u_${widget.receiverId ?? ''}';

  Future<void> _loadRemark() async {
    final v = await _remarkRepo.getRemark(_remarkKey());
    final a = await _remarkRepo.getCustomAvatar(_remarkKey());
    if (!mounted) return;
    setState(() {
      _remarkName = v;
      _customAvatar = a;
    });
  }

  Future<void> _editRemark() async {
    final controller = TextEditingController(text: _remarkName ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('设置备注'),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: '请输入备注')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        );
      },
    );
    if (ok != true) return;
    await _remarkRepo.setRemark(_remarkKey(), controller.text);
    await _loadRemark();
  }

  void _onScroll() {
    if (!_deleteMenuOpen) return;
    _deleteMenuOpen = false;
    Navigator.of(context).maybePop();
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _showInlineToast(String text) {
    _toastTimer?.cancel();
    setState(() {
      _toastText = text;
    });
    _toastTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _toastText = null);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectMode = false;
    });
  }

  void _setQuote(_ChatListItem message) {
    setState(() {
      _quotedMessage = message;
      _showMore = false;
      _showEmoji = false;
    });
    _focusNode.requestFocus();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus || !mounted) return;
    if (_showEmoji || _showMore) {
      setState(() {
        _showEmoji = false;
        _showMore = false;
      });
    }
    _scrollToBottom();
  }

  void _listenConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((r) {
      final online = r.isNotEmpty && !r.contains(ConnectivityResult.none);
      if (online) _retryPendingSends();
    });

    _imConnectionSubscription = _imService.connectionStream.listen((s) {
      if (s == im_service.ConnectionState.connected) _retryPendingSends();
    });
  }

  void _retryPendingSends() {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final m
        in _messages.where((e) => e.status == _MessageSendStatus.sending)) {
      if (m.sendTime != null && now - m.sendTime! >= 30000) continue;
      unawaited(_sendLocalText(m));
    }
  }

  void _scheduleMarkAsRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: 300), () async {
      await _imService.markConversationMessageAsRead(widget.conversationId);
    });
  }

  void _listenNewMessages() {
    _messageSubscription = _imService.messageStream.listen((msg) {
      if (!mounted) return;
      // 判断是否是当前会话的消息
      // sessionType: 1=单聊(C2C), 2=群聊(Group), 3=通知
      final isCurrentConv = !widget.isGroup
          ? (msg.sendID == widget.receiverId || msg.recvID == widget.receiverId)
          : msg.groupID == widget.receiverId;
      if (isCurrentConv) {
        final rawText = _extractRawTextFromRemote(msg);
        final incoming = _ChatListItem.fromRemoteMessage(
          msg,
          status: _MessageSendStatus.sent,
          digest: _imService.getMessageDigest(msg),
          rawText: rawText,
        );
        if (_deletedIds.contains(incoming.id)) return;
        final id = msg.clientMsgID ?? '';
        setState(() {
          final existingIndex =
              id.isEmpty ? -1 : _messages.indexWhere((m) => m.id == id);
          if (existingIndex >= 0) {
            _messages[existingIndex] = incoming;
          } else {
            _messages.add(incoming);
          }
          _sortMessages();
        });
        if (id.isNotEmpty) {
          _cancelSendTimeout(id);
        }
        _scheduleMarkAsRead();
        _scrollToBottom();
        _scheduleWriteCache();
      }
    });
  }

  Future<void> _loadMessages() async {
    _deletedIds = await _cacheRepo.readDeletedIds(widget.conversationId);
    final cached = await _cacheRepo.readMessages(widget.conversationId);
    if (!mounted) return;

    if (cached.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _messages = cached
            .map(
              (m) => _ChatListItem.fromCache(
                m,
                status: _MessageSendStatusX.fromStorage(m.status) ==
                            _MessageSendStatus.sending &&
                        m.sendTime != null &&
                        now - m.sendTime! >= 30000
                    ? _MessageSendStatus.failed
                    : _MessageSendStatusX.fromStorage(m.status),
              ),
            )
            .where((m) => !_deletedIds.contains(m.id))
            .toList();
        _sortMessages();
        _isLoading = false;
      });
      for (final m
          in _messages.where((e) => e.status == _MessageSendStatus.sending)) {
        _startSendTimeout(m.id);
      }
      _scrollToBottom();
    }

    unawaited(_refreshMessagesFromRemote());
  }

  Future<void> _refreshMessagesFromRemote() async {
    if (!_imService.isLoggedIn) {
      if (mounted && _messages.isEmpty) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final messages = await _imService.getHistoryMessages(
        conversationID: widget.conversationId,
        count: 50,
      );

      if (!mounted) return;
      final pending =
          _messages.where((m) => m.status != _MessageSendStatus.sent).toList();
      final remoteItems = messages
          .map(
            (m) => _ChatListItem.fromRemoteMessage(
              m,
              status: _MessageSendStatus.sent,
              digest: _imService.getMessageDigest(m),
              rawText: _extractRawTextFromRemote(m),
            ),
          )
          .where((m) => !_deletedIds.contains(m.id))
          .toList();
      final remoteIds = remoteItems.map((e) => e.id).toSet();
      final merged = [
        ...remoteItems,
        ...pending.where((e) => !remoteIds.contains(e.id)),
      ];

      setState(() {
        _messages = merged;
        _sortMessages();
        _isLoading = false;
      });

      _scheduleMarkAsRead();
      _scrollToBottom();
      await _writeCacheNow();
    } catch (e) {
      print('加载消息失败: $e');
      if (mounted && _messages.isEmpty) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scheduleWriteCache() {
    _cacheDebounce?.cancel();
    _cacheDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _writeCacheNow();
    });
  }

  Future<void> _writeCacheNow() async {
    final cached = _messages
        .map(
          (m) => ChatCachedMessage(
            id: m.id,
            sendID: m.sendID,
            senderNickname: m.senderNickname,
            text: m.text,
            originalText: m.originalText,
            quoteSenderNickname: m.quoteSenderNickname,
            quoteText: m.quoteText,
            sendTime: m.sendTime,
            status: m.status.storageValue,
          ),
        )
        .toList();
    await _cacheRepo.writeMessages(widget.conversationId, cached);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _imConnectionSubscription?.cancel();
    _markReadTimer?.cancel();
    _cacheDebounce?.cancel();
    _toastTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    for (final t in _sendTimeoutTimers.values) {
      t.cancel();
    }
    _sendTimeoutTimers.clear();
    for (final t in _sendRetryTimers.values) {
      t.cancel();
    }
    _sendRetryTimers.clear();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(colors, theme),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(colors, theme),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showEmoji) _buildEmojiPicker(colors, theme),
                if (_showMore) _buildMorePanel(colors, theme),
                if (_toastText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.textPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _toastText!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.textSecondary.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                _buildInputBar(colors, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BentoColors colors, ThemeData theme) {
    if (_selectMode) {
      return AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: _exitSelectMode,
        ),
        title: Text(
          '已选 ${_selectedIds.length}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.copy, color: colors.textPrimary),
            onPressed: _selectedIds.isEmpty ? null : _copySelected,
          ),
          IconButton(
            icon: Icon(Icons.forward_to_inbox, color: colors.textPrimary),
            onPressed: _selectedIds.isEmpty ? null : _forwardSelected,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.error),
            onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
          ),
        ],
      );
    }
    final displayName = (_remarkName != null && _remarkName!.trim().isNotEmpty) ? _remarkName!.trim() : widget.name;
    return AppBar(
      backgroundColor: colors.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: colors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.receiverId == null ? null : _editRemark,
        child: Row(
          children: [
            BentoAvatar(
              size: 36,
              imageUrl: _customAvatar ?? widget.faceUrl,
              text: displayName,
              backgroundColor: widget.isGroup ? colors.secondaryLight : colors.primaryLight,
              textColor: widget.isGroup ? colors.secondary : colors.primary,
            ),
            const SizedBox(width: BentoSpacing.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.isGroup)
                    Text(
                      '群聊',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_horiz, color: colors.textPrimary),
          onPressed: () => _showChatOptions(context),
        ),
      ],
    );
  }

  Widget _buildMessageList(BentoColors colors, ThemeData theme) {
    if (_isLoading) {
      return const BentoLoading.spinner();
    }

    if (!_imService.isInitialized && _messages.isEmpty) {
      return BentoEmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'IM 未初始化',
        description: '请稍候再试',
      );
    }

    if (_messages.isEmpty) {
      return BentoEmptyState(
        icon: Icons.chat_outlined,
        title: '暂无消息',
        description: '发送第一条消息开始聊天',
      );
    }

    return Container(
      color: colors.background,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(BentoSpacing.space16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _buildMessageItem(message, colors, theme);
        },
      ),
    );
  }

  Widget _buildMessageItem(
      _ChatListItem message, BentoColors colors, ThemeData theme) {
    final isMe = message.sendID == _imService.currentUserID;
    final content = message.text.isNotEmpty ? message.text : '[消息]';
    final selected = _selectedIds.contains(message.id);
    final use24Hour = context.watch<ChatSettingsCubit>().state.use24Hour;
    final sendTime = message.sendTime != null
        ? DateTime.fromMillisecondsSinceEpoch(message.sendTime!)
        : null;
    final timeText = sendTime == null
        ? null
        : DateFormat(use24Hour ? 'HH:mm' : 'a h:mm', 'zh_CN').format(sendTime);
    const avatarSize = 32.0;
    const gap = BentoSpacing.space8;
    const tailWidth = 8.0;
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (timeText != null)
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : avatarSize + gap + tailWidth,
                right: isMe ? avatarSize + gap + tailWidth : 0,
                bottom: 6,
              ),
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  timeText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                BentoAvatar(
                  size: avatarSize,
                  text: message.senderNickname ?? '用户',
                  backgroundColor: colors.primaryLight,
                  textColor: colors.primary,
                ),
                const SizedBox(width: gap),
              ],
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _selectMode ? () => _toggleSelect(message.id) : null,
                  onLongPress:
                      _selectMode ? () => _toggleSelect(message.id) : null,
                  onLongPressStart: _selectMode
                      ? null
                      : (d) => _showMessageMenu(d.globalPosition, message),
                  onHorizontalDragStart: (!isMe && !_selectMode)
                      ? (_) {
                          _replyDragId = message.id;
                          _replyDragDx = 0;
                        }
                      : null,
                  onHorizontalDragUpdate: (!isMe && !_selectMode)
                      ? (d) {
                          if (_replyDragId != message.id) return;
                          if (d.delta.dx <= 0) return;
                          _replyDragDx += d.delta.dx;
                          if (_replyDragDx >= 28) {
                            _replyDragId = null;
                            _replyDragDx = 0;
                            _setQuote(message);
                          }
                        }
                      : null,
                  onHorizontalDragEnd: (!isMe && !_selectMode)
                      ? (_) {
                          if (_replyDragId == message.id) {
                            _replyDragId = null;
                            _replyDragDx = 0;
                          }
                        }
                      : null,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: maxBubbleWidth,
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: _ChatBubble(
                                isMe: isMe,
                                backgroundColor: isMe
                                    ? colors.primary
                                    : colors.surfaceVariant,
                                textColor: isMe
                                    ? colors.textOnPrimary
                                    : colors.textPrimary,
                                text: content,
                                textStyle: theme.textTheme.bodyMedium,
                              ),
                            ),
                            if (isMe &&
                                message.quoteText != null &&
                                (message.quoteText ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxWidth: maxBubbleWidth),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: colors.textPrimary
                                            .withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${message.quoteSenderNickname ?? '用户'}: ${message.quoteText}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colors.textSecondary
                                              .withValues(alpha: 0.9),
                                          fontSize: 11,
                                          height: 1.25,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_selectMode)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color:
                                    selected ? colors.primary : colors.surface,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: selected
                                      ? colors.primary
                                      : colors.textTertiary
                                          .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: gap),
                _buildSendStatusIndicator(message, colors),
                const SizedBox(width: gap),
                BentoAvatar(
                  size: avatarSize,
                  text: '我',
                  backgroundColor: colors.secondaryLight,
                  textColor: colors.secondary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BentoColors colors, ThemeData theme) {
    final radius = BorderRadius.circular(BentoRadius.xl);
    return Container(
      padding: EdgeInsets.only(
        left: BentoSpacing.space12,
        right: BentoSpacing.space12,
        top: BentoSpacing.space8,
        bottom: MediaQuery.paddingOf(context).bottom + BentoSpacing.space8,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _quotedMessage == null
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_quotedMessage!.senderNickname ?? '用户'}: ${_quotedMessage!.text}',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _quotedMessage = null),
                          child: Icon(Icons.close,
                              size: 18, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                  color: colors.textSecondary,
                ),
                onPressed: () {
                  if (!_showEmoji) {
                    _focusNode.unfocus();
                  } else {
                    _focusNode.requestFocus();
                  }
                  setState(() {
                    _showEmoji = !_showEmoji;
                    _showMore = false;
                  });
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.surfaceVariant,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: BentoSpacing.space12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide:
                          BorderSide(color: colors.surfaceVariant, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide:
                          BorderSide(color: colors.surfaceVariant, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide(color: colors.primary, width: 1.2),
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  onTap: () {
                    if (_showEmoji || _showMore) {
                      setState(() {
                        _showEmoji = false;
                        _showMore = false;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: colors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _showMore = !_showMore;
                    _showEmoji = false;
                  });
                  _focusNode.unfocus();
                },
              ),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(BentoRadius.lg),
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker(BentoColors colors, ThemeData theme) {
    final emojis = [
      '😀',
      '😂',
      '🥰',
      '😎',
      '🤔',
      '👍',
      '👏',
      '🙏',
      '💪',
      '❤️',
      '🎉',
      '🔥'
    ];
    return Container(
      height: 120,
      padding: const EdgeInsets.all(BentoSpacing.space12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _messageController.text += emojis[index];
            },
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 28)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMorePanel(BentoColors colors, ThemeData theme) {
    final items = [
      {'icon': Icons.photo, 'label': '图片', 'color': colors.success},
      {'icon': Icons.camera_alt, 'label': '拍照', 'color': colors.warning},
      {'icon': Icons.insert_drive_file, 'label': '文件', 'color': colors.primary},
      {'icon': Icons.location_on, 'label': '位置', 'color': colors.error},
    ];

    return Container(
      height: 120,
      padding: const EdgeInsets.all(BentoSpacing.space16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: BentoSpacing.space16,
          crossAxisSpacing: BentoSpacing.space16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {},
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['label'] as String,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (widget.receiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法发送消息：缺少接收者信息')),
      );
      return;
    }

    final quote = _quotedMessage;
    final payloadText = encodeChatQuote(
      bodyText: text,
      quoteSenderNickname: quote?.senderNickname,
      quoteText: quote?.text,
    );

    _messageController.clear();
    setState(() => _quotedMessage = null);

    final localId =
        'local_${DateTime.now().millisecondsSinceEpoch}_${payloadText.hashCode}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = _ChatListItem(
      id: localId,
      text: text,
      originalText: payloadText,
      quoteSenderNickname: quote?.senderNickname,
      quoteText: quote?.text,
      sendID: _imService.currentUserID,
      senderNickname: '我',
      sendTime: now,
      status: _MessageSendStatus.sending,
    );

    setState(() {
      _messages.add(item);
      _sortMessages();
    });
    _scrollToBottom();
    _scheduleWriteCache();
    _startSendTimeout(localId);

    unawaited(_sendLocalText(item));
  }

  Future<void> _sendLocalText(_ChatListItem item) async {
    if (_sendingIds.contains(item.id)) return;
    if (widget.receiverId == null) return;
    if (!_imService.isLoggedIn) return;

    _sendingIds.add(item.id);
    final text = item.originalText ?? item.text;
    dynamic result;
    try {
      result = await _imService.sendTextMessage(
        receiverID: widget.receiverId!,
        text: text,
        isGroup: widget.isGroup,
      );
    } catch (_) {
      result = null;
    } finally {
      _sendingIds.remove(item.id);
    }

    if (!mounted) return;
    if (result == null) {
      _scheduleRetry(item.id);
      return;
    }

    _markSendSucceeded(item.id, result);
    await _refreshMessagesFromRemote();
  }

  void _startSendTimeout(String id) {
    _cancelSendTimeout(id);
    _sendTimeoutTimers[id] = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx < 0) return;
      if (_messages[idx].status == _MessageSendStatus.sending) {
        _markSendFailed(id);
      }
    });
  }

  void _cancelSendTimeout(String id) {
    final t = _sendTimeoutTimers.remove(id);
    t?.cancel();
  }

  void _scheduleRetry(String id) {
    _sendRetryTimers[id]?.cancel();
    _sendRetryTimers[id] = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx < 0) return;
      final m = _messages[idx];
      if (m.status != _MessageSendStatus.sending) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (m.sendTime != null && now - m.sendTime! >= 30000) return;
      unawaited(_sendLocalText(m));
    });
  }

  void _markSendFailed(String id) {
    _cancelSendTimeout(id);
    _sendRetryTimers.remove(id)?.cancel();
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    setState(() {
      _messages[idx] =
          _messages[idx].copyWith(status: _MessageSendStatus.failed);
    });
    _scheduleWriteCache();
  }

  void _markSendSucceeded(String localId, dynamic msg) {
    final id = msg.clientMsgID ?? localId;
    _cancelSendTimeout(localId);
    _cancelSendTimeout(id);
    _sendRetryTimers.remove(localId)?.cancel();
    _sendRetryTimers.remove(id)?.cancel();
    final idx = _messages.indexWhere((m) => m.id == localId || m.id == id);
    if (idx < 0) return;
    final rawText = _extractRawTextFromRemote(msg);
    setState(() {
      _messages[idx] = _ChatListItem.fromRemoteMessage(
        msg,
        status: _MessageSendStatus.sent,
        digest: _imService.getMessageDigest(msg),
        rawText: rawText,
      );
      _sortMessages();
    });
    _scheduleWriteCache();
  }

  Widget _buildSendStatusIndicator(_ChatListItem message, BentoColors colors) {
    if (message.status == _MessageSendStatus.sending) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            colors.textSecondary.withValues(alpha: 0.65),
          ),
        ),
      );
    }
    if (message.status == _MessageSendStatus.failed) {
      return GestureDetector(
        onTap: () => _promptResend(message),
        child: Icon(
          Icons.error_outline,
          size: 18,
          color: colors.error,
        ),
      );
    }
    return const SizedBox(width: 16, height: 16);
  }

  Future<void> _promptResend(_ChatListItem message) async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('发送失败'),
          content: const Text('是否重发该消息？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重发'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx < 0) return;

    final updated = _messages[idx].copyWith(
      status: _MessageSendStatus.sending,
      sendTime: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      _messages[idx] = updated;
    });
    _scheduleWriteCache();
    _startSendTimeout(updated.id);
    unawaited(_sendLocalText(updated));
  }

  Future<void> _copySelected() async {
    final texts = _messages
        .where((m) => _selectedIds.contains(m.id))
        .map((m) => m.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (texts.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texts.join('\n')));
    if (!mounted) return;
    _showInlineToast('已复制');
    _exitSelectMode();
  }

  Future<void> _forwardSelected() async {
    final texts = _messages
        .where((m) => _selectedIds.contains(m.id))
        .map((m) => m.originalText ?? m.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (texts.isEmpty) return;
    await _promptForward(texts.join('\n'));
    if (!mounted) return;
    _exitSelectMode();
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    for (final id in ids) {
      await _cacheRepo.addDeletedId(widget.conversationId, id);
      _deletedIds.add(id);
    }
    for (final id in ids) {
      _cancelSendTimeout(id);
      _sendRetryTimers.remove(id)?.cancel();
    }
    setState(() {
      _messages.removeWhere((m) => _selectedIds.contains(m.id));
      _selectedIds.clear();
      _selectMode = false;
    });
    await _writeCacheNow();
  }

  Future<void> _promptForward(String text) async {
    if (!_imService.isLoggedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('网络连接中，请稍候')));
      return;
    }

    if (text.trim().isEmpty) return;
    final colors = context.colors;
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: FutureBuilder<List<dynamic>>(
            future: _imService.getAllConversations(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? const [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(BentoSpacing.space20),
                  child: BentoLoading.spinner(),
                );
              }
              if (data.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(BentoSpacing.space20),
                  child: Text('暂无会话', style: theme.textTheme.bodyMedium),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(BentoSpacing.space12),
                itemCount: data.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colors.divider),
                itemBuilder: (context, index) {
                  final conv = data[index];
                  final isGroup =
                      conv.groupID != null && conv.groupID!.isNotEmpty;
                  final name = conv.showName ?? (isGroup ? '群聊' : '用户');
                  return ListTile(
                    leading: BentoAvatar(
                      size: 40,
                      text: name,
                      backgroundColor:
                          isGroup ? colors.secondaryLight : colors.primaryLight,
                      textColor: isGroup ? colors.secondary : colors.primary,
                    ),
                    title: Text(name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () async {
                      final target = isGroup ? conv.groupID : conv.userID;
                      if (target == null || target.isEmpty) return;
                      await _imService.sendTextMessage(
                        receiverID: target,
                        text: text,
                        isGroup: isGroup,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context)
                          .showSnackBar(const SnackBar(content: Text('已转发')));
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteMessageLocal(_ChatListItem message) async {
    await _cacheRepo.addDeletedId(widget.conversationId, message.id);
    _deletedIds.add(message.id);
    _cancelSendTimeout(message.id);
    _sendRetryTimers.remove(message.id)?.cancel();
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
    await _cacheRepo.removeMessage(widget.conversationId, message.id);
  }

  Future<void> _showMessageMenu(
      Offset globalPosition, _ChatListItem message) async {
    final colors = context.colors;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final size = overlay.size;

    const itemHeight = 44.0;
    const menuWidth = 200.0;
    const menuHeight = itemHeight * 5;
    const margin = 8.0;

    final showAbove = globalPosition.dy > size.height * 0.6;
    final y = (showAbove
            ? globalPosition.dy - menuHeight - 12
            : globalPosition.dy + 12)
        .clamp(margin, size.height - menuHeight - margin);
    final x = (globalPosition.dx - menuWidth / 2)
        .clamp(margin, size.width - menuWidth - margin);

    final position = RelativeRect.fromLTRB(
      x,
      y,
      size.width - x - menuWidth,
      size.height - y - menuHeight,
    );

    _deleteMenuOpen = true;
    final action = await showMenu<String>(
      context: context,
      color: colors.surface,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: position,
      items: [
        PopupMenuItem(
          value: 'copy',
          height: itemHeight,
          child: Row(
            children: [
              Icon(Icons.copy, color: colors.textPrimary, size: 18),
              const SizedBox(width: 10),
              const Text('复制'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'forward',
          height: itemHeight,
          child: Row(
            children: [
              Icon(Icons.forward_to_inbox, color: colors.textPrimary, size: 18),
              const SizedBox(width: 10),
              const Text('转发'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          height: itemHeight,
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: colors.error, size: 18),
              const SizedBox(width: 10),
              const Text('删除'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'multi',
          height: itemHeight,
          child: Row(
            children: [
              Icon(Icons.checklist, color: colors.textPrimary, size: 18),
              const SizedBox(width: 10),
              const Text('多选'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'quote',
          height: itemHeight,
          child: Row(
            children: [
              Icon(Icons.format_quote, color: colors.textPrimary, size: 18),
              const SizedBox(width: 10),
              const Text('引用'),
            ],
          ),
        ),
      ],
    );
    _deleteMenuOpen = false;

    if (!mounted) return;
    if (action == null) return;

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (mounted) {
        _showInlineToast('已复制');
      }
      return;
    }
    if (action == 'forward') {
      await _promptForward(message.originalText ?? message.text);
      return;
    }
    if (action == 'delete') {
      await _deleteMessageLocal(message);
      return;
    }
    if (action == 'multi') {
      setState(() {
        _selectMode = true;
        _selectedIds
          ..clear()
          ..add(message.id);
      });
      return;
    }
    if (action == 'quote') {
      _setQuote(message);
      return;
    }
  }

  void _showChatOptions(BuildContext context) {
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
              leading: Icon(Icons.search, color: colors.primary),
              title: const Text('查找聊天记录'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading:
                  Icon(Icons.notifications_off_outlined, color: colors.warning),
              title: const Text('消息免打扰'),
              onTap: () => Navigator.pop(context),
            ),
            if (widget.isGroup)
              ListTile(
                leading: Icon(Icons.group, color: colors.secondary),
                title: const Text('群成员'),
                onTap: () => Navigator.pop(context),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.error),
              title: const Text('清空聊天记录'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractRawTextFromRemote(dynamic msg) {
    try {
      final raw = msg.textElem?.content ??
          msg.advancedTextElem?.text ??
          msg.atTextElem?.text;
      if (raw is String && raw.isNotEmpty) return raw;
    } catch (e) {
      debugPrint('提取消息文本失败: $e');
    }
    return null;
  }
}

enum _MessageSendStatus { sent, sending, failed }

extension _MessageSendStatusX on _MessageSendStatus {
  String get storageValue {
    switch (this) {
      case _MessageSendStatus.sent:
        return 'sent';
      case _MessageSendStatus.sending:
        return 'sending';
      case _MessageSendStatus.failed:
        return 'failed';
    }
  }

  static _MessageSendStatus fromStorage(String raw) {
    switch (raw) {
      case 'sending':
        return _MessageSendStatus.sending;
      case 'failed':
        return _MessageSendStatus.failed;
      default:
        return _MessageSendStatus.sent;
    }
  }
}

class _ChatListItem {
  final String id;
  final String text;
  final String? originalText;
  final String? quoteSenderNickname;
  final String? quoteText;
  final String? sendID;
  final String? senderNickname;
  final int? sendTime;
  final _MessageSendStatus status;

  const _ChatListItem({
    required this.id,
    required this.text,
    required this.status,
    this.originalText,
    this.quoteSenderNickname,
    this.quoteText,
    this.sendID,
    this.senderNickname,
    this.sendTime,
  });

  factory _ChatListItem.fromRemoteMessage(
    dynamic message, {
    required _MessageSendStatus status,
    required String digest,
    required String? rawText,
  }) {
    final rawId = (message.clientMsgID as String?) ?? '';
    final sendTime = message.sendTime as int?;
    final sendID = message.sendID as String?;
    final effectiveRaw =
        (rawText != null && rawText.isNotEmpty) ? rawText : digest;
    final decoded = decodeChatQuote(effectiveRaw);
    final body = decoded.bodyText.isNotEmpty ? decoded.bodyText : digest;
    final id = rawId.isNotEmpty
        ? rawId
        : 'remote_${sendTime ?? 0}_${sendID ?? 'unknown'}_${effectiveRaw.hashCode}';
    return _ChatListItem(
      id: id,
      text: body,
      originalText: effectiveRaw,
      quoteSenderNickname: decoded.quoteSenderNickname,
      quoteText: decoded.quoteText,
      sendID: sendID,
      senderNickname: message.senderNickname as String?,
      sendTime: sendTime,
      status: status,
    );
  }

  factory _ChatListItem.fromCache(
    ChatCachedMessage message, {
    required _MessageSendStatus status,
  }) {
    final source = (message.originalText ?? message.text);
    final decoded = decodeChatQuote(source);
    final body = decoded.bodyText.isNotEmpty ? decoded.bodyText : message.text;
    return _ChatListItem(
      id: message.id,
      text: body,
      originalText: message.originalText ?? source,
      quoteSenderNickname:
          message.quoteSenderNickname ?? decoded.quoteSenderNickname,
      quoteText: message.quoteText ?? decoded.quoteText,
      sendID: message.sendID,
      senderNickname: message.senderNickname,
      sendTime: message.sendTime,
      status: status,
    );
  }

  _ChatListItem copyWith({
    String? id,
    String? text,
    String? originalText,
    String? quoteSenderNickname,
    String? quoteText,
    String? sendID,
    String? senderNickname,
    int? sendTime,
    _MessageSendStatus? status,
  }) {
    return _ChatListItem(
      id: id ?? this.id,
      text: text ?? this.text,
      originalText: originalText ?? this.originalText,
      quoteSenderNickname: quoteSenderNickname ?? this.quoteSenderNickname,
      quoteText: quoteText ?? this.quoteText,
      sendID: sendID ?? this.sendID,
      senderNickname: senderNickname ?? this.senderNickname,
      sendTime: sendTime ?? this.sendTime,
      status: status ?? this.status,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isMe;
  final Color backgroundColor;
  final Color textColor;
  final String text;
  final TextStyle? textStyle;

  const _ChatBubble({
    required this.isMe,
    required this.backgroundColor,
    required this.textColor,
    required this.text,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    const tailWidth = 8.0;
    return ClipPath(
      clipper: _ChatBubbleClipper(isMe: isMe),
      child: ColoredBox(
        color: backgroundColor,
        child: Padding(
          padding: EdgeInsets.only(
            left: BentoSpacing.space12 + (isMe ? 0 : tailWidth),
            right: BentoSpacing.space12 + (isMe ? tailWidth : 0),
            top: BentoSpacing.space10,
            bottom: BentoSpacing.space10,
          ),
          child: Text(
            text,
            style: (textStyle ?? const TextStyle())
                .copyWith(color: textColor, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class _ChatBubbleClipper extends CustomClipper<Path> {
  final bool isMe;

  const _ChatBubbleClipper({required this.isMe});

  @override
  Path getClip(Size size) {
    const radius = 12.0;
    const tailWidth = 8.0;
    const tailHeight = 10.0;

    final bodyLeft = isMe ? 0.0 : tailWidth;
    final bodyRight = isMe ? size.width - tailWidth : size.width;

    final tailBaseTop = size.height - radius - tailHeight - 2;
    final tailBaseBottom = tailBaseTop + tailHeight;
    final tailTipY = (tailBaseTop + tailBaseBottom) / 2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(bodyLeft, 0, bodyRight, size.height),
          const Radius.circular(radius),
        ),
      );

    if (isMe) {
      path
        ..moveTo(bodyRight, tailBaseTop)
        ..lineTo(size.width, tailTipY)
        ..lineTo(bodyRight, tailBaseBottom)
        ..close();
    } else {
      path
        ..moveTo(bodyLeft, tailBaseTop)
        ..lineTo(0, tailTipY)
        ..lineTo(bodyLeft, tailBaseBottom)
        ..close();
    }

    return path;
  }

  @override
  bool shouldReclip(covariant _ChatBubbleClipper oldClipper) {
    return oldClipper.isMe != isMe;
  }
}
