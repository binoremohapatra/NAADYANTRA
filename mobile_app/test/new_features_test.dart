import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/features/devices/screens/device_list_screen.dart';
import 'package:mobile_app/shared/motion/acoustic_hero_widget.dart';
import 'package:mobile_app/shared/widgets/connectivity_banner.dart';
import 'package:mobile_app/shared/models/common.dart';
import 'package:mobile_app/shared/models/device.dart';
import 'package:mobile_app/shared/services/providers.dart';
import 'package:mobile_app/shared/widgets/sahai_logo.dart';
import 'package:mobile_app/shared/widgets/haze_guard_logo.dart';
import 'package:mobile_app/shared/widgets/one_shot_animated_logo.dart';
import 'package:mobile_app/features/authentication/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AcousticHeroWidget Tests', () {
    testWidgets('renders idle state with correct label and RepaintBoundary', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AcousticHeroWidget(
              isLive: false,
              statusLabel: 'SYSTEM READY — IDLE',
            ),
          ),
        ),
      );

      expect(find.text('SYSTEM READY — IDLE'), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('renders active monitoring state with live label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AcousticHeroWidget(
              isLive: true,
              statusLabel: 'LIVE TELEMETRY STREAMING',
            ),
          ),
        ),
      );

      expect(find.text('LIVE TELEMETRY STREAMING'), findsOneWidget);
    });
  });

  group('ConnectivityBanner Tests', () {
    testWidgets('renders nothing when online', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isOfflineProvider.overrideWith((ref) => false)],
          child: const MaterialApp(home: Scaffold(body: ConnectivityBanner())),
        ),
      );

      expect(
        find.text('No network connection — showing cached data'),
        findsNothing,
      );
    });

    testWidgets('renders amber banner when offline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isOfflineProvider.overrideWith((ref) => true)],
          child: const MaterialApp(home: Scaffold(body: ConnectivityBanner())),
        ),
      );

      expect(
        find.text('No network connection — showing cached data'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });

  group('DeviceListScreen Tests', () {
    final mockDevices = [
      Device(
        id: 1,
        deviceId: 'SIH-DEV-01',
        name: 'Acoustic Flange Monitor A',
        firmwareVersion: 'v2.1.0',
        lastSeenAt: DateTime.now().subtract(const Duration(minutes: 5)),
        deviceMetadata: {'location': 'Zone A'},
        createdAt: DateTime(2026, 1, 1),
        isActive: true,
      ),
      Device(
        id: 2,
        deviceId: 'SIH-DEV-02',
        name: 'Bearing Resonator B',
        firmwareVersion: 'v2.0.8',
        lastSeenAt: DateTime.now().subtract(const Duration(days: 2)),
        deviceMetadata: {'location': 'Zone B'},
        createdAt: DateTime(2026, 1, 1),
        isActive: false,
      ),
    ];

    testWidgets('renders search field, filter chips, and device cards', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devicesProvider.overrideWith(
              (ref) => Future.value(
                PaginatedResponse<Device>(
                  total: 2,
                  page: 1,
                  pageSize: 20,
                  items: mockDevices,
                  isFromCache: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: DeviceListScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DEVICE INVENTORY'), findsOneWidget);
      expect(find.text('Search by name or device ID...'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Acoustic Flange Monitor A'), findsOneWidget);
      expect(find.text('Bearing Resonator B'), findsOneWidget);
    });
  });

  group('Haze Guard Logo Tests', () {
    testWidgets('renders static PNG logo with correct asset and containment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SahaiLogo(size: 48))),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(
        (imageWidget.image as AssetImage).assetName,
        'assets/icons/Haze_Guard_Logo_Static_Transparent.png',
      );
      expect(imageWidget.width, 48);
      expect(imageWidget.height, 48);
      expect(imageWidget.fit, BoxFit.contain);
    });

    testWidgets('HazeGuardLogo renders static transparent PNG', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HazeGuardLogo(size: 56))),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(
        (imageWidget.image as AssetImage).assetName,
        'assets/icons/Haze_Guard_Logo_Static_Transparent.png',
      );
      expect(imageWidget.width, 56);
      expect(imageWidget.height, 56);
      expect(imageWidget.fit, BoxFit.contain);
    });

    test(
      'OneShotAnimatedLogo points to exact Haze Guard inward animation files',
      () {
        expect(
          OneShotAnimatedLogo.animatedAssetPath,
          'assets/icons/Haze_Guard_Logo_Assembly_Inward.gif',
        );
        expect(
          OneShotAnimatedLogo.restingAssetPath,
          'assets/icons/Haze_Guard_Logo_Static_Transparent.png',
        );
      },
    );
  });

  group('Clean SplashScreen Tests', () {
    testWidgets('renders minimal splash screen without radiation or glow', (
      WidgetTester tester,
    ) async {
      OneShotAnimatedLogo.resetLaunchState();

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SplashScreen())),
      );

      // Splash shows the HAZEGUARD wordmark and a progress indicator
      expect(find.text('HAZEGUARD'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // OneShotAnimatedLogo widget should be present
      expect(find.byType(OneShotAnimatedLogo), findsOneWidget);
    });
  });
}
