/// Unified application exception hierarchy for Travel Buddy.
/// Designed for clean, predictable error handling without uncaught crashes.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

class NetworkException extends AppException {
  const NetworkException([
    super.message =
        'Network connection unavailable. Please check your internet.',
    String? code = 'NETWORK_ERROR',
  ]) : super(code: code);
}

class ApiException extends AppException {
  final int? statusCode;
  const ApiException(
    super.message, {
    super.code = 'API_ERROR',
    this.statusCode,
    super.details,
  });
}

class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    super.code = 'VALIDATION_ERROR',
    super.details,
  });
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code = 'NOT_FOUND'});
}

class RateLimitException extends AppException {
  const RateLimitException([
    super.message = 'Rate limit exceeded. Please wait a moment and try again.',
    String? code = 'RATE_LIMIT',
  ]) : super(code: code);
}

class ParsingException extends AppException {
  const ParsingException(
    super.message, {
    super.code = 'PARSE_ERROR',
    super.details,
  });
}

class UnknownException extends AppException {
  const UnknownException([
    super.message = 'An unexpected error occurred.',
    String? code = 'UNKNOWN_ERROR',
    dynamic details,
  ]) : super(code: code, details: details);
}
