import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/shared/backgrounds/naadyantra_animated_background.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NaadyantraAnimatedBackground Asset Contract Tests', () {
    test('all 14 background kinds define valid filenames and asset paths', () {
      expect(NaadyantraBackgroundKind.values.length, 14);

      for (final kind in NaadyantraBackgroundKind.values) {
        expect(kind.fileName, isNotEmpty);
        expect(
          kind.lightGifAsset,
          startsWith('assets/animations/backgrounds/light/'),
        );
        expect(kind.lightGifAsset, endsWith('_light.gif'));
        expect(
          kind.darkGifAsset,
          startsWith('assets/animations/backgrounds/dark/'),
        );
        expect(kind.darkGifAsset, endsWith('_dark.gif'));

        expect(
          kind.lightFallbackAsset,
          startsWith('assets/animations/backgrounds/fallback/light/'),
        );
        expect(kind.lightFallbackAsset, endsWith('_light.png'));
        expect(
          kind.darkFallbackAsset,
          startsWith('assets/animations/backgrounds/fallback/dark/'),
        );
        expect(kind.darkFallbackAsset, endsWith('_dark.png'));

        expect(kind.gifAssetFor(Brightness.light), kind.lightGifAsset);
        expect(kind.gifAssetFor(Brightness.dark), kind.darkGifAsset);
        expect(
          kind.fallbackAssetFor(Brightness.light),
          kind.lightFallbackAsset,
        );
        expect(kind.fallbackAssetFor(Brightness.dark), kind.darkFallbackAsset);

        // Backward compatibility
        expect(kind.gifAsset, startsWith('assets/animations/backgrounds/'));
        expect(kind.gifAsset, endsWith('.gif'));
      }
    });

    test('expected asset mapping matches screen operational purposes', () {
      expect(
        NaadyantraBackgroundKind.splash.lightGifAsset,
        'assets/animations/backgrounds/light/splash_light.gif',
      );
      expect(
        NaadyantraBackgroundKind.splash.darkGifAsset,
        'assets/animations/backgrounds/dark/splash_dark.gif',
      );
      expect(
        NaadyantraBackgroundKind.homeOverview.lightGifAsset,
        'assets/animations/backgrounds/light/home_overview_light.gif',
      );
      expect(
        NaadyantraBackgroundKind.homeOverview.darkGifAsset,
        'assets/animations/backgrounds/dark/home_overview_dark.gif',
      );
      expect(
        NaadyantraBackgroundKind.deviceInventory.lightGifAsset,
        'assets/animations/backgrounds/light/device_inventory_light.gif',
      );
      expect(
        NaadyantraBackgroundKind.deviceInventory.darkGifAsset,
        'assets/animations/backgrounds/dark/device_inventory_dark.gif',
      );
      expect(
        NaadyantraBackgroundKind.inspection.lightGifAsset,
        'assets/animations/backgrounds/light/inspection_light.gif',
      );
      expect(
        NaadyantraBackgroundKind.inspection.darkGifAsset,
        'assets/animations/backgrounds/dark/inspection_dark.gif',
      );
      expect(
        NaadyantraBackgroundKind.sessions.lightGifAsset,
        'assets/animations/backgrounds/light/sessions_light.gif',
      );
      expect(
        NaadyantraBackgroundKind.sessions.darkGifAsset,
        'assets/animations/backgrounds/dark/sessions_dark.gif',
      );
      expect(
        NaadyantraBackgroundKind.settings.lightGifAsset,
        'assets/animations/backgrounds/light/settings_light.gif',
      );
      expect(
        NaadyantraBackgroundKind.settings.darkGifAsset,
        'assets/animations/backgrounds/dark/settings_dark.gif',
      );
    });
  });

  group('NaadyantraAnimatedBackground Widget Rendering Tests', () {
    testWidgets(
      'renders foreground child and isolates background in RepaintBoundary',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NaadyantraAnimatedBackground(
                kind: NaadyantraBackgroundKind.homeOverview,
                child: Center(child: Text('FOREGROUND_CONTENT')),
              ),
            ),
          ),
        );

        expect(find.text('FOREGROUND_CONTENT'), findsOneWidget);
        expect(find.byType(RepaintBoundary), findsWidgets);
        expect(find.byType(IgnorePointer), findsWidgets);
        expect(find.byType(ExcludeSemantics), findsWidgets);
      },
    );

    testWidgets('respects custom scrim opacity in light and dark themes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: NaadyantraAnimatedBackground(
              kind: NaadyantraBackgroundKind.login,
              lightScrimOpacity: 0.85,
              darkScrimOpacity: 0.65,
              child: Text('LIGHT_LOGIN_PAGE'),
            ),
          ),
        ),
      );

      expect(find.text('LIGHT_LOGIN_PAGE'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: NaadyantraAnimatedBackground(
              kind: NaadyantraBackgroundKind.login,
              lightScrimOpacity: 0.85,
              darkScrimOpacity: 0.65,
              child: Text('DARK_LOGIN_PAGE'),
            ),
          ),
        ),
      );

      expect(find.text('DARK_LOGIN_PAGE'), findsOneWidget);
    });
  });
}
