import 'dart:async';
import 'package:flutter/foundation.dart';

/// Shared helper to ensure that asynchronous operations never hang indefinitely.
/// Returns [fallback] if provided, or rethrows a descriptive [TimeoutException].
Future<T> withTimeout<T>(
  Future<T> future, {
  Duration timeout = const Duration(seconds: 4),
  T? fallback,
  String operationName = 'Operation',
}) async {
  try {
    return await future.timeout(
      timeout,
      onTimeout: () {
        debugPrint('⚠️ [Timeout] $operationName timed out after ${timeout.inSeconds}s');
        if (fallback != null) {
          return fallback;
        }
        throw TimeoutException('$operationName timed out after ${timeout.inSeconds}s');
      },
    );
  } catch (e) {
    debugPrint('⚠️ [AsyncUtils] $operationName failed: $e');
    if (fallback != null) {
      return fallback;
    }
    rethrow;
  }
}
