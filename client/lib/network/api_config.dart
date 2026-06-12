class ApiConfig {
  static const String baseUrl = 'https://api.tweetcaht.com/';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String contentType = 'application/json';

  static const String userAgent = 'ThreadsApp/1.0';
}