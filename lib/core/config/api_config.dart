import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _envMapsProxy = String.fromEnvironment('GOOGLE_MAPS_PROXY_URL');
  static const String _envGeminiProxy = String.fromEnvironment('GEMINI_PROXY_URL');

  /// Resolves the base URL for the backend proxy API.
  /// 1. Prioritizes explicit build-time --dart-define (GOOGLE_MAPS_PROXY_URL / GEMINI_PROXY_URL).
  /// 2. In a production browser environment (e.g. Vercel, Firebase hosting),
  ///    defaults to the current origin (e.g. https://travel-buddy-iota-gold.vercel.app).
  /// 3. In local development or native apps, defaults to http://localhost:8080.
  static String get proxyBaseUrl {
    if (_envMapsProxy.isNotEmpty) return _envMapsProxy;
    if (_envGeminiProxy.isNotEmpty) return _envGeminiProxy;

    if (kIsWeb) {
      final baseUri = Uri.base;
      if (baseUri.hasScheme &&
          baseUri.host.isNotEmpty &&
          baseUri.host != 'localhost' &&
          baseUri.host != '127.0.0.1') {
        return baseUri.origin;
      }
    }

    return 'http://localhost:8080';
  }
}
