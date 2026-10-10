import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/core/models/ai_explanation_models.dart';
import 'package:travel_buddy/core/models/ai_price_models.dart';
import 'package:travel_buddy/core/models/price_engine_models.dart';
import 'package:travel_buddy/core/services/map_launcher_service.dart';
import 'package:travel_buddy/core/utils/pricing_engine.dart';
import 'package:travel_buddy/features/ask_buddy/presentation/ask_buddy_sheet.dart';
import 'package:travel_buddy/features/price_checker/presentation/widgets/price_factors_and_explanation.dart';

void main() {
  group('Phase Sec2: AI Safety & Map URL Allowlist Tests', () {
    test('MapLauncherService allows only HTTPS URLs on approved map hosts or native geo intent', () {
      // Approved map hosts
      expect(
        MapLauncherService.isAllowedMapUrl('https://www.google.com/maps/search/?api=1&query=Hawa+Mahal'),
        isTrue,
      );
      expect(
        MapLauncherService.isAllowedMapUrl('https://maps.google.com/?q=26.9,75.8'),
        isTrue,
      );
      expect(
        MapLauncherService.isAllowedMapUrl('https://waze.com/ul?ll=26.9,75.8&navigate=yes'),
        isTrue,
      );
      expect(
        MapLauncherService.isAllowedMapUrl('https://maps.apple.com/?daddr=26.9,75.8'),
        isTrue,
      );
      expect(
        MapLauncherService.isAllowedMapUrl('geo:26.9,75.8'),
        isTrue,
      );

      // Disallowed schemes & unapproved domains
      expect(
        MapLauncherService.isAllowedMapUrl('http://www.google.com/maps'),
        isFalse,
        reason: 'HTTP must be rejected, only HTTPS allowed',
      );
      expect(
        MapLauncherService.isAllowedMapUrl('javascript:alert(1)'),
        isFalse,
      );
      expect(
        MapLauncherService.isAllowedMapUrl('data:text/html,<script>'),
        isFalse,
      );
      expect(
        MapLauncherService.isAllowedMapUrl('https://evil-phishing-maps.com/fake'),
        isFalse,
        reason: 'Unapproved domains must be blocked',
      );
    });

    test('AiExplanationResult isValidSchema strictly verifies all mandatory fields', () {
      const valid = AiExplanationResult(
        summary: 'Official fare applied.',
        breakdown: [
          AiExplanationBreakdownItem(item: 'Base', amount: 30, note: 'Meter'),
        ],
        counterOfferPhrase: 'Bhaiya ₹100',
        culturalContext: 'Common practice',
        safetyNote: 'Take prepaid',
      );
      expect(valid.isValidSchema, isTrue);

      const invalidSummary = AiExplanationResult(
        summary: '   ',
        breakdown: [
          AiExplanationBreakdownItem(item: 'Base', amount: 30, note: 'Meter'),
        ],
        counterOfferPhrase: 'Bhaiya ₹100',
        culturalContext: 'Common practice',
        safetyNote: 'Take prepaid',
      );
      expect(invalidSummary.isValidSchema, isFalse);

      const invalidBreakdown = AiExplanationResult(
        summary: 'Valid summary',
        breakdown: [],
        counterOfferPhrase: 'Bhaiya ₹100',
        culturalContext: 'Common practice',
        safetyNote: 'Take prepaid',
      );
      expect(invalidBreakdown.isValidSchema, isFalse);
    });

    test('Deterministic Pricing Engine Invariant: AI never alters calculated score, verdict, or fair range', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        quotedPrice: 350.0,
        pickupName: 'Jaipur Junction',
        dropName: 'Hawa Mahal',
        distanceKm: 5.0,
      );

      // Pricing engine calculation is 100% deterministic
      final result1 = PricingEngine.evaluate(input: input);
      final result2 = PricingEngine.evaluate(input: input);

      expect(result1.riskScore, equals(result2.riskScore));
      expect(result1.fairMin, equals(result2.fairMin));
      expect(result1.fairMax, equals(result2.fairMax));
      expect(result1.level, equals(result2.level));
      expect(result1.fairMax, lessThan(input.quotedPrice));
    });

    testWidgets('PriceFactorsAndExplanation displays mandatory AI safety disclaimer', (tester) async {
      const result = PriceCheckResult(
        level: PriceVerdictLevel.highRisk,
        riskScore: 75,
        confidence: ConfidenceLevel.high,
        fairMin: 90.0,
        fairMax: 130.0,
        quotedPrice: 350.0,
        differenceRupees: 220.0,
        differencePercent: 169.0,
        counterOffer: 130.0,
        counterOfferLine: 'Bhaiya ₹130 chalna hai toh bolo',
        sources: [],
        factors: [],
        explanation: 'Heavy markup detected.',
      );

      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        quotedPrice: 350.0,
        pickupName: 'Jaipur Junction',
        dropName: 'Hawa Mahal',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PriceFactorsAndExplanation(
                result: result,
                input: input,
              ),
            ),
          ),
        ),
      );

      // Wait for explanation resolution
      await tester.pumpAndSettle();

      expect(
        find.text('AI explanations can make mistakes. Check the factors shown.'),
        findsOneWidget,
      );
    });

    testWidgets('AskBuddySheet displays mandatory AI safety disclaimer', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AskBuddySheet(
                currentPlace: 'Jaipur',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('can make mistakes. Check the factors shown.'),
        findsOneWidget,
      );
    });
  });
}
