import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/home/home_bloc.dart';
import '../blocs/home/home_bloc_base.dart';
import '../blocs/tracking/tracking_bloc.dart';
import '../blocs/tracking/tracking_event.dart';
import '../core/bento_colors.dart';
import '../repositories/app_update_repository.dart';
import '../api/dio_client.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/offline_banner.dart';
import 'package:tencent_chat_uikit/conversations_page.dart';
import 'package:tencent_chat_uikit/contacts_page.dart';
import 'attendance/map_dashboard_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 2; // 默认打卡页（IM 登录完成前消息/通讯录显示加载中）
  final AppUpdateRepository _updateRepository =
      AppUpdateRepository(apiClient: ApiClient());
  bool _checkedUpdate = false;

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    // 开启实时定位上报
    context.read<TrackingBloc>().add(StartTracking());
    // 加载初始数据
    context.read<HomeBloc>().add(const LoadHomeSummary());
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckForUpdate());
  }

  Future<void> _autoCheckForUpdate() async {
    if (_checkedUpdate || !mounted) return;
    _checkedUpdate = true;
    try {
      final update = await _updateRepository.checkLatest();
      if (!mounted || !update.hasUpdate) return;
      await AppUpdateDialog.show(context, update);
    } catch (_) {
      // 自动检查失败不打扰用户，设置页仍可手动检查。
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isOffline = authState is AuthAuthenticated && authState.isOffline;
        final isIMReady =
            authState is AuthAuthenticated && authState.imInitialized;
        return Scaffold(
          body: Column(
            children: [
              if (isOffline)
                OfflineBanner(
                  onRetry: () => context.read<AuthBloc>().add(AppStarted()),
                ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    // TUIKit 页面需要等 IM 登录完成后才能渲染，
                    // 否则 ConversationsPage/ContactsPage 在未登录状态下会闪退
                    if (isIMReady)
                      const ConversationsPage()
                    else
                      const _IMLoadingPlaceholder(label: '消息'),
                    if (isIMReady)
                      const ContactsPage()
                    else
                      const _IMLoadingPlaceholder(label: '通讯录'),
                    const MapDashboardScreen(),
                    const HistoryScreen(),
                    const ProfileScreen(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: colors.navBarBg,
              border: Border(
                top: BorderSide(color: colors.navBarBorder, width: 0.5),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: colors.primaryLight,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: '消息',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: '通讯录',
                ),
                NavigationDestination(
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: '打卡',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: '工作台',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: '我的',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// IM 登录完成前的占位加载页面
class _IMLoadingPlaceholder extends StatelessWidget {
  final String label;
  const _IMLoadingPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在连接$label服务...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
