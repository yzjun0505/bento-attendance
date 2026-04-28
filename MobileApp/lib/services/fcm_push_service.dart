class FcmPushService {
  static final FcmPushService _instance = FcmPushService._internal();
  factory FcmPushService() => _instance;
  FcmPushService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> setAccount(String account) async {
    if (!_initialized) await init();
  }
}
