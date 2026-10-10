import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/core/data/auth_repository.dart';
import 'package:travel_buddy/core/models/price_engine_models.dart';
import 'package:travel_buddy/core/services/gemini_proxy_service.dart';
import 'package:travel_buddy/features/ask_buddy/presentation/ask_buddy_sheet.dart';
import 'package:travel_buddy/features/price_checker/presentation/check_price_input_screen.dart';

class FailingMockGeminiProxyService extends GeminiProxyService {
  final bool simulate429;
  final bool simulateNetworkError;

  FailingMockGeminiProxyService({
    this.simulate429 = false,
    this.simulateNetworkError = false,
  });

  @override
  Stream<String> streamAgentMessage({
    required List<AgentMessage> history,
    String? currentPlace,
    String? screen,
    String? placeId,
    double? lat,
    double? lng,
    String? idToken,
    void Function(AgentMessage finalMessage)? onComplete,
  }) async* {
    if (simulateNetworkError) {
      throw Exception('Connection failed');
    }

    if (simulate429) {
      final msg = AgentMessage(
        id: 'msg_429',
        sender: 'buddy',
        text: 'Daily quota or request limit reached. In the meantime, you can check fair taxi fares directly.',
        timestamp: DateTime.now(),
        sources: const ['Playbook'],
        actions: const [
          AgentAction(
            type: 'check_price',
            label: 'Check a Price',
            params: {},
          ),
        ],
      );
      onComplete?.call(msg);
      return;
    }

    yield 'OK';
  }

  @override
  Future<AgentMessage> sendAgentMessage({
    required List<AgentMessage> history,
    String? currentPlace,
    String? screen,
    String? placeId,
    double? lat,
    double? lng,
    String? idToken,
  }) async {
    if (simulate429) {
      return AgentMessage(
        id: 'msg_429',
        sender: 'buddy',
        text: 'Daily quota or request limit reached. In the meantime, you can check fair taxi fares directly.',
        timestamp: DateTime.now(),
        sources: const ['Playbook'],
        actions: const [
          AgentAction(
            type: 'check_price',
            label: 'Check a Price',
            params: {},
          ),
        ],
      );
    }
    throw Exception('Upstream failure');
  }
}

class TestAuthRepo implements AuthRepository {
  final AppUser? user;
  TestAuthRepo([this.user]);

  @override
  AppUser? get currentUser => user;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(user);

  @override
  Future<AppUser?> signInWithGoogle() async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> getIdToken() async => user?.token;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase AG3: Failure Handling & Quota Tests', () {
    testWidgets('1. HTTP 429 rate limit / quota shows friendly message and Check a Price button without blocking app', (tester) async {
      final proxy = FailingMockGeminiProxyService(simulate429: true);
      final auth = TestAuthRepo(const AppUser(uid: 'u_quota', idToken: 'valid_tok'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            geminiProxyServiceProvider.overrideWithValue(proxy),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AskBuddySheet(currentPlace: 'Guwahati'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit query
      await tester.enterText(find.byType(TextField), 'Check fare');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Verify friendly message
      expect(find.textContaining('quota or request limit reached'), findsOneWidget);

      // Verify Check a Price button is present and tappable
      final checkPriceCard = find.text('Check a Price');
      expect(checkPriceCard, findsWidgets);

      await tester.tap(checkPriceCard.last);
      await tester.pumpAndSettle();

      // Verify Check a Price screen opened without blocking app
      expect(find.byType(CheckPriceInputScreen), findsOneWidget);
    });

    testWidgets('2. Upstream network timeout / error replaces placeholder with fallback and Check a Price button with retry banner', (tester) async {
      final proxy = FailingMockGeminiProxyService(simulateNetworkError: true);
      final auth = TestAuthRepo(const AppUser(uid: 'u_fail', idToken: 'valid_tok'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            geminiProxyServiceProvider.overrideWithValue(proxy),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AskBuddySheet(currentPlace: 'Guwahati'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit query
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Error banner with Retry
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Could not reach Ask Buddy'), findsOneWidget);

      // Friendly fallback message with Check a Price action
      expect(find.textContaining('could not reach live intelligence right now'), findsOneWidget);
      expect(find.text('Check a Price'), findsWidgets);
    });
  });
}
