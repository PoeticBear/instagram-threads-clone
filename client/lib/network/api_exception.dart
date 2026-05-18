class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException({
    required super.message,
    super.statusCode,
    super.data,
  });
}

class AuthException extends ApiException {
  AuthException({
    required super.message,
    super.statusCode,
    super.data,
  });
}

class ValidationException extends ApiException {
  ValidationException({
    required super.message,
    super.statusCode,
    super.data,
  });
}

class ServerException extends ApiException {
  ServerException({
    required super.message,
    super.statusCode,
    super.data,
  });
}