import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final _storage = const FlutterSecureStorage();

  ThemeBloc() : super(ThemeState.initial()) {
    on<ToggleTheme>(_onToggleTheme);
    on<SetTheme>(_onSetTheme);
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDarkMode = await _storage.read(key: 'is_dark_mode');
    if (isDarkMode != null) {
      add(SetTheme(isDarkMode == 'true'));
    }
  }

  Future<void> _onToggleTheme(ToggleTheme event, Emitter<ThemeState> emit) async {
    final newIsDarkMode = !state.isDarkMode;
    await _storage.write(key: 'is_dark_mode', value: newIsDarkMode.toString());
    emit(state.copyWith(isDarkMode: newIsDarkMode));
  }

  Future<void> _onSetTheme(SetTheme event, Emitter<ThemeState> emit) async {
    await _storage.write(key: 'is_dark_mode', value: event.isDarkMode.toString());
    emit(state.copyWith(isDarkMode: event.isDarkMode));
  }
}
