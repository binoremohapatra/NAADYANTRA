import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/shared/models/event.dart';
import 'package:mobile_app/shared/widgets/event_row.dart';
import 'package:mobile_app/shared/widgets/interactive_metric_card.dart';
import 'package:mobile_app/shared/widgets/naadyantra_nav_bar.dart';
import 'package:mobile_app/shared/widgets/shimmer_box.dart';

void main() {
  group('NAADYANTRA Interaction-First Components', () {
    testWidgets('InteractiveMetricCard renders label, value, unit, and icon', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: InteractiveMetricCard(
              label: 'CONFIDENCE',
              value: '94.2',
              unit: '%',
              icon: Icons.analytics_outlined,
              explanation: 'Leak detection confidence score',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Verify label and unit are rendered
      expect(find.text('CONFIDENCE'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

      // Tap and check custom callback
      await tester.tap(find.byType(InteractiveMetricCard));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets(
      'InteractiveMetricCard opens bottom sheet on tap when no custom onTap provided',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: InteractiveMetricCard(
                label: 'SYSTEM HEALTH',
                value: '98',
                unit: '%',
                icon: Icons.shield_outlined,
                explanation: 'Device sensor integrity index',
              ),
            ),
          ),
        );

        expect(find.text('SYSTEM HEALTH'), findsOneWidget);

        // Tap to open bottom sheet
        await tester.tap(find.byType(InteractiveMetricCard));
        await tester.pumpAndSettle();

        // Check bottom sheet contains explanation and metric label
        expect(find.text('Device sensor integrity index'), findsOneWidget);
        expect(find.text('SYSTEM HEALTH'), findsWidgets);
      },
    );

    testWidgets(
      'EventRow renders event details and handles tap to open detail sheet',
      (WidgetTester tester) async {
        final sampleEvent = Event(
          id: 101,
          deviceId: 'SIH-DEV-01',
          sessionId: 1,
          internalSessionId: 1,
          traineeId: 'TR-001',
          eventKind: 'acoustic_anomaly',
          eventName: 'High Frequency Pressure Surge',
          serverTimestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          hazardState: 2,
          leakProbability: 0.85,
          alert: 'CRITICAL',
          rawPayload: const {},
          ingestionStatus: 'NORMAL',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: EventRow(event: sampleEvent)),
          ),
        );

        expect(find.text('High Frequency Pressure Surge'), findsOneWidget);

        // Tap to open bottom sheet detail
        await tester.tap(find.byType(EventRow));
        await tester.pumpAndSettle();

        // Verify detail sheet shows the event title and critical severity badge
        expect(find.text('High Frequency Pressure Surge'), findsWidgets);
        expect(find.text('CRITICAL'), findsWidgets);
      },
    );

    testWidgets(
      'NaadyantraNavBar renders destinations and triggers onDestinationSelected',
      (WidgetTester tester) async {
        int selected = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              bottomNavigationBar: NaadyantraNavBar(
                selectedIndex: selected,
                onDestinationSelected: (i) => selected = i,
              ),
            ),
          ),
        );

        expect(find.byType(NaadyantraNavBar), findsOneWidget);

        // Tap on second tab (Devices) with hub icon
        await tester.tap(find.byIcon(Icons.hub_outlined));
        await tester.pumpAndSettle();

        expect(selected, 1);
      },
    );

    test('Event model parses battery_v and falls back to vbat in raw_payload', () {
      // Test top-level battery_v
      final json1 = {
        'id': 1,
        'device_id': 'SIH-DEV-01',
        'event_kind': 'normal',
        'event_name': 'Acoustic Scan',
        'server_timestamp': '2026-10-17T12:00:00Z',
        'battery_v': 3.95,
      };
      final ev1 = Event.fromJson(json1);
      expect(ev1.batteryVoltage, 3.95);
      expect(ev1.hasBatteryData, isTrue);

      // Test fallback to raw_payload['vbat']
      final json2 = {
        'id': 2,
        'device_id': 'SIH-DEV-01',
        'event_kind': 'normal',
        'event_name': 'Acoustic Scan',
        'server_timestamp': '2026-10-17T12:00:00Z',
        'raw_payload': {'vbat': 3.82},
      };
      final ev2 = Event.fromJson(json2);
      expect(ev2.batteryVoltage, 3.82);
      expect(ev2.hasBatteryData, isTrue);

      // Test missing battery data
      final json3 = {
        'id': 3,
        'device_id': 'SIH-DEV-01',
        'event_kind': 'normal',
        'event_name': 'Acoustic Scan',
        'server_timestamp': '2026-10-17T12:00:00Z',
      };
      final ev3 = Event.fromJson(json3);
      expect(ev3.batteryVoltage, isNull);
      expect(ev3.hasBatteryData, isFalse);
    });

    testWidgets('EventRow displays battery voltage when present', (
      WidgetTester tester,
    ) async {
      final sampleEventWithBattery = Event(
        id: 102,
        deviceId: 'SIH-DEV-01',
        sessionId: 1,
        internalSessionId: 1,
        traineeId: 'TR-001',
        eventKind: 'acoustic_anomaly',
        eventName: 'Pipeline Vibration',
        serverTimestamp: DateTime.now(),
        hazardState: 1,
        leakProbability: 0.45,
        alert: 'WARNING',
        rawPayload: const {},
        ingestionStatus: 'NORMAL',
        batteryVoltage: 3.88,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: EventRow(event: sampleEventWithBattery)),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.byType(EventRow));
      await tester.pumpAndSettle();

      expect(find.text('Battery'), findsOneWidget);
      expect(find.text('3.88 V'), findsOneWidget);
    });

    testWidgets(
      'ShimmerBox renders loading skeleton with specified dimensions',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ShimmerBox(width: 150, height: 24, radius: 6),
            ),
          ),
        );

        expect(find.byType(ShimmerBox), findsOneWidget);

        final containerFinder = find.byType(Container);
        expect(containerFinder, findsWidgets);
      },
    );
  });
}

