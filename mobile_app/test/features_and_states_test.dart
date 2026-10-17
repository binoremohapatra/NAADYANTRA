import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/shared/widgets/state_views.dart';
import 'package:mobile_app/features/help/screens/help_screen.dart';
import 'package:mobile_app/shared/models/assessment.dart';
import 'package:mobile_app/shared/models/session.dart';
import 'package:mobile_app/shared/models/common.dart';
import 'package:mobile_app/features/assessments/screens/assessment_list_screen.dart';
import 'package:mobile_app/features/assessments/screens/assessment_detail_screen.dart';
import 'package:mobile_app/features/sessions/screens/session_list_screen.dart';
import 'package:mobile_app/features/devices/screens/device_details_screen.dart';
import 'package:mobile_app/shared/models/device.dart';
import 'package:mobile_app/shared/models/event.dart';
import 'package:mobile_app/shared/services/providers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  group('Diagnostic State Views (Loading, Error, Empty)', () {
    testWidgets(
      'IndustrialLoadingView renders message and progress indicator',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: IndustrialLoadingView(
                message: 'Calibrating acoustic sensors...',
              ),
            ),
          ),
        );

        expect(find.text('Calibrating acoustic sensors...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'IndustrialErrorView renders title, message, and retry button',
      (WidgetTester tester) async {
        bool retried = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IndustrialErrorView(
                title: 'Ingestion Bus Timeout',
                message: 'ESP32 failed handshake on serial channel',
                onRetry: () => retried = true,
              ),
            ),
          ),
        );

        expect(find.text('Ingestion Bus Timeout'), findsOneWidget);
        expect(
          find.text('ESP32 failed handshake on serial channel'),
          findsOneWidget,
        );
        expect(find.text('Retry Connection'), findsOneWidget);

        await tester.tap(find.text('Retry Connection'));
        expect(retried, isTrue);
      },
    );

    testWidgets('IndustrialEmptyView renders action button and message', (
      WidgetTester tester,
    ) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IndustrialEmptyView(
              icon: Icons.history_rounded,
              title: 'No Telemetry Archives',
              message: 'Trigger an inspection session to record records.',
              actionLabel: 'Initiate Scan',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No Telemetry Archives'), findsOneWidget);
      expect(find.text('Initiate Scan'), findsOneWidget);

      await tester.tap(find.text('Initiate Scan'));
      expect(actionTapped, isTrue);
    });
  });

  group('Field Guide & Troubleshooting Screen', () {
    testWidgets('HelpScreen renders safety warning and category filter pills', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('FIELD GUIDE & TROUBLESHOOTING'), findsOneWidget);
      expect(find.text('VOCATIONAL TRAINING INSTRUMENT ONLY'), findsOneWidget);
      expect(find.text('ALL TOPICS'), findsOneWidget);
      expect(find.text('HARDWARE & SENSORS'), findsOneWidget);
      expect(find.text('METRICS & FORMULAS'), findsOneWidget);
    });

    testWidgets('HelpScreen expands question accordion on tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final questionFinder = find.text(
        'Why are Heat and UV sensors marked DISABLED?',
      );
      expect(questionFinder, findsOneWidget);

      await tester.tap(questionFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('thermal and UV photodiodes are de-energized'),
        findsOneWidget,
      );
    });
  });

  group('Vocational Assessment Screens', () {
    testWidgets('AssessmentListScreen renders items and passing badge', (
      WidgetTester tester,
    ) async {
      final mockAssessment = Assessment(
        id: 1,
        assessmentId: 'EVAL-MOCK-01',
        sessionId: 42,
        traineeId: 'TR-DEMO',
        rubricId: 'RUBRIC-PIPE-01',
        rubricVersion: '1.0',
        evidenceEventIds: [10, 11],
        score: 88.0,
        maxScore: 100.0,
        outcome: 'PASS',
        scoringExplanation:
            'Candidate verified leak isolation within tolerance.',
        createdBy: 'trainer_01',
        createdAt: DateTime(2026, 10, 13, 10, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assessmentsProvider.overrideWith(
              (ref) => Future.value(
                PaginatedResponse<Assessment>(
                  total: 1,
                  page: 1,
                  pageSize: 20,
                  items: [mockAssessment],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: AssessmentListScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('VOCATIONAL EVALUATIONS'), findsOneWidget);
      expect(find.text('TRAINEE #TR-DEMO'), findsOneWidget);
      expect(find.text('COMPETENT'), findsOneWidget);
      expect(find.text('88 / 100 pts (88%)'), findsOneWidget);
    });

    testWidgets('AssessmentDetailScreen renders detailed metadata and notes', (
      WidgetTester tester,
    ) async {
      final mockAssessment = Assessment(
        id: 1,
        assessmentId: 'eval-detail-99',
        sessionId: 108,
        traineeId: 'TR-TEST',
        rubricId: 'RUBRIC-HIGH-PRESSURE',
        rubricVersion: '2.0',
        evidenceEventIds: [101, 102],
        score: 95.0,
        maxScore: 100.0,
        outcome: 'CERTIFIED',
        scoringExplanation: 'Flawless flange acoustic survey.',
        createdBy: 'lead_trainer',
        createdAt: DateTime(2026, 10, 13, 12, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assessmentDetailProvider('eval-detail-99')
                .overrideWith((ref) => Future.value(mockAssessment)),
          ],
          child: const MaterialApp(
            home: AssessmentDetailScreen(assessmentId: 'eval-detail-99'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('EVALUATION #EVAL-DETAIL-99'), findsOneWidget);
      expect(find.text('Trainee: TR-TEST'), findsOneWidget);
      expect(find.text('Flawless flange acoustic survey.'), findsOneWidget);
      expect(find.text('EVT #101'), findsOneWidget);
      expect(find.text('EVT #102'), findsOneWidget);
    });
  });

  group('Session List Screen & Offline Cache Banner', () {
    testWidgets(
      'SessionListScreen displays OFFLINE BUFFER banner when data is cached',
      (WidgetTester tester) async {
        final mockSession = Session(
          id: 1,
          sessionId: 77,
          deviceId: 'SIH-NODE-01',
          traineeId: 'TR-OFFLINE',
          startedAt: DateTime(2026, 10, 13, 8, 30),
          endedAt: DateTime(2026, 10, 13, 9, 30),
          sessionMetadata: const {},
          createdAt: DateTime(2026, 10, 13, 8, 30),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionsProvider('1,20').overrideWith(
                (ref) => Future.value(
                  PaginatedResponse<Session>(
                    total: 1,
                    page: 1,
                    pageSize: 20,
                    items: [mockSession],
                    isFromCache: true,
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: SessionListScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('SESSION ARCHIVE'), findsOneWidget);
        expect(
          find.text('OFFLINE BUFFER — DISPLAYING PERSISTED SQLITE CACHE'),
          findsOneWidget,
        );
        expect(find.text('SESSION #77'), findsOneWidget);
      },
    );
  });

  group('Device Details Screen — Telemetry Visibility & Honest Disclosure', () {
    final mockDevice = Device(
      id: 1,
      deviceId: 'SIH-NODE-01',
      name: 'Flange Acoustic Probe',
      firmwareVersion: 'v2.4.1',
      lastSeenAt: DateTime(2026, 10, 13, 12, 0),
      deviceMetadata: {'location': 'Test Bench A'},
      createdAt: DateTime(2026, 10, 1, 0, 0),
      isActive: true,
    );

    final mockStatus = DeviceStatus(
      deviceId: 'SIH-NODE-01',
      lastSeenAt: DateTime(2026, 10, 13, 12, 0),
      firmwareVersion: 'v2.4.1',
      isOnline: true,
      recentActivityCount: 5,
      lastError: null,
    );

    final mockEvent = Event(
      id: 101,
      deviceId: 'SIH-NODE-01',
      sessionId: 42,
      internalSessionId: 1,
      traineeId: 'TR-01',
      eventKind: 'event',
      deviceTimestamp: 120500,
      serverTimestamp: DateTime(2026, 10, 13, 12, 0),
      deviceUptimeMs: 345000,
      eventName: 'LEAK_DETECTED',
      alert: 'HIGH',
      cause: 'RMS_EXCEEDED',
      modelLabel: 'HIGH_FREQ_LEAK',
      leakProbability: 0.94,
      rms: 382.5,
      gasDelta: 45,
      gasRatio: 0.82,
      temperature: null,
      uvDelta: null,
      wet: false,
      firmwareVersion: 'v2.4.1',
      rawPayload: {
        't': 120500,
        'up': 345000,
        'ev': 'LEAK_DETECTED',
        'rms': 382.5,
        'gas': 45,
        'gr': 0.82,
        'pl': 0.94,
      },
      ingestionStatus: 'PROCESSED',
    );

    final mockSummary = SessionSummary(
      id: 501,
      sessionId: 1,
      deviceSessionId: 42,
      deviceId: 'SIH-NODE-01',
      traineeId: 'TR-01',
      durationSeconds: 300,
      windows: 150,
      leakEvents: 3,
      gasEvents: 1,
      wetEvents: 0,
      heatEvents: 0,
      uvEvents: 0,
      noiseWindows: 12,
      maxLeakProbability: 0.94,
      firmwareVersion: 'v2.4.1',
      rawPayload: {
        'dur_s': 300,
        'windows': 150,
        'leak_events': 3,
        'max_leak_p': 0.94,
      },
      serverTimestamp: DateTime(2026, 10, 13, 12, 5),
    );

    testWidgets(
      'Renders real sensor metrics and honest disabled/unsupported hardware statuses',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              singleDeviceStatusProvider('SIH-NODE-01')
                  .overrideWith((ref) => Future.value(mockStatus)),
              singleDeviceDetailsProvider('SIH-NODE-01')
                  .overrideWith((ref) => Future.value(mockDevice)),
              deviceEventsProvider('SIH-NODE-01')
                  .overrideWith((ref) => Future.value([mockEvent])),
              deviceSummariesProvider('SIH-NODE-01')
                  .overrideWith((ref) => Future.value([mockSummary])),
            ],
            child: const MaterialApp(
              home: DeviceDetailsScreen(deviceId: 'SIH-NODE-01'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Header verification
        expect(find.text('NODE: SIH-NODE-01'), findsOneWidget);
        expect(find.textContaining('2.4.1'), findsWidgets);

        // Tab 1: Live & Sensors
        expect(find.text('382.5'), findsOneWidget); // Real Acoustic RMS
        expect(find.text('+45'), findsOneWidget); // Real Gas Delta
        expect(
          find.text('0.8'),
          findsOneWidget,
        ); // Real Gas Rs/R0 (formatted to 1 dec by readout tween)
        expect(find.text('DRY'), findsOneWidget); // Real Moisture state

        // Honest hardware disclosures (Zero fabrication)
        expect(
          find.text('DISABLED'),
          findsNWidgets(2),
        ); // Pyrometer & UV disabled in rig
        expect(
          find.text('UNSUPPORTED / HARDWARE NOT MOUNTED'),
          findsOneWidget,
        ); // IMU unmounted
        expect(
          find.text('UNSUPPORTED / NOT APPLICABLE'),
          findsOneWidget,
        ); // EMG unmounted
      },
    );

    testWidgets(
      'Navigates across Event Timeline, Summaries, Diagnostics, and Raw Telemetry tabs',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              singleDeviceStatusProvider('SIH-NODE-01')
                  .overrideWith((ref) => Future.value(mockStatus)),
              singleDeviceDetailsProvider('SIH-NODE-01')
                  .overrideWith((ref) => Future.value(mockDevice)),
              deviceEventsProvider('SIH-NODE-01')
                  .overrideWith((ref) => Future.value([mockEvent])),
              deviceSummariesProvider('SIH-NODE-01')
                  .overrideWith((ref) => Future.value([mockSummary])),
            ],
            child: const MaterialApp(
              home: DeviceDetailsScreen(deviceId: 'SIH-NODE-01'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Navigate to EVENT TIMELINE tab
        await tester.tap(find.text('EVENT TIMELINE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.textContaining('LEAK_DETECTED'), findsOneWidget);
        expect(find.textContaining('RMS_EXCEEDED'), findsOneWidget);

        // Navigate to SUMMARIES tab
        await tester.tap(find.text('SUMMARIES'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.text('SESSION #42 SUMMARY'), findsOneWidget);
        expect(find.text('DURATION: 300s'), findsOneWidget);
        expect(find.text('WINDOWS SAMPLED'), findsOneWidget);

        // Navigate to DIAGNOSTICS tab
        await tester.tap(find.text('DIAGNOSTICS'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('HARDWARE & BUS SPECIFICATIONS'), findsOneWidget);
        expect(find.textContaining('4000 Hz'), findsOneWidget);

        // Navigate to RAW TELEMETRY tab
        await tester.ensureVisible(find.text('RAW TELEMETRY'));
        await tester.tap(find.text('RAW TELEMETRY'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.textContaining('LATEST EVENT PAYLOADS'), findsOneWidget);
        expect(find.textContaining('EVENT #101'), findsOneWidget);
      },
    );

    group('Offline Connectivity State Providers', () {
      test(
        'isOfflineProvider resolves true when connectivity stream emits none',
        () async {
          final container = ProviderContainer(
            overrides: [
              connectivityStreamProvider.overrideWith(
                (ref) => Stream.value([ConnectivityResult.none]),
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(connectivityStreamProvider.future);
          final isOffline = container.read(isOfflineProvider);
          expect(isOffline, isTrue);
        },
      );

      test(
        'isOfflineProvider resolves false when connectivity stream emits wifi',
        () async {
          final container = ProviderContainer(
            overrides: [
              connectivityStreamProvider.overrideWith(
                (ref) => Stream.value([ConnectivityResult.wifi]),
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(connectivityStreamProvider.future);
          final isOffline = container.read(isOfflineProvider);
          expect(isOffline, isFalse);
        },
      );
    });
  });
}
