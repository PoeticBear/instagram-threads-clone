#!/usr/bin/env bash
# ============================================================================
# dev.sh — Instagram Threads Clone 一键调试入口
# ----------------------------------------------------------------------------
# 交互式选择 3 个维度:
#   1) API 环境 (dev / prod)
#   2) 运行模式 (debug / profile)
#   3) iOS 设备  (模拟器 / 真机)
#
# 用法:
#   # 从项目根目录执行
#   ./client/scripts/dev.sh
#
#   # 也可从 client/ 目录执行
#   bash scripts/dev.sh
#
#   # 跳过交互菜单(适合 CI / 习惯性脚本)
#   APP_ENV=dev FLUTTER_MODE=debug DEVICE_ID=FEED462A-... ./client/scripts/dev.sh
#
# 推荐:加个 alias 进一步省事
#   echo "alias dev='$PWD/client/scripts/dev.sh'" >> ~/.zshrc && source ~/.zshrc
#   之后在任何目录执行 `dev` 即可
# ============================================================================

set -euo pipefail

# ---- 颜色与日志工具 --------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
header() { printf "\n${CYAN}━━━ %s ━━━${NC}\n" "$1"; }
info()   { printf "${BLUE}ℹ${NC} %s\n" "$1"; }
ok()     { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn()   { printf "${YELLOW}⚠${NC} %s\n" "$1"; }
err()    { printf "${RED}✗${NC} %s\n" "$1"; }

# ---- 定位 client/ 目录并进入 -----------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$CLIENT_DIR"
ok "工作目录: $CLIENT_DIR"

# ---- 前置检查 --------------------------------------------------------------
if ! command -v flutter >/dev/null 2>&1; then
  err "未检测到 flutter,请先安装 Flutter SDK 并加入 PATH"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  err "未检测到 python3(macOS 自带;若缺失请安装 Command Line Tools)"
  exit 1
fi

# ============================================================================
# Step 1: API 环境
# ============================================================================
if [ -n "${APP_ENV:-}" ]; then
  ENV="$APP_ENV"
  ok "API 环境(env 注入): $ENV"
else
  header "Step 1 / 3  ·  选择 API 环境"
  cat <<'EOF'
  1) dev        →  http://192.168.1.27:8005/   本地后端
  2) prod       →  https://api.tweetcaht.com/  生产环境(默认)
EOF
  read -rp "  环境 [2]: " env_choice
  env_choice=${env_choice:-2}
  case "$env_choice" in
    1) ENV="dev" ;;
    2) ENV="prod" ;;
    *) err "无效选项: $env_choice"; exit 1 ;;
  esac
fi

# ============================================================================
# Step 2: 运行模式
# ============================================================================
if [ -n "${FLUTTER_MODE:-}" ]; then
  MODE="$FLUTTER_MODE"
  ok "运行模式(env 注入): $MODE"
else
  header "Step 2 / 3  ·  选择运行模式"
  cat <<'EOF'
  1) debug      →  默认,带 hot reload,日常开发
  2) profile    →  性能分析(DevTools: CPU/内存)
EOF
  read -rp "  模式 [1]: " mode_choice
  mode_choice=${mode_choice:-1}
  case "$mode_choice" in
    1) MODE="debug" ;;
    2) MODE="profile" ;;
    *) err "无效选项: $mode_choice"; exit 1 ;;
  esac
fi

# ============================================================================
# Step 3: iOS 设备
# ============================================================================
if [ -n "${DEVICE_ID:-}" ]; then
  ok "目标设备(env 注入): $DEVICE_ID"
  DEVICE_NAME=""
else
  header "Step 3 / 3  ·  选择 iOS 设备"

  # 启动模拟器(若没启动)
  if ! pgrep -x Simulator >/dev/null 2>&1; then
    info "Simulator 未启动,正在打开..."
    open -a Simulator
    sleep 2
  fi

  # 用 flutter devices --machine 拿结构化 JSON
  # 关键字段:name / id / targetPlatform / emulator / sdk
  DEVICES_JSON=$(flutter devices --machine 2>/dev/null || echo "[]")

  # 用 python3 解析为 name\tid\tsdk 三列(只保留 ios)
  DEVICES_TSV=$(printf '%s' "$DEVICES_JSON" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = []
for d in data:
    if d.get("targetPlatform") == "ios":
        name  = (d.get("name")  or "").replace("\t", " ").replace("|", "/")
        did   = (d.get("id")    or "").replace("\t", " ").replace("|", "/")
        emu   = d.get("emulator", False)
        sdk   = (d.get("sdk")   or "").replace("\t", " ")
        kind  = "模拟器" if emu else "真机"
        print(f"{name}\t{kind}\t{sdk}\t{did}")
')

  if [ -z "$DEVICES_TSV" ]; then
    err "未找到 iOS 设备"
    info "启动模拟器: open -a Simulator"
    info "或连接真机后重新执行"
    exit 1
  fi

  # 装进 bash 数组(避开 bash 3.2 不支持的 mapfile)
  IOS_NAMES=()
  IOS_KINDS=()
  IOS_SDKS=()
  IOS_IDS=()
  while IFS=$'\t' read -r name kind sdk did; do
    [ -z "$did" ] && continue
    IOS_NAMES+=("$name")
    IOS_KINDS+=("$kind")
    IOS_SDKS+=("$sdk")
    IOS_IDS+=("$did")
  done <<< "$DEVICES_TSV"

  # 打印菜单
  for i in "${!IOS_IDS[@]}"; do
    printf "  %d) %-20s  %-6s  %-30s  [%s]\n" \
      $((i+1)) "${IOS_NAMES[$i]}" "${IOS_KINDS[$i]}" "${IOS_SDKS[$i]}" "${IOS_IDS[$i]}"
  done
  echo
  read -rp "  设备 [1]: " dev_choice
  dev_choice=${dev_choice:-1}
  if ! [[ "$dev_choice" =~ ^[0-9]+$ ]] \
     || [ "$dev_choice" -lt 1 ] \
     || [ "$dev_choice" -gt ${#IOS_IDS[@]} ]; then
    err "无效选项: $dev_choice"
    exit 1
  fi
  idx=$((dev_choice-1))
  DEVICE_ID="${IOS_IDS[$idx]}"
  DEVICE_NAME="${IOS_NAMES[$idx]}"
fi

# ============================================================================
# 汇总 + 执行
# ============================================================================
header "即将执行"
printf "  ${GREEN}flutter run -d \"%s\" --%s --dart-define=APP_ENV=%s${NC}\n\n" \
  "$DEVICE_ID" "$MODE" "$ENV"
[ -n "${DEVICE_NAME:-}" ] && info "目标设备: $DEVICE_NAME"
info "API 环境: $ENV"
info "运行模式: $MODE"
echo
read -rp "  按 Enter 启动,Ctrl+C 取消: _"

# 用 exec 替换当前 shell,这样 Ctrl+C 直接杀 flutter,不会留下 wrapper
exec flutter run -d "$DEVICE_ID" --"$MODE" --dart-define=APP_ENV="$ENV"
