import 'package:flutter/widgets.dart';
import 'package:getuiflut/getuiflut.dart';

class GetuiPushService {
  static final GetuiPushService _instance = GetuiPushService._internal();
  factory GetuiPushService() => _instance;
  GetuiPushService._internal();

  bool _initialized = false;
  String? _alias;
  int _sn = 0;
  String? _clientId;

  Future<void> init() async {
    if (_initialized) return;
    const appId = String.fromEnvironment('GETUI_APP_ID');
    if (appId.isEmpty) {
      _initialized = true;
      return;
    }

    final sdk = Getuiflut();
    sdk.addEventHandler(
      onReceiveClientId: (res) async {
        _clientId = res;
        final alias = _alias;
        if (alias != null && alias.isNotEmpty) {
          await setAlias(alias);
        }
        return null;
      },
      onNotificationMessageArrived: (_) async => null,
      onNotificationMessageClicked: (_) async => null,
      onTransmitUserMessageReceive: (_) async => null,
      onReceiveOnlineState: (_) async => null,
      onRegisterDeviceToken: (_) async => null,
      onReceivePayload: (_) async => null,
      onReceiveNotificationResponse: (_) async => null,
      onAppLinkPayload: (_) async => null,
      onPushModeResult: (_) async => null,
      onSetTagResult: (_) async => null,
      onAliasResult: (_) async => null,
      onQueryTagResult: (_) async => null,
      onWillPresentNotification: (_) async => null,
      onOpenSettingsForNotification: (_) async => null,
      onGrantAuthorization: (_) async => null,
      onLiveActivityResult: (_) async => null,
      onRegisterPushToStartTokenResult: (_) async => null,
    );
    sdk.initGetuiSdk;
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      sdk.onActivityCreate();
    });
  }

  Future<void> setAlias(String alias) async {
    _alias = alias;
    if (!_initialized) return;
    if (alias.isEmpty) return;
    if (_clientId == null || _clientId!.isEmpty) return;
    _sn += 1;
    Getuiflut().bindAlias(alias, _sn.toString());
  }
}
