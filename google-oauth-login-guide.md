没问题，既然云端配置已经全部搞定，我们现在把焦点完全拉回你的代码编辑器。以下是你在 Flutter 项目中需要完成的完整工作清单，以及你和服务端同事的对接要点。

### 第一部分：客户端项目开发步骤

#### 1. 配置 iOS 专属的 URL Scheme (在 Xcode 中)

这一步是为了让用户在外部（网页或谷歌 App）授权完成后，能够顺利跳回到你的 App。

* 打开你从 Google Cloud 控制台下载的 `.plist` 文件，找到 `REVERSED_CLIENT_ID` 的值（格式类似 `com.googleusercontent.apps.12345...`）。
* 在你的 Flutter 项目中，打开 `ios/Runner/Info.plist` 文件。
* 将这个值添加到 `CFBundleURLSchemes` 中。代码结构如下：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- 在这里填入你的 REVERSED_CLIENT_ID -->
            <string>com.googleusercontent.apps.818599281759-s267l2ou3maiaa2vj9vr19d77bap3jec</string>
        </array>
    </dict>
</array>

```

#### 2. 引入 Flutter 依赖

在你的 `pubspec.yaml` 文件中添加谷歌官方的登录插件，并运行 `flutter pub get`：

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_sign_in: ^6.2.1 # 建议使用最新版本

```

#### 3. 编写 Dart 登录逻辑（核心步骤）

在你的登录页面或统一的 Auth 服务类中，编写完整的登录逻辑。这里**最重要的一点**是要把之前创建的 **Web 客户端 ID** 传进去。

```dart
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // 初始化 GoogleSignIn
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    // 务必注意：这里填的是后台创建的【Web 客户端 ID】，而不是 iOS 的客户端 ID！
    // 这能确保后端校验 token 时对得上暗号。
    serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com', 
  );

  Future<void> signInWithGoogle() async {
    try {
      // 1. 唤起底层的谷歌登录面板
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // 用户手动关闭了登录弹窗
        print("用户取消了登录");
        return;
      }

      // 2. 获取包含凭据的 Authentication 对象
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // 3. 提取需要发给服务端的凭据
      final String? idToken = googleAuth.idToken;
      final String? serverAuthCode = googleAuth.serverAuthCode; // 有时为空是正常的，取决于后端需求

      if (idToken != null) {
        // 4. 调用你们自己的接口，把 Token 发给服务端同事
        print("成功获取到 idToken: $idToken");
        await _sendToBackend(idToken, serverAuthCode);
      } else {
        print("登录失败：无法获取 idToken");
      }
    } catch (error) {
      print("谷歌登录发生错误: $error");
    }
  }

  Future<void> _sendToBackend(String idToken, String? serverAuthCode) async {
    // 在这里使用 http 或 dio 发送 POST 请求给你的后端...
  }
}

```

---

### 第二部分：你需要发送给服务端什么？

在用户成功授权后，你**绝对不要**只把用户的邮箱或名字发给后端去直接登录（这很容易被伪造）。你需要通过 API 请求发送以下安全凭证：

**1. `idToken`（必传项）**

* **这是什么：** 这是一个 JWT（JSON Web Token）字符串，包含了用户的基本信息（邮箱、头像等）以及谷歌的加密签名。
* **后端用来干嘛：** 后端收到后，会去向谷歌的服务器验证这个 Token 的真伪。验证通过后，后端才会从里面读取用户信息，在你们自己的数据库里注册或登录，最后返回给客户端你们自己系统的 Token（比如你平时用的业务 Token）。

**2. `serverAuthCode`（建议一并发送或与后端确认）**

* **这是什么：** 这是一个一次性的授权码。
* **后端用来干嘛：** 如果你们的服务端不仅仅是为了“登录”，还需要在用户离线时去访问该用户的谷歌日历、云盘等其他 Google API，服务端就需要用这个 `serverAuthCode` 去换取 `Access Token` 和 `Refresh Token`。如果不涉及这类高级操作，后端通常不需要这个码，只需校验 `idToken` 即可。

**总结一下你的工作流：**
改好 `Info.plist` -> 引入插件写好 Dart 代码获取到 `idToken` -> 把 `idToken` 塞进 HTTP 请求里发给后端 -> 接收后端返回的业务 Token 并保存 -> 登录成功跳转首页。