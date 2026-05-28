# 境图项目协同管理平台 📸

> 企业级智能考勤管理系统，支持外勤打卡、实时定位、水印防伪、腾讯云 IM 即时通讯、进度追踪等功能

[![GitHub Stars](https://img.shields.io/github/stars/yzjun0505/bento-attendance)](https://github.com/yzjun0505/bento-attendance/stargazers)
[![GitHub License](https://img.shields.io/github/license/yzjun0505/bento-attendance)](https://github.com/yzjun0505/bento-attendance/blob/main/LICENSE)
[![Project Status](https://img.shields.io/badge/status-active-green.svg)](https://github.com/yzjun0505/bento-attendance)

---

## 📋 目录

- [功能特性](#功能特性)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [环境变量配置](#环境变量配置)
- [一键部署](#一键部署)
- [项目亮点](#项目亮点)
- [License](#license)

---

## ✨ 功能特性

### 📱 移动端 (Flutter)
- **外勤打卡** - 支持多种打卡类型（上班、下班、外出、请假），误触防护确认弹窗与重复拦截
- **实时定位** - 集成高德地图，支持围栏打卡与轨迹回放
- **水印防伪** - 拍照自动添加时间、地点、用户信息、防伪码水印，自适应字号适配长地址
- **离线模式** - 网络断开时可离线打卡，自动同步
- **腾讯云 IM** - 即时通讯，支持单聊、群聊、系统通知
- **轨迹追踪** - 记录外勤人员移动轨迹，支持历史回放
- **进度上报** - 项目任务节点进度上报，每张照片自动添加水印
- **排班管理** - 查看个人排班表与打卡提醒
- **假期管理** - 查看节假日安排

### 🖥️ Web 管理端 (Vue.js)
- **用户管理** - 员工信息管理、角色权限分配
- **打卡管理** - 查看打卡记录、异常处理
- **排班管理** - 班次设置、排班表管理
- **项目管理** - 项目创建、员工绑定、项目进度驾驶舱
- **进度追踪** - 阶段节点管理、进度上报审核
- **审批管理** - 请假、外出审批流程
- **数据分析** - 考勤统计、报表导出（管理员不计入统计）
- **水印模板** - 自定义水印样式配置
- **AI 数据助理** - 可拖动悬浮助手，支持自然语言查询考勤、项目、审批、报表和确认式业务操作

### 🤖 AI 助手能力
- **对话查数据** - 查询今日/本周/本月出勤、异常打卡、项目外勤、员工个人考勤、审批待办
- **结构化结果** - 自动返回统计卡片、表格和图表数据，Web 管理端可直接展示
- **确认式操作** - 导出报表、发送通知、创建排班等操作需要二次确认后才执行
- **多端接入** - Web 管理端和 Flutter 移动端都内置可拖动 AI 小人入口
- **安全兜底** - AI 只通过后端受控工具访问数据，继承当前登录用户权限；未配置模型时使用本地数据模式

### 🔧 后端服务 (Node.js)
- **RESTful API** - 标准化接口设计
- **JWT 认证** - Access Token + Refresh Token 双 token 机制
- **数据持久化** - MySQL 主数据库，MongoDB 可选扩展
- **腾讯云 IM** - 服务端签发 UserSig，App 直连腾讯云
- **高德地图** - 地理编码、逆地理编码
- **文件上传** - 打卡照片、进度照片存储管理
- **App 更新** - 版本检查与 APK 下载分发

---

## 🛠️ 技术栈

| 分类 | 技术 | 版本 |
|------|------|------|
| 移动端 | Flutter | 3.19+ |
| 后端 | Node.js | 20+ |
| 前端 | Vue.js | 3+ |
| UI 框架 | Element Plus | - |
| 状态管理 (Flutter) | BLoC | - |
| 状态管理 (Vue) | Pinia | - |
| 数据库 | MySQL | 8.0+ |
| 数据库 (可选) | MongoDB | 7.0+ |
| 即时通讯 | 腾讯云 IM | - |
| 地图服务 | 高德地图 | Web API |
| 构建工具 | Docker | 24+ |
| 反向代理 | Nginx | 1.27 |

---

## 📁 项目结构

```
├── MobileApp/                  # Flutter 移动端
│   ├── lib/
│   │   ├── api/                # API 客户端 (Dio)
│   │   ├── blocs/              # BLoC 状态管理 (auth, attendance, progress, tracking 等)
│   │   ├── screens/            # 页面组件 (login, home, attendance, progress, chat 等)
│   │   ├── services/           # 业务服务
│   │   ├── utils/              # 工具函数
│   │   └── widgets/            # UI 组件
│   └── pubspec.yaml
│
├── BackEnd/                    # 后端服务
│   ├── server/                 # Node.js Express 服务
│   │   ├── controllers/        # 控制器
│   │   ├── models/             # 数据模型
│   │   ├── routes/             # 路由定义
│   │   ├── services/           # 业务服务
│   │   ├── middleware/         # 中间件 (auth, scope)
│   │   └── tests/              # 单元测试
│   ├── web-admin/              # Vue.js 管理端
│   │   └── src/
│   │       ├── api/            # API 请求 (Axios)
│   │       ├── components/     # 组件
│   │       ├── views/          # 页面
│   │       └── stores/         # Pinia 状态管理
│   ├── dist/                   # Web 管理端构建产物
│   ├── docker-compose.prod.yml # 生产环境 Docker Compose
│   ├── Dockerfile              # 后端 Docker 镜像
│   ├── nginx.prod.conf         # Nginx 生产配置
│   └── DEPLOYMENT.md           # 详细部署指南
│
└── TUIKit_Flutter/             # 腾讯云 IM UIKit (本地 path 依赖)
```

---

## 🚀 快速开始

### 环境要求

- Flutter 3.19+
- Node.js 20+
- MySQL 8.0+
- Docker 24+

### 1. 启动 MySQL

```bash
cd BackEnd && docker compose -f docker-compose.prod.yml up -d mysql
```

### 2. 启动后端服务

```bash
cd BackEnd/server
cp .env.example .env   # 编辑 .env 填入数据库密码等配置
npm install
npm start
```

### 3. 启动 Web 管理端

```bash
cd BackEnd/web-admin
npm install
npm run dev
```

### 4. 启动移动端

```bash
cd MobileApp
flutter pub get
flutter run --dart-define=SERVER_IP=你的局域网IP
```

---

## ⚙️ 环境变量配置

### BackEnd/server/.env

```env
# 服务器端口
PORT=3000

# MySQL 数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=user_information

# MongoDB 配置（可选）
MONGODB_URI=
MONGODB_DB=bento
MONGODB_REQUIRED=false

# JWT 认证
JWT_SECRET=your_jwt_secret_here
JWT_EXPIRES_IN=12h
JWT_REFRESH_SECRET=your_jwt_refresh_secret_here
JWT_REFRESH_EXPIRES_IN=7d

# 高德地图 API Key
AMAP_KEY=your_amap_key_here

# AI 助手（兼容 OpenAI 风格接口，不配置时启用本地数据模式）
AI_API_KEY=
AI_BASE_URL=https://api.deepseek.com/v1
AI_MODEL=deepseek-v4-flash
AI_TIMEOUT_MS=30000

# 腾讯云 IM 配置
TIM_SDK_APP_ID=your_tencent_im_app_id
TIM_SECRET_KEY=your_tencent_im_secret_key
TIM_ADMIN_USERID=administrator
TIM_API_HOST=console.tim.qq.com
TIM_EXPIRE_TIME=604800

# App 更新配置
APP_ANDROID_VERSION_NAME=1.0.0
APP_ANDROID_VERSION_CODE=1
APP_ANDROID_MIN_VERSION_CODE=1
APP_ANDROID_FORCE_UPDATE=false
APP_ANDROID_DOWNLOAD_URL=http://your-server/uploads/releases/app-release.apk
APP_ANDROID_RELEASE_NOTES=更新日志
```

### MobileApp 运行参数

```bash
flutter run \
  --dart-define=SERVER_IP=192.168.1.100 \
  --dart-define=AMAP_KEY=your_amap_key \
  --dart-define=AMAP_WEB_KEY=your_amap_web_key
```

---

## 🚢 一键部署

项目提供一键部署脚本，自动检测变更组件并部署到服务器：

```bash
cd BackEnd && ./deploy.sh            # 自动检测变更组件
cd BackEnd && ./deploy.sh --mobile   # 仅 APK
cd BackEnd && ./deploy.sh --web      # 仅 Web 管理端
cd BackEnd && ./deploy.sh --backend  # 仅后端
cd BackEnd && ./deploy.sh --all      # 全部部署
```

部署脚本自动完成：版本号递增、构建、rsync 同步、APK 上传、Docker 容器重建。

详细部署指南见 [DEPLOYMENT.md](BackEnd/DEPLOYMENT.md)。

---

## 🌟 项目亮点

### 1. 水印防伪系统
- 实时预览与实际拍摄一致性保证
- 自动添加时间戳、地理位置、用户信息、防伪码
- 自适应字号适配长地址，避免与右下角元素重叠
- 毛玻璃效果卡片背景

### 2. 离线打卡模式
- 网络断开时可正常打卡
- 自动同步机制确保数据完整性
- 本地缓存使用 SharedPreferences

### 3. 腾讯云 IM 即时通讯
- 基于腾讯云 IM 实现企业级消息推送
- 支持单聊、群聊、系统通知
- 服务端签发 UserSig，App 直连腾讯云，无需自建 IM 服务

### 4. 全链路数据追踪
- 移动端轨迹记录与回放
- 打卡位置验证
- 数据可视化报表

### 5. 项目进度追踪
- 阶段节点自动状态流转
- 进度上报集成水印拍照
- Web 端驾驶舱可视化项目进展

---

## 📊 数据库设计

### 核心数据表

| 表名 | 说明 | 关键字段 |
|------|------|----------|
| users | 用户信息 | id, username, name, role |
| checkins | 打卡记录 | id, user_id, type, location, photo |
| schedules | 排班表 | id, user_id, shift_id, date |
| shifts | 班次定义 | id, name, start_time, end_time |
| projects | 项目信息 | id, name, address, radius |
| task_nodes | 任务节点 | id, project_id, name, status, order |
| progress_reports | 进度上报 | id, task_node_id, user_id, photo, description |
| approvals | 审批记录 | id, user_id, type, status |

---

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 项目
2. 创建特性分支 `git checkout -b feature/xxx`
3. 提交更改 `git commit -m 'feat: xxx'`
4. 推送到分支 `git push origin feature/xxx`
5. 创建 Pull Request

---

## 📝 License

MIT License - 详见 [LICENSE](LICENSE)

---

## 📞 联系方式

- 项目地址: [https://github.com/yzjun0505/bento-attendance](https://github.com/yzjun0505/bento-attendance)
- 作者: yzjun0505

---

*Built with ❤️ for enterprise attendance management*
