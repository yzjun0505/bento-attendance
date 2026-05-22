import 'package:flutter/material.dart';
import 'package:tuikit_atomic_x/atomicx.dart';
import 'package:tencent_chat_uikit/conversations_page.dart';
import 'package:tencent_chat_uikit/contacts_page.dart';

class TUIKitChatTab extends StatefulWidget {
  const TUIKitChatTab({super.key});

  @override
  State<TUIKitChatTab> createState() => _TUIKitChatTabState();
}

class _TUIKitChatTabState extends State<TUIKitChatTab> {
  int _currentIndex = 0;
  late ConversationListStore _conversationListStore;
  int _totalUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _conversationListStore = ConversationListStore.create();
    _conversationListStore.addListener(_onUnreadCountChanged);
    _conversationListStore.getConversationTotalUnreadCount();
  }

  @override
  void dispose() {
    _conversationListStore.removeListener(_onUnreadCountChanged);
    super.dispose();
  }

  void _onUnreadCountChanged() {
    setState(() {
      _totalUnreadCount =
          _conversationListStore.conversationListState.totalUnreadCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BaseThemeProvider.colorsOf(context);
    final atomicLocale = AtomicLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ConversationsPage(),
          ContactsPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.bgColorBottomBar,
          border: Border(
            top: BorderSide(color: colors.strokeColorPrimary, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: colors.bgColorBottomBar,
            selectedItemColor: colors.buttonColorPrimaryDefault,
            unselectedItemColor: colors.textColorSecondary,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            items: [
              BottomNavigationBarItem(
                icon: _buildChatIcon(colors, false),
                activeIcon: _buildChatIcon(colors, true),
                label: atomicLocale.chat,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline,
                    color: colors.textColorSecondary),
                activeIcon:
                    Icon(Icons.people, color: colors.buttonColorPrimaryDefault),
                label: atomicLocale.contact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatIcon(SemanticColorScheme colors, bool isActive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isActive ? Icons.chat : Icons.chat_outlined,
          color: isActive
              ? colors.buttonColorPrimaryDefault
              : colors.textColorSecondary,
        ),
        if (_totalUnreadCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: colors.textColorError,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                _totalUnreadCount > 99 ? '99+' : '$_totalUnreadCount',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.textColorButton,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
