import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/core/models/ai_explanation_models.dart';
import 'package:travel_buddy/core/models/ai_price_models.dart';
import 'package:travel_buddy/core/models/price_engine_models.dart';
import 'package:travel_buddy/core/services/gemini_proxy_service.dart';

void main() {
  group('Gemini Proxy Service & AI Explanation Tests', () {
    test('AiExplanationResult serialization and parsing', () {
      final json = {
        'summary': 'Quoted fare is slightly inflated.',
        'breakdown': [
          {'item': 'Base fare', 'amount': 30.0, 'note': 'Gov tariff'},
          {'item': 'Distance', 'amount': 70.0, 'note': '5 km'},
        ],
        'counterOfferPhrase': 'Bhaiya ₹100 le lo',
        'culturalContext': 'Transit hubs regularly see 2x quotes.',
        'safetyNote': 'Politely decline and walk to prepaid booth.',
        'isFallback': false,
      };

      final result = AiExplanationResult.fromJson(json);
      expect(result.summary, 'Quoted fare is slightly inflated.');
      expect(result.breakdown.length, 2);
      expect(result.breakdown.first.amount, 30.0);
      expect(result.counterOfferPhrase, 'Bhaiya ₹100 le lo');
      expect(result.isFallback, isFalse);
    });

    test('GeminiProxyService fallback produces rich explanation on network failure', () async {
      final service = GeminiProxyService();
      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        quotedPrice: 350.0,
        pickupName: 'Jaipur Junction',
        dropName: 'Hawa Mahal',
      );

      const result = PriceCheckResult(
        level: PriceVerdictLevel.highRisk,
        riskScore: 78,
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

      // Triggers fallback gracefully (no live proxy on 8080 during unit test)
      final explanation = await service.getExplanation(
        result: result,
        input: input,
      );

      expect(explanation.summary, isNotEmpty);
      expect(explanation.breakdown.isNotEmpty, isTrue);
      expect(explanation.counterOfferPhrase, contains('130'));
      expect(explanation.culturalContext, isNotEmpty);
      expect(explanation.safetyNote, isNotEmpty);
      expect(explanation.isFallback, isTrue);
    });

    test('GeminiProxyService agent returns interactive action cards', () async {
      final service = GeminiProxyService();
      final response = await service.sendAgentMessage(
        history: [
          AgentMessage(
            id: '1',
            sender: 'user',
            text: 'Is ₹250 auto price fair from railway station?',
            timestamp: DateTime.now(),
          ),
        ],
        currentPlace: 'Jaipur',
      );

      expect(response.sender, 'buddy');
      expect(response.text, isNotEmpty);
      expect(response.actions.isNotEmpty, isTrue);
      expect(
        response.actions.any(
          (a) => a.type == 'check_price' || a.type == 'start_ride',
        ),
        isTrue,
      );
    });
  });
}
