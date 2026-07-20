#!/usr/bin/env bash
# ============================================================================
# appstore-release.sh — Instagram Threads Clone 一键发布到 App Store 正式环境
# ----------------------------------------------------------------------------
# 完整流水线：API 环境检查 → bump 构建号 → commit → push → build IPA →
#   上传 IPA → 上传 metadata + 截图 → 提交审核
#
# 与 release.sh（TestFlight 流水线）平级并存：
#   • TestFlight 内测：$ release.sh
#   • App Store 正式分发：$ appstore-release.sh
#
# 用法:
#   # 完整发布（默认）
#   ./client/scripts/appstore-release.sh
#
#   # 只重新上传 IPA（已存在，跳过 bump/build）
#   ./client/scripts/appstore-release.sh --only-upload
#
#   # 跳过构建号 bump（用于上传失败重试，避免重复递增）
#   ./client/scripts/appstore-release.sh --no-bump
#
#   # 跳过 git push（本地调试）
#   ./client/scripts/appstore-release.sh --no-push
#
#   # 跳过提交审核（只准备好审核包，但暂不提交）
#   ./client/scripts/appstore-release.sh --no-submit
#
#   # 组合使用
#   ./client/scripts/appstore-release.sh --only-upload --no-bump --no-submit
#
# 前置条件：
#   1. 已安装 fastlane（gem install fastlane）
#   2. 已配置 App Store Connect API Key：
#      - client/fastlane/api_key.json
#      - client/fastlane/auth/AuthKey_<KEY_ID>.p8
#   3. Appfile 的 apple_id 已填真实邮箱
#   4. App Store Connect 上 App 记录已存在（bundle ID = com.yt.threads）
#   5. ATB（协议 / 税务 / 银行）已生效
#
# 推荐 alias:
#   echo "alias release-appstore='$PWD/client/scripts/appstore-release.sh'" >> ~/.zshrc && source ~/.zshrc
# ============================================================================

set -euo pipefail

# ---- 颜色与日志工具 --------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'
header()  { printf "\n${CYAN}━━━ %s ━━━${NC}\n" "$1"; }
info()    { printf "${BLUE}ℹ${NC} %s\n" "$1"; }
ok()      { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn()    { printf "${YELLOW}⚠${NC} %s\n" "$1"; }
err()     { printf "${RED}✗${NC} %s\n" "$1"; }
dim()     { printf "${GRAY}  %s${NC}\n" "$1"; }

# ---- 定位 client/ 目录 -----------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(cd "$CLIENT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# ---- 参数解析 --------------------------------------------------------------
ONLY_UPLOAD=0
NO_BUMP=0
NO_PUSH=0
NO_SUBMIT=0
for arg in "$@"; do
  case "$arg" in
    --only-upload) ONLY_UPLOAD=1 ;;
    --no-bump)     NO_BUMP=1 ;;
    --no-push)     NO_PUSH=1 ;;
    --no-submit)   NO_SUBMIT=1 ;;
    --help|-h)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) err "未知参数: $arg（用 --help 查看用法）"; exit 2 ;;
  esac
done

if [ "$ONLY_UPLOAD" = "1" ] && [ "$NO_BUMP" != "1" ]; then
  NO_BUMP=1
  dim "--only-upload 默认隐含 --no-bump"
fi

# ---- 前置检查 --------------------------------------------------------------
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "未检测到 $1，请先安装并加入 PATH"
    dim "  • fastlane: gem install fastlane"
    dim "  • flutter: https://flutter.dev/docs/get-started/install"
    dim "  • xcodebuild: 安装 Xcode + Command Line Tools"
    exit 1
  fi
}
need_cmd flutter
need_cmd xcodebuild
need_cmd git
need_cmd fastlane

# ============================================================================
# Step 1: API 环境检查
# ----------------------------------------------------------------------------
# 读 client/lib/network/api_config.dart，确认 _prodBaseUrl 与 defaultValue。
# App Store 包禁止带 --dart-define=APP_ENV=dev。
# ============================================================================
header "Step 1/9  API 环境检查"

API_CONFIG="$CLIENT_DIR/lib/network/api_config.dart"
if [ ! -f "$API_CONFIG" ]; then
  err "未找到 $API_CONFIG"
  exit 1
fi

if grep -q "_prodBaseUrl = 'https://api.tweetcaht.com/'" "$API_CONFIG" \
  && grep -q "defaultValue: 'prod'" "$API_CONFIG"; then
  ok "API 指向 prod（https://api.tweetcaht.com/）"
else
  err "api_config.dart 未指向 prod 环境，拒绝发布"
  dim "检查 _prodBaseUrl 与 defaultValue 是否被改成 dev"
  exit 1
fi

# ============================================================================
# Step 2: API Key 检查
# ----------------------------------------------------------------------------
# 确认 fastlane/api_key.json 与 auth/*.p8 存在
# ============================================================================
header "Step 2/9  App Store Connect API Key 检查"

API_KEY_JSON="$CLIENT_DIR/fastlane/api_key.json"
if [ ! -f "$API_KEY_JSON" ]; then
  err "未找到 $API_KEY_JSON"
  dim "请参考 client/fastlane/README.md 首次使用 4 步走配置 API Key"
  exit 1
fi

KEY_FILEPATH_REL=$(python3 -c "import json; print(json.load(open('$API_KEY_JSON'))['key_filepath'])" 2>/dev/null || echo "")
if [ -z "$KEY_FILEPATH_REL" ]; then
  err "无法从 $API_KEY_JSON 解析 key_filepath 字段"
  exit 1
fi
KEY_FILEPATH_ABS="$CLIENT_DIR/fastlane/$KEY_FILEPATH_REL"
if [ ! -f "$KEY_FILEPATH_ABS" ]; then
  err "API Key 文件不存在: $KEY_FILEPATH_ABS"
  dim "请从 App Store Connect 后台下载 .p8 文件并放到 client/fastlane/auth/ 目录"
  exit 1
fi
ok "API Key config ready: ${KEY_FILEPATH_REL}"

# 检查 Appfile
APPFILE="$CLIENT_DIR/fastlane/Appfile"
if grep -E '^[[:space:]]*apple_id[[:space:]]+"REPLACE_WITH_YOUR_APPLE_ID' "$APPFILE" >/dev/null 2>&1; then
  err "Appfile 的 apple_id 还是占位符（REPLACE_WITH_YOUR_APPLE_ID）"
  dim "请编辑 $APPFILE 填入真实的 Apple ID 邮箱"
  exit 1
fi
ok "Appfile 已配置真实 apple_id"

# ============================================================================
# Step 3: 工作区检查
# ----------------------------------------------------------------------------
# 仅忽略 .claude/、*.ips、fastlane 敏感文件（api_key.json、auth/）
# ============================================================================
header "Step 3/9  工作区检查"

PENDING=$(git status --porcelain --untracked-files=all \
  | grep -vE '^\?\? \.claude/' \
  | grep -vE '^\?\? .*\.ips$' \
  | grep -vE '^\?\? client/fastlane/api_key\.json$' \
  | grep -vE '^\?\? client/fastlane/auth/' \
  | grep -vE '^\?\? client/\.fastlane/' \
  || true)

if [ -n "$PENDING" ]; then
  if [ "$ONLY_UPLOAD" = "1" ]; then
    warn "--only-upload 模式跳过工作区检查，但有以下未提交改动："
    printf "%s\n" "$PENDING" | sed 's/^/  /'
  else
    warn "工作区有未提交改动（已排除 .claude/、*.ips、fastlane 敏感文件）："
    printf "%s\n" "$PENDING" | sed 's/^/  /'
    err "请先提交（或 stash）再发版，或用 --only-upload 仅重传 IPA"
    exit 1
  fi
else
  ok "工作区干净"
fi

# ============================================================================
# Step 4: bump 构建号
# ============================================================================
if [ "$NO_BUMP" = "1" ]; then
  header "Step 4/9  跳过构建号 bump（--no-bump）"
else
  header "Step 4/9  递增构建号"

  PUBSPEC="$CLIENT_DIR/pubspec.yaml"
  CURRENT=$(grep -E '^version:' "$PUBSPEC" | head -1 | sed -E 's/^version:[[:space:]]*//')
  VERSION_PART=$(echo "$CURRENT" | cut -d+ -f1)
  BUILD_PART=$(echo "$CURRENT" | cut -d+ -f2)

  if [ -z "$BUILD_PART" ] || ! [[ "$BUILD_PART" =~ ^[0-9]+$ ]]; then
    err "无法解析 pubspec.yaml 构建号: $CURRENT"
    exit 1
  fi

  NEXT_BUILD=$((BUILD_PART + 1))
  NEXT_VERSION="${VERSION_PART}+${NEXT_BUILD}"

  info "bump: $CURRENT → $NEXT_VERSION"

  sed -i '' -E "s/^version: ${VERSION_PART}\.${BUILD_PART}/version: ${NEXT_VERSION}/" "$PUBSPEC"
  if ! grep -q "^version: ${NEXT_VERSION}\$" "$PUBSPEC"; then
    sed -i '' -E "s|^version:.*|version: ${NEXT_VERSION}|" "$PUBSPEC"
  fi
  if ! grep -q "^version: ${NEXT_VERSION}\$" "$PUBSPEC"; then
    err "pubspec.yaml 替换失败"
    exit 1
  fi

  git add "$PUBSPEC"
  git commit -m "chore: bump build to ${NEXT_VERSION} for App Store release" >/dev/null
  ok "已 commit：bump build → ${NEXT_VERSION}"
fi

# ============================================================================
# Step 5: git push
# ============================================================================
if [ "$NO_PUSH" = "1" ]; then
  header "Step 5/9  跳过 git push（--no-push）"
else
  header "Step 5/9  git push origin main"
  git push origin main
  ok "已推送"
fi

CURRENT_HASH=$(git rev-parse --short HEAD)
CURRENT_VERSION=$(grep -E '^version:' "$CLIENT_DIR/pubspec.yaml" | sed -E 's/^version:[[:space:]]*//')
info "本次发布：版本 ${CURRENT_VERSION}，HEAD = ${CURRENT_HASH}"

# ============================================================================
# Step 6: flutter build ipa --release
# ============================================================================
if [ "$ONLY_UPLOAD" = "1" ]; then
  header "Step 6/9  跳过 build（--only-upload）"
  ARCHIVE="$CLIENT_DIR/build/ios/archive/Runner.xcarchive"
  if [ ! -d "$ARCHIVE" ]; then
    err "未找到 archive: $ARCHIVE"
    dim "--only-upload 需要先成功执行过一次 build"
    exit 1
  fi
  ok "复用已有 archive: $ARCHIVE"
else
  header "Step 6/9  flutter build ipa --release"
  cd "$CLIENT_DIR"
  # App Store 正式包：不带 FEEDBACK_ENABLED（默认 false）→ Bug 反馈模块
  # 被 tree-shake 物理剔除，不出现在产物中。
  flutter build ipa --release
  cd "$PROJECT_DIR"
  ok "构建完成"

  ARCHIVE="$CLIENT_DIR/build/ios/archive/Runner.xcarchive"
  if [ ! -d "$ARCHIVE" ]; then
    err "build 后仍未找到 archive: $ARCHIVE"
    exit 1
  fi
fi

# ============================================================================
# Step 7: 上传 IPA 到 App Store Connect
# ----------------------------------------------------------------------------
# 复用 release.sh 已验证的 xcodebuild exportArchive 流（卡顿检测 + 重试）
# ============================================================================
header "Step 7/9  上传 IPA 到 App Store Connect"

UPLOAD_DIR="$CLIENT_DIR/build/ios/upload"
mkdir -p "$UPLOAD_DIR"

PLIST="$UPLOAD_DIR/UploadOptions.plist"
cat > "$PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>B3885SFCQJ</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
EOF

TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$UPLOAD_DIR/upload.${TS}.log"
STALL_THRESHOLD=300
MAX_ATTEMPTS=3

run_upload_once() {
  local attempt="$1"
  local attempt_log="$LOG_FILE.attempt${attempt}"
  : > "$attempt_log"

  info "上传尝试 ${attempt}/${MAX_ATTEMPTS}，日志：$attempt_log"
  echo "==== attempt $attempt start $(date '+%Y-%m-%d %H:%M:%S') ====" >> "$attempt_log"

  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$UPLOAD_DIR" \
    -exportOptionsPlist "$PLIST" \
    -allowProvisioningUpdates \
    > >(tee -a "$attempt_log") 2>&1 &
  local xcode_pid=$!

  (
    local start_ts
    start_ts=$(date +%s)
    while kill -0 "$xcode_pid" 2>/dev/null; do
      sleep 30
      local now
      now=$(date +%s)
      local mtime
      mtime=$(stat -f%m "$attempt_log" 2>/dev/null || echo "$now")
      local stall=$((now - mtime))
      local total=$((now - start_ts))

      if [ "$stall" -ge "$STALL_THRESHOLD" ]; then
        printf "${YELLOW}⚠${NC} 日志已 %s 秒无更新（>=%s），判定卡顿，kill 重试\n" \
          "$stall" "$STALL_THRESHOLD"
        kill -TERM "$xcode_pid" 2>/dev/null || true
        break
      else
        printf "${GRAY}⏱  attempt %s 已运行 %ss，日志最后更新于 %ss 前${NC}\n" \
          "$attempt" "$total" "$stall"
      fi
    done
  ) &
  local watch_pid=$!

  wait "$xcode_pid" 2>/dev/null
  local xcode_exit=$?
  kill "$watch_pid" 2>/dev/null || true
  wait "$watch_pid" 2>/dev/null || true

  cat "$attempt_log" >> "$LOG_FILE"

  if [ "$xcode_exit" -eq 0 ] && grep -q "EXPORT SUCCEEDED" "$attempt_log"; then
    return 0
  else
    warn "attempt $attempt 退出码=$xcode_exit"
    return 1
  fi
}

UPLOAD_OK=0
for attempt in $(seq 1 $MAX_ATTEMPTS); do
  if run_upload_once "$attempt"; then
    UPLOAD_OK=1
    break
  fi
  if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
    warn "attempt $attempt 失败，5 秒后重试..."
    sleep 5
  fi
done

if [ "$UPLOAD_OK" != "1" ]; then
  err "IPA 上传失败（${MAX_ATTEMPTS} 次重试均未成功）"
  dim "排错建议："
  dim "  1) 查看 $LOG_FILE 末尾的 Apple 错误信息"
  dim "  2) 用 GUI 版 Transporter app 拖 client/build/ios/ipa/Tweet.ipa 手动上传"
  exit 1
fi
ok "IPA 上传成功（** EXPORT SUCCEEDED **）"

# ============================================================================
# Step 8: 上传 metadata + 截图（fastlane upload_listing）
# ============================================================================
header "Step 8/9  上传 metadata + 截图到 App Store Connect"

cd "$CLIENT_DIR"
LISTING_LOG="$UPLOAD_DIR/listing.${TS}.log"
if fastlane ios upload_listing > "$LISTING_LOG" 2>&1; then
  ok "metadata + 截图已上传"
else
  err "metadata 上传失败，查看 $LISTING_LOG"
  dim "常见原因：privacy_url 还是占位符 / 截图尺寸不合规 / 缺字段"
  tail -30 "$LISTING_LOG" | sed 's/^/  /'
  exit 1
fi
cd "$PROJECT_DIR"

# ============================================================================
# Step 9: 提交审核（fastlane submit_for_review）
# ============================================================================
if [ "$NO_SUBMIT" = "1" ]; then
  header "Step 9/9  跳过提交审核（--no-submit）"
  warn "已上传 IPA + metadata + 截图，但未提交审核"
  warn "手动登录 App Store Connect 确认无误后，用以下命令提交："
  dim "  ./client/scripts/appstore-release.sh --no-bump --no-push --only-upload"
else
  header "Step 9/9  提交审核"

  cd "$CLIENT_DIR"
  SUBMIT_LOG="$UPLOAD_DIR/submit.${TS}.log"
  if fastlane ios submit_for_review > "$SUBMIT_LOG" 2>&1; then
    ok "审核已提交"
  else
    err "提交审核失败，查看 $SUBMIT_LOG"
    tail -30 "$SUBMIT_LOG" | sed 's/^/  /'
    cd "$PROJECT_DIR"
    exit 1
  fi
  cd "$PROJECT_DIR"
fi

# ============================================================================
# 回报
# ============================================================================
echo ""
header "🚀 App Store 发布完成"
ok "版本：${CURRENT_VERSION}"
ok "HEAD：${CURRENT_HASH}"
ok "IPA： $CLIENT_DIR/build/ios/ipa/Tweet.ipa"
ok "日志目录：$UPLOAD_DIR"
echo ""
info "App Store Connect 处理约需 5–15 分钟"
info "审核通常 24–48 小时，通过后自动上架（automatic_release: true）"
echo ""
warn "待你后续替换的内容（提交前）："
dim "  • client/fastlane/metadata/{en-US,zh-Hans}/privacy_url.txt — 真实隐私政策 URL"
dim "  • client/fastlane/metadata/{en-US,zh-Hans}/*.txt — AI 占位文案"
dim "  • client/fastlane/screenshots/{en-US,zh-Hans}/iPhone6.5/*.png — 占位截图，替换为真实 App 截图"
