import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_settings_state.dart';

class ChatSettingsCubit extends Cubit<ChatSettingsState> {
  static const storageKeyUse24Hour = 'chat_use_24h';

  ChatSettingsCubit() : super(ChatSettingsState.initial()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final use24Hour = prefs.getBool(storageKeyUse24Hour) ?? true;
    emit(state.copyWith(use24Hour: use24Hour, isLoaded: true));
  }

  Future<void> setUse24Hour(bool value) async {
    emit(state.copyWith(use24Hour: value, isLoaded: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKeyUse24Hour, value);
  }
}
