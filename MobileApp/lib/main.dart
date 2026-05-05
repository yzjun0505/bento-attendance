import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'api/dio_client.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/home/home_bloc.dart';
import 'blocs/home/home_bloc_base.dart';
import 'blocs/attendance/attendance_bloc.dart';
import 'blocs/attendance/attendance_event.dart';
import 'blocs/chat_settings/chat_settings_cubit.dart';
import 'blocs/tracking/tracking_bloc.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_state.dart';
import 'core/bento_typography.dart';
import 'core/bento_colors.dart';
import 'repositories/notification_repository.dart';
import 'repositories/project_repository.dart';
import 'repositories/checkin_repository.dart';
import 'repositories/checkin_type_repository.dart';
import 'repositories/location_repository.dart';
import 'screens/login/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/attendance/camera_checkin_screen.dart';
import 'screens/attendance/local_album_screen.dart';
import 'screens/track/track_screen.dart';
import 'screens/offline/offline_checkins_screen.dart';
import 'services/local_notification_service.dart';
import 'services/getui_push_service.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  await LocalNotificationService().init();
  await GetuiPushService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    
    // Repositories
    final projectRepo = ProjectRepository(apiClient: apiClient);
    final checkinRepo = CheckinRepository(apiClient: apiClient);
    final checkinTypeRepo = CheckinTypeRepository(apiClient: apiClient);
    final locationRepo = LocationRepository(apiClient: apiClient);
    final notificationRepo = NotificationRepository(apiClient: apiClient);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CheckinRepository>.value(value: checkinRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeBloc>(
            create: (context) => ThemeBloc(),
          ),
          BlocProvider<ChatSettingsCubit>(
            create: (context) => ChatSettingsCubit(),
          ),
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(apiClient: apiClient)..add(AppStarted()),
          ),
          BlocProvider<TrackingBloc>(
            create: (context) => TrackingBloc(locationRepository: locationRepo),
          ),
          BlocProvider<AttendanceBloc>(
            create: (context) => AttendanceBloc(
              projectRepository: projectRepo,
              checkinRepository: checkinRepo,
              checkinTypeRepository: checkinTypeRepo,
            )..add(LoadAttendanceData()),
          ),
          BlocProvider<HomeBloc>(
            create: (context) => HomeBloc(
              checkinRepository: checkinRepo,
              notificationRepository: notificationRepo,
              authBloc: BlocProvider.of<AuthBloc>(context),
            )..add(LoadHomeSummary()),
          ),
        ],
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp(
              title: 'Bento Attendance',
              debugShowCheckedModeBanner: false,
              theme: bentoLightTheme(),
              darkTheme: bentoDarkTheme(),
              themeMode: themeState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              home: const AuthWrapper(),
              routes: {
                '/camera_checkin': (context) => const CameraCheckinScreen(),
                '/gallery': (context) => const LocalAlbumScreen(),
                '/track': (context) => const TrackScreen(),
                '/offline_checkins': (context) => const OfflineCheckinsScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        return previous is AuthAuthenticated &&
            current is AuthUnauthenticated &&
            current.error != null;
      },
      listener: (context, state) {
        if (state is AuthUnauthenticated && state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        }
      },
      builder: (context, state) {
        if (state is AuthInitial) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).extension<BentoColors>()?.primary ?? const Color(0xFF3B82F6),
              ),
            ),
          );
        }
        if (state is AuthAuthenticated) {
          return const MainNavigation();
        }
        
        if (state is AuthLoading) {
           return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).extension<BentoColors>()?.primary ?? const Color(0xFF3B82F6),
              ),
            ),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
