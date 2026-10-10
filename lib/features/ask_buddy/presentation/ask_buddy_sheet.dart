import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/price_engine_models.dart';
import '../../../core/models/roadmap_models.dart';
import '../../../core/services/gemini_proxy_service.dart';
import '../../../core/services/map_launcher_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../airport_fares/presentation/airport_prepaid_fares_screen.dart';
import '../../price_checker/presentation/check_price_input_screen.dart';
import '../../ride/presentation/ride_mode_screen.dart';
import '../../roadmap/presentation/roadmap_screen.dart';
import '../../tourist_traps/presentation/tourist_traps_screen.dart';
import 'widgets/ask_buddy_message_bubble.dart';

/// Interactive "Ask Buddy" Guide Agent sheet with action cards and local tool handling
class AskBuddySheet extends ConsumerStatefulWidget {
  final String? initialPrompt;
  final String currentPlace;

  const AskBuddySheet({
    super.key,
    this.initialPrompt,
    this.currentPlace = 'Jaipur',
  });

  static Future<void> show(
    BuildContext context, {
    String? initialPrompt,
    String place = 'Jaipur',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AskBuddySheet(initialPrompt: initialPrompt, currentPlace: place),
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

  final List<String> _quickPrompts = const [
    'Is ₹250 auto fair here?',
    'Top tourist scams nearby?',
    'How do I bargain politely?',
    'Prepaid taxi rates from station',
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
            'How can I help protect your journey and wallet today?',
        timestamp: DateTime.now(),
        actions: const [
          AgentAction(type: 'check_price', label: 'Check a Price', params: {}),
          AgentAction(type: 'view_traps', label: 'Tourist Trap DB', params: {}),
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    _controller.clear();

    setState(() {
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
    final response = await proxyService.sendAgentMessage(
      history: _messages,
      currentPlace: widget.currentPlace,
    );

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(response);
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  static const Set<String> _allowedToolTypes = {
    'check_price',
    'checkPrice',
    'getAirportPrepaidFare',
    'get_airport_prepaid_fare',
    'view_traps',
    'getScamRadar',
    'start_ride',
    'go_here',
    'create_roadmap',
    'createRoadmap',
    'open_maps',
    'open_in_maps',
    'open_place',
    'openInMaps',
    'open_directions',
    'openDirections',
    'open_screen',
    'openScreen',
  };

  static const Set<String> _allowedScreens = {
    'check_price',
    'airport_fares',
    'tourist_traps',
    'ride_mode',
    'explore',
    'history',
    'profile',
    'roadmap',
  };

  void _executeAction(AgentAction action) {
    if (!_allowedToolTypes.contains(action.type)) {
      debugPrint('[SECURITY] Action rejected outside tool allowlist: ${action.type}');
      return;
    }

    Navigator.pop(context);
    if (action.type == 'getAirportPrepaidFare' ||
        action.type == 'get_airport_prepaid_fare') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AirportPrepaidFaresScreen()),
      );
    } else if (action.type == 'check_price' || action.type == 'checkPrice') {
      final pickup = action.params['pickup'] as String?;
      final drop = (action.params['drop'] ?? action.params['destination']) as String?;
      final quoted = (action.params['quoted'] as num?)?.toDouble();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckPriceInputScreen(
            initialPickupName: pickup,
            initialDropName: drop,
            initialQuotedPrice: quoted,
          ),
        ),
      );
    } else if (action.type == 'view_traps' || action.type == 'getScamRadar') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TouristTrapsScreen()),
      );
    } else if (action.type == 'start_ride') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RideModeScreen()),
      );
    } else if (action.type == 'go_here' ||
        action.type == 'create_roadmap' ||
        action.type == 'createRoadmap') {
      final dest =
          (action.params['destination'] as String?) ?? widget.currentPlace;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoadmapScreen(
            initialDestination: RoadmapLocation(
              name: dest,
              lat: (action.params['lat'] as num?)?.toDouble() ?? 26.9855,
              lng: (action.params['lng'] as num?)?.toDouble() ?? 75.8513,
            ),
          ),
        ),
      );
    } else if (action.type == 'open_maps' ||
        action.type == 'open_in_maps' ||
        action.type == 'open_place' ||
        action.type == 'openInMaps') {
      final name =
          (action.params['name'] as String?) ??
          (action.params['destination'] as String?);
      final lat = (action.params['lat'] as num?)?.toDouble();
      final lng = (action.params['lng'] as num?)?.toDouble();
      final placeId = action.params['placeId'] as String?;
      ref
          .read(mapLauncherServiceProvider)
          .openPlace(placeId: placeId, name: name, lat: lat, lng: lng);
    } else if (action.type == 'open_directions' ||
        action.type == 'openDirections') {
      final origin = action.params['origin'] as String?;
      final destination = action.params['destination'] as String?;
      final mode = (action.params['mode'] as String?) ?? 'driving';
      ref
          .read(mapLauncherServiceProvider)
          .openDirections(origin: origin, destination: destination, mode: mode);
    } else if (action.type == 'open_screen' || action.type == 'openScreen') {
      final screen = (action.params['screen'] as String? ?? '').toLowerCase();
      if (_allowedScreens.contains(screen)) {
        if (screen == 'check_price') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CheckPriceInputScreen()),
          );
        } else if (screen == 'airport_fares') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AirportPrepaidFaresScreen(),
            ),
          );
        } else if (screen == 'tourist_traps') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TouristTrapsScreen()),
          );
        } else if (screen == 'ride_mode') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RideModeScreen()),
          );
        } else if (screen == 'roadmap') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RoadmapScreen(
                initialDestination: RoadmapLocation(
                  name: 'Jaipur',
                  lat: 26.9124,
                  lng: 75.7873,
                ),
              ),
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Action: ${action.label}')));
    }
  }

  Widget _buildAiDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.amber.withOpacity(0.08),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: Colors.amber),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'AI explanations can make mistakes. Check the factors shown.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          _buildAiDisclaimer(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return const AskBuddyTypingIndicator();
                }
                return AskBuddyMessageBubble(
                  message: _messages[index],
                  onActionTap: _executeAction,
                );
              },
            ),
          ),
          _buildQuickChips(),
          _buildInputField(theme),
        ],
      ),
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
            icon: const Icon(Icons.close_rounded),
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
        child: Row(
          children: [
            Expanded(
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
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send_rounded),
              onPressed: () => _handleSend(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}
