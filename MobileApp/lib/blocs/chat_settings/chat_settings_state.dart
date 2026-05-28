import 'package:equatable/equatable.dart';

class ChatSettingsState extends Equatable {
  final bool use24Hour;
  final bool isLoaded;

  const ChatSettingsState({
    required this.use24Hour,
    required this.isLoaded,
  });

  factory ChatSettingsState.initial() {
    return const ChatSettingsState(use24Hour: true, isLoaded: false);
  }

  ChatSettingsState copyWith({
    bool? use24Hour,
    bool? isLoaded,
  }) {
    return ChatSettingsState(
      use24Hour: use24Hour ?? this.use24Hour,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  List<Object?> get props => [use24Hour, isLoaded];
}
