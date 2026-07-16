## ADDED Requirements

### Requirement: 写文字入口从底部"+"按钮 Popup 菜单进入
The system SHALL 在用户点击底部导航栏中间"+"按钮时,弹出 Popup 菜单(从下往上滑出);Popup 菜单 SHALL 至少包含「写文字」「普通图文」两个选项;点击「写文字」SHALL 进入写文字页面;点击「普通图文」SHALL 进入现有 `ComposePost` 页面。

#### Scenario: 点击"+"弹出菜单
- **WHEN** 用户点击底部导航栏中间"+"按钮
- **THEN** 系统从屏幕底部向上滑出 Popup 菜单,菜单内显示「写文字」和「普通图文」两个选项

#### Scenario: 在 Popup 中选择"写文字"
- **WHEN** 用户在 Popup 菜单中点击「写文字」
- **THEN** Popup 关闭,系统 push 写文字页面,用户可输入文字内容

#### Scenario: 在 Popup 中选择"普通图文"
- **WHEN** 用户在 Popup 菜单中点击「普通图文」
- **THEN** Popup 关闭,系统切换到现有 `ComposePost` 页面,行为与改动前一致

### Requirement: 写文字页面支持实时预览渐变文字卡片
The system SHALL 在写文字页面提供 3:4 比例的卡片预览;卡片 SHALL 始终居中显示用户当前输入的文字内容;用户键入文字时,卡片预览 SHALL 实时更新(无明显延迟)。

#### Scenario: 输入文字时卡片实时更新
- **WHEN** 用户在写文字页面的输入框中键入字符
- **THEN** 上方卡片预览在 200ms 内更新显示该字符

#### Scenario: 支持换行
- **WHEN** 用户在输入框中按下回车键
- **THEN** 卡片预览在对应位置插入换行,文字按多行布局渲染

#### Scenario: 空内容状态
- **WHEN** 用户未输入任何文字(内容为空)
- **THEN** 卡片预览显示占位提示文字(灰色)

### Requirement: 写文字页面提供 4 套预设渐变卡片样式
The system SHALL 在写文字页面提供至少 4 套渐变样式供用户选择;每套样式 SHALL 由纯 Flutter 代码绘制(`Container` + `BoxDecoration` + `LinearGradient`),不需要任何图片素材;选中样式 SHALL 在选择器中有视觉高亮(边框或缩放)。

#### Scenario: 默认选中第一套样式
- **WHEN** 用户进入写文字页面
- **THEN** 默认选中第一套渐变样式,卡片预览使用该样式渲染

#### Scenario: 切换样式
- **WHEN** 用户在样式选择器中点击其他样式的缩略图
- **THEN** 卡片预览切换为该样式,该缩略图显示选中状态(边框高亮)

### Requirement: 卡片字号自适应
The system SHALL 根据用户输入文字的字数自动调整卡片内文字的字号;字数 ≤ 40 时 SHALL 使用 24sp;字数 41~80 时 SHALL 使用 18sp;字数 > 80 时 SHALL 使用 16sp 并截断文字(末尾显示省略号)。

#### Scenario: 短文本字号
- **WHEN** 用户输入 ≤ 40 个字符
- **THEN** 卡片文字字号为 24sp

#### Scenario: 中等长度字号
- **WHEN** 用户输入 41~80 个字符
- **THEN** 卡片文字字号为 18sp

#### Scenario: 超长文本截断
- **WHEN** 用户输入 > 80 个字符
- **THEN** 卡片文字字号为 16sp,且文字截断到前 80 个字符 + 省略号

### Requirement: 卡片不带作者水印
The system SHALL 不在卡片上渲染作者头像、昵称、用户名等任何作者信息的水印;卡片 SHALL 仅展示纯文字。

#### Scenario: 卡片内容检查
- **WHEN** 用户渲染文字卡片(预览或截图)
- **THEN** 卡片内不包含任何头像 / 昵称 / 用户名等水印元素

### Requirement: 写文字页面通过复用 createPost 完成发布
The system SHALL 在用户点击「发布」按钮时,通过现有 `PostService.createPost` 接口完成发布;客户端 SHALL 先用 `ScreenshotController` 截取卡片 Widget 为 PNG,然后通过 `UploadService.uploadMedia` 上传拿到远端 URL,最后调用 `createPost` 提交,`content` 为用户输入的文字内容,`media_urls` 为卡片图片 URL,`media_types` 为 `[1]`。

#### Scenario: 发布成功
- **WHEN** 用户输入文字、选择卡片样式、点击「发布」,且所有网络请求成功
- **THEN** 系统显示「发布成功」提示,关闭写文字页面,新帖出现在 Feed 流顶部

#### Scenario: 发布失败提示
- **WHEN** 用户点击「发布」且任一网络请求失败(上传图片失败 / createPost 失败)
- **THEN** 系统显示「发布失败」提示,写文字页面保持打开,允许用户重试

### Requirement: 写文字页面支持把卡片保存到相册
The system SHALL 在写文字页面提供「保存到相册」入口;用户点击后 SHALL 把当前渲染的卡片(与预览一致)保存到 iOS 相册。

#### Scenario: 保存到相册成功
- **WHEN** 用户点击「保存到相册」且 iOS 授权通过
- **THEN** 卡片 PNG 写入 iOS 相册,系统显示「已保存到相册」提示

#### Scenario: 保存到相册失败
- **WHEN** 用户点击「保存到相册」且截图 / 写入相册失败
- **THEN** 系统显示「保存失败」提示,写文字页面保持打开

### Requirement: 写文字页面支持无内容时禁用发布
The system SHALL 在用户输入内容为空时禁用「发布」按钮;启用 SHALL 等到用户输入至少 1 个字符。

#### Scenario: 空内容时按钮禁用
- **WHEN** 用户未输入任何文字
- **THEN** 「发布」按钮显示为禁用状态(灰色),点击无响应

#### Scenario: 输入内容后按钮启用
- **WHEN** 用户在输入框中输入至少 1 个字符
- **THEN** 「发布」按钮变为可用状态

### Requirement: 写文字页面文案全 i18n 化
The system SHALL 所有用户可见字符串(AppBar 标题、菜单项、按钮文案、占位提示)均通过 `AppLocalizations` 读取;`app_zh.arb` 和 `app_en.arb` SHALL 同步更新所有新增 key。

#### Scenario: 中文环境显示中文
- **WHEN** 用户系统语言为简体中文
- **THEN** 写文字页面的所有文案显示为简体中文

#### Scenario: 英文环境显示英文
- **WHEN** 用户系统语言为英文
- **THEN** 写文字页面的所有文案显示为英文

### Requirement: 写文字页面支持关闭确认
The system SHALL 在用户输入了内容但未发布时,通过 AppBar 的关闭按钮(或系统返回手势)尝试关闭页面,先弹出「确认丢弃当前内容?」对话框,用户确认后才关闭。

#### Scenario: 空内容时关闭
- **WHEN** 用户未输入任何文字并尝试关闭页面
- **THEN** 直接关闭页面,不弹确认对话框

#### Scenario: 有内容时确认
- **WHEN** 用户输入了文字并尝试关闭页面
- **THEN** 弹出「确认丢弃当前内容?」对话框,用户点击「丢弃」才关闭,点击「取消」保持页面

### Requirement: 写文字页面仅维护 iOS
The system SHALL 不为 Android 写任何适配代码;`AndroidManifest.xml`、`android/app/src/main/` 等 Android 原生层 SHALL 不动。

#### Scenario: 代码范围
- **WHEN** 审查写文字功能的所有源码改动
- **THEN** 不包含 Android 平台特定的代码、配置或资源