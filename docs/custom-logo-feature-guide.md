这份技术指导文档可以直接复制并发送给你的 Flutter/iOS 研发团队。它包含了从原生配置到 Flutter 层调用的完整生命周期。

---

## 研发操作指南：Flutter (iOS) 动态切换应用图标功能实现

**功能目标**：允许用户在 App 内的主动操作下，从预设的若干个应用图标中进行动态切换（不包含自定义上传图片）。
**适用平台**：iOS 10.3+ (依赖系统 API `setAlternateIconName`)

### 一、 资源准备阶段 (UI/设计团队配合)

备选图标不能通过普通的 `Assets.xcassets` 进行管理，必须作为单独的文件引入。

1. **尺寸要求**：为每个备选图标准备标准尺寸。通常建议至少提供 `@2x` (120x120px) 和 `@3x` (180x180px) 两种分辨率。
2. **命名规范**：避免使用中文或特殊字符。例如，深色模式图标命名为 `icon_dark@2x.png` 和 `icon_dark@3x.png`。
3. **圆角说明**：iOS 系统会自动为应用图标裁剪圆角，**提供的图片必须是直角**，不能自带透明圆角。

---

### 二、 iOS 原生工程配置阶段 (Xcode 操作)

#### 1. 引入图标文件

* 打开 Xcode，右键点击 `Runner` 目录 -> 选择 `Add Files to "Runner"...`。
* 选中准备好的备选图标文件（不需要选中整个文件夹，直接选中图片）。
* **关键勾选**：确保在弹出窗口中勾选了 `Copy items if needed`，并且在下方的 `Add to targets` 中勾选了 `Runner`。

#### 2. 修改 `Info.plist`

系统需要预先知道有哪些备选图标。打开 `ios/Runner/Info.plist`，在 `<dict>` 标签内插入以下配置。

> **注意**：`<key>` 标签中的名称（如 `IconDark`）就是后续在 Flutter 侧需要传递的参数。`<string>` 标签中的名称必须是文件的实际前缀（不包含 `@2x` 和后缀 `.png`）。

```xml
<key>CFBundleIcons</key>
<dict>
    <key>CFBundleAlternateIcons</key>
    <dict>
        <key>IconDark</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>icon_dark</string> </array>
            <key>UIPrerenderedIcon</key>
            <false/>
        </dict>
        
        <key>IconHoliday</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>icon_holiday</string>
            </array>
            <key>UIPrerenderedIcon</key>
            <false/>
        </dict>
    </dict>
    
    <key>CFBundlePrimaryIcon</key>
    <dict>
        <key>CFBundleIconFiles</key>
        <array>
            <string>AppIcon</string>
        </array>
    </dict>
</dict>

<key>CFBundleIcons~ipad</key>
<dict>
    <key>CFBundleAlternateIcons</key>
    <dict>
        <key>IconDark</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>icon_dark</string>
            </array>
            <key>UIPrerenderedIcon</key>
            <false/>
        </dict>
        <key>IconHoliday</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>icon_holiday</string>
            </array>
            <key>UIPrerenderedIcon</key>
            <false/>
        </dict>
    </dict>
    <key>CFBundlePrimaryIcon</key>
    <dict>
        <key>CFBundleIconFiles</key>
        <array>
            <string>AppIcon</string>
        </array>
    </dict>
</dict>

```

---

### 三、 Flutter 业务逻辑接入阶段

建议使用目前维护状态较好的社区插件，例如 `flutter_dynamic_icon_plus`。

#### 1. 引入依赖

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter_dynamic_icon_plus: ^latest_version # 请替换为 pub.dev 上的最新版本

```

#### 2. 核心调用逻辑封装

在项目中创建一个工具类，专门处理图标切换逻辑，方便跨组件调用。

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

class AppIconManager {
  /// 切换应用图标
  /// [iconName] 对应 Info.plist 中的 key 值，例如 'IconDark'。传 null 恢复默认图标。
  static Future<bool> changeIcon(String? iconName) async {
    // 仅 iOS 支持此方案
    if (!Platform.isIOS) {
      return false;
    }

    try {
      // 1. 检查设备当前系统版本是否支持动态替换
      bool supports = await FlutterDynamicIconPlus.supportsAlternateIcons;
      if (!supports) {
        print("当前设备/系统版本不支持动态替换图标");
        return false;
      }

      // 2. 检查当前是否已经是该图标，避免重复调用
      String? currentIcon = await FlutterDynamicIconPlus.alternateIconName;
      if (currentIcon == iconName) {
        return true; 
      }

      // 3. 执行替换
      await FlutterDynamicIconPlus.setAlternateIconName(iconName);
      return true;

    } on PlatformException catch (e) {
      print("更换图标失败 (PlatformException): ${e.message}");
      return false;
    } catch (e) {
      print("更换图标失败 (Unknown): $e");
      return false;
    }
  }
}

```

---

### 四、 提审与产品限制 (必读事项)

1. **系统级弹窗**：调用 `setAlternateIconName` 成功后，iOS 系统会强制展示一个系统级 Alert 弹窗（文案类似：“你已将应用图标更改为 'XXX'”）。此弹窗为系统底层安全限制，**不可通过代码屏蔽或拦截**。
2. **App Store 审核红线**：
* **禁止静默修改**：代码中不能在后台自动判断时间、天气等因素静默更改图标，必须是在用户点击了某个具体的 UI 按钮（如“确认切换图标”）后触发。
* **图标相关性**：所有的备选图标必须体现出与本 App 品牌的关联性。


3. **Android 差异化**：Android 系统的动态换标机制（`activity-alias`）与 iOS 完全不同，且限制极多（会导致桌面快捷方式闪烁、App 重启甚至被杀后台）。本方案及插件仅在 iOS 端稳定生效。如果是跨平台项目，请在 UI 层面做好 Android 端的隐藏或功能降级处理。