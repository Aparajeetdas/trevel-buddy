import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_buddy/core/data/community_repository.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/utils/pricing_engine.dart';
import 'package:travel_buddy/core/utils/report_security_validator.dart';

void main() {
  group('Phase Sec3: Community Data Abuse & Anti-Poisoning Tests', () {
    test('validatePriceSanity accepts realistic fares and rejects outliers/insane amounts', () {
      // Auto: ₹10 - ₹5,000
      expect(ReportSecurityValidator.validatePriceSanity(ServiceType.auto, 150.0).isValid, isTrue);
      expect(ReportSecurityValidator.validatePriceSanity(ServiceType.auto, 5.0).isValid, isFalse);
      expect(ReportSecurityValidator.validatePriceSanity(ServiceType.auto, 10000.0).isValid, isFalse);

      // Taxi: ₹30 - ₹20,000
      expect(ReportSecurityValidator.validatePriceSanity(ServiceType.taxi, 850.0).isValid, isTrue);
      expect(ReportSecurityValidator.validatePriceSanity(ServiceType.taxi, 35000.0).isValid, isFalse);

      // Meal: ₹20 - ₹10,000
      expect(ReportSecurityValidator.validatePriceSanity(ServiceType.meal, 400.0).isValid, isTrue);
      expect(ReportSecurityValidator.validatePriceSanity(ServiceType.meal, 25000.0).isValid, isFalse);

      // Invalid numerical values
      expect(ReportSecurityValidator.validatePriceSanity(ServiceType.auto, -50.0).isValid, isFalse);
      expect(ReportSecurityValidator.validatePriceSanity(ServiceType.auto, double.nan).isValid, isFalse);
    });

    test('sanitizeReportText strips URLs, redacts phone numbers & emails, and clamps length', () {
      const rawText = 'Contact driver on +91 9876543210 or email guide@scam.in! Also check https://phishing.site/now for booking discounts.\x00\x08';
      final sanitized = ReportSecurityValidator.sanitizeReportText(rawText);

      expect(sanitized.contains('https://'), isFalse);
      expect(sanitized.contains('[LINK_REMOVED]'), isTrue);
      expect(sanitized.contains('9876543210'), isFalse);
      expect(sanitized.contains('[PHONE_REDACTED]'), isTrue);
      expect(sanitized.contains('guide@scam.in'), isFalse);
      expect(sanitized.contains('[EMAIL_REDACTED]'), isTrue);
      expect(sanitized.contains('\x00'), isFalse);

      // Max length clamping
      final longText = 'A' * 600;
      final clamped = ReportSecurityValidator.sanitizeReportText(longText, maxLength: 500);
      expect(clamped.length, lessThanOrEqualTo(500));
    });

    test('roundCoordinate obfuscates GPS location to ~100m resolution for user privacy', () {
      final roundedLat = ReportSecurityValidator.roundCoordinate(26.912456);
      final roundedLng = ReportSecurityValidator.roundCoordinate(75.787349);

      expect(roundedLat, 26.912);
      expect(roundedLng, 75.787);
    });

    test('Deduplication rejects submissions by same user for same route within 10 minutes', () {
      final now = DateTime.now();
      final report1 = PriceReport(
        id: 'r1',
        serviceType: ServiceType.auto,
        vehicleType: 'auto',
        routeOrPlace: 'Jaipur Junction to Hawa Mahal',
        pricePaid: 150.0,
        timestamp: now,
        wasFair: true,
        userId: 'user_123',
      );

      final duplicateReport = PriceReport(
        id: 'r2',
        serviceType: ServiceType.auto,
        vehicleType: 'auto',
        routeOrPlace: 'jaipur junction to hawa mahal',
        pricePaid: 160.0,
        timestamp: now.add(const Duration(minutes: 3)), // within 10 min
        wasFair: true,
        userId: 'user_123',
      );

      final differentUserReport = PriceReport(
        id: 'r3',
        serviceType: ServiceType.auto,
        vehicleType: 'auto',
        routeOrPlace: 'Jaipur Junction to Hawa Mahal',
        pricePaid: 150.0,
        timestamp: now.add(const Duration(minutes: 3)),
        wasFair: true,
        userId: 'user_456',
      );

      expect(ReportSecurityValidator.isDuplicateReport(duplicateReport, [report1]), isTrue);
      expect(ReportSecurityValidator.isDuplicateReport(differentUserReport, [report1]), isFalse);
    });

    test('Daily rate limiting enforces max 20 reports per user per day', () {
      final now = DateTime.now();
      final userReports = List.generate(
        20,
        (i) => PriceReport(
          id: 'rep_$i',
          serviceType: ServiceType.auto,
          vehicleType: 'auto',
          routeOrPlace: 'Route $i',
          pricePaid: 100.0 + i,
          timestamp: now.subtract(Duration(hours: i % 12)),
          wasFair: true,
          userId: 'busy_user',
        ),
      );

      expect(ReportSecurityValidator.checkDailyRateLimit('busy_user', userReports), isFalse);
      expect(ReportSecurityValidator.checkDailyRateLimit('new_user', userReports), isTrue);
    });

    test('calculateUserWeight assigns 0.5 to new users and 1.0 to consistent contributors', () {
      final pastReports = [
        PriceReport(
          id: '1',
          serviceType: ServiceType.auto,
          vehicleType: 'auto',
          routeOrPlace: 'R1',
          pricePaid: 100,
          timestamp: DateTime.now(),
          wasFair: true,
          userId: 'veteran',
        ),
        PriceReport(
          id: '2',
          serviceType: ServiceType.auto,
          vehicleType: 'auto',
          routeOrPlace: 'R2',
          pricePaid: 120,
          timestamp: DateTime.now(),
          wasFair: true,
          userId: 'veteran',
        ),
        PriceReport(
          id: '3',
          serviceType: ServiceType.auto,
          vehicleType: 'auto',
          routeOrPlace: 'R3',
          pricePaid: 110,
          timestamp: DateTime.now(),
          wasFair: true,
          userId: 'veteran',
        ),
      ];

      expect(ReportSecurityValidator.calculateUserWeight('veteran', pastReports), 1.0);
      expect(ReportSecurityValidator.calculateUserWeight('newbie', pastReports), 0.5);
    });

    test('PricingEngine excludes flagged reports from community benchmarks', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        quotedPrice: 150.0,
        pickupName: 'Jaipur Junction',
        dropName: 'Hawa Mahal',
        distanceKm: 5.0,
      );

      final unflaggedReports = List.generate(
        5,
        (i) => PriceReport(
          id: 'clean_$i',
          serviceType: ServiceType.auto,
          vehicleType: 'auto',
          routeOrPlace: 'Jaipur Junction to Hawa Mahal',
          pricePaid: 120.0 + (i * 5),
          timestamp: DateTime.now(),
          wasFair: true,
          isFlagged: false,
        ),
      );

      final flaggedReport = PriceReport(
        id: 'malicious',
        serviceType: ServiceType.auto,
        vehicleType: 'auto',
        routeOrPlace: 'Jaipur Junction to Hawa Mahal',
        pricePaid: 1200.0, // Poisoned 10x price!
        timestamp: DateTime.now(),
        wasFair: true,
        isFlagged: true, // Flagged by community review!
      );

      final res = PricingEngine.evaluate(
        input: input,
        reports: [...unflaggedReports, flaggedReport],
      );

      // The poisoned report of ₹1200 must NOT inflate the benchmark
      expect(res.sources.any((s) => s.type == 'community'), isTrue);
      final communitySource = res.sources.firstWhere(
        (s) => s.type == 'community',
      );
      expect(communitySource.amount, lessThan(200.0));
      expect(communitySource.reportCount, 5, reason: 'Flagged report must be completely excluded from count');
    });

    test('Photo byte validator accepts valid images < 2 MB and rejects oversized payloads', () {
      // 100 KB mock JPEG header (FF D8 FF)
      final jpegBytes = Uint8List(100 * 1024);
      jpegBytes[0] = 0xFF;
      jpegBytes[1] = 0xD8;
      jpegBytes[2] = 0xFF;
      expect(ReportSecurityValidator.validatePhotoBytes(jpegBytes), isTrue);

      // 3 MB oversized file (> 2 MB limit)
      final oversizedBytes = Uint8List(3 * 1024 * 1024);
      oversizedBytes[0] = 0xFF;
      oversizedBytes[1] = 0xD8;
      oversizedBytes[2] = 0xFF;
      expect(ReportSecurityValidator.validatePhotoBytes(oversizedBytes), isFalse);

      // Invalid format / corrupt bytes
      final corruptBytes = Uint8List.fromList([0x00, 0x01, 0x02]);
      expect(ReportSecurityValidator.validatePhotoBytes(corruptBytes), isFalse);
    });

    test('LocalCommunityRepository clearAllLocalData resets all stored cache', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({'travel_buddy_price_reports_v2': '[]'});
      final repo = LocalCommunityRepository();
      await repo.clearAllLocalData();
      final reports = await repo.getPriceReports();
      expect(reports.isNotEmpty, isTrue, reason: 'Fresh seed reports load gracefully after wipe');
    });
  });
}
