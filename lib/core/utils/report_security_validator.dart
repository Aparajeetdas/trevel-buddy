import 'dart:math';
import 'dart:typed_data';

import '../models/app_models.dart';

class PriceValidationResult {
  final bool isValid;
  final String? errorMessage;

  const PriceValidationResult({required this.isValid, this.errorMessage});
}

/// Security, validation, anti-poisoning, and privacy utilities for community reports
class ReportSecurityValidator {
  ReportSecurityValidator._();

  // Price Sanity Limits per Service Type
  static final Map<ServiceType, ({double min, double max})> priceSanityRanges = {
    ServiceType.auto: (min: 10.0, max: 5000.0),
    ServiceType.taxi: (min: 30.0, max: 20000.0),
    ServiceType.bikeTaxi: (min: 10.0, max: 2000.0),
    ServiceType.guide: (min: 100.0, max: 15000.0),
    ServiceType.meal: (min: 20.0, max: 10000.0),
    ServiceType.room: (min: 200.0, max: 50000.0),
    ServiceType.entryTicket: (min: 10.0, max: 10000.0),
    ServiceType.other: (min: 10.0, max: 50000.0),
  };

  /// Validates that a quoted or reported price is within realistic bounds for the service type
  static PriceValidationResult validatePriceSanity(ServiceType type, double price) {
    if (price.isNaN || price.isInfinite || price <= 0) {
      return const PriceValidationResult(
        isValid: false,
        errorMessage: 'Price must be a valid positive number.',
      );
    }

    final range = priceSanityRanges[type] ?? (min: 10.0, max: 50000.0);
    if (price < range.min) {
      return PriceValidationResult(
        isValid: false,
        errorMessage: 'Price cannot be lower than ₹${range.min.toStringAsFixed(0)} for ${type.displayName}.',
      );
    }
    if (price > range.max) {
      return PriceValidationResult(
        isValid: false,
        errorMessage: 'Price cannot exceed realistic ceiling of ₹${range.max.toStringAsFixed(0)} for ${type.displayName}.',
      );
    }

    return const PriceValidationResult(isValid: true);
  }

  static final RegExp _urlRegex = RegExp(
    r'(?:https?:\/\/|www\.)[^\s]+',
    caseSensitive: false,
  );

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _phoneRegex = RegExp(
    r'(?:\+?91[\s-]?)?[6-9]\d{9}|\b\d{10}\b|\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b',
  );

  static final RegExp _controlCharsRegex = RegExp(r'[\x00-\x1F\x7F]');

  /// Sanitizes user-submitted text by stripping URLs, redacting phone numbers & emails,
  /// stripping control characters, and capping string length.
  static String sanitizeReportText(String? input, {int maxLength = 500}) {
    if (input == null || input.isEmpty) return '';

    // 1. Strip control characters
    String cleaned = input.replaceAll(_controlCharsRegex, ' ');

    // 2. Strip URLs (no external links allowed in reports)
    cleaned = cleaned.replaceAll(_urlRegex, '[LINK_REMOVED]');

    // 3. Redact Email addresses
    cleaned = cleaned.replaceAll(_emailRegex, '[EMAIL_REDACTED]');

    // 4. Redact Phone numbers (protect driver and traveller privacy)
    cleaned = cleaned.replaceAll(_phoneRegex, '[PHONE_REDACTED]');

    // 5. Trim and clamp length
    cleaned = cleaned.trim();
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }

    return cleaned;
  }

  /// Obfuscates precise GPS coordinates to ~100m resolution (~0.001 deg) for privacy
  static double? roundCoordinate(double? coord, {int decimals = 3}) {
    if (coord == null || coord.isNaN) return null;
    final factor = pow(10, decimals).toDouble();
    return (coord * factor).round() / factor;
  }

  /// Verifies latitude is in [-90, 90] and longitude is in [-180, 180]
  static bool areCoordinatesValid(double? lat, double? lng) {
    if (lat == null || lng == null) return true; // Optional fields
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  /// Enforces a maximum of 20 reports per user per day
  static bool checkDailyRateLimit(String userId, List<PriceReport> allReports) {
    final now = DateTime.now();
    final todayReportsCount = allReports.where((r) {
      if (r.userId != userId) return false;
      return now.difference(r.timestamp).inHours < 24;
    }).length;

    return todayReportsCount < 20;
  }

  /// Detects rapid duplicate submissions (same user, same route or place, within 10 minutes)
  static bool isDuplicateReport(PriceReport newReport, List<PriceReport> existingReports) {
    final now = newReport.timestamp;
    final normalizedRoute = newReport.routeOrPlace.trim().toLowerCase();

    return existingReports.any((r) {
      if (r.userId != null && newReport.userId != null && r.userId != newReport.userId) {
        return false;
      }
      final diffSeconds = now.difference(r.timestamp).inSeconds.abs();
      if (diffSeconds > 600) return false; // More than 10 minutes apart

      final existingRoute = r.routeOrPlace.trim().toLowerCase();
      return existingRoute == normalizedRoute ||
          (existingRoute.isNotEmpty && normalizedRoute.contains(existingRoute));
    });
  }

  /// Calculates report weight:
  /// - Brand-new anonymous account (< 3 historical reports): 0.5
  /// - Consistent contributor (>= 3 prior reports): 1.0
  static double calculateUserWeight(String userId, List<PriceReport> historicalReports) {
    final priorValidCount = historicalReports.where((r) => r.userId == userId && !r.isFlagged).length;
    return priorValidCount >= 3 ? 1.0 : 0.5;
  }

  /// Validates attached photo: max 2 MB (2 * 1024 * 1024 bytes)
  static bool validatePhotoBytes(Uint8List bytes) {
    const maxBytes = 2 * 1024 * 1024; // 2 MB
    if (bytes.length > maxBytes || bytes.isEmpty) return false;

    // Check magic bytes for JPEG (FF D8), PNG (89 50 4E 47), or WebP (RIFF....WEBP)
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true; // JPEG
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true; // PNG
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true; // WebP
    }

    return false;
  }
}
