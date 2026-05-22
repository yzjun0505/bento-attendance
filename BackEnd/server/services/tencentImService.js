/**
 * 腾讯云 IM 服务层
 * 文档: https://cloud.tencent.com/document/product/269/1519
 */
const axios = require('axios');
const crypto = require('crypto');
const zlib = require('zlib');

const TIM_SDK_APP_ID = process.env.TIM_SDK_APP_ID || process.env.TENCENT_IM_SDK_APP_ID || '';
const TIM_SECRET_KEY = process.env.TIM_SECRET_KEY || process.env.TENCENT_IM_SECRET_KEY || '';
const TIM_ADMIN_USERID = process.env.TIM_ADMIN_USERID || 'administrator';
const TIM_API_HOST = process.env.TIM_API_HOST || 'console.tim.qq.com';
const TIM_EXPIRE_TIME = process.env.TIM_EXPIRE_TIME || 604800; // 7天

class TencentIMService {
  constructor() {
    this.sdkAppId = TIM_SDK_APP_ID;
    this.secretKey = TIM_SECRET_KEY;
    this.adminUserID = TIM_ADMIN_USERID;
    this.apiHost = TIM_API_HOST;
    this._userSigCache = new Map();
    this._userInfoCache = new Map();
  }

  _ensureConfigured() {
    if (!this.sdkAppId || !this.secretKey) {
      throw new Error('腾讯云 IM 未配置 TIM_SDK_APP_ID 或 TIM_SECRET_KEY');
    }
  }

  _genUserSig(userID, expireTime = TIM_EXPIRE_TIME) {
    this._ensureConfigured();
    const identifier = userID.toString();
    const sdkAppId = parseInt(this.sdkAppId, 10);
    const expire = parseInt(expireTime, 10);
    const time = Math.floor(Date.now() / 1000);

    const contentToBeSigned =
      `TLS.identifier:${identifier}\n` +
      `TLS.sdkappid:${sdkAppId}\n` +
      `TLS.time:${time}\n` +
      `TLS.expire:${expire}\n`;

    const signature = crypto
      .createHmac('sha256', this.secretKey)
      .update(contentToBeSigned)
      .digest('base64');

    const sigDoc = {
      'TLS.ver': '2.0',
      'TLS.identifier': identifier,
      'TLS.sdkappid': sdkAppId,
      'TLS.expire': expire,
      'TLS.time': time,
      'TLS.sig': signature,
    };

    return zlib
      .deflateSync(Buffer.from(JSON.stringify(sigDoc)))
      .toString('base64')
      .replace(/\+/g, '*')
      .replace(/\//g, '-')
      .replace(/=/g, '_');
  }

  _genRandom() {
    return Math.floor(Math.random() * 4294967295);
  }

  async request(serviceName, command, data, options = {}) {
    const { userID = this.adminUserID } = options;
    const userSig = this._genUserSig(userID);
    const random = this._genRandom();
    
    const url = `https://${this.apiHost}/v4/${serviceName}/${command}?sdkappid=${this.sdkAppId}&identifier=${userID}&usersig=${userSig}&random=${random}&contenttype=json`;
    
    try {
      const response = await axios({
        method: 'post',
        url,
        data,
        headers: {
          'Content-Type': 'application/json',
        },
        timeout: 15000,
      });
      
      return response.data;
    } catch (error) {
      console.error(`腾讯云 IM API 请求失败 [${serviceName}/${command}]:`, error.message);
      throw error;
    }
  }

  async registerUser({ userID, nickname, faceURL, role }) {
    try {
      const displayName = nickname || `用户${userID}`;

      const response = await this.request('im_open_login_svc', 'account_import', {
        Identifier: userID.toString(),
        Nick: displayName,
        FaceUrl: faceURL || '',
      });
      
      if (response.ActionStatus === 'OK' || response.ErrorCode === 0 || response.ErrorCode === 70168) {
        console.log(`腾讯云 IM 用户注册成功: ${userID}`);
        return { success: true, data: null, existed: response.ErrorCode === 70168 };
      }
      
      console.error('腾讯云 IM 用户注册失败:', response.ErrorInfo);
      return { success: false, message: response.ErrorInfo || '注册失败' };
    } catch (error) {
      console.error('腾讯云 IM 用户注册异常:', error.message);
      return { success: false, message: error.message };
    }
  }

  async getUserToken(userID, expireTime = TIM_EXPIRE_TIME) {
    try {
      const userSig = this._genUserSig(userID, expireTime);
      console.log(`腾讯云 IM 获取 UserSig 成功: ${userID}`);
      return { 
        success: true, 
        data: { 
          token: userSig,
          expireTime: expireTime,
        } 
      };
    } catch (error) {
      console.error('获取 UserSig 失败:', error.message);
      return { success: false, message: error.message };
    }
  }

  async getUserInfo(userID) {
    const userIDStr = userID.toString();
    const now = Date.now();
    
    const cached = this._userInfoCache.get(userIDStr);
    if (cached && now < cached.expire) {
      return { success: true, data: cached.data };
    }
    
    try {
      const response = await this.request('im_open_login_svc', 'get_appid_info', {
        IdentifierList: [userIDStr],
      });
      
      if (response.ActionStatus === 'OK' && response.Result?.length > 0) {
        const userInfo = response.Result[0];
        this._userInfoCache.set(userIDStr, {
          data: userInfo,
          expire: now + 5 * 60 * 1000,
        });
        return { success: true, data: userInfo };
      }
      return { success: false, message: '用户不存在' };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  async updateUserInfo({ userID, nickname, faceURL, ex, role }) {
    try {
      const displayName = nickname || '';

      const response = await this.request('im_open_login_svc', 'account_import', {
        Identifier: userID.toString(),
        Nick: displayName,
        FaceUrl: faceURL || '',
      });
      
      if (response.ActionStatus === 'OK' || response.ErrorCode === 0) {
        this._userInfoCache.delete(userID.toString());
        return { success: true };
      }
      return { success: false, message: response.ErrorInfo };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  async sendMessage({ recvID, sendID, content, contentType = 'TIMTextElem' }) {
    try {
      const msgBody = [];
      
      if (contentType === 'TIMTextElem') {
        msgBody.push({
          MsgType: 'TIMTextElem',
          MsgContent: { Text: content },
        });
      } else {
        msgBody.push({
          MsgType: contentType,
          MsgContent: content,
        });
      }
      
      const response = await this.request('openim', 'sendmsg', {
        SyncOtherMachine: 1,
        From_Account: sendID.toString(),
        To_Account: recvID.toString(),
        MsgRandom: this._genRandom(),
        MsgTimeStamp: Math.floor(Date.now() / 1000),
        MsgBody: msgBody,
        OfflinePushInfo: {
          PushFlag: 1,
          Title: '新消息',
          Desc: content.substring(0, 50),
        },
      });
      
      if (response.ActionStatus === 'OK') {
        return { success: true, data: response };
      }
      return { success: false, message: response.ErrorInfo };
    } catch (error) {
      console.error('发送消息失败:', error.message);
      return { success: false, message: error.message };
    }
  }

  async getConversations({ userID, pageNumber = 1, showNumber = 20 }) {
    try {
      const response = await this.request('open_msg', 'get_conversations', {
        From_Account: userID.toString(),
        TimeStamp: 0,
        OrderType: 1,
      });
      
      if (response.ActionStatus === 'OK') {
        const conversations = response.ConversationListSet || [];
        const start = (pageNumber - 1) * showNumber;
        const paginated = conversations.slice(start, start + showNumber);
        
        return { 
          success: true, 
          data: {
            conversationList: paginated.map(conv => ({
              conversationID: conv.ConversationId,
              type: conv.Type,
              peerAccount: conv.PeerAccount,
              unreadCount: conv.UnreadMsgCount || 0,
              lastMsg: conv.LastMsg,
              isActive: conv.IsActive,
            })),
            totalCount: conversations.length,
          }
        };
      }
      return { success: false, message: response.ErrorInfo || '获取会话列表失败' };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  async markConversationAsRead({ userID, peerAccount }) {
    try {
      const response = await this.request('open_msg', 'set_c2c_peceipt', {
        From_Account: userID.toString(),
        PeerAccount: peerAccount.toString(),
      });
      
      if (response.ActionStatus === 'OK') {
        return { success: true, data: null };
      }
      return { success: false, message: response.ErrorInfo || '标记已读失败' };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  async getSortedConversationList({ userID, pageNumber = 1, showNumber = 20 }) {
    return this.getConversations({ userID, pageNumber, showNumber });
  }

  async getConversationsHasReadAndMaxSeq({ userID, conversationIDs = [] }) {
    try {
      const response = await this.request('open_msg', 'get_conversations', {
        From_Account: userID.toString(),
        TimeStamp: 0,
        OrderType: 1,
      });
      
      if (response.ActionStatus === 'OK') {
        const seqs = {};
        const conversations = response.ConversationListSet || [];
        
        for (const conv of conversations) {
          seqs[conv.ConversationId] = {
            maxSeq: conv.LastMsg?.MsgSeq || 0,
            hasReadSeq: conv.UnreadMsgCount > 0 ? 0 : (conv.LastMsg?.MsgSeq || 0),
          };
        }
        
        return { success: true, data: { seqs } };
      }
      return { success: false, message: response.ErrorInfo || '获取会话 seq 信息失败' };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  async setConversations({ operatorUserID, userIDs, conversation }) {
    try {
      const response = await this.request('open_msg', 'set_conversation', {
        From_Account: operatorUserID.toString(),
        ConversationId: conversation.conversationID,
        IsPinned: conversation.isPinned ? 1 : 0,
      });
      
      if (response.ActionStatus === 'OK') {
        return { success: true, data: null };
      }
      return { success: false, message: response.ErrorInfo || '更新会话失败' };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  getConfig(host) {
    return {
      sdkAppId: this.sdkAppId,
      apiHost: this.apiHost,
    };
  }

  getSdkAppId() {
    return this.sdkAppId;
  }
}

const tencentIMService = new TencentIMService();
module.exports = tencentIMService;
