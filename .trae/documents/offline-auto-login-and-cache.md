## Summary
- 目标：实现“离线可进 / 免重复登录 / 离线可看信息（尽量全可用，只读）”，并在网络恢复后自动同步。
- 额外：同一账号“每个系统最多 1 台设备在线”（Android 1 台 + iOS 1 台 + 桌面 1 台），超过则让旧会话失效（通过 refresh token 失效实现）。

## Current State Analysis
### 登录/会话
- App 启动时由 [AuthBloc._onAppStarted](file:///Users/eva/Desktop/Project/MobileApp/lib/blocs/auth/auth_bloc.dart#L44-L77) 读取 `jwt_token` 后请求 `/auth/profile` 校验。
- 只要 `/auth/profile` 请求失败（包括离线/超时），就会进入 `AuthUnauthenticated`，从而回到登录页：[main.dart AuthWrapper](file:///Users/eva/Desktop/Project/MobileApp/lib/main.dart#L99-L120)。
- App 目前只持久化 `jwt_token`/`im_token`/`im_api_addr`/`im_ws_addr`，未持久化用户资料、未读数、以及 `refresh_token`。

### 离线数据展示
- 通知列表 [NotificationRepository.getNotifications](file:///Users/eva/Desktop/Project/MobileApp/lib/repositories/notification_repository.dart#L10-L39) 在异常时会 `rethrow`，导致通知页离线时只显示错误而不是缓存：[NotificationScreen](file:///Users/eva/Desktop/Project/MobileApp/lib/screens/notifications/notification_screen.dart)。
- IM SDK 离线时 `login()` 会失败并设置 `_isLoggedIn=false`，[HomeScreen/ChatScreen] 多处以 `isLoggedIn` 作为“是否展示消息”的 gate，导致离线看不到本地消息。
- 项目里已存在离线提示组件 [OfflineBanner](file:///Users/eva/Desktop/Project/MobileApp/lib/widgets/offline_banner.dart)，但未形成统一“离线模式”状态与回退策略。

### 多设备限制（后端）
- 后端有 sessions 表（refresh token 机制）：[db.js sessions 表](file:///Users/eva/Desktop/Project/BackEnd/server/models/db.js#L391-L407) + [sessionController](file:///Users/eva/Desktop/Project/BackEnd/server/controllers/sessionController.js)。
- 目前登录会创建 session，但 App 未保存 refresh token；后端也未区分 platform/device 进行限制。
- JWT 校验中间件仅校验签名与过期：[authMiddleware](file:///Users/eva/Desktop/Project/BackEnd/server/middleware/auth.js#L10-L24)，无法“即时踢下线”，只能通过 refresh token 失效在下一次刷新时生效。

## Proposed Changes
### A. App：离线免登（核心）
1) 持久化关键会话信息
- 在登录成功（`/auth/login`）后额外写入：
  - `refresh_token`（后端返回的 `data.refresh_token`）
  - `user_profile_json`（登录返回的 user）
  - `last_login_at`（毫秒时间戳，便于后续排查/可选策略）
- 文件：[AuthBloc._onLoggedIn](file:///Users/eva/Desktop/Project/MobileApp/lib/blocs/auth/auth_bloc.dart)

2) AppStarted：离线也进入主界面
- 修改 `AuthBloc._onAppStarted`：
  - 若本地存在 `jwt_token`：
    - 尝试请求 `/auth/profile`（建议加较短超时，比如 3~5 秒）
    - **成功**：更新 `user_profile_json` 并 `emit(AuthAuthenticated(...))`
    - **网络类失败（超时/无法连接）**：读取 `user_profile_json`，若存在则 `emit(AuthAuthenticated(..., isOffline: true))`，让用户离线也能进入主界面
    - **鉴权失败（401/403）**：清理 token 并回到登录页
- 需要在 `AuthState.AuthAuthenticated` 新增字段：`isOffline`（默认 false）
- 文件：
  - [auth_state.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/blocs/auth/auth_state.dart)
  - [auth_bloc.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/blocs/auth/auth_bloc.dart)
  - [main.dart AuthWrapper](file:///Users/eva/Desktop/Project/MobileApp/lib/main.dart#L99-L120)（无需改逻辑，只会因为 AuthAuthenticated 而进主界面）

3) 网络恢复后自动转在线
- 使用 `connectivity_plus`（项目已依赖但未使用）监听网络变化：
  - 网络从无到有时：触发一次 `/auth/profile` 刷新 + 触发 Home/Attendance/Notifications 刷新
  - 离线 banner 自动消失
- 实现方式二选一（计划采用更易落地的方案）：
  - 方案 A（推荐）：在 `AuthBloc` 内部维护 `StreamSubscription<ConnectivityResult>`，只负责刷新 Auth（profile/refresh token）
  - 方案 B：新建 `ConnectivityCubit`/`NetworkBloc` 统一管理离线状态，页面通过 BlocBuilder 展示 OfflineBanner
- 文件：
  - 新增：`lib/services/network_service.dart` 或 `lib/blocs/network/...`（按现有 Bloc 组织方式）
  - 改动：`auth_bloc.dart`

### B. App：token 自动刷新（减少重复登录）
1) 存储并使用 refresh_token
- 登录保存 refresh token（见 A.1）
- `ApiClient` 的 Dio interceptor 在收到 401 时：
  - 若存在 refresh_token：调用 `/sessions/refresh` 获取新 access_token
  - 写回 `jwt_token` 并重试原请求（需防并发：加 refresh 锁/队列）
  - 若 refresh 失败：触发 `AuthBloc.add(LoggedOut())`
- 文件：
  - [dio_client.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/api/dio_client.dart)
  - [auth_bloc.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/blocs/auth/auth_bloc.dart)（登出联动）

### C. App：离线“尽量全可用”的数据回退（只读）
1) 通知（信息）缓存
- 在 `NotificationRepository.getNotifications/getUnreadCount` 成功后，把结果缓存到本地（secure storage 存 JSON 即可）：
  - `cached_notifications_page1`
  - `cached_notifications_unread_count`
- 在网络异常时不抛错，直接返回缓存，通知页不再显示“加载失败”，而是显示缓存并提示离线模式。
- 文件：
  - [notification_repository.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/repositories/notification_repository.dart)
  - [notification_screen.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/screens/notifications/notification_screen.dart)

2) 首页/明细/打卡数据缓存（范围：只读展示，不保证最新）
- Home summary（今日考勤、最近通知等）在 `HomeBloc` 请求成功时缓存最后一次 `HomeSummaryLoaded` 的关键字段；失败且离线时读取缓存并 emit “stale 数据”。
- AttendanceBloc、HistoryScreen 同理：请求成功缓存、离线时读取缓存展示；涉及分页的只缓存第一页或最近 N 条。
- 需要为对应 State 增加 `isStale` 或 `dataFromCache` 标识，用于 UI 显示“离线/数据可能不是最新”。
- 相关文件：
  - [home_bloc.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/blocs/home/home_bloc.dart)
  - [attendance_bloc.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/blocs/attendance/attendance_bloc.dart)
  - [history_screen.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/screens/history/history_screen.dart)

3) 离线提示条统一接入
- 在 MainNavigation 的各 Tab 页面顶端统一渲染 `OfflineBanner`（根据 AuthState.isOffline 或 NetworkBloc 状态）。
- 文件：
  - [main_navigation.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/screens/main_navigation.dart)
  - [offline_banner.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/widgets/offline_banner.dart)

### D. App：IM 离线可读（不强制“已登录”才显示）
> 目标：离线时允许查看本地会话/消息；发送按钮不可用；网络恢复后自动重连并恢复发送。

- 调整 HomeScreen/ChatScreen 里对 `_imService.isLoggedIn` 的 gate：
  - 展示列表/消息：以 “SDK 已初始化 + 已有历史数据” 为准（允许 disconnected）
  - 发送：必须 connected（可用 OpenIM connectionStream 或 NetworkBloc 判定）
- 在 AuthAuthenticated(isOffline=true) 时也照样触发一次后台 IM init/login（不阻塞 UI），并在失败时不影响 UI 的本地读取。
- 文件：
  - [home_screen.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/screens/home/home_screen.dart)
  - [chat_screen.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/screens/chat/chat_screen.dart)
  - [openim_service.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/services/openim_service.dart)（增加“当前连接状态”getter，便于 UI 判断）

### E. 后端：同一账号每系统最多 1 台在线（基于 refresh token 的会话限制）
> 说明：因为 access token 是无状态 JWT，无法即时失效；方案采用 “限制/清理 sessions 表中的 refresh token”，让旧设备在 access token 过期后无法续期，从而被迫重新登录。

1) 传递设备标识
- App 每次请求增加 header：
  - `X-Platform`: `android|ios|macos|windows|linux|web`
  - `X-Device-Id`: 本机生成并持久化的 UUID（secure storage）
- 文件：[dio_client.dart](file:///Users/eva/Desktop/Project/MobileApp/lib/api/dio_client.dart)

2) sessions 表增加维度字段并 enforce
- 数据库迁移：sessions 表新增字段 `platform`、`device_id`，并增加索引 `(user_id, platform)`。
- 登录创建 session 前：
  - 查找并删除该 `user_id + platform` 下所有旧 session（或保留 1 条最新，删除其他）
  - 再插入新 session
- 文件：
  - [db.js](file:///Users/eva/Desktop/Project/BackEnd/server/models/db.js)（加入 ALTER TABLE 迁移逻辑）
  - [sessionController.js createSession](file:///Users/eva/Desktop/Project/BackEnd/server/controllers/sessionController.js#L22-L53)
  - [authController.js login](file:///Users/eva/Desktop/Project/BackEnd/server/controllers/authController.js#L43-L104)（将 platform/device 透传给 createSession）

## Assumptions & Decisions
- 离线范围：尽量全可用（本地缓存只读展示），发送/写操作在离线时禁用并提示。
- 自动登录：长期免登（token 存在就可进主界面；仅在 token 确认失效时要求重新登录）。
- 多设备限制：同一账号每个系统最多 1 台（通过 refresh token 失效实现）。
- 不做“即时踢下线”的强一致（需要改 JWT 机制/每请求查 session，成本较高），本期先满足“禁止长期同时在线”。

## Verification
### Mobile
- 启动时断网（飞行模式）：
  - 若之前已登录：直接进入主界面，展示 OfflineBanner，可查看缓存通知/缓存业务数据/本地聊天记录
  - 若从未登录：仍停留登录页
- 断网 → 恢复网络：
  - OfflineBanner 自动消失
  - `/auth/profile` 自动刷新成功
  - 首页/通知/打卡数据可手动或自动刷新
- Token 过期场景：
  - 在线时自动走 `/sessions/refresh` 获取新 token；不要求用户重新登录
- 运行：`flutter test`、`flutter analyze`

### Backend
- 新登录同一账号同一 platform：
  - 新 session 创建成功
  - 旧 session（refresh token）被删除
- 手动验证：调用 `/api/sessions/refresh` 使用旧 refresh token 应返回 401
