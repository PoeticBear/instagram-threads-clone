class ApiConfig {
  // 环境 URL 常量
  static const String _prodBaseUrl = 'https://api.tweetcaht.com/';
  static const String _devBaseUrl = 'http://192.168.1.27:8005/';

  // 编译期环境变量，默认 prod
  // 通过 --dart-define=APP_ENV=dev 切换到开发环境
  static const String _appEnv =
      String.fromEnvironment('APP_ENV', defaultValue: 'prod');

  // 运行时 baseUrl（编译期常量，无运行时开销）
  static const String baseUrl =
      _appEnv == 'dev' ? _devBaseUrl : _prodBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String contentType = 'application/json';

  static const String userAgent = 'TweetApp/1.0';

  /// 当前环境（仅供日志/调试使用，运行时不要再变更）
  static const String environment = _appEnv;
}
