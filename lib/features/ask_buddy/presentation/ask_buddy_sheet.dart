import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/auth_repository.dart';
import '../../../core/models/price_engine_models.dart';
import '../../../core/models/roadmap_models.dart';
import '../../../core/services/gemini_proxy_service.dart';
import '../../../core/services/map_launcher_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../airport_fares/presentation/airport_prepaid_fares_screen.dart';
import '../../price_checker/presentation/check_price_input_screen.dart';
import '../../roadmap/presentation/roadmap_screen.dart';
import '../../tourist_traps/presentation/tourist_traps_screen.dart';
import 'widgets/ask_buddy_message_bubble.dart';

/// Interactive "Ask Buddy" Guide Agent sheet with action cards, streaming, and sign-in gating
class AskBuddySheet extends ConsumerStatefulWidget {
  final String? initialPrompt;
  final String currentPlace;
  final String screenName;
  final bool isSidePanel;

  const AskBuddySheet({
    super.key,
    this.initialPrompt,
    this.currentPlace = 'Guwahati',
    this.screenName = 'home',
    this.isSidePanel = false,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialPrompt,
    String place = 'Guwahati',
    String screen = 'home',
  }) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    if (isWide) {
      return showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Ask Buddy Side Panel',
        barrierColor: Colors.black45,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, anim1, anim2) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            child: SizedBox(
              width: 420,
              height: double.infinity,
              child: AskBuddySheet(
                initialPrompt: initialPrompt,
                currentPlace: place,
                screenName: screen,
                isSidePanel: true,
              ),
            ),
          ),
        ),
        transitionBuilder: (ctx, anim1, anim2, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AskBuddySheet(
        initialPrompt: initialPrompt,
        currentPlace: place,
        screenName: screen,
        isSidePanel: false,
      ),
    );
  }

  @override
  ConsumerState<AskBuddySheet> createState() => _AskBuddySheetState();
}

class _AskBuddySheetState extends ConsumerState<AskBuddySheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AgentMessage> _messages = [];
  bool _isTyping = false;
  String? _errorMessage;
  String? _pendingMessage;
  String? _lastUserQuery;
  StreamSubscription<String>? _streamSub;

  final List<String> _quickPrompts = const [
    'Is Rs 1200 fair from the airport to Ganeshguri?',
    'Scams near me',
    'Plan how to reach Shillong',
    'Best time to visit',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      AgentMessage(
        id: 'welcome',
        sender: 'buddy',
        text:
            'Namaste! I am Buddy, your AI Travel Guide and Fair Price Guardian for ${widget.currentPlace}. '
            'Grounding every price in official rate cards and verified community data. How can I help today?',
        timestamp: DateTime.now(),
        actions: const [
          AgentAction(type: 'check_price', label: 'Check a Price', params: {}),
          AgentAction(type: 'airport_fares', label: 'LGBI Airport Fares', params: {}),
          AgentAction(type: 'view_traps', label: 'Tourist Trap Radar', params: {}),
        ],
      ),
    );

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    _controller.clear();

    // Sign-in Gate Check
    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    if (user == null) {
      _pendingMessage = query;
      final signedIn = await showDialog<AppUser?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Sign In Required'),
            ],
          ),
          content: const Text(
            'Sign in with Google to chat with Buddy and access real-time fare intelligence.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.account_circle_rounded),
              label: const Text('Sign in with Google'),
              onPressed: () async {
                final u = await authRepo.signInWithGoogle();
                if (ctx.mounted) Navigator.pop(ctx, u);
              },
            ),
          ],
        ),
      );

      if (signedIn != null && _pendingMessage != null) {
        final toSend = _pendingMessage!;
        _pendingMessage = null;
        await _executeSend(toSend, token: signedIn.token);
      }
      return;
    }

    await _executeSend(query, token: user.token);
  }

  Future<void> _executeSend(String query, {String? token}) async {
    _lastUserQuery = query;
    setState(() {
      _errorMessage = null;
      _messages.add(
        AgentMessage(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'user',
          text: query,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    final proxyService = ref.read(geminiProxyServiceProvider);
    final placeholderId = 'buddy_${DateTime.now().millisecondsSinceEpoch}';

    // Placeholder message for streaming tokens
    final placeholderMessage = AgentMessage(
      id: placeholderId,
      sender: 'buddy',
      text: '',
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(placeholderMessage);
    });

    final historyForApi = _messages.where((m) => m.id != placeholderId).toList();
    final buffer = StringBuffer();

    try {
      _streamSub?.cancel();
      final stream = proxyService.streamAgentMessage(
        history: historyForApi,
        currentPlace: widget.currentPlace,
        screen: widget.screenName,
        idToken: token,
        onComplete: (finalMsg) {
          if (!mounted) return;
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == placeholderId);
            if (idx != -1) {
              _messages[idx] = finalMsg;
            }
            _isTyping = false;
          });
          _scrollToBottom();
        },
      );

      _streamSub = stream.listen(
        (token) {
          buffer.write(token);
          if (!mounted) return;
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == placeholderId);
            if (idx != -1) {
              _messages[idx] = _messages[idx].copyWith(text: buffer.toString());
            }
          });
          _scrollToBottom();
        },
        onError: (err) async {
          try {
            // Fallback to non-streaming on stream interruption
            final fallbackMsg = await proxyService.sendAgentMessage(
              history: historyForApi,
              currentPlace: widget.currentPlace,
              screen: widget.screenName,
              idToken: token,
            );
            if (!mounted) return;
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == placeholderId);
              if (idx != -1) {
                _messages[idx] = fallbackMsg;
              }
              _isTyping = false;
            });
            _scrollToBottom();
          } catch (_) {
            if (!mounted) return;
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == placeholderId);
              if (idx != -1) {
                _messages[idx] = AgentMessage(
                  id: placeholderId,
                  sender: 'buddy',
                  text: 'I could not reach live intelligence right now. You can check official taxi tariffs and fair prices directly.',
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
              _isTyping = false;
              _errorMessage = 'Could not reach Ask Buddy. Please check your network and retry.';
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == placeholderId);
        if (idx != -1) {
          _messages[idx] = AgentMessage(
            id: placeholderId,
            sender: 'buddy',
            text: 'I could not reach live intelligence right now. You can check official taxi tariffs and fair prices directly.',
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
        _isTyping = false;
        _errorMessage = 'Could not reach Ask Buddy. Please check your network and retry.';
      });
    }
  }

  void _handleActionTap(AgentAction action) {
    final type = action.type;
    final params = action.params;

    if (type == 'check_price' || (type == 'open_screen' && params['screen'] == 'check_price')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckPriceInputScreen(
            initialPickupName: params['pickup'] as String? ?? 'LGBI Airport, Guwahati',
            initialDropName: (params['destination'] ?? params['drop']) as String?,
            initialQuotedPrice: (params['quotedPrice'] as num?)?.toDouble(),
          ),
        ),
      );
      return;
    }

    if (type == 'open_in_maps' || type == 'open_place') {
      final lat = (params['lat'] as num?)?.toDouble();
      final lng = (params['lng'] as num?)?.toDouble();
      final query = (params['query'] ?? params['destination']) as String?;
      final placeId = params['placeId'] as String?;
      MapLauncherService().openPlace(
        context: context,
        name: query ?? 'Destination',
        lat: lat,
        lng: lng,
        placeId: placeId,
      );
      return;
    }

    if (type == 'open_directions') {
      final dest = (params['destination'] ?? params['drop']) as String? ?? '';
      MapLauncherService().openDirections(
        context: context,
        destination: dest,
        mode: params['mode'] as String? ?? 'driving',
      );
      return;
    }

    if (type == 'roadmap' || type == 'create_roadmap' || (type == 'open_screen' && params['screen'] == 'roadmap')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoadmapScreen(
            initialOrigin: RoadmapLocation(
              name: params['origin'] as String? ?? 'Origin',
              lat: (params['originLat'] as num?)?.toDouble() ?? 26.1061,
              lng: (params['originLng'] as num?)?.toDouble() ?? 91.5859,
            ),
            initialDestination: RoadmapLocation(
              name: (params['destination'] ?? params['drop']) as String? ?? 'Destination',
              lat: (params['destLat'] as num?)?.toDouble() ?? 26.1450,
              lng: (params['destLng'] as num?)?.toDouble() ?? 91.7850,
            ),
          ),
        ),
      );
      return;
    }

    if (type == 'airport_fares' || (type == 'open_screen' && params['screen'] == 'airport_fares')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AirportPrepaidFaresScreen()),
      );
      return;
    }

    if (type == 'view_traps' || type == 'tourist_traps' || (type == 'open_screen' && params['screen'] == 'tourist_traps')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TouristTrapsScreen()),
      );
      return;
    }

    if (type == 'call_112' || type == 'emergency') {
      launchUrl(Uri.parse('tel:112'));
      return;
    }

    // Default fallback: open Check a Price
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckPriceInputScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final content = Column(
      children: [
        _buildHeader(theme),
        const Divider(height: 1),

        // Error Banner with Retry
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.danger.withOpacity(0.12),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _lastUserQuery != null ? () => _handleSend(_lastUserQuery!) : null,
                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        // Messages Feed
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isTyping) {
                return const AskBuddyTypingIndicator();
              }
              final msg = _messages[index];
              return AskBuddyMessageBubble(
                message: msg,
                onActionTap: _handleActionTap,
                onRetry: msg.sender != 'user' && _lastUserQuery != null
                    ? () => _handleSend(_lastUserQuery!)
                    : null,
              );
            },
          ),
        ),

        // Quick Suggestion Chips
        _buildQuickChips(),

        // Input Field & Disclaimer Note
        _buildInputField(theme),
      ],
    );

    if (widget.isSidePanel) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: content,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85 + bottomInset,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: content,
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ask Buddy • AI Guide',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  'Gemini 1.5 Price & Safety Agent • ${widget.currentPlace}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(
                  AgentMessage(
                    id: 'welcome',
                    sender: 'buddy',
                    text:
                        'Namaste! I am Buddy, your AI Travel Guide and Fair Price Guardian for ${widget.currentPlace}. '
                        'Grounding every price in official rate cards and verified community data. How can I help today?',
                    timestamp: DateTime.now(),
                    actions: const [
                      AgentAction(type: 'check_price', label: 'Check a Price', params: {}),
                      AgentAction(type: 'airport_fares', label: 'LGBI Airport Fares', params: {}),
                      AgentAction(type: 'view_traps', label: 'Tourist Trap Radar', params: {}),
                    ],
                  ),
                );
                _errorMessage = null;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _quickPrompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (_, i) => ActionChip(
          label: Text(_quickPrompts[i], style: const TextStyle(fontSize: 11)),
          onPressed: () => _handleSend(_quickPrompts[i]),
        ),
      ),
    );
  }

  Widget _buildInputField(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Ask Buddy query input',
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _handleSend,
                      decoration: InputDecoration(
                        hintText: 'Ask about prices, routes, or scams...',
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded),
                  tooltip: 'Send',
                  onPressed: () => _handleSend(_controller.text),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'AI can make mistakes. Check the factors shown.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
