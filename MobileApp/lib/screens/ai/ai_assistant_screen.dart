import 'package:flutter/material.dart';
import '../../api/dio_client.dart';
import '../../core/bento_colors.dart';
import '../../repositories/ai_repository.dart';

class AiAssistantScreen extends StatefulWidget {
  final String page;

  const AiAssistantScreen({super.key, this.page = 'mobile'});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  late final AiRepository _repository;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AiMessage> _messages = [];
  List<String> _suggestions = [];
  String? _conversationId;
  bool _loading = false;
  int? _confirmingActionId;
  bool _aiModelEnabled = false;

  @override
  void initState() {
    super.initState();
    _repository = AiRepository(apiClient: ApiClient());
    _loadSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _context => {
        'page': widget.page,
        'platform': 'mobile',
      };

  Future<void> _loadSuggestions() async {
    try {
      final items = await _repository.getSuggestions(context: _context);
      if (mounted) setState(() => _suggestions = items);
    } catch (_) {
      if (mounted) {
        setState(() => _suggestions = ['今天管理摘要', '本周异常打卡统计', '有哪些待审批申请？']);
      }
    }
  }

  Future<void> _send([String? text]) async {
    final content = (text ?? _controller.text).trim();
    if (content.isEmpty || _loading) return;

    _controller.clear();
    setState(() {
      _messages.add(_AiMessage(role: 'user', content: content));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final data = await _repository.sendMessage(
        message: content,
        conversationId: _conversationId,
        context: _context,
      );
      setState(() {
        _conversationId = data['conversationId']?.toString();
        _aiModelEnabled = data['aiModelEnabled'] == true;
        _messages.add(_AiMessage(
          role: 'assistant',
          content: data['message']?.toString() ?? '已完成查询',
          result: data['result'] is Map
              ? Map<String, dynamic>.from(data['result'])
              : null,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(_AiMessage(role: 'assistant', content: 'AI 助手暂时不可用：$e'));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  Future<void> _confirmAction(Map<String, dynamic> action) async {
    final id = int.tryParse(action['id']?.toString() ?? '');
    if (id == null) return;
    setState(() => _confirmingActionId = id);
    try {
      final result = await _repository.confirmAction(id);
      final resultPayload = result['result'];
      final message = resultPayload is Map
          ? (resultPayload['message']?.toString() ?? '操作已完成')
          : '操作已完成';
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败：$e')));
    } finally {
      if (mounted) setState(() => _confirmingActionId = null);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('境图 AI 助手'),
            Text(
              _aiModelEnabled ? '智能模型' : '本地数据模式',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _conversationId = null;
                _messages.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome(colors)
                : _buildMessages(colors),
          ),
          _buildInput(colors),
        ],
      ),
    );
  }

  Widget _buildWelcome(BentoColors colors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '今天想看哪块数据？',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((item) {
            return ActionChip(
              label: Text(item),
              onPressed: () => _send(item),
              backgroundColor: colors.primaryLight,
              labelStyle: TextStyle(color: colors.primary),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessages(BentoColors colors) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_loading && index == _messages.length) {
          return _buildBubble(
            colors,
            const _AiMessage(role: 'assistant', content: '正在查询...'),
          );
        }
        return _buildBubble(colors, _messages[index]);
      },
    );
  }

  Widget _buildBubble(BentoColors colors, _AiMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isUser ? colors.primary : colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? colors.textOnPrimary : colors.textPrimary,
                height: 1.5,
              ),
            ),
            if (message.result != null) ...[
              const SizedBox(height: 10),
              _AiResultView(
                result: message.result!,
                confirmingActionId: _confirmingActionId,
                onConfirm: _confirmAction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(BentoColors colors) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: colors.navBarBg,
          border: Border(top: BorderSide(color: colors.navBarBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '问我考勤、项目、审批或报表',
                  filled: true,
                  fillColor: colors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _loading ? null : () => _send(),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiResultView extends StatelessWidget {
  final Map<String, dynamic> result;
  final int? confirmingActionId;
  final ValueChanged<Map<String, dynamic>> onConfirm;

  const _AiResultView({
    required this.result,
    required this.confirmingActionId,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cards = result['cards'] is List ? result['cards'] as List : const [];
    final rows = result['rows'] is List ? result['rows'] as List : const [];
    final columns =
        result['columns'] is List ? result['columns'] as List : const [];
    final action = result['action'] is Map
        ? Map<String, dynamic>.from(result['action'])
        : null;
    final actionId =
        action == null ? null : int.tryParse(action['id']?.toString() ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cards.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards.map((raw) {
              final card = Map<String, dynamic>.from(raw as Map);
              return Container(
                width: 126,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card['label']?.toString() ?? '',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      card['value']?.toString() ?? '-',
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...rows.take(6).map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: columns.take(4).map((rawCol) {
                  final col = Map<String, dynamic>.from(rawCol as Map);
                  final prop = col['prop']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${col['label']}: ${row[prop] ?? '-'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
        if (action != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.warningLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action['title']?.toString() ?? '待确认操作',
                  style: TextStyle(
                      color: colors.warning, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: confirmingActionId == actionId
                      ? null
                      : () => onConfirm(action),
                  child: Text(confirmingActionId == actionId ? '执行中' : '确认执行'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AiMessage {
  final String role;
  final String content;
  final Map<String, dynamic>? result;

  const _AiMessage({
    required this.role,
    required this.content,
    this.result,
  });
}
