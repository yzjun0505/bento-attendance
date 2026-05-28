# 境图后端与管理端部署指南

本文档用于把本地 `BackEnd` 部署到腾讯云服务器。当前即时通讯使用腾讯云 IM，腾讯 IM 服务本身不需要部署到服务器；服务器只需要部署业务后端、管理端静态资源、MySQL、Nginx，以及后端签发腾讯 IM `UserSig` 所需的配置。

## 1. Docker 在本项目里的作用

本项目服务器上的 Docker 只负责运行你自己的业务系统：

- `bento_app`：Node.js 业务后端，提供 `/api/*`、版本更新、打卡、项目、人员、设备、腾讯 IM UserSig 签发等接口。
- `bento_mysql`：MySQL 数据库。
- `bento_nginx`：Nginx，对外监听 80 端口，转发 API，并提供 `/uploads/*` 文件下载。

腾讯云 IM 是官方云服务，App 通过腾讯 SDK 直连腾讯云；服务器只保存 `TIM_SDK_APP_ID`、`TIM_SECRET_KEY`，用于登录时给 App 签发 `UserSig`。不需要部署 OpenIM，也不需要部署腾讯 IM 服务端。

## 2. 服务器目录

生产目录固定为：

```bash
/opt/bento-attendance
```

关键文件：

```bash
/opt/bento-attendance/docker-compose.prod.yml
/opt/bento-attendance/Dockerfile
/opt/bento-attendance/nginx.prod.conf
/opt/bento-attendance/.env
/opt/bento-attendance/server
/opt/bento-attendance/dist
/opt/bento-attendance/uploads
```

注意：`.env`、`server/.env`、`uploads/` 是生产数据或密钥文件，部署同步时不要覆盖。

## 3. 本地发布前检查

在本地项目根目录：

```bash
cd /Users/eva/Desktop/Project
```

检查移动端：

```bash
cd MobileApp
flutter analyze
```

检查后端 JS 语法：

```bash
cd /Users/eva/Desktop/Project
for f in BackEnd/server/app.js BackEnd/server/controllers/*.js BackEnd/server/routes/*.js BackEnd/server/middleware/*.js BackEnd/server/models/*.js BackEnd/server/services/*.js BackEnd/server/utils/*.js; do
  node --check "$f" || exit 1
done
```

构建管理端：

```bash
cd /Users/eva/Desktop/Project/BackEnd/web-admin
npm run build
```

构建完成后，产物会输出到：

```bash
/Users/eva/Desktop/Project/BackEnd/dist
```

## 4. 同步代码到服务器

从本地执行：

```bash
cd /Users/eva/Desktop/Project
rsync -az --delete \
  --exclude=.env \
  --exclude=server/.env \
  --exclude=uploads/ \
  --exclude=server/node_modules/ \
  --exclude=web-admin/node_modules/ \
  --exclude=backend.log \
  BackEnd/ ubuntu@150.158.79.174:/opt/bento-attendance/
```

输入服务器密码后等待同步完成。

## 5. 服务器环境变量

登录服务器：

```bash
ssh ubuntu@150.158.79.174
cd /opt/bento-attendance
```

检查 `.env`，至少包含：

```bash
DB_PASSWORD=你的数据库密码
DB_NAME=你的数据库名
JWT_SECRET=你的JWT密钥
JWT_REFRESH_SECRET=你的刷新Token密钥
ADMIN_USERNAME=admin
ADMIN_PASSWORD=你的管理员初始密码

TIM_SDK_APP_ID=腾讯云IM的SDKAppID
TIM_SECRET_KEY=腾讯云IM的SecretKey
TIM_ADMIN_USERID=administrator

AI_API_KEY=你的DeepSeek API Key
AI_BASE_URL=https://api.deepseek.com/v1
AI_MODEL=deepseek-v4-flash
AI_TIMEOUT_MS=30000

APP_ANDROID_VERSION_NAME=1.0.10
APP_ANDROID_VERSION_CODE=19
APP_ANDROID_MIN_VERSION_CODE=1
APP_ANDROID_FORCE_UPDATE=false
APP_ANDROID_DOWNLOAD_URL=http://150.158.79.174/uploads/releases/app-v1.0.10-19.apk
APP_ANDROID_RELEASE_NOTES=本次更新说明
```

不要把腾讯 IM `SecretKey` 写进 App，也不要提交到 GitHub。

## 6. 重建并启动后端

在服务器执行：

```bash
cd /opt/bento-attendance
docker compose -f docker-compose.prod.yml up -d --build app nginx
```

如果数据库容器不存在或首次部署，执行：

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

查看容器：

```bash
docker ps
```

正常应看到：

```text
bento_mysql
bento_app
bento_nginx
```

## 7. 验证部署

服务器内验证：

```bash
curl -s http://127.0.0.1/api/health
```

本地或手机浏览器验证：

```bash
curl -s http://150.158.79.174/api/health
```

正常返回类似：

```json
{
  "code": 200,
  "message": "OK",
  "services": {
    "mysql": { "ok": true },
    "mongo": { "enabled": false, "ok": true }
  }
}
```

查看后端日志：

```bash
docker logs --tail=100 bento_app
```

查看 Nginx：

```bash
docker logs --tail=100 bento_nginx
```

## 8. APK 发布流程

如果需要发布新版 APK，本地构建：

```bash
cd /Users/eva/Desktop/Project/MobileApp
flutter build apk --release
```

生成文件：

```bash
build/app/outputs/flutter-apk/app-release.apk
```

重命名并上传到服务器：

```bash
cd /Users/eva/Desktop/Project/MobileApp
scp build/app/outputs/flutter-apk/app-release.apk \
  ubuntu@150.158.79.174:/opt/bento-attendance/uploads/releases/app-v1.0.10-19.apk
```

验证下载：

```bash
curl -I http://150.158.79.174/uploads/releases/app-v1.0.10-19.apk
```

如果版本号变更，要同步修改：

- `MobileApp/pubspec.yaml`
- `/opt/bento-attendance/.env` 里的 `APP_ANDROID_VERSION_NAME`
- `/opt/bento-attendance/.env` 里的 `APP_ANDROID_VERSION_CODE`
- `/opt/bento-attendance/.env` 里的 `APP_ANDROID_DOWNLOAD_URL`

修改 `.env` 后重启后端：

```bash
cd /opt/bento-attendance
docker compose -f docker-compose.prod.yml up -d --build app
```

## 9. 常见问题

### 手机端能用腾讯 IM，为什么服务器还要配置 TIM？

App 不能保存腾讯云 IM `SecretKey`。正确做法是：App 登录业务后端，后端用 `TIM_SECRET_KEY` 签发 `UserSig`，App 再拿 `UserSig` 登录腾讯云 IM。

### Docker 是不是 OpenIM？

不是。Docker 现在只跑业务系统。OpenIM 已经不用了，腾讯 IM 不需要自建服务。

### 只改了管理端页面，需要重启 Docker 吗？

需要。管理端构建产物 `dist/` 会被复制进 `bento_app` 镜像，所以同步后要重新构建 `bento_app`。

### 只上传 APK，需要重启 Docker 吗？

通常不需要。APK 放在 `/opt/bento-attendance/uploads/releases/`，由 `bento_nginx` 直接提供下载。只有版本接口 `.env` 改了，才需要重启 `bento_app`。
