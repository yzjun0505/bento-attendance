/**
 * OpenIM 服务层 - 深度整合版
 */
const axios = require('axios');
const os = require('os');

// OpenIM 配置
const OPENIM_API_URL = process.env.OPENIM_API_URL || 'http://localhost:10002';
const OPENIM_WS_URL = process.env.OPENIM_WS_URL || 'ws://localhost:10001';
const OPENIM_EXTERNAL_API_URL = process.env.OPENIM_EXTERNAL_API_URL;
const OPENIM_EXTERNAL_WS_URL = process.env.OPENIM_EXTERNAL_WS_URL;
const OPENIM_SECRET = process.env.OPENIM_SECRET || 'openIM123';
const OPENIM_ADMIN_USERID = process.env.OPENIM_ADMIN_USERID || 'imAdmin';
const OPENIM_MOCK_MODE = process.env.OPENIM_MOCK_MODE === 'true' || false;

class OpenIMService {
  constructor() {
    this.apiUrl = OPENIM_API_URL;
    this.wsUrl = OPENIM_WS_URL;
    this.secret = OPENIM_SECRET;
    this.adminUserID = OPENIM_ADMIN_USERID;
    this._adminToken = null;
    this._adminTokenExpire = 0;
    this._userInfoCache = new Map();
    this._userTokenCache = new Map();
    this._mockTokens = new Map();
  }

  /**
   * 生成唯一的 operationID
   */
  _genOperationID() {
    return `bento_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  }

  /**
   * 发送请求到 OpenIM API
   */
  async request(endpoint, data, options = {}) {
    const { method = 'post', token } = options;
    try {
      const headers = {
        'Content-Type': 'application/json',
        'operationID': this._genOperationID(),
      };
      if (token) {
        headers['token'] = token;
      }

      const response = await axios({
        method,
        url: `${this.apiUrl}${endpoint}`,
        data,
        headers,
        timeout: 15000,
      });
      return response.data;
    } catch (error) {
      console.error(`OpenIM API 请求失败 [${endpoint}]:`, error.message);
      throw error;
    }
  }

  /**
   * 获取管理员 token（带缓存）
   */
  async getAdminToken() {
    const now = Date.now();
    if (this._adminToken && now < this._adminTokenExpire) {
      return this._adminToken;
    }

    try {
      const response = await this.request('/auth/get_admin_token', {
        secret: this.secret,
        platformID: 5, // 管理员平台
        userID: this.adminUserID,
      });

      if (response.errCode === 0 && response.data?.token) {
        this._adminToken = response.data.token;
        // 缓存 1 小时
        this._adminTokenExpire = now + 3600 * 1000;
        console.log('OpenIM 管理员 token 获取成功');
        return this._adminToken;
      }
      
      console.error('获取管理员 token 失败:', response.errMsg);
      return null;
    } catch (error) {
      console.error('获取管理员 token 异常:', error.message);
      return null;
    }
  }

  /**
   * 注册用户到 OpenIM
   */
  async registerUser({ userID, nickname, faceURL }) {
    // Mock模式：直接返回成功
    if (OPENIM_MOCK_MODE) {
      console.log(`OpenIM [Mock] 用户注册成功: ${userID}`);
      return { success: true, data: null, existed: false };
    }
    
    try {
      const adminToken = await this.getAdminToken();
      if (!adminToken) {
        return { success: false, message: '无法获取管理员 token' };
      }

      const response = await this.request('/user/user_register', {
        users: [{
          userID: userID.toString(),
          nickname: nickname || `用户${userID}`,
          faceURL: faceURL || '',
          ex: '',
        }],
      }, { token: adminToken });

      if (response.errCode === 0) {
        console.log(`OpenIM 用户注册成功: ${userID}`);
        return { success: true, data: response.data };
      }
      // 用户已存在不算失败
      const errMsg = response.errMsg || '';
      const errDlt = response.errDlt || '';
      if (response.errCode === 1102 || errMsg.includes('RegisteredAlready') || errDlt.includes('registered already')) {
        console.log(`OpenIM 用户已存在: ${userID}`);
        return { success: true, data: null, existed: true };
      }
      return { success: false, message: errMsg || errDlt };
    } catch (error) {
      console.error('OpenIM用户注册失败:', error.message);
      return { success: false, message: error.message };
    }
  }

  /**
   * 获取用户 token
   */
  async getUserToken(userID, platformID = 1) {
    // Mock模式：生成模拟token
    if (OPENIM_MOCK_MODE) {
      const mockToken = `mock_im_token_${userID}_${Date.now()}`;
      this._mockTokens.set(userID.toString(), mockToken);
      console.log(`OpenIM [Mock] 获取用户 token 成功: ${userID}`);
      return { success: true, data: { token: mockToken } };
    }
    
    try {
      const adminToken = await this.getAdminToken();
      if (!adminToken) {
        return { success: false, message: '无法获取管理员 token' };
      }

      const response = await this.request('/auth/get_user_token', {
        platformID: platformID,
        userID: userID.toString(),
      }, { token: adminToken });

      if (response.errCode === 0) {
        console.log(`OpenIM 获取用户 token 成功: ${userID}`);
        return { success: true, data: response.data };
      }
      console.error('获取用户 token 失败:', response.errMsg, response.errDlt);
      return { success: false, message: response.errMsg || response.errDlt };
    } catch (error) {
      console.error('获取IM Token失败:', error.message);
      return { success: false, message: error.message };
    }
  }

  /**
   * 获取用户 token（带缓存，减少频繁向 OpenIM 拉取）
   * 注意：这里缓存只用于后端调用 OpenIM REST API，不影响前端拿到的 imToken。
   */
  async getUserTokenCached(userID, platformID = 1) {
    const userIDStr = userID.toString();
    const now = Date.now();
    const cached = this._userTokenCache.get(userIDStr);
    if (cached && now < cached.expire && cached.token) {
      return { success: true, data: { token: cached.token } };
    }

    const tokenResult = await this.getUserToken(userID, platformID);
    if (tokenResult?.success && tokenResult?.data?.token) {
      // 经验值：缓存 55 分钟（管理员 token 也是按小时缓存）
      this._userTokenCache.set(userIDStr, {
        token: tokenResult.data.token,
        expire: now + 55 * 60 * 1000,
      });
    }
    return tokenResult;
  }

  /**
   * 获取用户信息（带缓存）
   */
  async getUserInfo(userID) {
    const userIDStr = userID.toString();
    const now = Date.now();
    
    // 检查缓存
    const cached = this._userInfoCache.get(userIDStr);
    if (cached && now < cached.expire) {
      return { success: true, data: cached.data };
    }
    
    try {
      const adminToken = await this.getAdminToken();
      if (!adminToken) {
        return { success: false, message: '无法获取管理员 token' };
      }

      const response = await this.request('/user/get_users_info', {
        userIDList: [userIDStr],
      }, { token: adminToken });

      if (response.errCode === 0 && response.data?.userInfoList?.length > 0) {
        const userInfo = response.data.userInfoList[0];
        // 缓存5分钟
        this._userInfoCache.set(userIDStr, {
          data: userInfo,
          expire: now + 5 * 60 * 1000
        });
        return { success: true, data: userInfo };
      }
      return { success: false, message: '用户不存在' };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  /**
   * 更新用户信息
   */
  async updateUserInfo({ userID, nickname, faceURL, ex }) {
    try {
      const adminToken = await this.getAdminToken();
      if (!adminToken) {
        return { success: false, message: '无法获取管理员 token' };
      }

      const response = await this.request('/user/update_user_info', {
        userID: userID.toString(),
        nickname,
        faceURL: faceURL || '',
        ex: ex || '',
      }, { token: adminToken });

      if (response.errCode === 0) {
        // 清除用户信息缓存
        this._userInfoCache.delete(userID.toString());
        return { success: true };
      }
      return { success: false, message: response.errMsg };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  /**
   * 发送消息
   */
  async sendMessage({ recvID, sendID, content, contentType = 101, isGroup = false, groupID }) {
    try {
      const adminToken = await this.getAdminToken();
      if (!adminToken) {
        return { success: false, message: '无法获取管理员 token' };
      }

      const response = await this.request('/msg/send_msg', {
        recvID: recvID,
        sendID: sendID.toString(),
        groupID: isGroup ? recvID : (groupID || ''),
        senderPlatformID: 5,
        contentType: contentType,
        content: JSON.stringify({ text: content }),
        isOnlineOnly: false,
        notOfflinePush: false,
        offlinePushInfo: {
          title: '新消息',
          desc: content.substring(0, 50),
          ex: '',
          iOSPushSound: '',
          iOSBadgeCount: true,
        },
      }, { token: adminToken });

      if (response.errCode === 0) {
        return { success: true, data: response.data };
      }
      return { success: false, message: response.errMsg };
    } catch (error) {
      console.error('发送消息失败:', error.message);
      return { success: false, message: error.message };
    }
  }

  /**
   * 获取排序后的会话列表（置顶优先 + 最后消息时间倒序）
   * OpenIM API: /conversation/get_sorted_conversation_list
   */
  async getSortedConversationList({ userID, pageNumber = 1, showNumber = 20, conversationIDs = [] }) {
    try {
      const tokenResult = await this.getUserTokenCached(userID);
      if (!tokenResult?.success) {
        return { success: false, message: tokenResult?.message || '无法获取用户 token' };
      }

      const resp = await this.request('/conversation/get_sorted_conversation_list', {
        userID: userID.toString(),
        conversationIDs,
        pagination: { pageNumber, showNumber },
      }, { token: tokenResult.data.token });

      if (resp.errCode === 0) {
        return { success: true, data: resp.data };
      }
      return { success: false, message: resp.errMsg || resp.errDlt || '获取会话列表失败' };
    } catch (err) {
      return { success: false, message: err.message };
    }
  }

  /**
   * 获取会话已读 seq / 最大 seq（用于计算未读、以及一键清除未读）
   * OpenIM API: /msg/get_conversations_has_read_and_max_seq
   */
  async getConversationsHasReadAndMaxSeq({ userID, conversationIDs = [], returnPinned = false }) {
    try {
      const tokenResult = await this.getUserTokenCached(userID);
      if (!tokenResult?.success) {
        return { success: false, message: tokenResult?.message || '无法获取用户 token' };
      }

      const resp = await this.request('/msg/get_conversations_has_read_and_max_seq', {
        userID: userID.toString(),
        conversationIDs,
        returnPinned,
      }, { token: tokenResult.data.token });

      if (resp.errCode === 0) {
        return { success: true, data: resp.data };
      }
      return { success: false, message: resp.errMsg || resp.errDlt || '获取会话 seq 信息失败' };
    } catch (err) {
      return { success: false, message: err.message };
    }
  }

  /**
   * 标记会话为已读（清空未读数）
   * OpenIM API: /msg/mark_conversation_as_read
   */
  async markConversationAsRead({ userID, conversationID, hasReadSeq, seqs = [] }) {
    try {
      const tokenResult = await this.getUserTokenCached(userID);
      if (!tokenResult?.success) {
        return { success: false, message: tokenResult?.message || '无法获取用户 token' };
      }

      const resp = await this.request('/msg/mark_conversation_as_read', {
        userID: userID.toString(),
        conversationID,
        hasReadSeq,
        seqs,
      }, { token: tokenResult.data.token });

      if (resp.errCode === 0) {
        return { success: true, data: resp.data };
      }
      return { success: false, message: resp.errMsg || resp.errDlt || '标记已读失败' };
    } catch (err) {
      return { success: false, message: err.message };
    }
  }

  /**
   * 更新会话字段（例如置顶/免打扰/阅后即焚等）
   * OpenIM API: /conversation/set_conversations
   */
  async setConversations({ operatorUserID, userIDs, conversation }) {
    try {
      const tokenResult = await this.getUserTokenCached(operatorUserID);
      if (!tokenResult?.success) {
        return { success: false, message: tokenResult?.message || '无法获取用户 token' };
      }

      const resp = await this.request('/conversation/set_conversations', {
        userIDs,
        conversation,
      }, { token: tokenResult.data.token });

      if (resp.errCode === 0) {
        return { success: true, data: resp.data };
      }
      return { success: false, message: resp.errMsg || resp.errDlt || '更新会话失败' };
    } catch (err) {
      return { success: false, message: err.message };
    }
  }

  /**
   * 获取给客户端使用的配置信息
   */
  getConfig(host) {
    // 优先使用明确定义的外部地址
    if (OPENIM_EXTERNAL_API_URL && OPENIM_EXTERNAL_WS_URL) {
      return {
        apiAddr: OPENIM_EXTERNAL_API_URL,
        wsAddr: OPENIM_EXTERNAL_WS_URL,
      };
    }

    // 否则根据请求的 host 动态推算
    const hostWithoutPort = host.split(':')[0];

    // 真机/局域网访问场景：
    // - 如果管理端从 localhost 打开，hostWithoutPort 会是 localhost，但手机无法访问 localhost
    // - 允许通过环境变量指定一个“对外可访问”的 IP/域名，或自动探测局域网 IP
    const publicHost = process.env.OPENIM_PUBLIC_HOST || process.env.PUBLIC_HOST || '';
    const isLocalhost = hostWithoutPort === 'localhost' || hostWithoutPort === '127.0.0.1';

    const detectLanIP = () => {
      try {
        const nets = os.networkInterfaces();
        const candidates = [];
        for (const name of Object.keys(nets)) {
          for (const net of nets[name] || []) {
            if (net.family !== 'IPv4' || net.internal) continue;
            candidates.push(net.address);
          }
        }
        // 优先挑常见局域网段
        const preferred =
          candidates.find((ip) => ip.startsWith('192.168.')) ||
          candidates.find((ip) => ip.startsWith('10.')) ||
          candidates.find((ip) => ip.startsWith('172.16.') || ip.startsWith('172.17.') || ip.startsWith('172.18.') || ip.startsWith('172.19.') || ip.startsWith('172.2') || ip.startsWith('172.3')) ||
          candidates[0];
        return preferred || '';
      } catch (e) {
        return '';
      }
    };

    const finalHost = isLocalhost
      ? (publicHost || detectLanIP() || hostWithoutPort)
      : hostWithoutPort;
    
    // 注意：如果后端访问地址是 localhost，但客户端（手机）不在本地，推算会失败
    // 在生产环境或真机调试时，强烈建议指明 OPENIM_EXTERNAL_API_URL
    return {
      apiAddr: `http://${finalHost}:10002`,
      wsAddr: `ws://${finalHost}:10001`,
    };
  }
}

const openIMService = new OpenIMService();
module.exports = openIMService;
