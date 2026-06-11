class ApiConfig {
  static const String baseUrl = 'http://192.168.1.27:8005/';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String contentType = 'application/json';

  static const String userAgent = 'ThreadsApp/1.0';
}