# 主题切换功能（深色/浅色模式）技术实施方案

## 一、现状总结

| 维度 | 现状 |
|------|------|
| ThemeData | 仅 `ThemeData(brightness: Brightness.dark)`，无自定义色彩 |
| 状态管理 | 无 ThemeProvider / ThemeNotifier |
| 用户入口 | 设置页面无"外观"或"主题"选项 |
| 持久化 | SharedPreferences 无主题相关 key |
| 颜色引用 | 54 个文件中约 887 处硬编码颜色，全部读取自 `Colors.black/white/grey` 或 `Color(0xff...)` |

## 二、架构参考：LocaleProvider 模式

项目中语言切换功能已完整实现，采用以下 4 层架构，主题切换将完全复用此模式：

```
SharedPreferences (持久化)
       ↓
ThemeProvider extends ChangeNotifier (状态管理)
       ↓
MultiProvider 注册 + Consumer<ThemeProvider> 包裹 MaterialApp (响应式重建)
       ↓
Settings 页面 UI 入口 (用户交互)
```

## 三、分阶段子任务拆分

> 原则：每个阶段可独立完成、独立验证，不依赖后续阶段。

---

### 阶段 1：创建 ThemeProvider 状态管理 + MaterialApp 接入

**目标**：建立主题切换的骨架，使应用具备响应式切换 `ThemeMode` 的能力。

**涉及文件**：

| 操作 | 文件路径 |
|------|----------|
| 新建 | `lib/state/theme.state.dart` |
| 修改 | `lib/main.dart` |

**详细设计**：

**1.1 新建 `lib/state/theme.state.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = GetIt.I<SharedPreferences>();
    final saved = prefs.getString(_themeKey);
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.dark,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = GetIt.I<SharedPreferences>();
    await prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  void switchToDark() => setThemeMode(ThemeMode.dark);
  void switchToLight() => setThemeMode(ThemeMode.light);
  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
```

**1.2 修改 `lib/main.dart`**

- 注册 `ChangeNotifierProvider<ThemeProvider>` 到 `MultiProvider.providers`
- 将 `Consumer<LocaleProvider>` 扩展为同时消费 `LocaleProvider` 和 `ThemeProvider`（使用嵌套 Consumer 或 `Consumer2`）
- 在 `MaterialApp` 中设置 `theme:` (浅色)、`darkTheme:` (深色)、`themeMode:` 三个参数

```dart
// MultiProvider 中新增（在 LocaleProvider 之前或之后均可）
ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),

// MaterialApp 配置改为：
child: Consumer2<LocaleProvider, ThemeProvider>(
  builder: (context, localeProvider, themeProvider, _) {
    return MaterialApp(
      locale: localeProvider.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en'), Locale('zh')],
      theme: ThemeData(brightness: Brightness.light),   // 新增：浅色主题
      darkTheme: ThemeData(brightness: Brightness.dark), // 原有：深色主题
      themeMode: themeProvider.themeMode,                // 新增：动态切换
      title: 'Threads',
      debugShowCheckedModeBanner: false,
      home: SplashPage(),
    );
  },
),
```

**验证方式**：启动应用，通过 Flutter DevTools 或代码临时调用 `ThemeProvider.switchToLight()`，确认整个 MaterialApp 会响应 `ThemeMode` 切换（此时页面仍为黑色硬编码，但 Scaffold 等 Material 组件的默认颜色会跟随 ThemeData 变化）。

---

### 阶段 2：定义完整的 AppColors 色彩系统 + ThemeData

**目标**：建立浅色/深色两套完整的色彩定义，并生成对应的 `ThemeData`。

**涉及文件**：

| 操作 | 文件路径 |
|------|----------|
| 新建 | `lib/theme/app_colors.dart` |
| 新建 | `lib/theme/app_theme.dart` |

**详细设计**：

**2.1 新建 `lib/theme/app_colors.dart`**

定义一个 `AppColors` 类，包含所有语义化颜色字段，提供 `light` 和 `dark` 两个静态实例：

```dart
import 'package:flutter/material.dart';

class AppColors {
  // --- Surfaces ---
  final Color background;       // 页面主背景
  final Color surface;          // 卡片/输入框/弹窗背景
  final Color surfaceSecondary; // 次级表面（列表项背景等）
  final Color surfaceTertiary;  // 三级表面（工具栏等）

  // --- Dividers & Borders ---
  final Color divider;          // 主分割线
  final Color dividerSecondary; // 次级分割线
  final Color border;           // 边框/轮廓

  // --- Text ---
  final Color textPrimary;      // 主要文字
  final Color textSecondary;    // 次要文字
  final Color textMuted;        // 弱化文字（时间戳等）
  final Color textHint;         // 占位提示文字

  // --- Accents (保持不变) ---
  final Color accent;
  final Color like;
  final Color repost;
  final Color destructive;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.surfaceTertiary,
    required this.divider,
    required this.dividerSecondary,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textHint,
    required this.accent,
    required this.like,
    required this.repost,
    required this.destructive,
  });

  // 深色主题色彩（当前应用的实际配色）
  static const dark = AppColors(
    background: Colors.black,
    surface: Color(0xff1a1a1a),
    surfaceSecondary: Color(0xff222222),
    surfaceTertiary: Color(0xff292929),
    divider: Color(0xff2e2e2e),
    dividerSecondary: Color(0xff444444),
    border: Color(0xff333333),
    textPrimary: Colors.white,
    textSecondary: Colors.grey,
    textMuted: Color(0xff888888),
    textHint: Color(0xff707070),
    accent: Colors.blue,
    like: Colors.red,
    repost: Colors.green,
    destructive: Colors.red,
  );

  // 浅色主题色彩（参考 Instagram Threads 官方浅色模式）
  static const light = AppColors(
    background: Colors.white,
    surface: Color(0xffefefef),
    surfaceSecondary: Color(0xfff5f5f5),
    surfaceTertiary: Color(0xfff8f8f8),
    divider: Color(0xffefefef),
    dividerSecondary: Color(0xffd8d8d8),
    border: Color(0xffd0d0d0),
    textPrimary: Colors.black,
    textSecondary: Color(0xff666666),
    textMuted: Color(0xff999999),
    textHint: Color(0xffa0a0a0),
    accent: Color(0xff0064e0),
    like: Colors.red,
    repost: Colors.green,
    destructive: Colors.red,
  );
}
```

**2.2 新建 `lib/theme/app_theme.dart`**

利用 `AppColors` 生成浅色/深色 `ThemeData`：

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = _buildTheme(AppColors.light, Brightness.light);
  static ThemeData darkTheme = _buildTheme(AppColors.dark, Brightness.dark);

  static ThemeData _buildTheme(AppColors colors, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      dividerColor: colors.divider,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
        // 可按需覆盖更多 ColorScheme 字段
      ),
    );
  }
}
```

**2.3 更新 `main.dart` 中的 ThemeData 引用**

将阶段 1 中的简写 `ThemeData(brightness: ...)` 替换为 `AppTheme.lightTheme` / `AppTheme.darkTheme`。

**验证方式**：启动应用，确认深色模式视觉效果与改动前一致（无回归）。

---

### 阶段 3：设置页面添加主题切换 UI 入口

**目标**：在 Settings 页面添加"外观"切换选项，用户可通过点击切换深色/浅色模式。

**涉及文件**：

| 操作 | 文件路径 |
|------|----------|
| 修改 | `lib/common/settings.dart` |
| 修改 | `lib/l10n/app_en.arb` |
| 修改 | `lib/l10n/app_zh.arb` |
| 重新生成 | `flutter gen-l10n` |

**详细设计**：

**3.1 在 settings.dart 中语言切换行上方新增主题切换行**

复用语言切换的 `Row + Icon + Text + Consumer<ThemeProvider>` 模式：

```dart
// 主题切换行（放在语言切换行上方）
Row(
  mainAxisAlignment: MainAxisAlignment.start,
  children: [
    const SizedBox(width: 20),
    const Icon(CupertinoIcons.moon, size: 30),  // 或 brightness_solid
    const SizedBox(width: 20),
    Expanded(
      child: Text(
        l10n.appearance,  // "外观" / "Appearance"
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: themeColors.textPrimary),
      ),
    ),
    Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return GestureDetector(
          onTap: () => themeProvider.toggleTheme(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.dark.surface, // 阶段 4 时替换为动态颜色
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              themeProvider.themeMode == ThemeMode.dark ? 'Dark' : 'Light',
              style: TextStyle(color: AppColors.dark.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        );
      },
    ),
    const SizedBox(width: 20),
  ],
),
```

**3.2 国际化字符串**

在 `app_en.arb` 和 `app_zh.arb` 中添加：
```json
// app_en.arb
"appearance": "Appearance"

// app_zh.arb
"appearance": "外观"
```

**验证方式**：启动应用 → 进入设置页面 → 点击 "Appearance / 外观" 行 → 确认 ThemeProvider 状态切换并持久化到 SharedPreferences。此时页面颜色仍是硬编码的黑色，但通过 DevTools 可验证 ThemeMode 确实切换了。

---

### 阶段 4：逐步替换硬编码颜色 — 核心页面（骨架页面）

**目标**：将应用骨架（导航框架、主要 Tab 页面）的硬编码颜色替换为从 `Theme.of(context)` 或 `AppColors` 读取，使主题切换时骨架能正确响应。

**涉及文件**（按优先级排序）：

| 文件 | 说明 |
|------|------|
| `lib/pages/home.dart` | 底部导航栏（自定义 Container） |
| `lib/pages/feed/feed.dart` | Feed Tab |
| `lib/pages/search/search.dart` | 搜索 Tab |
| `lib/pages/notification/notification.dart` | 通知 Tab |
| `lib/pages/message/message_page.dart` | 消息 Tab |
| `lib/pages/profile/myprofile.dart` | 我的资料 Tab |
| `lib/common/splash.dart` | 启动页 |
| `lib/common/settings.dart` | 设置主页 |

**替换规则**：

| 原硬编码值 | 替换为 |
|-----------|--------|
| `Colors.black` (作为背景) | `Theme.of(context).scaffoldBackgroundColor` |
| `Colors.white` (作为文字) | `Theme.of(context).colorScheme.onSurface` |
| `Color(0xff1a1a1a)` | 需通过 `ThemeExtension` 或辅助方法获取 `surface` 颜色 |
| `Colors.grey` | `Theme.of(context).colorScheme.onSurfaceVariant` |
| `Color(0xff2e2e2e)` / `Color.fromARGB(255,46,46,46)` (分割线) | `Theme.of(context).dividerColor` |

**引入 ThemeExtension 的方式**：

为了让非标准颜色（如 `surface`、`textMuted` 等）能通过 `Theme.of(context)` 访问，在 `app_theme.dart` 中注册一个 `ThemeExtension`：

```dart
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final AppColors colors;
  AppColorsExtension(this.colors);

  @override
  AppColorsExtension copyWith([AppColors? colors]) =>
      AppColorsExtension(colors ?? this.colors);

  @override
  AppColorsExtension lerp(AppColorsExtension other, double t) =>
      AppColorsExtension(t < 0.5 ? colors : other.colors);
}
```

在 `AppTheme._buildTheme()` 中注册：
```dart
extensions: [AppColorsExtension(colors)],
```

使用方式：
```dart
final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
// 然后使用 appColors.surface, appColors.textPrimary 等
```

**验证方式**：启动应用 → 切换主题 → 确认首页、底部导航栏、各 Tab 页面的背景和文字颜色正确跟随切换。

---

### 阶段 5：替换硬编码颜色 — 子页面和设置子页面

**目标**：将深层页面（帖子详情、个人资料详情、设置子页面等）的硬编码颜色替换。

**涉及文件**：

| 文件 | 说明 |
|------|------|
| `lib/pages/profile/profile.dart` | 他人资料页 |
| `lib/pages/profile/edit.dart` | 编辑资料页 |
| `lib/pages/post/post_detail_page.dart` | 帖子详情页 |
| `lib/pages/post/reply_review_page.dart` | 回复审核页 |
| `lib/pages/post/guest_reply_review_page.dart` | 访客回复审核页 |
| `lib/pages/post/scheduled_posts_page.dart` | 定时帖子页 |
| `lib/pages/composePost/post.dart` | 发帖页 |
| `lib/common/settings/notification_settings.dart` | 通知设置 |
| `lib/common/settings/privacy_settings.dart` | 隐私设置 |
| `lib/common/settings/hidden_words_page.dart` | 隐藏词汇 |
| `lib/common/settings/collections_page.dart` | 收藏集 |
| `lib/common/settings/links_page.dart` | 链接管理 |
| `lib/common/settings/relation_control_page.dart` | 关系管理 |

**替换规则**：同阶段 4。

**验证方式**：逐页面导航 → 切换主题 → 确认各子页面颜色正确。

---

### 阶段 6：替换硬编码颜色 — 通用组件和认证页面

**目标**：完成剩余所有文件的颜色替换，实现 100% 主题适配。

**涉及文件**：

| 文件 | 说明 |
|------|------|
| `lib/widget/feedpost.dart` | 帖子卡片组件（使用量最大的组件） |
| `lib/widget/reply_bottom_sheet.dart` | 回复底部弹窗 |
| `lib/widget/poll_widget.dart` | 投票组件 |
| `lib/widget/search_post_tile.dart` | 搜索帖子瓦片 |
| `lib/widget/topic_tile.dart` | 话题标签 |
| `lib/widget/edit_history_sheet.dart` | 编辑历史弹窗 |
| `lib/widget/draft_list_sheet.dart` | 草稿列表弹窗 |
| `lib/widget/chat_bubble.dart` | 聊天气泡 |
| `lib/widget/reaction_picker.dart` | 表情选择器 |
| `lib/widget/custom/title_text.dart` | 通用文本组件（修复 color 参数被忽略的 bug） |
| `lib/auth/signup/*.dart` | 注册流程所有页面 |
| `lib/pages/search/*.dart` | 搜索相关页面 |
| `lib/pages/activity/*.dart` | 活动相关页面 |
| 其他所有含硬编码颜色的文件 | 完整覆盖 |

**验证方式**：全面回归测试，在深色和浅色模式下逐页面验证视觉效果。

---

## 四、各阶段依赖关系

```
阶段 1 (ThemeProvider + MaterialApp 接入)
  ↓
阶段 2 (AppColors 色彩系统 + ThemeData)
  ↓
阶段 3 (Settings UI 入口)
  ↓
阶段 4 (骨架页面颜色替换)  ← 从此阶段开始产生用户可见效果
  ↓
阶段 5 (子页面颜色替换)
  ↓
阶段 6 (通用组件 + 认证页面颜色替换)  ← 100% 完成
```

阶段 1-3 为基础设施建设，阶段 4-6 为渐进式颜色替换。每个阶段完成后应用都可正常编译运行，不会破坏已有功能。

## 五、关键风险与注意事项

1. **CupertinoThemeData**：`lib/pages/profile/edit.dart` 和 `lib/auth/signup/signup.dart` 中有硬编码的 `CupertinoThemeData(brightness: Brightness.dark)`，需根据当前 ThemeMode 动态设置 brightness。
2. **TitleText 组件 bug**：`lib/widget/custom/title_text.dart` 的 `color` 参数被忽略，始终使用 `Colors.white`，需一并修复。
3. **颜色映射精度**：浅色模式的色彩值需要实际在设备上调试确认，建议在阶段 4 完成后进行一次视觉走查。
4. **Consumer2 性能**：`Consumer2<LocaleProvider, ThemeProvider>` 在每次 locale 或 theme 变化时都会重建 MaterialApp，这与当前 `Consumer<LocaleProvider>` 的行为一致，不会引入额外开销。
