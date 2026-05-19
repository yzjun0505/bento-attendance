import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../api/dio_client.dart';
import '../../blocs/chat_settings/chat_settings_cubit.dart';
import '../../blocs/chat_settings/chat_settings_state.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../repositories/app_update_repository.dart';
import '../../widgets/app_update_dialog.dart';
import '../../widgets/bento_card.dart';
import 'environment_diagnostics_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppUpdateRepository _updateRepository =
      AppUpdateRepository(apiClient: ApiClient());
  String _versionLabel = '读取中';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionLabel = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return Container(
            color: colors.background,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildThemeSection(context, state, colors),
                const SizedBox(height: 20),
                _buildChatSection(context, colors),
                const SizedBox(height: 20),
                _buildEnvironmentSection(context, colors),
                const SizedBox(height: 20),
                _buildAboutSection(context, colors),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeSection(
      BuildContext context, ThemeState state, BentoColors colors) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '外观',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildThemeToggle(context, state, colors),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(
      BuildContext context, ThemeState state, BentoColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(BentoRadius.sm),
      ),
      child: SwitchListTile(
        title: Text(
          '深色模式',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          state.isDarkMode ? '当前：深色主题' : '当前：浅色主题',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        value: state.isDarkMode,
        onChanged: (value) {
          context.read<ThemeBloc>().add(ToggleTheme());
        },
        activeThumbColor: colors.primary,
        secondary: Icon(
          state.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: colors.primary,
        ),
      ),
    );
  }

  Widget _buildChatSection(BuildContext context, BentoColors colors) {
    return BentoCard(
      child: BlocBuilder<ChatSettingsCubit, ChatSettingsState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '聊天',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                ),
                child: SwitchListTile(
                  title: Text(
                    '24 小时制',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    state.use24Hour ? '当前：24 小时制' : '当前：12 小时制',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  value: state.use24Hour,
                  onChanged: (value) {
                    context.read<ChatSettingsCubit>().setUse24Hour(value);
                  },
                  activeThumbColor: colors.primary,
                  secondary: Icon(
                    Icons.schedule,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEnvironmentSection(BuildContext context, BentoColors colors) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '环境',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(BentoRadius.sm),
            ),
            child: ListTile(
              leading: Icon(Icons.network_check, color: colors.primary),
              title: Text(
                '服务诊断',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'API、OpenIM 与当前地址',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EnvironmentDiagnosticsScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, BentoColors colors) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '关于',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            context,
            '版本',
            _versionLabel,
            Icons.info_outline,
            colors,
          ),
          const Divider(height: 24),
          _buildUpdateTile(context, colors),
          const Divider(height: 24),
          _buildInfoTile(
            context,
            '开发者',
            'Your Company',
            Icons.code,
            colors,
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateTile(BuildContext context, BentoColors colors) {
    return ListTile(
      leading: Icon(Icons.system_update_alt, color: colors.primary),
      title: Text(
        '检查更新',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        _checkingUpdate ? '正在检查最新版本' : '获取新版本并下载安装包',
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 14,
        ),
      ),
      trailing: _checkingUpdate
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          : Icon(Icons.chevron_right, color: colors.textTertiary),
      onTap: _checkingUpdate ? null : () => _checkForUpdate(context),
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    BentoColors colors,
  ) {
    return ListTile(
      leading: Icon(icon, color: colors.primary),
      title: Text(
        title,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    setState(() {
      _checkingUpdate = true;
    });

    try {
      final update = await _updateRepository.checkLatest();
      if (!context.mounted) return;

      if (!update.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本')),
        );
        return;
      }

      await AppUpdateDialog.show(context, update);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
        });
      }
    }
  }

}
