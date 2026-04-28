import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:path_provider/path_provider.dart';
import '../api/dio_client.dart';
import 'local_notification_service.dart';

class OpenIMService {
  static final OpenIMService _instance = OpenIMService._internal();
  factory OpenIMService() => _instance;
  OpenIMService._internal();

  String? _apiAddr;
  String? _wsAddr;

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isLoggedIn = false;
  String? _currentUserID;
  String? _currentToken;

  final _messageController = StreamController<Message>.broadcast();
  final _connectionController = StreamController<ConnectionState>.broadcast();
  final _conversationController =
      StreamController<ConversationInfo>.broadcast();
  final _totalUnreadController = StreamController<int>.broadcast();
  ConnectionState _lastConnectionState = ConnectionState.disconnected;

  Completer<bool>? _loginCompleter;
  Completer<void>? _initCompleter;

  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  Stream<Message> get messageStream => _messageController.stream;
  Stream<ConnectionState> get connectionStream => _connectionController.stream;
  Stream<ConversationInfo> get conversationStream =>
      _conversationController.stream;
  Stream<int> get totalUnreadStream => _totalUnreadController.stream;
  ConnectionState get lastConnectionState => _lastConnectionState;
  bool get isConnected => _lastConnectionState == ConnectionState.connected;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String? get currentUserID => _currentUserID;
  String? get apiAddr => _apiAddr;
  String? get wsAddr => _wsAddr;

  void reset() {
    try {
      if (_isInitialized) {
        OpenIM.iMManager.unInitSDK();
        print('=== OpenIM SDK unInitSDK 已调用 ===');
      }
    } catch (e) {
      print('=== OpenIM unInitSDK 异常（可忽略）: $e ===');
    }
    _cancelReconnect();
    _isInitialized = false;
    _isInitializing = false;
    _isLoggedIn = false;
    _currentUserID = null;
    _currentToken = null;
    _apiAddr = null;
    _wsAddr = null;
    _loginCompleter = null;
    _initCompleter = null;
    _retryCount = 0;
    _lastConnectionState = ConnectionState.disconnected;
    print('=== OpenIMService 已重置 ===');
  }

  Future<void> preInit({String? apiAddr, String? wsAddr}) async {
    if (apiAddr != null) _apiAddr = apiAddr;
    if (wsAddr != null) _wsAddr = wsAddr;
    print('=== OpenIM preInit: 配置已缓存 ===');
  }

  Future<void> ensureInitialized({String? apiAddr, String? wsAddr}) async {
    if (_isInitialized) return;
    if (_isInitializing && _initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    await init(apiAddr: apiAddr, wsAddr: wsAddr);
  }

  Future<void> init({String? apiAddr, String? wsAddr}) async {
    if (_isInitialized) {
      print('=== OpenIM SDK 已初始化，跳过（apiAddr=$_apiAddr, wsAddr=$_wsAddr）===');
      return;
    }

    if (_isInitializing && _initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    _isInitializing = true;
    _initCompleter = Completer<void>();

    _apiAddr = apiAddr ?? _apiAddr ?? ApiClient.openIMApiUrl;
    _wsAddr = wsAddr ?? _wsAddr ?? ApiClient.openIMWsUrl;

    _apiAddr = _normalizeAddr(_apiAddr!, scheme: 'http');
    _wsAddr = _normalizeAddr(_wsAddr!, scheme: 'ws');

    print('=== OpenIM init: apiAddr=$_apiAddr, wsAddr=$_wsAddr ===');

    if (_apiAddr == null || _wsAddr == null) {
      final errMsg = 'OpenIM 初始化失败: apiAddr=$_apiAddr, wsAddr=$_wsAddr。请确认后端 imConfig 配置正确。';
      print('=== $errMsg ===');
      _isInitializing = false;
      _initCompleter!.completeError(Exception(errMsg));
      throw Exception(errMsg);
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbDir = Directory('${dir.path}/openim');
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
        print('=== OpenIM 创建数据库目录: ${dbDir.path} ===');
      }

      int platformID = 1;
      if (Platform.isIOS) {
        platformID = 2;
      } else if (Platform.isMacOS) {
        platformID = 5;
      }

      print('=== OpenIM initSDK 开始: platformID=$platformID ===');
      await OpenIM.iMManager.initSDK(
        platformID: platformID,
        apiAddr: _apiAddr!,
        wsAddr: _wsAddr!,
        dataDir: '${dir.path}/openim',
        logLevel: 5,
        listener: OnConnectListener(
          onConnectFailed: (code, errorMsg) {
            print('=== OpenIM 连接失败: code=$code, errorMsg=$errorMsg ===');
            _lastConnectionState = ConnectionState.disconnected;
            _connectionController.add(ConnectionState.disconnected);
            if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
              _loginCompleter!.complete(false);
            }
            _attemptReconnect();
          },
          onConnecting: () {
            print('=== OpenIM 连接中... ===');
            _lastConnectionState = ConnectionState.connecting;
            _connectionController.add(ConnectionState.connecting);
          },
          onConnectSuccess: () {
            print('=== OpenIM 连接成功！===');
            _lastConnectionState = ConnectionState.connected;
            _connectionController.add(ConnectionState.connected);
            _isLoggedIn = true;
            _retryCount = 0;
            _cancelReconnect();
            if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
              _loginCompleter!.complete(true);
            }
          },
          onKickedOffline: () {
            print('=== OpenIM 被踢下线 ===');
            _isLoggedIn = false;
            _cancelReconnect();
            _lastConnectionState = ConnectionState.kicked;
            _connectionController.add(ConnectionState.kicked);
          },
          onUserTokenExpired: () {
            print('=== OpenIM Token 已过期 ===');
            _cancelReconnect();
            _lastConnectionState = ConnectionState.tokenExpired;
            _connectionController.add(ConnectionState.tokenExpired);
          },
        ),
      );

      _setupListeners();
      _isInitialized = true;
      _isInitializing = false;
      _initCompleter!.complete();
      print('=== OpenIM SDK 初始化成功！===');
    } catch (e, stackTrace) {
      print('=== OpenIM SDK 初始化失败: $e ===');
      print('=== StackTrace: $stackTrace ===');
      _isInitializing = false;
      _initCompleter!.completeError(e);
      rethrow;
    }
  }

  String _normalizeAddr(String raw, {required String scheme}) {
    try {
      final uri = Uri.parse(raw);
      final host = uri.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        final replaced = uri.replace(host: ApiClient.serverIp, scheme: scheme);
        return replaced.toString();
      }
      if (uri.scheme.isEmpty) {
        return '$scheme://$raw';
      }
      if (uri.scheme != scheme) {
        return uri.replace(scheme: scheme).toString();
      }
      return raw;
    } catch (_) {
      if (raw.startsWith('localhost') || raw.startsWith('127.0.0.1')) {
        return raw.replaceFirst('localhost', ApiClient.serverIp).replaceFirst('127.0.0.1', ApiClient.serverIp);
      }
      return raw;
    }
  }

  void _attemptReconnect() {
    if (_isReconnecting || _retryCount >= _maxRetries) {
      if (_retryCount >= _maxRetries) {
        print('=== OpenIM 已达到最大重连次数($_maxRetries)，停止重连 ===');
      }
      return;
    }

    if (_currentUserID == null || _currentToken == null) {
      print('=== OpenIM 无法重连：缺少 userID 或 token ===');
      return;
    }

    _isReconnecting = true;
    _retryCount++;

    final delay = Duration(seconds: 1 << (_retryCount - 1));
    print('=== OpenIM 尝试第 $_retryCount 次重连，延迟 ${delay.inSeconds} 秒 ===');

    _reconnectTimer = Timer(delay, () async {
      try {
        print('=== OpenIM 重新登录中... userID=$_currentUserID ===');
        _connectionController.add(ConnectionState.connecting);
        
        final success = await login(
          userID: _currentUserID!,
          token: _currentToken!,
        );
        
        if (success) {
          print('=== OpenIM 重连成功！===');
        } else {
          print('=== OpenIM 重连失败，将在稍后继续尝试 ===');
        }
      } catch (e) {
        print('=== OpenIM 重连异常: $e ===');
        _connectionController.add(ConnectionState.disconnected);
      } finally {
        _isReconnecting = false;
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isReconnecting = false;
  }

  void _setupListeners() {
    OpenIM.iMManager.messageManager.setAdvancedMsgListener(
      OnAdvancedMsgListener(
        onRecvNewMessage: (Message msg) {
          _messageController.add(msg);
          final state = WidgetsBinding.instance.lifecycleState;
          final notify = state != AppLifecycleState.resumed;
          if (notify) {
            final title = (msg.senderNickname?.isNotEmpty == true) ? msg.senderNickname! : '新消息';
            final body = getMessageDigest(msg);
            LocalNotificationService().showChatMessage(title: title, body: body.isNotEmpty ? body : '[新消息]');
          }
          print('收到新消息: ${msg.textElem?.content ?? '[非文本消息]'}');
        },
        onRecvC2CReadReceipt: (List<ReadReceiptInfo> list) {
          print('消息已读回执: ${list.length}条');
        },
      ),
    );

    OpenIM.iMManager.conversationManager.setConversationListener(
      OnConversationListener(
        onConversationChanged: (List<ConversationInfo> list) {
          for (var conv in list) {
            _conversationController.add(conv);
          }
        },
        onNewConversation: (List<ConversationInfo> list) {
          for (var conv in list) {
            _conversationController.add(conv);
          }
        },
        onTotalUnreadMessageCountChanged: (int count) {
          print('未读消息总数: $count');
          _totalUnreadController.add(count);
        },
      ),
    );

    OpenIM.iMManager.friendshipManager.setFriendshipListener(
      OnFriendshipListener(
        onFriendApplicationAdded: (FriendApplicationInfo info) {
          print('好友申请: ${info.fromNickname}');
        },
        onFriendApplicationAccepted: (FriendApplicationInfo info) {
          print('好友申请已接受: ${info.fromNickname}');
        },
        onFriendApplicationRejected: (FriendApplicationInfo info) {
          print('好友申请被拒绝: ${info.fromNickname}');
        },
        onFriendAdded: (FriendInfo info) {
          print('新增好友: ${info.nickname}');
        },
        onFriendDeleted: (FriendInfo info) {
          print('删除好友: ${info.nickname}');
        },
        onFriendInfoChanged: (FriendInfo info) {
          print('好友信息变更: ${info.nickname}');
        },
      ),
    );

    OpenIM.iMManager.groupManager.setGroupListener(
      OnGroupListener(
        onGroupApplicationAdded: (GroupApplicationInfo info) {
          print('入群申请: ${info.groupName}');
        },
        onGroupApplicationAccepted: (GroupApplicationInfo info) {
          print('入群申请已接受: ${info.groupName}');
        },
        onGroupApplicationRejected: (GroupApplicationInfo info) {
          print('入群申请被拒绝: ${info.groupName}');
        },
        onGroupMemberAdded: (GroupMembersInfo info) {
          print('新成员加入群: ${info.nickname}');
        },
        onGroupMemberDeleted: (GroupMembersInfo info) {
          print('成员离开群: ${info.nickname}');
        },
        onGroupInfoChanged: (GroupInfo info) {
          print('群信息变更: ${info.groupName}');
        },
        onGroupMemberInfoChanged: (GroupMembersInfo info) {
          print('群成员信息变更: ${info.nickname}');
        },
        onGroupDismissed: (GroupInfo info) {
          print('群解散: ${info.groupName}');
        },
      ),
    );

    OpenIM.iMManager.userManager.setUserListener(
      OnUserListener(
        onSelfInfoUpdated: (UserInfo info) {
          print('用户信息更新: ${info.nickname}');
        },
      ),
    );
  }

  Future<bool> login({
    required String userID,
    required String token,
  }) async {
    try {
      await ensureInitialized();
      
      print('=== OpenIM login 开始: userID=$userID, token=${token.substring(0, 20)}... ===');

      _loginCompleter = Completer<bool>();
      _cancelReconnect();
      _retryCount = 0;

      await OpenIM.iMManager.login(
        userID: userID,
        token: token,
        defaultValue: () async => UserInfo(userID: userID),
        checkLoginStatus: false,
      );

      print('=== OpenIM login() 原生调用已返回，等待 onConnectSuccess 回调... ===');

      final connected = await _loginCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('=== OpenIM 等待连接超时(15s)，可能登录未完成 ===');
          return false;
        },
      );

      if (connected) {
        _isLoggedIn = true;
        _currentUserID = userID;
        _currentToken = token;
        print('=== OpenIM 登录成功！userID=$userID ===');
      } else {
        _isLoggedIn = false;
        print('=== OpenIM 登录失败：连接未建立 ===');
      }

      return connected;
    } catch (e, stackTrace) {
      print('=== OpenIM 登录异常: $e ===');
      print('=== StackTrace: $stackTrace ===');
      _isLoggedIn = false;
      return false;
    }
  }

  Future<void> logout() async {
    try {
      _cancelReconnect();
      await OpenIM.iMManager.logout();
      _isLoggedIn = false;
      _currentUserID = null;
      _currentToken = null;
      _retryCount = 0;
      _lastConnectionState = ConnectionState.disconnected;
      _connectionController.add(ConnectionState.disconnected);
      print('IM已登出');
    } catch (e) {
      print('IM登出失败: $e');
    }
  }

  Future<Message?> sendTextMessage({
    required String receiverID,
    required String text,
    bool isGroup = false,
  }) async {
    try {
      await ensureInitialized();
      final message = await OpenIM.iMManager.messageManager.createTextMessage(
        text: text,
      );
      final result = await OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        userID: isGroup ? null : receiverID,
        groupID: isGroup ? receiverID : null,
        offlinePushInfo: OfflinePushInfo(
          title: '新消息',
          desc: text,
        ),
      );
      print('消息发送成功: ${result.clientMsgID}');
      return result;
    } catch (e) {
      print('发送消息失败: $e');
      return null;
    }
  }

  Future<Message?> sendImageMessage({
    required String receiverID,
    required String imagePath,
    bool isGroup = false,
  }) async {
    try {
      await ensureInitialized();
      final message = await OpenIM.iMManager.messageManager.createImageMessage(
        imagePath: imagePath,
      );
      return await OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        userID: isGroup ? null : receiverID,
        groupID: isGroup ? receiverID : null,
        offlinePushInfo: OfflinePushInfo(
          title: '新图片',
          desc: '[图片]',
        ),
      );
    } catch (e) {
      print('发送图片失败: $e');
      return null;
    }
  }

  Future<Message?> sendFileMessage({
    required String receiverID,
    required String filePath,
    required String fileName,
    bool isGroup = false,
  }) async {
    try {
      await ensureInitialized();
      final message = await OpenIM.iMManager.messageManager.createFileMessage(
        filePath: filePath,
        fileName: fileName,
      );
      return await OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        userID: isGroup ? null : receiverID,
        groupID: isGroup ? receiverID : null,
        offlinePushInfo: OfflinePushInfo(
          title: '新文件',
          desc: '[文件] $fileName',
        ),
      );
    } catch (e) {
      print('发送文件失败: $e');
      return null;
    }
  }

  Future<List<Message>> getHistoryMessages({
    required String conversationID,
    int count = 20,
    Message? startMsg,
  }) async {
    try {
      await ensureInitialized();
      final result =
          await OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
        conversationID: conversationID,
        count: count,
        startMsg: startMsg,
      );
      return result.messageList ?? [];
    } catch (e) {
      print('获取历史消息失败: $e');
      return [];
    }
  }

  Future<List<ConversationInfo>> getAllConversations() async {
    try {
      await ensureInitialized();
      final convs = await OpenIM.iMManager.conversationManager
          .getAllConversationList();
      print('=== getAllConversations 成功: ${convs.length} 个会话 ===');
      return convs;
    } catch (e) {
      print('获取会话列表失败: $e');
      return [];
    }
  }

  Future<List<FriendInfo>> getFriendList() async {
    try {
      await ensureInitialized();
      final friends = await OpenIM.iMManager.friendshipManager.getFriendList();
      print('=== getFriendList 成功: ${friends.length} 个好友 ===');
      for (var f in friends) {
        print('  好友: ${f.nickname} (userID=${f.userID})');
      }
      return friends;
    } catch (e) {
      print('获取好友列表失败: $e');
      return [];
    }
  }

  Future<List<GroupInfo>> getJoinedGroupList() async {
    try {
      await ensureInitialized();
      return await OpenIM.iMManager.groupManager.getJoinedGroupList();
    } catch (e) {
      print('获取群组列表失败: $e');
      return [];
    }
  }

  Future<String?> getOrCreateSingleConversationID(String userID) async {
    try {
      await ensureInitialized();
      final conv = await OpenIM.iMManager.conversationManager.getOneConversation(
        sourceID: userID,
        sessionType: ConversationType.single,
      );
      return conv.conversationID;
    } catch (e) {
      print('获取单聊会话ID失败: $e');
      return null;
    }
  }

  Future<String?> getOrCreateGroupConversationID(
    String groupID, {
    int sessionType = ConversationType.superGroup,
  }) async {
    try {
      await ensureInitialized();
      final conv = await OpenIM.iMManager.conversationManager.getOneConversation(
        sourceID: groupID,
        sessionType: sessionType,
      );
      return conv.conversationID;
    } catch (e) {
      print('获取群聊会话ID失败: $e');
      return null;
    }
  }

  Future<PublicUserInfo?> searchUser({required String userID}) async {
    try {
      await ensureInitialized();
      final users = await OpenIM.iMManager.userManager.getUsersInfo(
        userIDList: [userID],
      );
      if (users.isNotEmpty) {
        print('找到用户: ${users.first.nickname} (ID: ${users.first.userID})');
        return users.first;
      }
      print('用户不存在: $userID');
      return null;
    } catch (e) {
      print('搜索用户失败: $e');
      return null;
    }
  }

  Future<void> addFriend({required String userID, String reason = ''}) async {
    try {
      await ensureInitialized();
      final userInfo = await searchUser(userID: userID);
      if (userInfo == null) {
        throw Exception('用户不存在，请检查用户ID是否正确');
      }
      if (userID == _currentUserID) {
        throw Exception('不能添加自己为好友');
      }
      await OpenIM.iMManager.friendshipManager.addFriend(
        userID: userID,
        reason: reason,
      );
      print('好友申请已发送: $userID');
    } catch (e) {
      print('发送好友申请失败: $e');
      rethrow;
    }
  }

  Future<List<FriendApplicationInfo>> getReceivedFriendApplications() async {
    try {
      await ensureInitialized();
      return await OpenIM.iMManager.friendshipManager.getFriendApplicationListAsRecipient();
    } catch (e) {
      print('获取收到的好友申请失败: $e');
      return [];
    }
  }

  Future<List<FriendApplicationInfo>> getSentFriendApplications() async {
    try {
      await ensureInitialized();
      return await OpenIM.iMManager.friendshipManager.getFriendApplicationListAsApplicant();
    } catch (e) {
      print('获取发出的好友申请失败: $e');
      return [];
    }
  }

  Future<List<dynamic>> getFriendApplicationList() async {
    try {
      await ensureInitialized();
      final received = await getReceivedFriendApplications();
      final sent = await getSentFriendApplications();
      return [...received, ...sent];
    } catch (e) {
      print('获取好友申请列表失败: $e');
      return [];
    }
  }

  Future<int> getUnhandledFriendApplicationCount() async {
    try {
      await ensureInitialized();
      final received = await getReceivedFriendApplications();
      return received.where((app) => app.handleResult == 0).length;
    } catch (e) {
      print('获取未处理好友申请数量失败: $e');
      return 0;
    }
  }

  Future<void> acceptFriendApplication({required String userID}) async {
    try {
      await ensureInitialized();
      await OpenIM.iMManager.friendshipManager.acceptFriendApplication(userID: userID);
      print('已接受好友申请: $userID');
    } catch (e) {
      print('接受好友申请失败: $e');
      rethrow;
    }
  }

  Future<void> refuseFriendApplication({required String userID}) async {
    try {
      await ensureInitialized();
      await OpenIM.iMManager.friendshipManager.refuseFriendApplication(userID: userID);
      print('已拒绝好友申请: $userID');
    } catch (e) {
      print('拒绝好友申请失败: $e');
      rethrow;
    }
  }

  Future<GroupInfo?> createGroup({
    required String groupName,
    String? notification,
    String? introduction,
    List<String>? memberUserIDs,
  }) async {
    try {
      await ensureInitialized();
      final groupInfo = GroupInfo(
        groupID: '',
        groupName: groupName,
        notification: notification,
        introduction: introduction,
      );
      final result = await OpenIM.iMManager.groupManager.createGroup(
        groupInfo: groupInfo,
        memberUserIDs: memberUserIDs ?? [],
      );
      print('群组创建成功: ${result.groupName}');
      return result;
    } catch (e) {
      print('创建群组失败: $e');
      rethrow;
    }
  }

  Future<void> joinGroup({required String groupID, String reason = ''}) async {
    try {
      await ensureInitialized();
      await OpenIM.iMManager.groupManager.joinGroup(
        groupID: groupID,
        reason: reason,
        joinSource: 2,
      );
      print('入群申请已发送: $groupID');
    } catch (e) {
      print('申请入群失败: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> searchFriend({required String keyword}) async {
    try {
      await ensureInitialized();
      final result = await OpenIM.iMManager.friendshipManager.searchFriends(
        keywordList: [keyword],
        isSearchUserID: true,
        isSearchNickname: true,
      );
      return result;
    } catch (e) {
      print('搜索好友失败: $e');
      return [];
    }
  }

  Future<List<dynamic>> searchGroup({required String keyword}) async {
    try {
      await ensureInitialized();
      final result = await OpenIM.iMManager.groupManager.searchGroups(
        keywordList: [keyword],
        isSearchGroupID: true,
        isSearchGroupName: true,
      );
      return result;
    } catch (e) {
      print('搜索群组失败: $e');
      return [];
    }
  }

  Future<UserInfo?> getSelfUserInfo() async {
    try {
      await ensureInitialized();
      return await OpenIM.iMManager.userManager.getSelfUserInfo();
    } catch (e) {
      print('获取用户信息失败: $e');
      return null;
    }
  }

  Future<void> setSelfUserInfo({
    required String nickname,
    String? faceURL,
    String? ex,
  }) async {
    try {
      await ensureInitialized();
      await OpenIM.iMManager.userManager.setSelfInfo(
        nickname: nickname,
        faceURL: faceURL,
        ex: ex,
      );
      print('用户信息更新成功');
    } catch (e) {
      print('更新用户信息失败: $e');
    }
  }

  Future<void> markConversationMessageAsRead(String conversationID) async {
    try {
      await ensureInitialized();
      await OpenIM.iMManager.conversationManager.markConversationMessageAsRead(
        conversationID: conversationID,
      );
    } catch (e) {
      print('标记已读失败: $e');
    }
  }

  Future<void> pinConversation({required String conversationID, required bool pinned}) async {
    try {
      await ensureInitialized();
      await OpenIM.iMManager.conversationManager.pinConversation(
        conversationID: conversationID,
        isPinned: pinned,
      );
    } catch (e) {
      print('置顶会话失败: $e');
    }
  }

  Future<void> deleteConversation({required String conversationID}) async {
    try {
      await ensureInitialized();
      await OpenIM.iMManager.conversationManager.deleteConversationAndDeleteAllMsg(
        conversationID: conversationID,
      );
    } catch (e) {
      print('删除会话失败: $e');
    }
  }

  String getMessageDigest(Message? msg) {
    if (msg == null) return '';
    final ct = msg.contentType;
    if (ct == MessageType.text) {
      return msg.textElem?.content ?? '';
    }
    if (ct == MessageType.advancedText) {
      return msg.advancedTextElem?.text ?? '';
    }
    if (ct == MessageType.atText) {
      return msg.atTextElem?.text ?? '';
    }
    if (ct == MessageType.picture) return '[图片]';
    if (ct == MessageType.video) return '[视频]';
    if (ct == MessageType.voice) return '[语音]';
    if (ct == MessageType.file) return '[文件]';
    if (ct == MessageType.location) return '[位置]';
    if (ct == MessageType.card) return '[名片]';
    if (ct == MessageType.quote) return '[引用]';
    if (ct == MessageType.customFace) return '[表情]';
    if (ct == MessageType.custom) return '[自定义消息]';
    if (ct != null && ct >= MessageType.notificationBegin) return '[通知]';
    return '[消息]';
  }

  Future<int> getTotalUnreadMsgCount() async {
    try {
      await ensureInitialized();
      return await OpenIM.iMManager.conversationManager
          .getTotalUnreadMsgCount();
    } catch (e) {
      return 0;
    }
  }

  void dispose() {
    _cancelReconnect();
    _messageController.close();
    _connectionController.close();
    _conversationController.close();
  }
}

enum ConnectionState {
  connected,
  connecting,
  disconnected,
  kicked,
  tokenExpired,
}
