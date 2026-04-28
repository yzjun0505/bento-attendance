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
import '../widgets/offline_banner.dart';
import 'home/home_screen.dart';
import 'attendance/map_dashboard_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0; // 默认看板页

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    // 开启实时定位上报
    context.read<TrackingBloc>().add(StartTracking());
    // 加载初始数据
    context.read<HomeBloc>().add(LoadHomeSummary());
  }

  Widget _buildCurrentScreen(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const MapDashboardScreen();
      case 2:
        return const HistoryScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isOffline = authState is AuthAuthenticated && authState.isOffline;
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
                  children: const [
                    HomeScreen(),
                    MapDashboardScreen(),
                    HistoryScreen(),
                    ProfileScreen(),
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
                if (index == 0) {
                  context.read<HomeBloc>().add(const LoadHomeSummary(silent: true));
                }
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
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: '打卡',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_toggle_off),
                  selectedIcon: Icon(Icons.history),
                  label: '明细',
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
