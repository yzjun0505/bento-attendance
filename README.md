# 境图考勤系统 📸

> 企业级智能考勤管理系统，支持外勤打卡、实时定位、水印防伪、即时通讯等功能

[![GitHub Stars](https://img.shields.io/github/stars/yzjun0505/bento-attendance)](https://github.com/yzjun0505/bento-attendance/stargazers)
[![GitHub License](https://img.shields.io/github/license/yzjun0505/bento-attendance)](https://github.com/yzjun0505/bento-attendance/blob/main/LICENSE)
[![Project Status](https://img.shields.io/badge/status-active-green.svg)](https://github.com/yzjun0505/bento-attendance)

***

## 📋 目录

- [功能特性](#功能特性)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [环境变量配置](#环境变量配置)
- [项目亮点](#项目亮点)
- [License](#license)

***

## ✨ 功能特性

### 📱 移动端 (Flutter)

- **外勤打卡** - 支持多种打卡类型（上班、下班、外出、请假）
- **实时定位** - 集成高德地图，支持围栏打卡
- **水印防伪** - 拍照自动添加时间、地点、用户信息水印
- **离线模式** - 网络断开时可离线打卡，自动同步
- **消息推送** - 集成 OpenIM 即时通讯
- **轨迹追踪** - 记录外勤人员移动轨迹
- **排班管理** - 查看个人排班表
- **假期管理** - 查看节假日安排

### 🖥️ Web 管理端 (Vue.js)

- **用户管理** - 员工信息管理、角色权限分配
- **打卡管理** - 查看打卡记录、异常处理
- **排班管理** - 班次设置、排班表管理
- **项目管理** - 项目创建、员工绑定
- **审批管理** - 请假、外出审批流程
- **数据分析** - 考勤统计、报表导出
- **水印模板** - 自定义水印样式配置

### 🔧 后端服务 (Node.js)

- **RESTful API** - 标准化接口设计
- **JWT 认证** - 安全的用户身份验证
- **数据持久化** - MySQL + MongoDB 双数据库
- **即时通讯** - OpenIM 服务集成
- **高德地图** - 地理编码、逆地理编码
- **文件上传** - 打卡照片存储管理

***

## 🛠️ 技术栈

| 分类   | 技术      | 版本      |
| ---- | ------- | ------- |
| 移动端  | Flutter | 3.19+   |
| 后端   | Node.js | 20+     |
| 前端   | Vue.js  | 3+      |
| 数据库  | MySQL   | 8.0+    |
| 数据库  | MongoDB | 7.0+    |
| 即时通讯 | OpenIM  | 3.5+    |
| 地图服务 | 高德地图    | Web API |
| 构建工具 | Docker  | 24+     |

***

## 📁 项目结构

```
├── MobileApp/              # Flutter 移动端
│   ├── lib/
│   │   ├── api/            # API 客户端
│   │   ├── blocs/          # BLoC 状态管理
│   │   ├── screens/        # 页面组件
│   │   ├── services/       # 业务服务
│   │   ├── utils/          # 工具函数
│   │   └── widgets/        # UI 组件
│   └── pubspec.yaml
│
├── BackEnd/                # 后端服务
│   ├── server/             # Node.js 服务
│   │   ├── controllers/    # 控制器
│   │   ├── models/         # 数据模型
│   │   ├── routes/         # 路由定义
│   │   ├── services/       # 业务服务
│   │   └── tests/          # 单元测试
│   └── web-admin/          # Vue.js 管理端
│       ├── src/
│       │   ├── api/        # API 请求
│       │   ├── components/ # 组件
│       │   ├── views/      # 页面
│       │   └── stores/     # Pinia 状态管理
│       └── vite.config.js
│
└── openIM/                 # OpenIM 即时通讯服务
    └── open-im-server/
```

***

## 🚀 快速开始

### 环境要求

- Flutter 3.19+
- Node.js 20+
- MySQL 8.0+
- Docker 24+

### 1. 启动基础设施

```bash
# 启动 MySQL（后端数据库）
cd BackEnd && docker compose up -d

# 启动 OpenIM 服务（即时通讯）
cd openIM/open-im-server && ./start-all.sh
```

### 2. 启动后端服务

```bash
cd BackEnd/server
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

***

## ⚙️ 环境变量配置

### BackEnd/server/.env

```env
PORT=3000
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=user_information
JWT_SECRET=your_jwt_secret
AMAP_KEY=your_amap_web_service_key
```

### MobileApp 运行参数

```bash
flutter run \
  --dart-define=SERVER_IP=192.168.1.100 \
  --dart-define=AMAP_KEY=your_amap_key \
  --dart-define=AMAP_WEB_KEY=your_amap_web_key
```

***

## 🌟 项目亮点

### 1. 水印防伪系统

- 实时预览与实际拍摄一致性保证
- 支持自定义水印模板
- 自动添加时间戳、地理位置、用户信息

### 2. 离线打卡模式

- 网络断开时可正常打卡
- 自动同步机制确保数据完整性
- 本地缓存使用 SharedPreferences

### 3. 即时通讯集成

- 基于 OpenIM 实现企业级消息推送
- 支持单聊、群聊、系统通知
- 智能重连机制保证连接稳定性

### 4. 全链路数据追踪

- 移动端轨迹记录
- 打卡位置验证
- 数据可视化报表

***

## 📊 数据库设计

### 核心数据表

| 表名        | 说明   | 关键字段                                |
| --------- | ---- | ----------------------------------- |
| users     | 用户信息 | id, username, name, role            |
| checkins  | 打卡记录 | id, user\_id, type, location, photo |
| schedules | 排班表  | id, user\_id, shift\_id, date       |
| shifts    | 班次定义 | id, name, start\_time, end\_time    |
| projects  | 项目信息 | id, name, address, radius           |
| approvals | 审批记录 | id, user\_id, type, status          |

***

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 项目
2. 创建特性分支 `git checkout -b feature/xxx`
3. 提交更改 `git commit -m 'feat: xxx'`
4. 推送到分支 `git push origin feature/xxx`
5. 创建 Pull Request

***

## 📝 License

MIT License - 详见 [LICENSE](LICENSE)

***

## 📞 联系方式

- 项目地址: <https://github.com/yzjun0505/bento-attendance>
- 作者: yzjun0505

***

*Built with ❤️ for enterprise attendance management*
