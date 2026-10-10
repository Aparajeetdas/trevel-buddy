import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/ai_explanation_models.dart';
import '../models/price_engine_models.dart';

final geminiProxyServiceProvider = Provider<GeminiProxyService>((ref) {
  return GeminiProxyService();
});

/// Client service communicating with the secure Gemini Serverless Proxy
class GeminiProxyService {
  final String _proxyBaseUrl;
  final http.Client _client;

  GeminiProxyService({http.Client? client, String? proxyBaseUrl})
      : _client = client ?? http.Client(),
        _proxyBaseUrl = proxyBaseUrl ?? ApiConfig.proxyBaseUrl;

  /// Request structured AI fare analysis from the proxy, with deterministic local fallback
  Future<AiExplanationResult> getExplanation({
    required PriceCheckResult result,
    required PriceCheckInput input,
    String language = 'English',
  }) async {
    final payload = {
      'serviceType': input.serviceType.name,
      'pickupName': input.pickupName ?? '',
      'dropName': input.dropName ?? '',
      'quoted': input.quotedPrice,
      'fairMin': result.fairMin,
      'fairMax': result.fairMax,
      'verdict': result.level.label,
      'factors': result.factors.map((f) => f.toJson()).toList(),
      'nearbyTraps': result.nearbyTraps.map((t) => t.type).toList(),
      'language': language,
    };

    try {
      final uri = Uri.parse('$_proxyBaseUrl/explain');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final parsed = AiExplanationResult.fromJson(data);
        if (parsed.isValidSchema) {
          return parsed;
        }
      }
    } catch (_) {
      // Graceful fallback on network timeout, offline state, or proxy down
    }

    return _generateLocalFallback(result, input);
  }

  static const Set<String> _allowedToolTypes = {
    'check_price',
    'checkPrice',
    'getAirportPrepaidFare',
    'get_airport_prepaid_fare',
    'get_place_details',
    'getPlaceDetails',
    'search_nearby',
    'searchNearby',
    'view_traps',
    'getScamRadar',
    'get_playbook',
    'getPlaybook',
    'create_roadmap',
    'createRoadmap',
    'go_here',
    'open_in_maps',
    'openInMaps',
    'open_maps',
    'open_place',
    'open_directions',
    'openDirections',
    'open_screen',
    'openScreen',
    'start_ride',
  };

  /// Request agent response with function calling & action suggestions
  Future<AgentMessage> sendAgentMessage({
    required List<AgentMessage> history,
    String? currentPlace,
    double? lat,
    double? lng,
  }) async {
    final payload = {
      'messages': history.map((m) => m.toJson()).toList(),
      'currentPlace': currentPlace ?? 'Jaipur',
      'currentCoordinates': {'lat': lat ?? 26.9239, 'lng': lng ?? 75.8267},
    };

    try {
      final uri = Uri.parse('$_proxyBaseUrl/agent');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawActions = data['actions'] as List<dynamic>? ?? [];
        final actions = <AgentAction>[];
        for (final item in rawActions) {
          if (item is Map<String, dynamic>) {
            final type = item['type'] as String? ?? '';
            if (_allowedToolTypes.contains(type)) {
              actions.add(AgentAction.fromJson(item));
            }
          }
        }

        final rawText = data['text'] as String?;
        if (rawText != null && rawText.trim().isNotEmpty) {
          return AgentMessage(
            id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
            sender: 'buddy',
            text: rawText,
            timestamp: DateTime.now(),
            actions: actions,
          );
        }
      }
    } catch (_) {
      // Fallback to local intelligent agent
    }

    return _generateLocalAgentFallback(history, currentPlace ?? 'Jaipur');
  }

  AiExplanationResult _generateLocalFallback(
    PriceCheckResult result,
    PriceCheckInput input,
  ) {
    final diff = input.quotedPrice - result.fairMax;
    final pickup = input.pickupName ?? 'Pickup';
    final drop = input.dropName ?? 'Destination';

    String summary;
    if (result.level.name == 'fair') {
      summary =
          'Quoted price of ₹${input.quotedPrice.toStringAsFixed(0)} is within the official fair range (₹${result.fairMin.toStringAsFixed(0)} - ₹${result.fairMax.toStringAsFixed(0)}) for travel from $pickup to $drop.';
    } else if (result.level.name == 'suspicious') {
      summary =
          'Quoted price of ₹${input.quotedPrice.toStringAsFixed(0)} is moderately above standard benchmarks (+₹${diff.toStringAsFixed(0)} markup). Counter-offer advised.';
    } else {
      summary =
          'Quoted price of ₹${input.quotedPrice.toStringAsFixed(0)} represents a heavy markup of ₹${diff.toStringAsFixed(0)} above the fair ceiling. High likelihood of tourist trap pricing.';
    }

    final breakdown = <AiExplanationBreakdownItem>[
      AiExplanationBreakdownItem(
        item: 'Base Fare & Distance Tariff',
        amount: result.fairMin,
        note: 'Calculated using official government notified rate cards',
      ),
      AiExplanationBreakdownItem(
        item: 'Traffic & Waiting Buffer',
        amount: (result.fairMax - result.fairMin).clamp(0, 99999),
        note: 'Realistic community variance observed across active reports',
      ),
    ];

    if (diff > 0) {
      breakdown.push(
        AiExplanationBreakdownItem(
          item: 'Tourist Markup Premium',
          amount: diff,
          note: 'Excess surcharge over local fair rates',
        ),
      );
    }

    String counterOfferPhrase;
    if (input.serviceType.name == 'guide') {
      counterOfferPhrase =
          'Sir, ₹${result.fairMax.toStringAsFixed(0)} is the government-approved rate for certified guides. Let us proceed at that.';
    } else {
      counterOfferPhrase =
          'Bhaiya, ₹${result.fairMax.toStringAsFixed(0)} doonga. Chalna hai toh theek hai (I will give ₹${result.fairMax.toStringAsFixed(0)}, otherwise I will take another ride).';
    }

    const culturalContext =
        'Drivers and touts outside tourist transit hubs frequently begin negotiations with 2x-3x elevated quotes. Politely stating the exact local rate or asking to run the digital meter immediately resets expectations.';

    final safetyNote = result.level.name == 'highRisk'
        ? 'Do not engage in arguments if the vendor becomes hostile. Walk away toward official prepaid kiosks or traffic police outposts.'
        : 'Verify your destination on the map before boarding and ensure payment terms are settled in advance.';

    return AiExplanationResult(
      summary: summary,
      breakdown: breakdown,
      counterOfferPhrase: counterOfferPhrase,
      culturalContext: culturalContext,
      safetyNote: safetyNote,
      isFallback: true,
    );
  }

  AgentMessage _generateLocalAgentFallback(
    List<AgentMessage> history,
    String place,
  ) {
    final query = history.isNotEmpty ? history.last.text.toLowerCase() : '';

    if (query.contains('step') || query.contains('explain step')) {
      return AgentMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'buddy',
        text: 'When navigating this route, board verified prepaid autos or metro lines at designated stops. Never accept diversions to unverified handicraft shops along the way.',
        timestamp: DateTime.now(),
        actions: [
          AgentAction(
            type: 'create_roadmap',
            label: 'Open Full Roadmap',
            params: {'destination': place},
          ),
        ],
      );
    }

    if (query.contains('roadmap') ||
        query.contains('route') ||
        query.contains('how to get') ||
        query.contains('go to') ||
        query.contains('reach') ||
        query.contains('direction')) {
      return AgentMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'buddy',
        text:
            'I can generate a multi-modal roadmap to get to $place with fair prices, step-by-step guidance, and scam trap warnings along the way!',
        timestamp: DateTime.now(),
        actions: [
          AgentAction(
            type: 'create_roadmap',
            label: 'Go Here: Roadmap to $place',
            params: {'destination': place, 'lat': 26.9855, 'lng': 75.8513},
          ),
          const AgentAction(
            type: 'check_price',
            label: 'Check Transit Fare',
            params: {},
          ),
        ],
      );
    }

    if (query.contains('shillong') ||
        (query.contains('prepaid') &&
            (query.contains('taxi') ||
                query.contains('fare') ||
                query.contains('airport') ||
                query.contains('counter'))) ||
        (query.contains('airport') &&
            (query.contains('taxi') ||
                query.contains('fare') ||
                query.contains('cab') ||
                query.contains('rates')))) {
      if (query.contains('shillong')) {
        return AgentMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'buddy',
          text:
              '[Official tariff] Official LGBI Airport Pre-paid Taxi rates to Shillong:\n'
              '• Shillong (Police Bazar): ₹2,600 (about 110 km)\n'
              '• Shillong (Barapani): ₹2,300 (about 95 km)\n'
              '• Shillong (NEHU/Mawlai): ₹2,400 (about 100 km)\n\n'
              'Note: Confirm at the counter whether tolls are included.',
          timestamp: DateTime.now(),
          actions: const [
            AgentAction(
              type: 'getAirportPrepaidFare',
              label: 'View Airport Rate Card',
              params: {'destination': 'Shillong'},
            ),
            AgentAction(
              type: 'check_price',
              label: 'Check Police Bazar (₹2,600)',
              params: {
                'pickup': 'LGBI Airport, Guwahati',
                'drop': 'Shillong (Police Bazar)',
                'quoted': 2600,
                'serviceType': 'taxi',
              },
            ),
          ],
        );
      }

      if (query.contains('ganeshguri')) {
        return AgentMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'buddy',
          text:
              '[Official tariff] LGBI Airport Pre-paid Taxi to Ganeshguri is fixed at ₹680 (about 31 km, ~₹21.9/km).\n\n'
              'Drivers cannot charge above the official tariff. Note: Ask the counter whether tolls are included.',
          timestamp: DateTime.now(),
          actions: const [
            AgentAction(
              type: 'getAirportPrepaidFare',
              label: 'View Airport Rate Card',
              params: {'destination': 'Ganeshguri'},
            ),
            AgentAction(
              type: 'check_price',
              label: 'Check Ganeshguri (₹680)',
              params: {
                'pickup': 'LGBI Airport, Guwahati',
                'drop': 'Ganeshguri',
                'quoted': 680,
                'serviceType': 'taxi',
              },
            ),
          ],
        );
      }

      return AgentMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'buddy',
        text:
            '[Official tariff] The LGBI Airport Pre-paid Taxi Counter in Guwahati has government-notified fixed tariffs for over 60 destinations across Guwahati, Assam, and Meghalaya (e.g. Ganeshguri ₹680, Shillong ₹2,600).\n\n'
            'Ask the counter whether tolls are included before boarding.',
        timestamp: DateTime.now(),
        actions: const [
          AgentAction(
            type: 'getAirportPrepaidFare',
            label: 'View All Airport Fares',
            params: {},
          ),
          AgentAction(
            type: 'check_price',
            label: 'Check Pre-paid Price',
            params: {
              'pickup': 'LGBI Airport, Guwahati',
              'drop': 'Ganeshguri',
              'quoted': 680,
              'serviceType': 'taxi',
            },
          ),
        ],
      );
    }

    if (query.contains('auto') ||
        query.contains('fare') ||
        query.contains('price') ||
        query.contains('ride') ||
        query.contains('meter')) {
      return AgentMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'buddy',
        text:
            'In $place, daytime auto-rickshaws start at ₹30 base plus ₹12 per km. You should always insist on meter or check with my fair price tool before boarding!',
        timestamp: DateTime.now(),
        actions: const [
          AgentAction(
            type: 'check_price',
            label: 'Check Auto Price (₹250 test)',
            params: {
              'serviceType': 'auto',
              'quoted': 250,
              'pickup': 'Jaipur Junction',
              'drop': 'Hawa Mahal',
            },
          ),
          AgentAction(
            type: 'start_ride',
            label: 'Start Live Ride Meter',
            params: {},
          ),
        ],
      );
    }

    if (query.contains('scam') ||
        query.contains('trap') ||
        query.contains('safe') ||
        query.contains('danger')) {
      return AgentMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'buddy',
        text:
            'Around $place, watch out for "Temple closed today" diversions and gem factory detours. Tap below to browse all verified tourist traps nearby.',
        timestamp: DateTime.now(),
        actions: const [
          AgentAction(
            type: 'view_traps',
            label: 'View Tourist Trap Database',
            params: {},
          ),
          AgentAction(
            type: 'show_map',
            label: 'Show Anomaly Zones on Map',
            params: {'lat': 26.9239, 'lng': 75.8267},
          ),
        ],
      );
    }

    return AgentMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'buddy',
      text:
          'Namaste! I am Buddy, your AI Travel Guide and Fair Price Guardian. Ask me about local taxi rates, monument guides, tourist traps, or safe routes in $place.',
      timestamp: DateTime.now(),
      actions: const [
        AgentAction(
          type: 'check_price',
          label: 'Check a Price Before You Pay',
          params: {},
        ),
        AgentAction(
          type: 'view_traps',
          label: 'Browse Tourist Trap DB',
          params: {},
        ),
      ],
    );
  }
}

extension _ListPush<T> on List<T> {
  void push(T item) => add(item);
}
