import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_buddy/core/widgets/main_shell_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createShellTestApp({required double width, required double height}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainShellScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      const Scaffold(body: Center(child: Text('Home Content'))),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/explore',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Explore Content')),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Profile Content')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  group('Responsive Layout Breakpoint Tests (390px, 768px, 1440px)', () {
    testWidgets(
      '1. Mobile layout at 390px width renders bottom NavigationBar and hides NavigationRail',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createShellTestApp(width: 390, height: 844));
        await tester.pumpAndSettle();

        // NavigationBar should be present for < 600px width
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.text('Home Content'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Explore'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Tablet layout at 768px width renders side NavigationRail and hides NavigationBar',
      (tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createShellTestApp(width: 768, height: 1024));
        await tester.pumpAndSettle();

        // NavigationRail should be present for >= 600px width
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text('Home Content'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Desktop layout at 1440px width enforces max width content bounds (1100px)',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createShellTestApp(width: 1440, height: 900));
        await tester.pumpAndSettle();

        // NavigationRail present
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);

        // Verify ConstrainedBox with maxWidth 1100 is in the widget tree
        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.byType(ConstrainedBox),
        );
        final has1100MaxWidth = constrainedBoxes.any(
          (box) => box.constraints.maxWidth == 1100.0,
        );
        expect(
          has1100MaxWidth,
          isTrue,
          reason: 'Must constrain wide desktop view to 1100px max width',
        );
      },
    );
  });
}
