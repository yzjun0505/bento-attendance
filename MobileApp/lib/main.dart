import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tuikit_atomic_x/atomicx.dart';
import 'api/dio_client.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/home/home_bloc.dart';
import 'blocs/home/home_bloc_base.dart';
import 'blocs/attendance/attendance_bloc.dart';
import 'blocs/attendance/attendance_event.dart';
import 'blocs/chat_settings/chat_settings_cubit.dart';
import 'blocs/progress/progress_bloc.dart';
import 'blocs/tracking/tracking_bloc.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_state.dart' as app_theme;
import 'core/bento_typography.dart';
import 'core/bento_colors.dart';
import 'repositories/notification_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/project_repository.dart';
import 'repositories/checkin_repository.dart';
import 'repositories/checkin_type_repository.dart';
import 'repositories/location_repository.dart';
import 'screens/login/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/attendance/camera_checkin_screen.dart';
import 'screens/attendance/local_album_screen.dart';
import 'screens/approval/create_approval_screen.dart';
import 'screens/approval/approval_list_screen.dart';
import 'screens/calendar/attendance_calendar_screen.dart';
import 'screens/track/track_screen.dart';
import 'screens/offline/offline_checkins_screen.dart';
import 'screens/checkins/my_checkins_screen.dart';
import 'screens/checkins/team_checkins_screen.dart';
import 'screens/personnel/personnel_list_screen.dart';
import 'screens/personnel/personnel_form_screen.dart';
import 'screens/device/device_list_screen.dart';
import 'screens/device/device_form_screen.dart';
import 'screens/progress/progress_workbench_screen.dart';
import 'screens/progress/project_progress_screen.dart';
import 'screens/progress/create_node_screen.dart';
import 'models/device_model.dart';
import 'services/local_notification_service.dart';
import 'services/tuikit_config.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  await ApiClient.loadRuntimeConfig();
  await LocalNotificationService().init();
  await TUIKitConfig.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();

    final projectRepo = ProjectRepository(apiClient: apiClient);
    final checkinRepo = CheckinRepository(apiClient: apiClient);
    final checkinTypeRepo = CheckinTypeRepository(apiClient: apiClient);
    final locationRepo = LocationRepository(apiClient: apiClient);
    final notificationRepo = NotificationRepository(apiClient: apiClient);
    final progressRepo = ProgressRepository(apiClient: apiClient);

    return ComponentTheme(
      child: MultiRepositoryProvider(
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
              create: (context) =>
                  AuthBloc(apiClient: apiClient)..add(AppStarted()),
            ),
            BlocProvider<TrackingBloc>(
              create: (context) =>
                  TrackingBloc(locationRepository: locationRepo),
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
              )..add(const LoadHomeSummary()),
            ),
            BlocProvider<ProgressBloc>(
              create: (context) => ProgressBloc(repository: progressRepo),
            ),
          ],
          child: BlocBuilder<ThemeBloc, app_theme.ThemeState>(
            builder: (context, themeState) {
              return MultiProvider(
                providers: [
                  ChangeNotifierProvider(create: (_) => LoginInfoState()),
                  ChangeNotifierProvider.value(value: LocaleProvider()),
                ],
                child: Consumer<LocaleProvider>(
                  builder: (context, localeProvider, child) {
                    return MaterialApp(
                      title: '境图',
                      debugShowCheckedModeBanner: false,
                      localizationsDelegates: const [
                        AtomicLocalizations.delegate,
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                      supportedLocales: AtomicLocalizations.supportedLocales,
                      locale: localeProvider.locale,
                      theme: bentoLightTheme(),
                      darkTheme: bentoDarkTheme(),
                      themeMode: themeState.isDarkMode
                          ? ThemeMode.dark
                          : ThemeMode.light,
                      home: const AuthWrapper(),
                      routes: {
                        '/camera_checkin': (context) =>
                            const CameraCheckinScreen(),
                        '/gallery': (context) => const LocalAlbumScreen(),
                        '/track': (context) => const TrackScreen(),
                        '/offline_checkins': (context) =>
                            const OfflineCheckinsScreen(),
                        '/approval': (context) => const ApprovalListScreen(),
                        '/approval/create': (context) =>
                            const CreateApprovalScreen(),
                        '/calendar': (context) =>
                            const AttendanceCalendarScreen(),
                        '/my_checkins': (context) => const MyCheckinsScreen(),
                        '/team_checkins': (context) =>
                            const TeamCheckinsScreen(),
                        '/personnel': (context) => const PersonnelListScreen(),
                        '/personnel/create': (context) =>
                            const PersonnelFormScreen(),
                        '/personnel/edit': (context) {
                          final user =
                              ModalRoute.of(context)!.settings.arguments;
                          return PersonnelFormScreen(user: user);
                        },
                        '/devices': (context) => const DeviceListScreen(),
                        '/devices/create': (context) =>
                            const DeviceFormScreen(),
                        '/devices/edit': (context) {
                          final device = ModalRoute.of(context)!
                              .settings
                              .arguments as Device;
                          return DeviceFormScreen(device: device);
                        },
                        '/progress_workbench': (context) =>
                            const ProgressWorkbenchScreen(),
                        '/project_progress': (context) {
                          final args = ModalRoute.of(context)!
                              .settings
                              .arguments as Map<String, dynamic>;
                          return ProjectProgressScreen(
                            projectId: args['projectId'] as int,
                            projectName: args['projectName'] as String,
                          );
                        },
                        '/create_node': (context) {
                          final args = ModalRoute.of(context)!
                              .settings
                              .arguments as Map<String, dynamic>;
                          return CreateNodeScreen(
                            projectId: args['projectId'] as int,
                            projectName: args['projectName'] as String,
                          );
                        },
                      },
                    );
                  },
                ),
              );
            },
          ),
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
                color: Theme.of(context).extension<BentoColors>()?.primary ??
                    const Color(0xFF3B82F6),
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
                color: Theme.of(context).extension<BentoColors>()?.primary ??
                    const Color(0xFF3B82F6),
              ),
            ),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
