#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/BackEnd"
WEB_DIR="$BACKEND_DIR/web-admin"
MOBILE_DIR="$ROOT_DIR/MobileApp"
PUBSPEC="$MOBILE_DIR/pubspec.yaml"

SERVER="${DEPLOY_SERVER:-ubuntu@150.158.79.174}"
SERVER_DIR="${DEPLOY_SERVER_DIR:-/opt/bento-attendance}"
PUBLIC_BASE_URL="${DEPLOY_PUBLIC_BASE_URL:-http://150.158.79.174}"
SSH_KEY="${DEPLOY_SSH_KEY:-}"
MODE="auto"
YES=0
DRY_RUN=0
RUN_TESTS=0
SKIP_FLUTTER_ANALYZE=0
BUILD_IOS=0
SPLIT_PER_ABI=1
VERSION_NAME=""
VERSION_CODE=""
BUMP="build"
RELEASE_NOTES=""
FORCE_UPDATE=""
MIN_VERSION_CODE=""

STATE_FILE=".deploy-state"
APK_SOURCE="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"
APK_OUTPUT_DIR="$MOBILE_DIR/build/app/outputs/flutter-apk"

usage() {
  cat <<'EOF'
境图一键部署脚本

用法:
  ./deploy.sh                         # 自动判断改了哪些端并部署
  ./deploy.sh --all                   # 前端 + 后端 + 手机端全部构建部署
  ./deploy.sh --web                   # 只构建并部署管理端
  ./deploy.sh --backend               # 只部署后端
  ./deploy.sh --mobile                # 只打包并上传 APK，同时更新服务端版本配置
  ./deploy.sh --check                 # 只做本地检查，不上传

常用参数:
  -y, --yes                           跳过确认
  --server ubuntu@1.2.3.4             覆盖服务器
  --key /path/to/macOS.pem            指定 SSH 私钥
  --public-url http://1.2.3.4         APK 下载域名或 IP
  --version-name 1.0.11               指定 App 版本名
  --version-code 12                   指定 App build 号
  --bump build|patch|minor|major|none 自动升版本，默认 build
  --notes "更新说明"                  写入 APP_ANDROID_RELEASE_NOTES
  --force-update true|false           写入 APP_ANDROID_FORCE_UPDATE
  --min-version-code 10               写入 APP_ANDROID_MIN_VERSION_CODE
  --run-tests                         运行后端 npm test 和 Flutter analyze
  --skip-flutter-analyze              手机端构建前跳过 flutter analyze
  --ios                               额外构建 iOS ipa（需要本机签名环境）
  --split-per-abi                     构建更小的分 ABI APK，并发布 arm64-v8a（默认）
  --universal-apk                     构建兼容所有 ABI 的通用 APK，文件更大
  --dry-run                           只展示将执行的部署动作

也可用环境变量:
  DEPLOY_SERVER, DEPLOY_SERVER_DIR, DEPLOY_PUBLIC_BASE_URL, DEPLOY_SSH_KEY
EOF
}

log() { printf '\033[1;34m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m错误: %s\033[0m\n' "$*" >&2; exit 1; }

run() {
  if (( DRY_RUN )); then
    printf '[dry-run] %q' "$1"
    shift || true
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

find_ssh_key() {
  if [[ -n "$SSH_KEY" ]]; then return; fi
  local candidates=(
    "$ROOT_DIR/macOS.pem"
    "$HOME/.ssh/macOS.pem"
    "$HOME/Downloads/macOS.pem"
    "$HOME/Desktop/macOS.pem"
  )
  for key in "${candidates[@]}"; do
    if [[ -f "$key" ]]; then
      SSH_KEY="$key"
      return
    fi
  done
}

ssh_cmd() {
  ssh -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    -o Compression=no \
    -c aes128-gcm@openssh.com \
    "$SERVER" "$@"
}

scp_cmd() {
  scp -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    -o Compression=no \
    -c aes128-gcm@openssh.com \
    "$@"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) MODE="all" ;;
      --auto) MODE="auto" ;;
      --web) MODE="web" ;;
      --backend) MODE="backend" ;;
      --mobile) MODE="mobile" ;;
      --check) MODE="check" ;;
      -y|--yes) YES=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --run-tests) RUN_TESTS=1 ;;
      --skip-flutter-analyze) SKIP_FLUTTER_ANALYZE=1 ;;
      --ios) BUILD_IOS=1 ;;
      --split-per-abi) SPLIT_PER_ABI=1 ;;
      --universal-apk) SPLIT_PER_ABI=0 ;;
      --server) SERVER="${2:-}"; shift ;;
      --key) SSH_KEY="${2:-}"; shift ;;
      --public-url) PUBLIC_BASE_URL="${2:-}"; shift ;;
      --version-name) VERSION_NAME="${2:-}"; shift ;;
      --version-code) VERSION_CODE="${2:-}"; shift ;;
      --bump) BUMP="${2:-}"; shift ;;
      --notes) RELEASE_NOTES="${2:-}"; shift ;;
      --force-update) FORCE_UPDATE="${2:-}"; shift ;;
      --min-version-code) MIN_VERSION_CODE="${2:-}"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "未知参数: $1。用 --help 查看帮助。" ;;
    esac
    shift
  done
}

git_paths_since_remote() {
  local remote_sha base
  remote_sha=""
  if [[ -n "$SSH_KEY" && -f "$SSH_KEY" ]]; then
    remote_sha="$(ssh_cmd "cat '$SERVER_DIR/$STATE_FILE' 2>/dev/null | sed -n 's/^git_sha=//p' | tail -1" || true)"
  fi
  if [[ -n "$remote_sha" ]] && git -C "$ROOT_DIR" cat-file -e "$remote_sha^{commit}" 2>/dev/null; then
    base="$remote_sha"
  else
    base="HEAD"
  fi

  {
    git -C "$ROOT_DIR" diff --name-only "$base"..HEAD 2>/dev/null || true
    git -C "$ROOT_DIR" diff --name-only 2>/dev/null || true
    git -C "$ROOT_DIR" diff --name-only --cached 2>/dev/null || true
    git -C "$ROOT_DIR" ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u
}

detect_components() {
  DEPLOY_WEB=0
  DEPLOY_BACKEND=0
  DEPLOY_MOBILE=0

  case "$MODE" in
    all) DEPLOY_WEB=1; DEPLOY_BACKEND=1; DEPLOY_MOBILE=1; return ;;
    web) DEPLOY_WEB=1; return ;;
    backend) DEPLOY_BACKEND=1; return ;;
    mobile) DEPLOY_MOBILE=1; return ;;
    check) DEPLOY_WEB=1; DEPLOY_BACKEND=1; DEPLOY_MOBILE=1; return ;;
    auto) ;;
    *) die "不支持的模式: $MODE" ;;
  esac

  local paths path changed=0
  paths="$(git_paths_since_remote)"
  if [[ -z "$paths" ]]; then
    warn "没有检测到本地或远端部署点之后的改动，将只做后端健康检查。"
    return
  fi

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    changed=1
    case "$path" in
      BackEnd/web-admin/*) DEPLOY_WEB=1 ;;
      BackEnd/server/*|BackEnd/Dockerfile|BackEnd/docker-compose.prod.yml|BackEnd/nginx.prod.conf) DEPLOY_BACKEND=1 ;;
      BackEnd/dist/*) DEPLOY_WEB=1 ;;
      MobileApp/*|TUIKit_Flutter/*) DEPLOY_MOBILE=1 ;;
      deploy.sh) DEPLOY_WEB=1; DEPLOY_BACKEND=1 ;;
    esac
  done <<< "$paths"

  if (( changed == 0 )); then
    warn "没有检测到可部署改动。"
  fi
}

current_mobile_version() {
  grep '^version:' "$PUBSPEC" | awk '{print $2}'
}

bump_version_name() {
  local name="$1"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$name"
  major="${major:-0}"; minor="${minor:-0}"; patch="${patch:-0}"
  case "$BUMP" in
    none|build) printf '%s\n' "$name" ;;
    patch) printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))" ;;
    minor) printf '%s.%s.0\n' "$major" "$((minor + 1))" ;;
    major) printf '%s.0.0\n' "$((major + 1))" ;;
    *) die "--bump 只支持 build|patch|minor|major|none" ;;
  esac
}

prepare_mobile_version() {
  local current current_name current_code next_name next_code
  current="$(current_mobile_version)"
  current_name="${current%%+*}"
  current_code="${current##*+}"
  [[ "$current_code" =~ ^[0-9]+$ ]] || die "MobileApp/pubspec.yaml 版本号格式应类似 1.0.10+11"

  next_name="${VERSION_NAME:-$(bump_version_name "$current_name")}"
  if [[ -n "$VERSION_CODE" ]]; then
    next_code="$VERSION_CODE"
  elif [[ "$BUMP" == "none" ]]; then
    next_code="$current_code"
  else
    next_code="$((current_code + 1))"
  fi

  [[ "$next_code" =~ ^[0-9]+$ ]] || die "--version-code 必须是数字"
  MOBILE_VERSION_NAME="$next_name"
  MOBILE_VERSION_CODE="$next_code"
  MOBILE_VERSION="$MOBILE_VERSION_NAME+$MOBILE_VERSION_CODE"
  APK_FILENAME="app-v${MOBILE_VERSION_NAME}-${MOBILE_VERSION_CODE}.apk"
  APK_DOWNLOAD_URL="${PUBLIC_BASE_URL%/}/uploads/releases/${APK_FILENAME}"
}

format_bytes() {
  local bytes="$1"
  awk -v b="$bytes" 'BEGIN {
    split("B KB MB GB", u, " ");
    i=1;
    while (b >= 1024 && i < 4) { b/=1024; i++ }
    printf "%.1f%s", b, u[i]
  }'
}

confirm() {
  (( YES )) && return 0
  printf '\n即将部署到: %s:%s\n' "$SERVER" "$SERVER_DIR"
  printf '部署内容:'
  (( DEPLOY_WEB )) && printf ' 管理端'
  (( DEPLOY_BACKEND )) && printf ' 后端'
  (( DEPLOY_MOBILE )) && printf ' 手机端'
  printf '\n'
  if (( DEPLOY_MOBILE )); then
    printf 'App 版本: %s\nAPK: %s\n' "$MOBILE_VERSION" "$APK_DOWNLOAD_URL"
  fi
  read -r -p "确认继续？(y/N) " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || die "已取消"
}

preflight() {
  need_cmd git
  need_cmd ssh
  need_cmd scp
  need_cmd rsync
  need_cmd node
  need_cmd npm
  if (( DEPLOY_MOBILE )); then need_cmd flutter; fi

  find_ssh_key
  [[ -f "$SSH_KEY" ]] || die "找不到 SSH 私钥 macOS.pem。请放到 ~/.ssh/macOS.pem，或使用 --key 指定。"
  chmod 600 "$SSH_KEY" 2>/dev/null || warn "无法 chmod 600 $SSH_KEY，请手动检查私钥权限。"

  [[ -d "$BACKEND_DIR" ]] || die "找不到 BackEnd 目录"
  [[ -d "$WEB_DIR" ]] || die "找不到 BackEnd/web-admin 目录"
  [[ -f "$PUBSPEC" ]] || die "找不到 MobileApp/pubspec.yaml"

  if (( DRY_RUN == 0 )); then
    ssh_cmd "echo connected >/dev/null" || die "无法连接服务器: $SERVER"
  fi
}

check_backend() {
  log "[检查] 后端 JS 语法"
  find "$BACKEND_DIR/server" \
    -path "$BACKEND_DIR/server/node_modules" -prune -o \
    -path "$BACKEND_DIR/server/coverage" -prune -o \
    -name '*.js' -print0 | xargs -0 -n 1 node --check >/dev/null
  ok "后端语法检查通过"

  if (( RUN_TESTS )); then
    log "[检查] 后端测试"
    (cd "$BACKEND_DIR/server" && npm test)
    ok "后端测试通过"
  fi
}

build_web() {
  log "[构建] 管理端"
  (cd "$WEB_DIR" && npm ci && npm run build)
  [[ -d "$BACKEND_DIR/dist" ]] || die "管理端 dist 未生成"
  ok "管理端构建完成: BackEnd/dist"
}

check_mobile() {
  log "[检查] 手机端"
  (cd "$MOBILE_DIR" && flutter pub get)
  if (( SKIP_FLUTTER_ANALYZE == 0 )); then
    (cd "$MOBILE_DIR" && flutter analyze)
  fi
  ok "手机端检查完成"
}

build_mobile() {
  log "[版本] 更新 MobileApp/pubspec.yaml"
  local current
  current="$(current_mobile_version)"
  if [[ "$current" != "$MOBILE_VERSION" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^version: .*/version: $MOBILE_VERSION/" "$PUBSPEC"
    else
      sed -i "s/^version: .*/version: $MOBILE_VERSION/" "$PUBSPEC"
    fi
  fi
  ok "App 版本: $current -> $MOBILE_VERSION"

  log "[构建] Android APK"
  (cd "$MOBILE_DIR" && flutter pub get)
  if (( RUN_TESTS && SKIP_FLUTTER_ANALYZE == 0 )); then
    (cd "$MOBILE_DIR" && flutter analyze)
  fi
  if (( SPLIT_PER_ABI )); then
    (cd "$MOBILE_DIR" && flutter build apk --release --split-per-abi)
    APK_SOURCE="$APK_OUTPUT_DIR/app-arm64-v8a-release.apk"
  else
    (cd "$MOBILE_DIR" && flutter build apk --release)
    APK_SOURCE="$APK_OUTPUT_DIR/app-release.apk"
  fi
  [[ -f "$APK_SOURCE" ]] || die "APK 未生成: $APK_SOURCE"
  ok "APK 构建完成: $(format_bytes "$(wc -c < "$APK_SOURCE")")"

  if (( BUILD_IOS )); then
    log "[构建] iOS ipa"
    (cd "$MOBILE_DIR" && flutter build ipa --release)
    ok "iOS ipa 构建完成"
  fi
}

remote_docker() {
  ssh_cmd "if docker ps >/dev/null 2>&1; then echo docker; else echo 'sudo docker'; fi"
}

ensure_remote_dir() {
  log "[远端] 准备服务器目录"
  ssh_cmd "mkdir -p '$SERVER_DIR/uploads/releases' 2>/dev/null || (sudo mkdir -p '$SERVER_DIR/uploads/releases' && sudo chown -R \$(id -un):\$(id -gn) '$SERVER_DIR')"
  ok "服务器目录可用"
}

sync_backend() {
  log "[上传] 同步 BackEnd 到服务器"
  local rsync_path=""
  if ! ssh_cmd "test -w '$SERVER_DIR'"; then
    rsync_path="--rsync-path=sudo rsync"
  fi

  rsync -az --compress-level=1 --delete --partial --progress --stats \
    $rsync_path \
    --exclude='.env' \
    --exclude='.DS_Store' \
    --exclude='server/.env' \
    --exclude='uploads/' \
    --exclude='server/uploads/' \
    --exclude='server/node_modules/' \
    --exclude='web-admin/node_modules/' \
    --exclude='web-admin/.vite/' \
    --exclude='server/coverage/' \
    --exclude='server/logs/' \
    --exclude='*.log' \
    -e "ssh -i '$SSH_KEY' -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o Compression=no -c aes128-gcm@openssh.com" \
    "$BACKEND_DIR/" "$SERVER:$SERVER_DIR/"
  ok "BackEnd 同步完成"
}

upload_mobile() {
  log "[上传] APK"
  local local_size local_sha remote_dir remote_dest remote_tmp upload_pid remote_size percent remote_sha
  local_size="$(wc -c < "$APK_SOURCE" | tr -d ' ')"
  local_sha="$(shasum -a 256 "$APK_SOURCE" | awk '{print $1}')"
  remote_dir="$SERVER_DIR/uploads/releases"
  remote_dest="$remote_dir/$APK_FILENAME"
  remote_tmp="$remote_dir/.$APK_FILENAME.uploading"

  printf '本地 APK: %s (%s)\n' "$APK_SOURCE" "$(format_bytes "$local_size")"
  printf '本地 SHA256: %s\n' "$local_sha"

  ssh_cmd "mkdir -p '$remote_dir' 2>/dev/null || (sudo mkdir -p '$remote_dir' && sudo chown -R \$(id -un):\$(id -gn) '$SERVER_DIR')"
  ssh_cmd "rm -f '$remote_tmp' '$remote_dest'"

  ssh -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    -o Compression=no \
    -c aes128-gcm@openssh.com \
    "$SERVER" "cat > '$remote_tmp'" < "$APK_SOURCE" &
  upload_pid=$!

  while kill -0 "$upload_pid" 2>/dev/null; do
    sleep 5
    remote_size="$(ssh_cmd "stat -c %s '$remote_tmp' 2>/dev/null || echo 0" | tail -1 | tr -d '\r')"
    if [[ "$remote_size" =~ ^[0-9]+$ ]] && (( local_size > 0 )); then
      percent=$(( remote_size * 100 / local_size ))
      printf '\r上传进度: %s / %s (%s%%)' "$(format_bytes "$remote_size")" "$(format_bytes "$local_size")" "$percent"
    fi
  done
  wait "$upload_pid"
  printf '\n'

  remote_sha="$(ssh_cmd "sha256sum '$remote_tmp' | awk '{print \$1}'")"
  [[ "$remote_sha" == "$local_sha" ]] || die "APK SHA256 校验失败: local=$local_sha remote=$remote_sha"
  ssh_cmd "mv '$remote_tmp' '$remote_dest' && chmod 644 '$remote_dest'"
  ok "APK 已上传: $APK_DOWNLOAD_URL"
}

remote_set_env() {
  local key="$1" value="$2"
  local qkey qvalue
  [[ -n "$value" ]] || return 0
  printf -v qkey '%q' "$key"
  printf -v qvalue '%q' "$value"
  ssh_cmd "cd '$SERVER_DIR' && touch .env && python3 - $qkey $qvalue <<'PY'
import sys
from pathlib import Path
key, value = sys.argv[1], sys.argv[2]
path = Path('.env')
lines = path.read_text().splitlines() if path.exists() else []
prefix = key + '='
done = False
out = []
for line in lines:
    if line.startswith(prefix):
        out.append(prefix + value)
        done = True
    else:
        out.append(line)
if not done:
    out.append(prefix + value)
path.write_text('\\n'.join(out) + '\\n')
PY"
}

update_remote_version_env() {
  (( DEPLOY_MOBILE )) || return 0
  log "[远端] 更新 App 版本配置"
  remote_set_env APP_ANDROID_VERSION_NAME "$MOBILE_VERSION_NAME"
  remote_set_env APP_ANDROID_VERSION_CODE "$MOBILE_VERSION_CODE"
  remote_set_env APP_ANDROID_DOWNLOAD_URL "$APK_DOWNLOAD_URL"
  remote_set_env APP_ANDROID_RELEASE_NOTES "$RELEASE_NOTES"
  remote_set_env APP_ANDROID_FORCE_UPDATE "$FORCE_UPDATE"
  remote_set_env APP_ANDROID_MIN_VERSION_CODE "$MIN_VERSION_CODE"
  ok "服务器 .env 版本配置已更新"
}

restart_remote() {
  if (( DEPLOY_WEB == 0 && DEPLOY_BACKEND == 0 && DEPLOY_MOBILE == 0 )); then
    return 0
  fi

  log "[远端] 重建/重启 Docker 服务"
  local docker_cmd
  docker_cmd="$(remote_docker)"

  if (( DEPLOY_WEB || DEPLOY_BACKEND )); then
    ssh_cmd "cd '$SERVER_DIR' && $docker_cmd compose -f docker-compose.prod.yml up -d --build app nginx"
  elif (( DEPLOY_MOBILE )); then
    ssh_cmd "cd '$SERVER_DIR' && $docker_cmd compose -f docker-compose.prod.yml up -d app nginx"
  fi
  ok "远端服务已启动"
}

write_remote_state() {
  local sha
  sha="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || true)"
  [[ -n "$sha" ]] || return 0
  ssh_cmd "cat > '$SERVER_DIR/$STATE_FILE' <<EOF
git_sha=$sha
deployed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mode=$MODE
web=$DEPLOY_WEB
backend=$DEPLOY_BACKEND
mobile=$DEPLOY_MOBILE
version=${MOBILE_VERSION:-}
EOF"
}

health_check() {
  log "[验证] 健康检查"
  ssh_cmd "sleep 3; curl -fsS http://127.0.0.1/api/health || curl -fsS http://127.0.0.1/health || true"
  printf '\n'
  if (( DEPLOY_MOBILE )); then
    ssh_cmd "curl -fsSI '$APK_DOWNLOAD_URL' | head -n 1 || true"
  fi
  ok "验证命令已执行"
}

summary() {
  printf '\n========================================\n'
  printf '部署完成\n'
  printf '服务器: %s\n' "$SERVER"
  printf '目录: %s\n' "$SERVER_DIR"
  printf '内容:'
  (( DEPLOY_WEB )) && printf ' 管理端'
  (( DEPLOY_BACKEND )) && printf ' 后端'
  (( DEPLOY_MOBILE )) && printf ' 手机端'
  printf '\n'
  if (( DEPLOY_MOBILE )); then
    printf 'App 版本: %s\n' "$MOBILE_VERSION"
    printf 'APK 下载: %s\n' "$APK_DOWNLOAD_URL"
  fi
  printf '========================================\n'
}

main() {
  parse_args "$@"
  find_ssh_key
  detect_components
  if (( DEPLOY_MOBILE )); then prepare_mobile_version; fi

  log "境图一键部署"
  printf '模式: %s\n' "$MODE"
  printf '服务器: %s\n' "$SERVER"
  printf 'SSH Key: %s\n' "${SSH_KEY:-自动查找 macOS.pem}"

  preflight
  confirm

  if (( DRY_RUN )); then
    ok "dry-run 完成，未构建也未上传。"
    exit 0
  fi

  if (( DEPLOY_BACKEND )) || [[ "$MODE" == "check" ]]; then check_backend; fi
  if (( DEPLOY_WEB )); then build_web; fi
  if [[ "$MODE" == "check" ]]; then
    check_mobile
  elif (( DEPLOY_MOBILE )); then
    build_mobile
  fi

  if [[ "$MODE" == "check" ]]; then
    ok "本地检查完成，未上传。"
    exit 0
  fi

  ensure_remote_dir
  if (( DEPLOY_WEB || DEPLOY_BACKEND )); then sync_backend; fi
  if (( DEPLOY_MOBILE )); then upload_mobile; update_remote_version_env; fi
  restart_remote
  write_remote_state
  health_check
  summary
}

main "$@"
