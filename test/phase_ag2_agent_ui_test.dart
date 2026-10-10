import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/core/data/auth_repository.dart';
import 'package:travel_buddy/core/models/price_engine_models.dart';
import 'package:travel_buddy/core/services/gemini_proxy_service.dart';
import 'package:travel_buddy/core/widgets/ask_buddy_floating_button.dart';
import 'package:travel_buddy/features/ask_buddy/presentation/ask_buddy_sheet.dart';
import 'package:travel_buddy/features/ask_buddy/presentation/widgets/ask_buddy_message_bubble.dart';

class TestAuthRepository implements AuthRepository {
  AppUser? _user;
  TestAuthRepository([this._user]);

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(_user);

  @override
  Future<AppUser?> signInWithGoogle() async {
    _user = const AppUser(
      uid: 'user_123',
      displayName: 'Test Traveler',
      idToken: 'valid_test_token_123',
    );
    return _user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }

  @override
  Future<String?> getIdToken() async => _user?.token;
}

class TestGeminiProxyService extends GeminiProxyService {
  final List<String> emittedTokens;
  final AgentMessage finalMessage;
  String? lastSentToken;
  String? lastSentPrompt;

  TestGeminiProxyService({
    this.emittedTokens = const ['₹1200 ', 'is high, ', 'standard prepaid fare is ₹850.'],
    AgentMessage? finalMessage,
  }) : finalMessage = finalMessage ??
            AgentMessage(
              id: 'resp_1',
              sender: 'buddy',
              text: '₹1200 is high, standard prepaid fare is ₹850.',
              timestamp: DateTime.now(),
              sources: const ['Official LGBI Tariff', 'Prepaid Taxi Counter'],
              actions: const [
                AgentAction(
                  type: 'airport_fares',
                  label: 'View LGBI Airport Fares',
                  params: {},
                ),
                AgentAction(
                  type: 'check_price',
                  label: 'Check Fair Price',
                  params: {'drop': 'Ganeshguri'},
                ),
              ],
            );

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
    lastSentToken = idToken;
    lastSentPrompt = history.isNotEmpty ? history.last.text : null;
    for (final token in emittedTokens) {
      yield token;
    }
    if (onComplete != null) {
      onComplete(finalMessage);
    }
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
    lastSentToken = idToken;
    lastSentPrompt = history.isNotEmpty ? history.last.text : null;
    return finalMessage;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase AG2: Ask Buddy Chat UI & Stream Integration Tests', () {
    testWidgets('1. AskBuddySheet renders header, suggestions, input, and AI disclaimer', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              TestAuthRepository(const AppUser(uid: 'u1', idToken: 'tok1')),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AskBuddySheet(currentPlace: 'Guwahati'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Ask Buddy • AI Guide'), findsOneWidget);
      expect(find.textContaining('Guwahati'), findsWidgets);

      // 4 Suggestion chips
      expect(find.text('Is Rs 1200 fair from the airport to Ganeshguri?'), findsOneWidget);
      expect(find.text('Scams near me'), findsOneWidget);
      expect(find.text('Plan how to reach Shillong'), findsOneWidget);
      expect(find.text('Best time to visit'), findsOneWidget);

      // Input field & AI disclaimer
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('AI can make mistakes. Check the factors shown.'), findsOneWidget);

      // Initial welcome message actions
      expect(find.text('Check a Price'), findsOneWidget);
      expect(find.text('LGBI Airport Fares'), findsOneWidget);
      expect(find.text('Tourist Trap Radar'), findsOneWidget);
    });

    testWidgets('2. Suggestion chip tap submits message and streams response with sources & actions', (tester) async {
      final proxy = TestGeminiProxyService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              TestAuthRepository(const AppUser(uid: 'u1', idToken: 'valid_tok')),
            ),
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

      // Tap suggestion chip
      final chipFinder = find.text('Is Rs 1200 fair from the airport to Ganeshguri?');
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      expect(proxy.lastSentToken, 'valid_tok');
      expect(proxy.lastSentPrompt, 'Is Rs 1200 fair from the airport to Ganeshguri?');

      // Verify streamed text and sources
      expect(find.text('₹1200 is high, standard prepaid fare is ₹850.'), findsOneWidget);
      expect(find.text('[Official LGBI Tariff]'), findsOneWidget);
      expect(find.text('[Prepaid Taxi Counter]'), findsOneWidget);

      // Verify action cards
      expect(find.text('View LGBI Airport Fares'), findsOneWidget);
      expect(find.text('Check Fair Price'), findsOneWidget);
    });

    testWidgets('3. Sign-in gate prompts unauthenticated user and resumes pending message upon sign-in', (tester) async {
      final auth = TestAuthRepository(null); // Signed out initially
      final proxy = TestGeminiProxyService();

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

      // Enter query while signed out
      await tester.enterText(find.byType(TextField), 'What is the rate to Police Bazar?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Verify Sign-in dialog appears
      expect(find.text('Sign In Required'), findsOneWidget);
      expect(find.text('Sign in with Google to chat with Buddy and access real-time fare intelligence.'), findsOneWidget);

      // Tap Sign in with Google
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      // Dialog dismisses and pending message automatically sent
      expect(find.text('Sign In Required'), findsNothing);
      expect(proxy.lastSentPrompt, 'What is the rate to Police Bazar?');
      expect(proxy.lastSentToken, 'valid_test_token_123');
    });

    testWidgets('4. Reset button clears in-memory chat history back to welcome state', (tester) async {
      final proxy = TestGeminiProxyService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              TestAuthRepository(const AppUser(uid: 'u1', idToken: 'token1')),
            ),
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

      // Submit a query
      await tester.enterText(find.byType(TextField), 'Hello Buddy');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Hello Buddy'), findsOneWidget);

      // Tap Reset Chat button in header
      await tester.tap(find.byTooltip('Reset Chat'));
      await tester.pumpAndSettle();

      // User query is cleared, only welcome message remains
      expect(find.text('Hello Buddy'), findsNothing);
      expect(find.textContaining('Namaste! I am Buddy'), findsOneWidget);
    });

    testWidgets('5. Responsive layout: show opens side panel on wide screen and bottom sheet on mobile', (tester) async {
      // 1. Mobile screen (width 400)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => AskBuddySheet.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // On mobile it uses showModalBottomSheet (ModalBottomSheetRoute)
      expect(find.byType(AskBuddySheet), findsOneWidget);
      final mobileSheet = tester.widget<AskBuddySheet>(find.byType(AskBuddySheet));
      expect(mobileSheet.isSidePanel, isFalse);

      // Close sheet
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // 2. Wide screen (width 1024)
      tester.view.physicalSize = const Size(1024, 800);
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AskBuddySheet), findsOneWidget);
      final wideSheet = tester.widget<AskBuddySheet>(find.byType(AskBuddySheet));
      expect(wideSheet.isSidePanel, isTrue);
    });

    testWidgets('6. Action card navigation dispatches to target screens', (tester) async {
      final msg = AgentMessage(
        id: 'msg_nav',
        sender: 'buddy',
        text: 'Action dispatch test',
        timestamp: DateTime.now(),
        actions: const [
          AgentAction(type: 'check_price', label: 'Check Price Card', params: {'drop': 'Paltan Bazar'}),
          AgentAction(type: 'airport_fares', label: 'Airport Fares Card', params: {}),
          AgentAction(type: 'tourist_traps', label: 'Scam Radar Card', params: {}),
          AgentAction(type: 'roadmap', label: 'Roadmap Card', params: {}),
        ],
      );

      AgentAction? tappedAction;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AskBuddyMessageBubble(
              message: msg,
              onActionTap: (act) => tappedAction = act,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all action chips are visible
      expect(find.text('Check Price Card'), findsOneWidget);
      expect(find.text('Airport Fares Card'), findsOneWidget);
      expect(find.text('Scam Radar Card'), findsOneWidget);
      expect(find.text('Roadmap Card'), findsOneWidget);

      // Tap Check Price Card
      await tester.tap(find.text('Check Price Card'));
      expect(tappedAction?.type, 'check_price');

      // Tap Airport Fares Card
      await tester.tap(find.text('Airport Fares Card'));
      expect(tappedAction?.type, 'airport_fares');
    });

    testWidgets('7. AskBuddyFloatingButton launches AskBuddySheet on tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              floatingActionButton: AskBuddyFloatingButton(place: 'Guwahati'),
              body: Center(child: Text('Home')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ask Buddy'), findsOneWidget);
      await tester.tap(find.text('Ask Buddy'));
      await tester.pumpAndSettle();

      expect(find.byType(AskBuddySheet), findsOneWidget);
    });
  });
}
