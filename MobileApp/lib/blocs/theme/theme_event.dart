abstract class ThemeEvent {}

class ToggleTheme extends ThemeEvent {}

class SetTheme extends ThemeEvent {
  final bool isDarkMode;

  SetTheme(this.isDarkMode);
}
