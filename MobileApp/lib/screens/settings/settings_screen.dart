import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/chat_settings/chat_settings_cubit.dart';
import '../../blocs/chat_settings/chat_settings_state.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_card.dart';
import 'environment_diagnostics_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            '1.0.0',
            Icons.info_outline,
            colors,
          ),
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
}
