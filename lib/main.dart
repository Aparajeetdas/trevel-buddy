import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/local_data_repository.dart';
import 'core/data/tariff_repository.dart';
import 'core/router/app_router.dart';
import 'core/services/gemini_proxy_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/async_utils.dart';
import 'core/widgets/responsive_phone_frame.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // Friendly error screen for widget build crashes (never blank white screen)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0D9488),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We encountered an issue loading this section. You can return home or reload.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => appRouter.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    };

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('⚠️ [FlutterError] ${details.exceptionAsString()}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('⚠️ [PlatformDispatcher] Unhandled platform error: $error');
      return true;
    };

    runApp(const ProviderScope(child: TravelBuddyApp()));
  }, (error, stack) {
    debugPrint('⚠️ [Uncaught Zone Error] $error\n$stack');
  });
}

class TravelBuddyApp extends ConsumerStatefulWidget {
  const TravelBuddyApp({super.key});

  @override
  ConsumerState<TravelBuddyApp> createState() => _TravelBuddyAppState();
}

class _TravelBuddyAppState extends ConsumerState<TravelBuddyApp> {
  @override
  void initState() {
    super.initState();
    // Non-blocking background startup tasks scheduled after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runBackgroundStartupTasks();
    });
  }

  void _runBackgroundStartupTasks() async {
    // 1. Pre-warm scam zones in background (3-5s timeout)
    unawaited(
      withTimeout(
        ref.read(appRepositoryProvider).getScamReportZones(),
        timeout: const Duration(seconds: 4),
        fallback: [],
        operationName: 'Preload Scam Zones',
      ).then((_) {}),
    );

    // 2. Pre-warm tariffs in background (3-5s timeout)
    unawaited(
      withTimeout(
        ref.read(govTariffRepositoryProvider).getTariffs(),
        timeout: const Duration(seconds: 4),
        fallback: [],
        operationName: 'Preload Tariffs',
      ).then((_) {}),
    );

    // 3. Check proxy availability in background (3s timeout)
    unawaited(
      withTimeout(
        Future(() async {
          try {
            final _ = ref.read(geminiProxyServiceProvider);
            debugPrint('🔍 [Startup] Proxy initialized');
          } catch (e) {
            debugPrint('ℹ️ [Startup] Operating in offline mode: $e');
          }
        }),
        timeout: const Duration(seconds: 3),
        operationName: 'Proxy Check',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Travel Buddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        return ResponsivePhoneFrame(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
