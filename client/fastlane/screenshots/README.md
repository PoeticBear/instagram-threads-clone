# App Store 截图

本目录存放 App Store Connect 上架用的 iPhone 6.5" 截图。

## ⚠️ 当前状态：**占位骨架**

当前 10 张 PNG 是 `generate.py` 生成的**占位图**，用于跑通 Fastlane 流水线。**真实上架前请用真实 App 截图替换**——App Store 审核员一眼能看出这是 mockup，会以"截图与实际功能不符"为由拒绝。

替换方法：直接覆盖同名文件即可，**保持文件名前缀**（`01_*` 到 `05_*`），否则需要同步更新 `Fastfile` 里的顺序。

---

## 📐 Apple 硬性要求

| 项 | 要求 |
|---|---|
| **设备** | iPhone-only 应用，**不**提交 iPad / Apple Watch 截图 |
| **数量** | 最多 10 张，最少 1 张（推荐 5–8 张） |
| **App Preview 视频** | 最多 3 个（本期不做） |
| **尺寸**（任选其一）| `1242×2688` / `2688×1242` / `1284×2778` / `2778×1284` |
| **格式** | PNG 或 JPEG，RGB 色彩空间 |
| **文件大小** | 每张 ≤ 8 MB（推荐 ≤ 2 MB） |

---

## 📁 当前目录结构

```
screenshots/
├── README.md
├── generate.py                            # 占位图生成脚本（生成完可删除）
├── en-US/
│   └── iPhone6.5/
│       ├── 01_login.png                   # 登录页
│       ├── 02_feed.png                    # 首页 Feed
│       ├── 03_compose.png                 # 发帖
│       ├── 04_notifications.png           # 通知
│       └── 05_profile.png                 # 个人主页
└── zh-Hans/
    └── iPhone6.5/
        ├── 01_login.png
        ├── 02_feed.png
        ├── 03_compose.png
        ├── 04_notifications.png
        └── 05_profile.png
```

---

## 🛠️ 如何生成真实截图

### 方案 A：iOS 模拟器截图（最简单）

```bash
# 1. 启动模拟器
open -a Simulator
# 在模拟器里打开 Tweet App，进入要截的页面

# 2. 命令行截屏（自动保存到桌面）
xcrun simctl io booted screenshot ~/Desktop/01_login.png
```

然后用 `sips` 调整到要求的尺寸：
```bash
sips -z 2688 1242 ~/Desktop/01_login.png --out client/fastlane/screenshots/en-US/iPhone6.5/01_login.png
```

### 方案 B：iPhone 真机截图

在真机上进入对应页面 → 截屏（电源 + 音量上）→ AirDrop 到 Mac → 用 `sips` 调整尺寸后归档到对应目录。

### 方案 C：用 `app-store-screenshots` skill（项目里未安装）

如果后续安装了 `app-store-screenshots` skill（Next.js 程序化生成），可用 skill 一键生成带营销文案的 mockup 截图。

---

## 🔄 替换占位图后的回归

替换完截图，跑一次 dry-run 校验：

```bash
cd client && fastlane ios upload_listing --dry_run
```

fastlane 会自动校验每张截图的尺寸是否在 Apple 允许清单内，不合规直接报错。

---

## 🗑️ 何时删除 `generate.py`

当真实截图就位后，`generate.py` 不再有用途，可删除。本目录其余文件（`README.md` + 截图子目录）**保留入 git**。
