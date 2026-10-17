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
