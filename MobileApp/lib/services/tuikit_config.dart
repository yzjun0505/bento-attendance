import 'package:flutter/widgets.dart';
import 'package:tuikit_atomic_x/atomicx.dart';

const int kTencentIMAppId = 1600142882;

class TUIKitConfig {
  static final TUIKitConfig _instance = TUIKitConfig._internal();
  factory TUIKitConfig() => _instance;
  TUIKitConfig._internal();

  static Future<void> init() async {
    try {
      // AtomicX 当前版本从配置文件路径初始化；这里保持轻量初始化，失败不阻塞业务 App。
      await AppBuilder.init(path: 'assets/appConfig.json');
      debugPrint('=== TUIKit 初始化成功 ===');
    } catch (e) {
      debugPrint('=== TUIKit 初始化失败: $e ===');
    }
  }
}

class LoginInfoState with ChangeNotifier {
  String? _userID;
  String? _userSig;

  String? get userID => _userID;
  String? get userSig => _userSig;

  void login(String userID, String userSig) {
    _userID = userID;
    _userSig = userSig;
    notifyListeners();
  }

  void logout() {
    _userID = null;
    _userSig = null;
    notifyListeners();
  }

  bool get isLoggedIn => _userID != null && _userSig != null;
}
