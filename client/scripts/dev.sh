#!/usr/bin/env bash
# ============================================================================
# dev.sh — Instagram Threads Clone 一键调试入口
# ----------------------------------------------------------------------------
# 单一交互菜单:env(2) × mode(2) × device(N) = 2N 个组合,选中即启动,无二次确认。
#
# 维度:
#   1) API 环境  (dev / prod)
#   2) 运行模式  (debug / profile)
#   3) iOS 设备  (动态枚举 flutter devices --machine 的 iOS 项)
#
# 用法:
#   # 从项目根目录执行
#   ./client/scripts/dev.sh
#
#   # 也可从 client/ 目录执行
#   bash scripts/dev.sh
#
#   # CI / 完全无交互:三个变量必须同时设置(避免部分注入造成歧义)
#   APP_ENV=dev FLUTTER_MODE=debug DEVICE_ID=<UUID> ./client/scripts/dev.sh
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
# 检测 iOS 设备
# ----------------------------------------------------------------------------
# 无论走 env-var 还是交互菜单,都先枚举一遍:env-var 模式用它回查 kind
# (用于 profile+模拟器的兼容性回退判断);交互模式用它生成菜单。
# ============================================================================

# 没注入 DEVICE_ID 时,顺手把模拟器 App 唤起(确保能被 flutter devices 看到)
if [ -z "${DEVICE_ID:-}" ]; then
  if ! pgrep -x Simulator >/dev/null 2>&1; then
    info "Simulator 未启动,正在打开..."
    open -a Simulator
    sleep 2
  fi
fi

DEVICES_JSON=$(flutter devices --machine 2>/dev/null || echo "[]")

# 用 python3 解析为 name\tkind\tsdk\tdid 四列(只保留 ios)
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

# ============================================================================
# 决定 ENV / MODE / DEVICE_ID
# ----------------------------------------------------------------------------
# 三种模式:
#   a) 三个 env-var 全注入 → 完全跳过菜单(CI / 自动化)
#   b) 部分注入           → 报错(避免歧义:要么全免交互,要么走菜单)
#   c) 全未注入           → 单一 2N 选项菜单,选完即 exec,不再二次确认
# ============================================================================
HAS_ENV="${APP_ENV:+1}"
HAS_MODE="${FLUTTER_MODE:+1}"
HAS_DEV="${DEVICE_ID:+1}"
HAS_ANY=$((HAS_ENV + HAS_MODE + HAS_DEV))

if [ "$HAS_ANY" -eq 3 ]; then
  ENV="$APP_ENV"
  MODE="$FLUTTER_MODE"
  # 回查 kind(给兼容性检查用),找不到就留空
  DEVICE_KIND=""
  for i in "${!IOS_IDS[@]}"; do
    if [ "${IOS_IDS[$i]}" = "$DEVICE_ID" ]; then
      DEVICE_KIND="${IOS_KINDS[$i]}"
      DEVICE_NAME="${IOS_NAMES[$i]}"
      break
    fi
  done
  ok "env 注入: ENV=$ENV  MODE=$MODE  DEVICE=$DEVICE_ID  KIND=${DEVICE_KIND:-?}"
elif [ "$HAS_ANY" -gt 0 ]; then
  err "env-var 快捷入口要求 APP_ENV / FLUTTER_MODE / DEVICE_ID 三个变量同时设置"
  err "否则请使用交互菜单(不要设置任何 env-var)"
  exit 1
else
  if [ "${#IOS_IDS[@]}" -eq 0 ]; then
    err "未找到 iOS 设备"
    info "启动模拟器: open -a Simulator"
    info "或连接真机后重新执行"
    exit 1
  fi

  ENV_OPTS=("dev" "prod")
  MODE_OPTS=("debug" "profile")

  header "选择运行配置(env × mode × device,共 $(( ${#ENV_OPTS[@]} * ${#MODE_OPTS[@]} * ${#IOS_IDS[@]} )) 项)"

  # 拼装所有 2×2×N 组合,顺序:env 外层 → mode 中层 → device 内层
  COMBO_ENVS=()
  COMBO_MODES=()
  COMBO_IDS=()
  COMBO_NAMES=()
  COMBO_KINDS=()
  for env in "${ENV_OPTS[@]}"; do
    for mode in "${MODE_OPTS[@]}"; do
      for i in "${!IOS_IDS[@]}"; do
        COMBO_ENVS+=("$env")
        COMBO_MODES+=("$mode")
        COMBO_IDS+=("${IOS_IDS[$i]}")
        COMBO_NAMES+=("${IOS_NAMES[$i]}")
        COMBO_KINDS+=("${IOS_KINDS[$i]}")
      done
    done
  done

  TOTAL=${#COMBO_IDS[@]}

  # 打印菜单(列头单独上色,与数据行区分)
  printf "  ${CYAN}%-4s  %-6s  %-7s  %-22s  %-6s  %s${NC}\n" "#" "ENV" "MODE" "DEVICE" "KIND" "ID"
  printf "  %s\n" "------------------------------------------------------------------------------------"
  for i in "${!COMBO_IDS[@]}"; do
    printf "  %2d) %-6s  %-7s  %-22s  %-6s  %s\n" \
      $((i+1)) "${COMBO_ENVS[$i]}" "${COMBO_MODES[$i]}" \
      "${COMBO_NAMES[$i]}" "${COMBO_KINDS[$i]}" "${COMBO_IDS[$i]}"
  done
  echo

  read -rp "  配置 [1]: " combo_choice
  combo_choice=${combo_choice:-1}
  if ! [[ "$combo_choice" =~ ^[0-9]+$ ]] \
     || [ "$combo_choice" -lt 1 ] \
     || [ "$combo_choice" -gt $TOTAL ]; then
    err "无效选项: $combo_choice"
    exit 1
  fi
  idx=$((combo_choice-1))
  ENV="${COMBO_ENVS[$idx]}"
  MODE="${COMBO_MODES[$idx]}"
  DEVICE_ID="${COMBO_IDS[$idx]}"
  DEVICE_NAME="${COMBO_NAMES[$idx]}"
  DEVICE_KIND="${COMBO_KINDS[$idx]}"
fi

# ============================================================================
# 兼容性校验:profile 模式不支持 iOS 模拟器(Flutter 限制)
# ============================================================================
if [ "$MODE" = "profile" ] && [ "${DEVICE_KIND:-}" = "模拟器" ]; then
  warn "Profile 模式不支持 iOS 模拟器(Flutter 限制,仅真机支持)"
  warn "自动回退到 debug 模式"
  echo
  MODE="debug"
fi

# ============================================================================
# 汇总 + 执行(无二次确认)
# ============================================================================
header "即将执行"
printf "  ${GREEN}flutter run -d \"%s\" --%s --dart-define=APP_ENV=%s${NC}\n\n" \
  "$DEVICE_ID" "$MODE" "$ENV"
[ -n "${DEVICE_NAME:-}" ] && info "目标设备: $DEVICE_NAME"
info "API 环境: $ENV"
info "运行模式: $MODE"

# 用 exec 替换当前 shell,这样 Ctrl+C 直接杀 flutter,不会留下 wrapper
exec flutter run -d "$DEVICE_ID" --"$MODE" --dart-define=APP_ENV="$ENV"
