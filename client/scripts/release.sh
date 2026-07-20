#!/usr/bin/env bash
# ============================================================================
# release.sh — Instagram Threads Clone 一键发布到 TestFlight
# ----------------------------------------------------------------------------
# 完整流水线：API 环境检查 → bump 构建号 → commit → push → build IPA → 上传
#
# 上传步骤的特性：
#   • 实时展示 xcodebuild 原始输出（每一步都可见，不再「看不到进度」）
#   • 同步 tee 到日志文件 client/build/ios/upload/upload.<timestamp>.log
#   • 5 分钟日志无更新 → 自动 kill 重试（判定 Apple 服务器卡顿）
#   • 最多重试 3 次（实测正常 1 分 30 秒左右完成）
#
# 用法:
#   # 完整发布（默认）
#   ./client/scripts/release.sh
#
#   # 只重新上传（IPA 已存在，跳过 bump/build）
#   ./client/scripts/release.sh --only-upload
#
#   # 跳过构建号 bump（用于上传失败重试，避免重复递增）
#   ./client/scripts/release.sh --no-bump
#
#   # 跳过 git push（本地调试，仅 build + 上传）
#   ./client/scripts/release.sh --no-push
#
#   # 组合使用
#   ./client/scripts/release.sh --only-upload --no-bump
#
# 推荐 alias:
#   echo "alias release='$PWD/client/scripts/release.sh'" >> ~/.zshrc && source ~/.zshrc
#   之后在任何目录执行 `release` 即可
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
dim()      { printf "${GRAY}  %s${NC}\n" "$1"; }

# ---- 定位 client/ 目录 -----------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(cd "$CLIENT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# ---- 参数解析 --------------------------------------------------------------
ONLY_UPLOAD=0
NO_BUMP=0
NO_PUSH=0
for arg in "$@"; do
  case "$arg" in
    --only-upload) ONLY_UPLOAD=1 ;;
    --no-bump)     NO_BUMP=1 ;;
    --no-push)     NO_PUSH=1 ;;
    --help|-h)
      sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) err "未知参数: $arg（用 --help 查看用法）"; exit 2 ;;
  esac
done

if [ "$ONLY_UPLOAD" = "1" ] && [ "$NO_BUMP" != "1" ]; then
  # --only-upload 默认隐含 --no-bump（IPA 已存在意味着版本已确定）
  NO_BUMP=1
fi

# ---- 前置检查 --------------------------------------------------------------
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "未检测到 $1，请先安装并加入 PATH"
    exit 1
  fi
}
need_cmd flutter
need_cmd xcodebuild
need_cmd git

# ============================================================================
# Step 1: API 环境检查
# ----------------------------------------------------------------------------
# 读 client/lib/network/api_config.dart，确认：
#   • _prodBaseUrl = 'https://api.tweetcaht.com/'
#   • defaultValue: 'prod'
# 任何 release/TestFlight 包必须走 prod，禁止 dev。
# ============================================================================
header "Step 1/6  API 环境检查"

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
# Step 2: 工作区检查
# ----------------------------------------------------------------------------
# 仅忽略 .claude/ 与 *.ips（敏感/崩溃日志）。若还有其他未提交改动，
# 提示用户先提交，避免把未完成工作带入 release commit。
# ============================================================================
header "Step 2/6  工作区检查"

# 过滤掉 .claude/ 与 .ips 后的「需要关注的改动」
PENDING=$(git status --porcelain --untracked-files=all \
  | grep -vE '^\?\? \.claude/' \
  | grep -vE '^\?\? .*\.ips$' \
  || true)

if [ -n "$PENDING" ]; then
  if [ "$ONLY_UPLOAD" = "1" ]; then
    warn "--only-upload 模式跳过工作区检查，但有以下未提交改动："
    printf "%s\n" "$PENDING" | sed 's/^/  /'
  else
    warn "工作区有未提交改动（已排除 .claude/ 与 *.ips）："
    printf "%s\n" "$PENDING" | sed 's/^/  /'
    err "请先提交（或 stash）再发版，或用 --only-upload 仅重传 IPA"
    exit 1
  fi
else
  ok "工作区干净（仅可能存在 .claude/ 或 *.ips，已忽略）"
fi

# ============================================================================
# Step 3: bump 构建号
# ----------------------------------------------------------------------------
# 解析 client/pubspec.yaml 的 version: X.Y.Z+N，把 N 递增为 N+1。
# 作为独立 commit：chore: bump build to X.Y.Z+(N+1) for TestFlight release
# ============================================================================
if [ "$NO_BUMP" = "1" ]; then
  header "Step 3/6  跳过构建号 bump（--no-bump）"
else
  header "Step 3/6  递增构建号"

  PUBSPEC="$CLIENT_DIR/pubspec.yaml"
  # 同时匹配版本号与构建号
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

  # 用 sed 替换。需要转义 / 与 +（这里都是数字，安全）
  sed -i '' -E "s/^version: ${VERSION_PART}\.${BUILD_PART}/version: ${NEXT_VERSION}/" "$PUBSPEC"
  # macOS sed 兼容写法：直接替换整行更稳
  if ! grep -q "^version: ${NEXT_VERSION}\$" "$PUBSPEC"; then
    # 兜底：直接替换匹配 ^version: 的整行
    sed -i '' -E "s|^version:.*|version: ${NEXT_VERSION}|" "$PUBSPEC"
  fi

  if ! grep -q "^version: ${NEXT_VERSION}\$" "$PUBSPEC"; then
    err "pubspec.yaml 替换失败"
    exit 1
  fi

  git add "$PUBSPEC"
  git commit -m "chore: bump build to ${NEXT_VERSION} for TestFlight release" >/dev/null
  ok "已 commit：bump build → ${NEXT_VERSION}"
fi

# ============================================================================
# Step 4: git push
# ============================================================================
if [ "$NO_PUSH" = "1" ]; then
  header "Step 4/6  跳过 git push（--no-push）"
else
  header "Step 4/6  git push origin main"
  git push origin main
  ok "已推送"
fi

CURRENT_HASH=$(git rev-parse --short HEAD)
CURRENT_VERSION=$(grep -E '^version:' "$CLIENT_DIR/pubspec.yaml" | sed -E 's/^version:[[:space:]]*//')
info "本次发布：版本 ${CURRENT_VERSION}，HEAD = ${CURRENT_HASH}"

# ============================================================================
# Step 5: flutter build ipa --release
# ----------------------------------------------------------------------------
# 注意：禁止带 --dart-define=APP_ENV=dev（release/TestFlight 一律走 prod）
# ============================================================================
if [ "$ONLY_UPLOAD" = "1" ]; then
  header "Step 5/6  跳过 build（--only-upload）"
  # 验证已有 IPA
  ARCHIVE="$CLIENT_DIR/build/ios/archive/Runner.xcarchive"
  if [ ! -d "$ARCHIVE" ]; then
    err "未找到 archive: $ARCHIVE"
    dim "--only-upload 需要先成功执行过一次 build"
    exit 1
  fi
  ok "复用已有 archive: $ARCHIVE"
else
  header "Step 5/6  flutter build ipa --release"
  cd "$CLIENT_DIR"
  # TestFlight 包启用内部测试「截屏 → Bug 反馈」闭环（FEEDBACK_ENABLED）。
  # 注意：仍不带 APP_ENV=dev（release 一律走 prod）。
  flutter build ipa --release --dart-define=FEEDBACK_ENABLED=true
  cd "$PROJECT_DIR"
  ok "构建完成"
fi

ARCHIVE="$CLIENT_DIR/build/ios/archive/Runner.xcarchive"
if [ ! -d "$ARCHIVE" ]; then
  err "build 后仍未找到 archive: $ARCHIVE"
  exit 1
fi

# ============================================================================
# Step 6: 上传到 App Store Connect（带进度展示 + 卡顿检测 + 自动重试）
# ----------------------------------------------------------------------------
# 策略：
#   1. 创建 UploadOptions.plist
#   2. 调 xcodebuild -exportArchive
#   3. stdout/stderr 同时输出到终端 + tee 到日志文件
#   4. 后台 watchdog 监控日志 mtime；5 分钟无更新判定卡顿 → kill
#   5. 失败重试最多 3 次（实测：卡顿多为 Apple 端瞬时抖动，重试通常秒过）
# ============================================================================
header "Step 6/6  上传到 App Store Connect"

UPLOAD_DIR="$CLIENT_DIR/build/ios/upload"
mkdir -p "$UPLOAD_DIR"

# 创建/覆盖 UploadOptions.plist
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

# 卡顿阈值（秒）—— 5 分钟无新日志判定为 Apple 端卡顿
STALL_THRESHOLD=300
# 最大重试次数
MAX_ATTEMPTS=3

# ----------------------------------------------------------------------------
# run_upload_once：跑一次上传，返回退出码
# 全程 tee 到 LOG_FILE。后台 watchdog 监控 mtime，超过阈值 kill xcodebuild。
# ----------------------------------------------------------------------------

# 注意：因管道与 trap 的交互复杂，本函数不做美化过滤，
# 直接让 xcodebuild 的原始输出（带 Progress xx%）展示到终端，
# 确保每一步（Sending analysis / Uploading / Waiting processing）都可见。
run_upload_once() {
  local attempt="$1"
  local attempt_log="$LOG_FILE.attempt${attempt}"
  : > "$attempt_log"

  info "上传尝试 ${attempt}/${MAX_ATTEMPTS}，日志：$attempt_log"
  echo "" >> "$attempt_log"
  echo "==== attempt $attempt start $(date '+%Y-%m-%d %H:%M:%S') ====" >> "$attempt_log"

  # 后台 xcodebuild；stdout/stderr 合并后 tee 到日志
  # NOTE: 用 process substitution 而非管道，避免 set -e + pipefail 误杀
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$UPLOAD_DIR" \
    -exportOptionsPlist "$PLIST" \
    -allowProvisioningUpdates \
    > >(tee -a "$attempt_log") 2>&1 &
  local xcode_pid=$!

  # 后台 watchdog：每 30 秒检查日志 mtime，超过阈值 kill xcodebuild
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
        printf "${YELLOW}⚠${NC} 日志已 %s 秒无更新（>=%s），判定 Apple 端卡顿，kill 重试\n" \
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

  # 等待 xcodebuild 结束
  wait "$xcode_pid" 2>/dev/null
  local xcode_exit=$?
  # 清理 watchdog
  kill "$watch_pid" 2>/dev/null || true
  wait "$watch_pid" 2>/dev/null || true

  # 汇总到主日志
  cat "$attempt_log" >> "$LOG_FILE"

  if [ "$xcode_exit" -eq 0 ] && grep -q "EXPORT SUCCEEDED" "$attempt_log"; then
    return 0
  else
    warn "attempt $attempt 退出码=$xcode_exit"
    return 1
  fi
}

# 重试循环
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

echo ""
info "完整日志：$LOG_FILE"

if [ "$UPLOAD_OK" != "1" ]; then
  err "上传失败（${MAX_ATTEMPTS} 次重试均未成功）"
  dim "排错建议："
  dim "  1) 查看 $LOG_FILE 末尾的 Apple 错误信息"
  dim "  2) 若是 ITMS-xxxx 错误，搜索该错误码（一般是签名 / Info.plist / 隐私清单问题）"
  dim "  3) 若是 Apple 服务器持续无响应，过 10-30 分钟再试"
  dim "  4) 用 GUI 版 Transporter app 拖 client/build/ios/ipa/Tweet.ipa 手动上传"
  exit 1
fi

ok "上传成功（** EXPORT SUCCEEDED **）"

# ============================================================================
# 回报
# ============================================================================
echo ""
header "🚀 发布完成"
ok "版本：${CURRENT_VERSION}"
ok "HEAD：${CURRENT_HASH}"
ok "IPA： $CLIENT_DIR/build/ios/ipa/Tweet.ipa"
ok "日志：$LOG_FILE"
echo ""
info "App Store Connect 处理约需 5–15 分钟，之后可在 TestFlight 看到新构建"
