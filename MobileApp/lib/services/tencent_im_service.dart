import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:tuikit_atomic_x/atomicx.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimGroupListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_response_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart' as sdk_group;
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import '../api/dio_client.dart';
import 'local_notification_service.dart';

class TencentIMService {
  static final TencentIMService _instance = TencentIMService._internal();
  factory TencentIMService() => _instance;
  TencentIMService._internal();

  String? _sdkAppId;

  bool _isInitialized = false;
  bool _isLoggedIn = false;
  String? _currentUserID;

  final _messageController = StreamController<V2TimMessage>.broadcast();
  final _connectionController = StreamController<ConnectionState>.broadcast();
  final _conversationController =
      StreamController<V2TimConversation>.broadcast();
  final _totalUnreadController = StreamController<int>.broadcast();

  ConnectionState _lastConnectionState = ConnectionState.disconnected;

  Stream<V2TimMessage> get messageStream => _messageController.stream;
  Stream<ConnectionState> get connectionStream => _connectionController.stream;
  Stream<V2TimConversation> get conversationStream =>
      _conversationController.stream;
  Stream<int> get totalUnreadStream => _totalUnreadController.stream;

  ConnectionState get lastConnectionState => _lastConnectionState;
  bool get isConnected => _lastConnectionState == ConnectionState.connected;
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String? get currentUserID => _currentUserID;

  void reset() {
    try {
      if (_isInitialized && _isLoggedIn) {
        // 注意: 实际的 LoginStore.shared.logout() 由 auth_bloc 调用
        // 这里只重置内部状态
        debugPrint('=== 腾讯云 IM 内部状态重置 ===');
      }
    } catch (e) {
      debugPrint('=== 腾讯云 IM 重置异常（可忽略）: $e ===');
    }
    _isInitialized = false;
    _isLoggedIn = false;
    _currentUserID = null;
    _sdkAppId = null;
    _lastConnectionState = ConnectionState.disconnected;
    debugPrint('=== TencentIMService 已重置 ===');
  }

  /// 标记 IM 已通过 TUIKit LoginStore 登录，同步内部状态
  void markLoggedIn(String userID) {
    _isInitialized = true;
    _isLoggedIn = true;
    _currentUserID = userID;
    _lastConnectionState = ConnectionState.connected;
    _connectionController.add(ConnectionState.connected);
    debugPrint('=== TencentIMService 标记已登录: userID=$userID ===');
  }

  Future<void> init({String? sdkAppId}) async {
    if (_isInitialized) {
      debugPrint('=== 腾讯云 IM SDK 已初始化，跳过 ===');
      return;
    }

    _sdkAppId = sdkAppId ?? ApiClient.tencentIMAppId;

    if (_sdkAppId == null || _sdkAppId!.isEmpty) {
      debugPrint('=== 腾讯云 IM 初始化失败: sdkAppId 为空 ===');
      throw Exception('腾讯云 IM sdkAppId 未配置');
    }

    debugPrint('=== 腾讯云 IM initSDK 开始: sdkAppId=$_sdkAppId ===');

    try {
      final result = await TencentImSDKPlugin.v2TIMManager.initSDK(
        sdkAppID: int.parse(_sdkAppId!),
        loglevel: LogLevelEnum.V2TIM_LOG_DEBUG,
        listener: V2TimSDKListener(
          onConnectFailed: (code, error) {
            debugPrint('=== 腾讯云 IM 连接失败: code=$code, error=$error ===');
            _lastConnectionState = ConnectionState.disconnected;
            _connectionController.add(ConnectionState.disconnected);
          },
          onConnectSuccess: () {
            debugPrint('=== 腾讯云 IM 连接成功！===');
            _lastConnectionState = ConnectionState.connected;
            _connectionController.add(ConnectionState.connected);
          },
          onConnecting: () {
            debugPrint('=== 腾讯云 IM 连接中... ===');
            _lastConnectionState = ConnectionState.connecting;
            _connectionController.add(ConnectionState.connecting);
          },
          onKickedOffline: () {
            debugPrint('=== 腾讯云 IM 被踢下线 ===');
            _isLoggedIn = false;
            _lastConnectionState = ConnectionState.kicked;
            _connectionController.add(ConnectionState.kicked);
          },
          onUserSigExpired: () {
            debugPrint('=== 腾讯云 IM UserSig 已过期 ===');
            _lastConnectionState = ConnectionState.tokenExpired;
            _connectionController.add(ConnectionState.tokenExpired);
          },
        ),
      );

      if (result.code == 0) {
        _isInitialized = true;
        _setupListeners();
        debugPrint('=== 腾讯云 IM SDK 初始化成功！===');
      } else {
        debugPrint('=== 腾讯云 IM SDK 初始化失败: ${result.desc} ===');
        throw Exception('腾讯云 IM SDK 初始化失败: ${result.desc}');
      }
    } catch (e, stackTrace) {
      debugPrint('=== 腾讯云 IM SDK 初始化异常: $e ===');
      debugPrint('=== StackTrace: $stackTrace ===');
      rethrow;
    }
  }

  void _setupListeners() {
    TencentImSDKPlugin.v2TIMManager.getMessageManager().addAdvancedMsgListener(
          listener: V2TimAdvancedMsgListener(
            onRecvNewMessage: (V2TimMessage msg) {
              _messageController.add(msg);
              final state = WidgetsBinding.instance.lifecycleState;
              final notify = state != AppLifecycleState.resumed;
              if (notify) {
                final title = msg.nickName ?? msg.sender ?? '新消息';
                final body = getMessageDigest(msg);
                LocalNotificationService().showChatMessage(
                  title: title,
                  body: body.isNotEmpty ? body : '[新消息]',
                );
              }
              debugPrint('收到新消息: ${msg.textElem?.text ?? '[非文本消息]'}');
            },
            onRecvC2CReadReceipt: (List<V2TimMessageReceipt> list) {
              debugPrint('消息已读回执: ${list.length}条');
            },
          ),
        );

    TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .setConversationListener(
          listener: V2TimConversationListener(
            onConversationChanged: (List<V2TimConversation> list) {
              for (var conv in list) {
                _conversationController.add(conv);
              }
            },
            onNewConversation: (List<V2TimConversation> list) {
              for (var conv in list) {
                _conversationController.add(conv);
              }
            },
            onTotalUnreadMessageCountChanged: (int count) {
              debugPrint('未读消息总数: $count');
              _totalUnreadController.add(count);
            },
          ),
        );

    TencentImSDKPlugin.v2TIMManager.getFriendshipManager().setFriendListener(
          listener: V2TimFriendshipListener(
            onFriendApplicationListAdded: (List<V2TimFriendApplication> list) {
              debugPrint('好友申请: ${list.length}条');
            },
            onFriendListAdded: (List<V2TimFriendInfo> list) {
              debugPrint('新增好友: ${list.length}个');
            },
            onFriendListDeleted: (List<String> list) {
              debugPrint('删除好友: ${list.length}个');
            },
          ),
        );

    TencentImSDKPlugin.v2TIMManager.setGroupListener(
      listener: V2TimGroupListener(
        onMemberEnter: (String groupID, List<V2TimGroupMemberInfo> list) {
          debugPrint('新成员加入群: $groupID');
        },
        onMemberLeave: (String groupID, V2TimGroupMemberInfo member) {
          debugPrint('成员离开群: $groupID');
        },
        onGroupInfoChanged: (String groupID, List<V2TimGroupChangeInfo> list) {
          debugPrint('群信息变更: $groupID');
        },
      ),
    );
  }

  Future<bool> login({
    required String userID,
    required String userSig,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      debugPrint('=== 腾讯云 IM login 开始: userID=$userID ===');

      final result = await LoginStore.shared.login(
        sdkAppID: int.parse(_sdkAppId!),
        userID: userID,
        userSig: userSig,
      );

      if (result.errorCode == 0) {
        _isLoggedIn = true;
        _currentUserID = userID;
        debugPrint('=== 腾讯云 IM 登录成功！userID=$userID ===');
        return true;
      } else {
        debugPrint('=== 腾讯云 IM 登录失败: ${result.errorMessage} ===');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('=== 腾讯云 IM 登录异常: $e ===');
      debugPrint('=== StackTrace: $stackTrace ===');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await LoginStore.shared.logout();
      _isLoggedIn = false;
      _currentUserID = null;
      _lastConnectionState = ConnectionState.disconnected;
      _connectionController.add(ConnectionState.disconnected);
      debugPrint('腾讯云 IM 已登出');
    } catch (e) {
      debugPrint('腾讯云 IM 登出失败: $e');
    }
  }

  Future<V2TimMessage?> sendTextMessage({
    required String receiverID,
    required String text,
    bool isGroup = false,
  }) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final manager = TencentImSDKPlugin.v2TIMManager.getMessageManager();
      final createResult = await manager.createTextMessage(text: text);
      if (createResult.code != 0 || createResult.data == null) {
        debugPrint('创建文本消息失败: ${createResult.desc}');
        return null;
      }

      final result = await manager.sendMessage(
        message: createResult.data!.messageInfo,
        receiver: isGroup ? '' : receiverID,
        groupID: isGroup ? receiverID : '',
        onlineUserOnly: false,
      );

      if (result.code == 0 && result.data != null) {
        debugPrint('消息发送成功: ${result.data!.msgID}');
        return result.data;
      } else {
        debugPrint('发送消息失败: ${result.desc}');
        return null;
      }
    } catch (e) {
      debugPrint('发送消息失败: $e');
      return null;
    }
  }

  Future<V2TimMessage?> sendImageMessage({
    required String receiverID,
    required String imagePath,
    bool isGroup = false,
  }) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final manager = TencentImSDKPlugin.v2TIMManager.getMessageManager();
      final createResult =
          await manager.createImageMessage(imagePath: imagePath);
      if (createResult.code != 0 || createResult.data == null) {
        debugPrint('创建图片消息失败: ${createResult.desc}');
        return null;
      }

      final result = await manager.sendMessage(
        message: createResult.data!.messageInfo,
        receiver: isGroup ? '' : receiverID,
        groupID: isGroup ? receiverID : '',
      );

      if (result.code == 0 && result.data != null) {
        return result.data;
      }
      return null;
    } catch (e) {
      debugPrint('发送图片失败: $e');
      return null;
    }
  }

  Future<V2TimMessage?> sendFileMessage({
    required String receiverID,
    required String filePath,
    required String fileName,
    bool isGroup = false,
  }) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final manager = TencentImSDKPlugin.v2TIMManager.getMessageManager();
      final createResult = await manager.createFileMessage(
        filePath: filePath,
        fileName: fileName,
      );
      if (createResult.code != 0 || createResult.data == null) {
        debugPrint('创建文件消息失败: ${createResult.desc}');
        return null;
      }

      final result = await manager.sendMessage(
        message: createResult.data!.messageInfo,
        receiver: isGroup ? '' : receiverID,
        groupID: isGroup ? receiverID : '',
      );

      if (result.code == 0 && result.data != null) {
        return result.data;
      }
      return null;
    } catch (e) {
      debugPrint('发送文件失败: $e');
      return null;
    }
  }

  Future<List<V2TimMessage>> getHistoryMessages({
    required String conversationID,
    int count = 20,
    String? nextSeq,
  }) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final isC2C = !conversationID.startsWith('group_');
      final result = await TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .getHistoryMessageList(
            count: count,
            getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
            userID: isC2C ? conversationID : null,
            groupID: isC2C ? null : conversationID,
          );

      if (result.code == 0 && result.data != null) {
        return result.data!;
      }
      return [];
    } catch (e) {
      debugPrint('获取历史消息失败: $e');
      return [];
    }
  }

  Future<List<V2TimConversation>> getAllConversations() async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversationList(nextSeq: '0', count: 100);

      if (result.code == 0 && result.data?.conversationList != null) {
        final list = result.data!.conversationList ?? [];
        debugPrint('=== getAllConversations 成功: ${list.length} 个会话 ===');
        return list;
      }
      return [];
    } catch (e) {
      debugPrint('获取会话列表失败: $e');
      return [];
    }
  }

  Future<List<V2TimFriendInfo>> getFriendList() async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .getFriendList();

      if (result.code == 0 && result.data != null) {
        debugPrint('=== getFriendList 成功: ${result.data!.length} 个好友 ===');
        return result.data!;
      }
      return [];
    } catch (e) {
      debugPrint('获取好友列表失败: $e');
      return [];
    }
  }

  Future<List<V2TimGroupInfo>> getJoinedGroupList() async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getGroupManager()
          .getJoinedGroupList();

      if (result.code == 0 && result.data != null) {
        return result.data!;
      }
      return [];
    } catch (e) {
      debugPrint('获取群组列表失败: $e');
      return [];
    }
  }

  Future<String?> getOrCreateSingleConversationID(String userID) async {
    return 'c2c_$userID';
  }

  Future<String?> getOrCreateGroupConversationID(String groupID) async {
    return 'group_$groupID';
  }

  Future<V2TimUserFullInfo?> searchUser({required String userID}) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
        userIDList: [userID],
      );

      if (result.code == 0 && result.data != null && result.data!.isNotEmpty) {
        debugPrint(
            '找到用户: ${result.data!.first.nickName} (ID: ${result.data!.first.userID})');
        return result.data!.first;
      }
      debugPrint('用户不存在: $userID');
      return null;
    } catch (e) {
      debugPrint('搜索用户失败: $e');
      return null;
    }
  }

  Future<void> addFriend({required String userID, String reason = ''}) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      if (userID == _currentUserID) {
        throw Exception('不能添加自己为好友');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .addFriend(
            userID: userID,
            addType: FriendTypeEnum.V2TIM_FRIEND_TYPE_BOTH,
            addWording: reason,
          );

      if (result.code == 0) {
        debugPrint('好友申请已发送: $userID');
      } else {
        throw Exception(result.desc);
      }
    } catch (e) {
      debugPrint('发送好友申请失败: $e');
      rethrow;
    }
  }

  Future<List<V2TimFriendApplication>> getReceivedFriendApplications() async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .getFriendApplicationList();

      if (result.code == 0 && result.data != null) {
        return (result.data!.friendApplicationList ?? [])
            .whereType<V2TimFriendApplication>()
            .where((app) =>
                app.type ==
                FriendApplicationTypeEnum
                    .V2TIM_FRIEND_APPLICATION_COME_IN.index)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('获取收到的好友申请失败: $e');
      return [];
    }
  }

  Future<void> acceptFriendApplication({required String userID}) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .acceptFriendApplication(
            responseType:
                FriendResponseTypeEnum.V2TIM_FRIEND_ACCEPT_AGREE_AND_ADD,
            type: FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_COME_IN,
            userID: userID,
          );

      if (result.code == 0) {
        debugPrint('已接受好友申请: $userID');
      } else {
        throw Exception(result.desc);
      }
    } catch (e) {
      debugPrint('接受好友申请失败: $e');
      rethrow;
    }
  }

  Future<void> refuseFriendApplication({required String userID}) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .refuseFriendApplication(
            type: FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_COME_IN,
            userID: userID,
          );

      if (result.code == 0) {
        debugPrint('已拒绝好友申请: $userID');
      } else {
        throw Exception(result.desc);
      }
    } catch (e) {
      debugPrint('拒绝好友申请失败: $e');
      rethrow;
    }
  }

  Future<String?> createGroup({
    required String groupName,
    String? notification,
    String? introduction,
    List<String>? memberUserIDs,
  }) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result =
          await TencentImSDKPlugin.v2TIMManager.getGroupManager().createGroup(
                groupType: sdk_group.GroupType.Public,
                groupName: groupName,
                notification: notification,
                introduction: introduction,
                memberList: memberUserIDs
                    ?.map((id) => V2TimGroupMember(
                          userID: id,
                          role: GroupMemberRoleTypeEnum
                              .V2TIM_GROUP_MEMBER_ROLE_MEMBER,
                        ))
                    .toList(),
              );

      if (result.code == 0 && result.data != null) {
        debugPrint('群组创建成功: ${result.data}');
        return result.data;
      } else {
        throw Exception(result.desc);
      }
    } catch (e) {
      debugPrint('创建群组失败: $e');
      rethrow;
    }
  }

  Future<void> joinGroup({required String groupID, String reason = ''}) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager.joinGroup(
        groupID: groupID,
        message: reason,
      );

      if (result.code == 0) {
        debugPrint('入群申请已发送: $groupID');
      } else {
        throw Exception(result.desc);
      }
    } catch (e) {
      debugPrint('申请入群失败: $e');
      rethrow;
    }
  }

  Future<List<V2TimFriendInfoResult>> searchFriend(
      {required String keyword}) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .searchFriends(
            searchParam: V2TimFriendSearchParam(
              keywordList: [keyword],
              isSearchUserID: true,
              isSearchNickName: true,
              isSearchRemark: true,
            ),
          );

      if (result.code == 0 && result.data != null) {
        return result.data!;
      }
      return [];
    } catch (e) {
      debugPrint('搜索好友失败: $e');
      return [];
    }
  }

  Future<V2TimUserFullInfo?> getSelfUserInfo() async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final userID = _currentUserID;
      if (userID == null || userID.isEmpty) return null;

      final result = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
        userIDList: [userID],
      );

      if (result.code == 0 && result.data != null && result.data!.isNotEmpty) {
        return result.data!.first;
      }
      return null;
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
      return null;
    }
  }

  Future<void> setSelfUserInfo({
    required String nickname,
    String? faceURL,
    String? selfSignature,
  }) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager.setSelfInfo(
        userFullInfo: V2TimUserFullInfo(
          nickName: nickname,
          faceUrl: faceURL,
          selfSignature: selfSignature,
        ),
      );

      if (result.code == 0) {
        debugPrint('用户信息更新成功');
      } else {
        debugPrint('更新用户信息失败: ${result.desc}');
      }
    } catch (e) {
      debugPrint('更新用户信息失败: $e');
    }
  }

  Future<void> markConversationMessageAsRead(String conversationID) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .cleanConversationUnreadMessageCount(
            conversationID: conversationID,
            cleanTimestamp: 0,
            cleanSequence: 0,
          );

      if (result.code != 0) {
        debugPrint('标记已读失败: ${result.desc}');
      }
    } catch (e) {
      debugPrint('标记已读失败: $e');
    }
  }

  Future<void> pinConversation(
      {required String conversationID, required bool pinned}) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .pinConversation(
            conversationID: conversationID,
            isPinned: pinned,
          );

      if (result.code != 0) {
        debugPrint('置顶会话失败: ${result.desc}');
      }
    } catch (e) {
      debugPrint('置顶会话失败: $e');
    }
  }

  Future<void> deleteConversation({required String conversationID}) async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .deleteConversation(
            conversationID: conversationID,
          );

      if (result.code != 0) {
        debugPrint('删除会话失败: ${result.desc}');
      }
    } catch (e) {
      debugPrint('删除会话失败: $e');
    }
  }

  String getMessageDigest(V2TimMessage? msg) {
    if (msg == null) return '';

    final elemType = msg.elemType;

    switch (elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return msg.textElem?.text ?? '';
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return '[图片]';
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return '[视频]';
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return '[语音]';
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        return '[文件]';
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return '[位置]';
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return '[表情]';
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return '[自定义消息]';
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        return '[群通知]';
      default:
        return '[消息]';
    }
  }

  Future<int> getTotalUnreadMsgCount() async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        return 0;
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getTotalUnreadMessageCount();

      if (result.code == 0 && result.data != null) {
        return result.data!;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getUnhandledFriendApplicationCount() async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        return 0;
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .getFriendApplicationList();

      if (result.code == 0 && result.data != null) {
        return (result.data!.friendApplicationList ?? [])
            .whereType<V2TimFriendApplication>()
            .where((app) =>
                app.type ==
                FriendApplicationTypeEnum
                    .V2TIM_FRIEND_APPLICATION_COME_IN.index)
            .length;
      }
      return 0;
    } catch (e) {
      debugPrint('获取好友申请数量失败: $e');
      return 0;
    }
  }

  Future<List<V2TimFriendApplication>> getSentFriendApplications() async {
    try {
      if (!_isInitialized || !_isLoggedIn) {
        throw Exception('腾讯云 IM 未初始化或未登录');
      }

      final result = await TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .getFriendApplicationList();

      if (result.code == 0 && result.data != null) {
        return (result.data!.friendApplicationList ?? [])
            .whereType<V2TimFriendApplication>()
            .where((app) =>
                app.type ==
                FriendApplicationTypeEnum
                    .V2TIM_FRIEND_APPLICATION_SEND_OUT.index)
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('获取发出的好友申请失败: $e');
      return [];
    }
  }

  void dispose() {
    _messageController.close();
    _connectionController.close();
    _conversationController.close();
    _totalUnreadController.close();
  }
}

enum ConnectionState {
  connected,
  connecting,
  disconnected,
  kicked,
  tokenExpired,
}
