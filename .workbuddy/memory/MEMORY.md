# Bento Attendance 项目记忆

## 项目概述
多端协同打卡人员实时移动管理系统，包含：
- **BackEnd/server**：Node.js + Express + MySQL 后端
- **BackEnd/web-admin**：Vue3 Web 管理端（编译产物在 BackEnd/dist）
- **MobileApp**：Flutter 移动端（Android/iOS）
- **FrontEnd**：Web 前端（与 web-admin 可能重叠）

## 技术栈
- 后端：Node.js Express, MySQL, Socket.IO, ExcelJS
- 移动端：Flutter, flutter_bloc, geolocator, camera, dio, webview_flutter
- 管理端：Vue3, Element Plus, Vite
- 地图：高德地图 Web API（逆地理编码Key: ae275848401da60cbf76669fdc22b450）
- 地图：高德地图 Android SDK Key: a3b83561d4e3f6a9a99734716903d73f（包名 com.example.mobile_app，debug SHA1: CC:A9:95:57:E0:A0:77:91:1B:E5:77:46:E9:46:C6:9D:4D:B8:37:E2）

## 主题系统
- `core/bento_colors.dart` — BentoColors ThemeExtension + context.colors
- `core/bento_typography.dart` — bentoLightTheme()/bentoDarkTheme()
- 所有页面使用 context.colors 访问语义颜色 token

## 网络配置
- 真机调试IP: `10.59.13.3`（电脑当前局域网 IP，`ifconfig` 确认）
- DioClient baseUrl: `http://10.59.13.3:3000/api`（Flutter 端硬编码，需与后端实际 IP 一致）
- 后端端口: 3000
- OpenIM API: `10.59.13.3:10002`，WS: `10.59.13.3:10001`
- USB真机调试：需 `adb reverse tcp:3000 tcp:3000` 转发端口
- **imConfig 地址已改为从请求 Host header 动态推导**，不再硬编码 IP
- 后端 OpenIM 桥接层（openim.js 内部调用）用 `localhost:10002`，前端 imConfig 由 authController 从 Host 动态推
- 手机浏览器报 ERR_NAME_NOT_RESOLVED 通常是因为输入了中文标点/字符，网络实际上是通的（adb shell curl 可验证）

## 数据库要点
- `checkins.type` 已从 ENUM 改为 VARCHAR(50)，支持自定义打卡类型
- `checkin_types` 表：code/name/icon/color/category/sort_order，category 分 attendance/business/inspection
- `projects` 表有 latitude/longitude/radius，用于围栏判定
- `attendance_groups` 表实际列名：`work_start_time`/`work_end_time`（不是 start_time/end_time），有 `early_leave_tolerance` 和 `status` 列
- 后端查询时用 `AS start_time`/`AS end_time` 映射给前端
- 后端 LIMIT/OFFSET 用 `db.query()` + 直接拼接，不能用 `db.execute()` 的占位符

## Web 管理端布局规范（2026-04-29 更新）

- **统一卡片布局**：所有列表页使用 `.unified-card` 包裹 `.header-section` + `.filter-section` + `.table-section`，不再使用分开的 `.page-header` / `.filter-bar` / `.table-card` "三条白杠" 样式
- `.unified-card` / `.header-section` / `.filter-section` / `.table-section` 样式定义在全局 `src/styles/index.css`
- 涉及页面：Holidays、Schedules、Shifts、Tracks、Projects、AttendanceGroups、Notifications、OfflineCheckins

## 导航菜单结构（2026-04-29 更新）

**顶部高频导航栏**：工作台、实时位置、打卡记录、人员管理、项目管理、轨迹回放

**基础设置下拉菜单**：排班管理、节假日管理、班次管理、考勤组设置、设备管理、水印设计、离线打卡记录

## API 路由
- `/api/checkin` — 打卡 CRUD
- `/api/checkin/reserve-code` — 预占防伪码
- `/api/checkin-types` — 打卡类型 CRUD
- `/api/projects/nearby` — 附近项目查询（lat/lng/radius）
- `/api/watermarks/templates` — 水印模板
- `/api/attendance-groups/my` — 获取当前用户所属考勤组（通过 attendance_group_members 关联查询）
- 注意：`/my` 必须在 `/:id` 之前注册路由

## 打卡类型体系（2026-04-10 扩展）
| code | 名称 | 类别 | 颜色 |
|------|------|------|------|
| clock_in | 上班打卡 | attendance | #22C55E |
| clock_out | 下班打卡 | attendance | #EF4444 |
| site_visit | 实地考察 | business | #3B82F6 |
| progress | 项目进度上报 | business | #F59E0B |
| safety | 安全检查 | inspection | #EF4444 |
| device | 设备位置上报 | inspection | #8B5CF6 |
| custom | 自定义 | business | #6B7280 |

## MySQL 注意事项
- MySQL 不支持 `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` 语法（MariaDB 才支持），迁移需用 try/catch + `ER_DUP_FIELDNAME` 错误码
- 后端 LIMIT/OFFSET 用 `db.query()` + 直接拼接，不能用 `db.execute()` 的占位符
- **时区关键（2026-04-29 修复）**：
  - MySQL 服务器时区为 CST（北京时间），`timezone: 'Z'` 是错误配置
  - `db.js` 连接池配置：`dateStrings: true`（返回原始字符串），**不要设 `timezone: 'Z'`**
  - 后端返回的时间字符串是本地时间（如 `"2026-04-29 23:26:29"`），前端 **不要加 Z 后缀**（否则会+8h偏移）
  - 前端 formatTime 统一用 `str.replace(' ', 'T')` 让浏览器按本地时间解析
  - Flutter 端 `DateTime.parse()` 对无时区后缀的字符串按本地时间解析，不需要 `.toLocal()`
  - 所有需要格式化日期的地方必须用本地时间格式化，禁止用 `toISOString()`

## 坐标系关键点
- GPS 返回 WGS84 坐标，高德/国测局用的是 GCJ02，两者有几百米偏移
- `camera_checkin_screen.dart` 的 `_initGeo()` 必须做 WGS84→GCJ02 转换（用 `CoordUtils.wgs84ToGcj02`）
- `local_album_screen.dart` 上传时也必须做坐标转换
- `attendance_bloc.dart` 的 `LoadAttendanceData` 已正确转换
- 后端项目坐标和附近项目 API 均为 GCJ02

## 高德地图安全密钥
- JS API 2.0 安全密钥 (securityJsCode): `c673cb06b1823f9e290ab592a2eaadd7`
- 必须在加载 JS API 之前配置 `window._AMapSecurityConfig`
- 缺少此配置会导致瓦片不显示

## 即时通讯（OpenIM）
- 使用 OpenIM v3 开源方案，Flutter 插件 `flutter_openim_sdk: ^3.5.1`
- `openim_service.dart` — 单例封装 SDK（init/login/消息/会话/好友/群组）
- `auth_bloc.dart` 在用户登录和恢复登录时自动 `_initAndLoginIM()`
- 后端 `routes/openim.js` 是 OpenIM API v3 桥接层
- 后端登录接口返回 `imToken` + `imConfig`（apiAddr/wsAddr）
- imConfig 默认地址为 `10.51.253.110:10002`(API)/`10001`(WS)，不再用 localhost
- Flutter 端 imConfig 保存到 secure storage（key: im_api_addr, im_ws_addr），恢复登录时读取
- 首页消息中心已改为从 OpenIM 获取真实会话数据，不再有假数据

### OpenIM v3 API 关键注意事项
- **所有请求需要 `operationID` header**，否则返回 ArgsError
- **`/auth/get_user_token` 不再接受 `secret` 参数**，需要先调 `/auth/get_admin_token` 获取管理员 token，再在 header 中传 `token`
- **`/user/user_register` 请求体用 `users` 数组**（不是单个用户对象）
- 用户已注册返回 errCode=1102, errMsg="RegisteredAlreadyError"
- 管理员默认 userID: `imAdmin`，secret: `openIM123`
- 管理员 token 缓存 1 小时，避免频繁请求

### OpenIM Flutter SDK v3.8 登录关键注意事项
- **`login()` 内部会调 `getSelfUserInfo()`**，但登录是异步的，SDK 可能还在同步数据，导致 10009 错误
- **必须传 `defaultValue`** 绕过 `getSelfUserInfo`：`defaultValue: () async => UserInfo(userID: userID)`
- **真正的登录完成标志是 `onConnectSuccess` 回调**，不是 `login()` 返回
- 当前实现用 `Completer<bool>` 等待 `onConnectSuccess` 回调，超时 15 秒

## 已知问题 / 待办
- 地图看板：已集成高德地图 WebView（JS API 2.0），支持蓝点定位、围栏圈、项目标注、暗色主题
- USB真机调试：需 `adb reverse tcp:3000 tcp:3000` 转发端口
- 后台管理端需要适配多打卡类型
- users 表 email 字段迁移已修复（2026-04-10）
- 后端围栏默认半径已统一为 500 米（与 nearby API 一致）
