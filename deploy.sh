#!/bin/bash
set -e

SSH_KEY="$HOME/.ssh/macOS.pem"
SERVER="ubuntu@150.158.79.174"
PROJECT="/Users/eva/Desktop/Project"
PUBSPEC="$PROJECT/MobileApp/pubspec.yaml"
APK_SOURCE="$PROJECT/MobileApp/build/app/outputs/flutter-apk/app-release.apk"
SERVER_DIR="/opt/bento-attendance"
UPLOADS_DIR="$SERVER_DIR/uploads/releases"

# ============================================
# 1. 读取当前版本号并自动递增
# ============================================
CURRENT_VERSION=$(grep '^version:' "$PUBSPEC" | awk '{print $2}')
VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
VERSION_CODE=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

NEW_VERSION_CODE=$((VERSION_CODE + 1))

echo "========================================="
echo "  境图一键部署"
echo "========================================="
echo ""
echo "  当前版本: $VERSION_NAME (build $VERSION_CODE)"
echo "  新版 build: $NEW_VERSION_CODE"
echo ""

# 询问是否要升版本名称（如 1.0.9 → 1.0.10）
read -p "  是否升级版本名称？当前 $VERSION_NAME，输入新版本号或直接回车跳过: " INPUT_NAME
if [ -n "$INPUT_NAME" ]; then
  NEW_VERSION_NAME="$INPUT_NAME"
else
  NEW_VERSION_NAME="$VERSION_NAME"
fi

NEW_VERSION="$NEW_VERSION_NAME+$NEW_VERSION_CODE"
APK_FILENAME="app-v${NEW_VERSION_NAME}-${NEW_VERSION_CODE}.apk"
APK_DOWNLOAD_URL="http://150.158.79.174/uploads/releases/${APK_FILENAME}"

echo ""
echo "  → 新版本: $NEW_VERSION"
echo "  → APK 文件名: $APK_FILENAME"
echo ""

read -p "  确认部署？(y/n) " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "已取消"
  exit 0
fi

# ============================================
# 2. 更新 pubspec.yaml 版本号
# ============================================
echo ""
echo "[1/6] 更新版本号..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
else
  sed -i "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
fi
echo "✓ pubspec.yaml: $CURRENT_VERSION → $NEW_VERSION"

# ============================================
# 3. 构建 APK
# ============================================
echo ""
echo "[2/6] 构建 APK (release)..."
cd "$PROJECT/MobileApp"
flutter clean > /dev/null 2>&1
flutter build apk --release
echo "✓ APK 构建完成"

# ============================================
# 4. 检查后端语法 + 构建管理端
# ============================================
echo ""
echo "[3/6] 构建管理端 + 检查后端..."
cd "$PROJECT"
for f in BackEnd/server/app.js BackEnd/server/controllers/*.js BackEnd/server/routes/*.js BackEnd/server/middleware/*.js BackEnd/server/models/*.js BackEnd/server/services/*.js; do
  node --check "$f" || exit 1
done
echo "✓ 语法检查通过"

cd "$PROJECT/BackEnd/web-admin"
npm run build > /dev/null 2>&1
echo "✓ 管理端构建完成"

# ============================================
# 5. 同步代码到服务器
# ============================================
echo ""
echo "[4/6] 同步代码到服务器..."
cd "$PROJECT"
rsync -az --delete \
  --exclude=.env \
  --exclude=server/.env \
  --exclude=uploads/ \
  --exclude=server/node_modules/ \
  --exclude=web-admin/node_modules/ \
  --exclude=backend.log \
  -e "ssh -i $SSH_KEY" \
  BackEnd/ "$SERVER:$SERVER_DIR/"
echo "✓ 代码同步完成"

# ============================================
# 6. 上传 APK + 更新服务器版本配置
# ============================================
echo ""
echo "[5/6] 上传 APK..."
ssh -i "$SSH_KEY" "$SERVER" "mkdir -p $UPLOADS_DIR"
scp -i "$SSH_KEY" "$APK_SOURCE" "$SERVER:$UPLOADS_DIR/$APK_FILENAME"
echo "✓ APK 上传完成"

echo ""
echo "  更新服务器版本配置..."
ssh -i "$SSH_KEY" "$SERVER" << UPDATE_ENV
cd $SERVER_DIR
# 更新 .env 中的版本信息
sed -i "s/^APP_ANDROID_VERSION_NAME=.*/APP_ANDROID_VERSION_NAME=$NEW_VERSION_NAME/" .env
sed -i "s/^APP_ANDROID_VERSION_CODE=.*/APP_ANDROID_VERSION_CODE=$NEW_VERSION_CODE/" .env
sed -i "s|^APP_ANDROID_DOWNLOAD_URL=.*|APP_ANDROID_DOWNLOAD_URL=$APK_DOWNLOAD_URL|" .env
echo "✓ 服务器 .env 已更新"
UPDATE_ENV

# ============================================
# 7. 重建 Docker 容器
# ============================================
echo ""
echo "[6/6] 重建服务器容器..."
ssh -i "$SSH_KEY" "$SERVER" << 'REMOTE'
cd /opt/bento-attendance
docker compose -f docker-compose.prod.yml up -d --build app nginx

echo ""
echo "=== 容器状态 ==="
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "=== 健康检查 ==="
sleep 3
curl -s http://127.0.0.1/api/health | python3 -m json.tool 2>/dev/null || curl -s http://127.0.0.1/api/health
REMOTE

# ============================================
# 完成
# ============================================
echo ""
echo "========================================="
echo "  部署完成！"
echo "  新版本: $NEW_VERSION"
echo "  APK 下载: $APK_DOWNLOAD_URL"
echo "========================================="
