# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

境图 (JingMap) — a multi-end collaborative attendance tracking system with real-time location. Three components:

- **BackEnd** — Node.js + Express REST API with MySQL and optional MongoDB, Docker-deployed behind Nginx
- **MobileApp** — Flutter app (Android/iOS) using BLoC pattern, Tencent IM for messaging
- **web-admin** — Vue 3 + Element Plus SPA, built by Vite, served from the backend's `/dist/`

## Build Commands

```bash
# Web admin (dev and build)
cd BackEnd/web-admin && npm run dev      # Vite dev server
cd BackEnd/web-admin && npm run build    # outputs to BackEnd/dist/

# Mobile APK
cd MobileApp && flutter build apk --release
# → MobileApp/build/app/outputs/flutter-apk/app-release.apk

# Backend syntax check (no compilation needed)
cd /Users/eva/Desktop/Project
for f in BackEnd/server/app.js BackEnd/server/controllers/*.js BackEnd/server/routes/*.js BackEnd/server/middleware/*.js BackEnd/server/models/*.js BackEnd/server/services/*.js; do
  node --check "$f" || exit 1
done
```

## One-Click Deploy

```bash
./deploy.sh                 # auto-detect changed components
./deploy.sh --mobile        # APK only
./deploy.sh --web           # web admin only
./deploy.sh --backend       # backend only
./deploy.sh --all           # everything
```

The script auto-increments the build number in `MobileApp/pubspec.yaml`, updates the server `.env` with new version info, builds, rsyncs, uploads APK, and rebuilds Docker containers. Configure via env vars: `DEPLOY_SERVER`, `DEPLOY_SSH_KEY`, `DEPLOY_PUBLIC_BASE_URL`.

## Architecture

### Backend (`BackEnd/server/`)

Entry: `app.js` — creates Express app, attaches Socket.IO, mounts all routes, handles SPA fallback.

**Three-tier pattern:** Route → Controller → Model (via `models/db.js` connection pool)

**Middleware:**
- `auth.js` exports: `authMiddleware` (JWT Bearer verify), `adminOnly`, `managerOrAdmin`
- `authScope.js` — scope-based authorization for project managers (newer)
- Rate limiting: 1000 req/15min on `/api/`
- `app.set('trust proxy', 1)` because behind Nginx

**Auth flow:**
1. `POST /api/auth/login` — validates credentials, generates JWT access token + refresh token, auto-registers user on Tencent IM and issues UserSig
2. Sessions tracked in `sessions` table (device, IP, refresh token)
3. Refresh via `POST /api/auth/refresh`
4. Mobile: `LoginScreen` → `AuthBloc` → `AuthWrapper` switches between `LoginScreen` and `MainNavigation`

**Key API routes (all under `/api/`):**
| Route | Purpose |
|---|---|
| `/api/auth` | Login, register, refresh, logout |
| `/api/users` | User CRUD, managed by admin/manager |
| `/api/checkin` | Attendance check-in/out with photo/watermark |
| `/api/location` | Real-time location reporting |
| `/api/projects` | Project management |
| `/api/devices` | Device registration and management |
| `/api/upload` | File upload (photos, watermarks) |
| `/api/im` | Tencent IM UserSig issuance |
| `/api/ai` | AI assistant proxy (OpenAI-compatible) |
| `/api/project-managers` | Project manager authorization |
| `/api/task-nodes` | Progress tracking task nodes |
| `/api/progress-reports` | Progress report submissions |
| `/api/app` | App version check for updates |

**Database:** MySQL (auto-creates tables in `initDatabase()`), with optional MongoDB Atlas for extended features. Connection pool configured with 50 max connections, 30-min idle timeout.

### Web Admin (`BackEnd/web-admin/`)

Vue 3 + Element Plus + Pinia + Vue Router. Built output goes to `BackEnd/dist/`, served by Express as static files and embedded in Docker image.

**Router guard:** checks `localStorage.token` for non-public routes, redirects to `/login`.

**API layer:** `src/api/request.js` wraps Axios with JWT interceptor. Separate API modules under `src/api/`.

### Mobile App (`MobileApp/`)

Flutter with BLoC state management. Key BLoCs:
- `AuthBloc` — login/logout/IM init/auth state machine
- `AttendanceBloc` — check-in data loading
- `HomeBloc` — home screen summary
- `TrackingBloc` — real-time GPS location reporting
- `ThemeBloc` — light/dark mode
- `ProgressBloc` — task progress tracking
- `ChatSettingsCubit` — IM settings

**Navigation:** 5-tab bottom nav: Messages (Tencent IM), Contacts, Attendance (map dashboard), Workbench (progress, checkins, personnel, approvals), Profile.

**API client:** `lib/api/dio_client.dart` — Dio instance with JWT interceptor, automatic token refresh, device ID, Tencent IM app ID. Base URL defaults to `http://150.158.79.174/api` but can be overridden via `--dart-define=SERVER_IP=...` or `--dart-define=API_BASE_URL=...`.

**Initialization order:** `main()` → `ApiClient.loadRuntimeConfig()` (reads `assets/appConfig.json`) → `LocalNotificationService().init()` → `TUIKitConfig.init()` (Tencent IM SDK init) → `runApp()` → `AuthBloc` dispatches `AppStarted()`.

**App update check:** `MainNavigation` auto-checks on first load, displays `AppUpdateDialog` when server version > installed version.

### Docker / Deployment

Three containers in `docker-compose.prod.yml`:
1. **bento_mysql** — MySQL 8.0, persistent volume
2. **bento_app** — Node.js backend (build from `Dockerfile`), exposes port 3000, depends on healthy MySQL
3. **bento_nginx** — Nginx 1.27 Alpine, port 80 → proxies to app:3000, serves `/uploads/` directly with aggressive caching

Server directory: `/opt/bento-attendance/`. The deploy script rsyncs `BackEnd/` there (excluding `.env`, `uploads/`, `node_modules/`), then rebuilds containers.

**Critical server files never overwritten by rsync:** `.env`, `server/.env`, `uploads/`.

## Tencent IM Integration

Replaced OpenIM (removed). The server holds `TIM_SDK_APP_ID` and `TIM_SECRET_KEY` in `.env` and issues `UserSig` on login. The Flutter app uses `tuikit_atomic_x` and `tencent_chat_uikit` packages from `TUIKit_Flutter/` (local path dependency). IM login happens asynchronously after backend auth; the messages/contacts tabs show a loading placeholder until `IMLoginResult` event confirms initialization.

## File Notes

- `deploy.sh` — production deployment script, tracks last-deployed git SHA in `.deploy-state` on server to auto-detect changed components
- `.env` / `server/.env` — server-side secrets, never committed or synced via rsync
- `MobileApp/assets/appConfig.json` — runtime config loaded on app start
- `TUIKit_Flutter/` — local Tencent IM UIKit, referenced by `pubspec.yaml` path dependency
- `chat-demo/` — separate demo project, not part of the main build
