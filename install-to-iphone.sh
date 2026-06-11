#!/usr/bin/env bash
# install-to-iphone.sh
# 一键安装 Threads Flutter App 到 iPhone 14 Plus 真机
#
# 用法：
#   ./install-to-iphone.sh              # Debug 模式（默认，附带 hot reload）
#   ./install-to-iphone.sh --profile    # Profile 模式（性能分析，可接 DevTools）
#   ./install-to-iphone.sh --release    # Release 模式（性能最接近线上）
#   ./install-to-iphone.sh --clean      # 先 flutter clean 再安装（解决奇怪问题时用）
#   ./install-to-iphone.sh --no-pub-get # 跳过 pub get（依赖没变时用）
#   ./install-to-iphone.sh --help       # 查看帮助
#
# 退出方式：App 启动后按 q 或 Ctrl+C 退出
# 调试快捷键（仅 Debug 模式）：r=Hot Reload, R=Hot Restart, p=网格

set -euo pipefail

# ---------- 配置 ----------
# 目标 iPhone 14 Plus：设备名「打工专用热点」
DEVICE_NAME="打工专用热点"
DEVICE_UDID="00008110-000479412ED2401E"
PUB_MIRROR="https://pub.flutter-io.cn"

# 自动定位 client 目录（脚本应放在项目根目录，与 client/ 同级）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$SCRIPT_DIR/client"

# ---------- 参数解析 ----------
# RUN_MODE: 空 = Debug；或 --profile / --release
RUN_MODE=""
DO_CLEAN=0
SKIP_PUB_GET=0
for arg in "$@"; do
  case "$arg" in
    --release|-r)   RUN_MODE="--release" ;;
    --profile|-p)   RUN_MODE="--profile" ;;
    --debug|-d)     RUN_MODE="" ;;
    --clean|-c)     DO_CLEAN=1 ;;
    --no-pub-get)   SKIP_PUB_GET=1 ;;
    --help|-h)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *) echo "未知参数: $arg（用 --help 查看用法）" >&2; exit 1 ;;
  esac
done

# ---------- 设备预检 ----------
echo "==> 检查 iPhone 连接状态..."
if ! command -v flutter >/dev/null 2>&1; then
  echo "✗ 找不到 flutter，请确认 PATH 包含 Flutter SDK" >&2
  exit 1
fi

# 注意：不能用 `flutter devices | grep -q`。
# grep -q 匹配到 UDID 后会立刻关管道，触发 SIGPIPE 把上游 flutter devices 杀掉，
# 配合 pipefail 让脚本误判设备未连接。改为先缓存到变量再匹配。
FD_OUT="$(PUB_HOSTED_URL="$PUB_MIRROR" flutter devices 2>/dev/null || true)"
if ! echo "$FD_OUT" | grep -q "$DEVICE_UDID"; then
  echo ""
  echo "✗ 未检测到 $DEVICE_NAME ($DEVICE_UDID)" >&2
  echo "" >&2
  echo "  请检查：" >&2
  echo "  1) iPhone 用数据线连接 Mac" >&2
  echo "  2) iPhone 已解锁，并在首次连接时点击「信任此电脑」" >&2
  echo "  3) iPhone 已打开「设置 → 隐私与安全 → 开发者模式」" >&2
  echo "  4) 运行 'flutter devices' 确认能看到这台设备" >&2
  exit 1
fi
echo "✓ $DEVICE_NAME 已连接"

# ---------- 准备 ----------
if [[ ! -d "$CLIENT_DIR" ]]; then
  echo "✗ 找不到 client 目录: $CLIENT_DIR" >&2
  echo "  脚本应放在项目根目录（与 client/ 同级）" >&2
  exit 1
fi
cd "$CLIENT_DIR"

if [[ $DO_CLEAN -eq 1 ]]; then
  echo "==> flutter clean..."
  flutter clean
fi

if [[ $SKIP_PUB_GET -eq 0 ]]; then
  echo "==> flutter pub get..."
  PUB_HOSTED_URL="$PUB_MIRROR" flutter pub get
fi

# ---------- 启动 ----------
# 把 --release/--profile 翻译成可读名称
case "$RUN_MODE" in
  --release) MODE_LABEL="release" ;;
  --profile) MODE_LABEL="profile" ;;
  *)         MODE_LABEL="debug" ;;
esac
echo "==> flutter run $MODE_LABEL → $DEVICE_NAME"
echo "    （App 启动后按 q 退出；仅 debug 模式支持 r=Hot Reload, R=Hot Restart, p=网格）"
echo ""
PUB_HOSTED_URL="$PUB_MIRROR" flutter run $RUN_MODE -d "$DEVICE_UDID"
