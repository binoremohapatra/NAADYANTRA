import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/services/providers.dart';
import '../features/authentication/screens/login_screen.dart';
import '../features/authentication/screens/splash_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/devices/screens/device_details_screen.dart';
import '../features/devices/screens/device_list_screen.dart';
import '../features/sessions/screens/session_list_screen.dart';
import '../features/sessions/screens/session_detail_screen.dart';
import '../features/events/screens/events_screen.dart';
import '../features/settings/screens/settings_screen.dart';

import '../features/assessments/screens/assessment_list_screen.dart';
import '../features/assessments/screens/assessment_detail_screen.dart';
import '../features/help/screens/help_screen.dart';
import '../shared/widgets/state_views.dart';

// Router Provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final path = state.uri.toString();
      // Let splash handle its own auth-check navigation.
      if (path == '/splash') return null;
      if (!authState.isAuthenticated && path != '/login') {
        return '/login';
      }
      if (authState.isAuthenticated && path == '/login') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/devices',
        name: 'device-list',
        builder: (context, state) => const DeviceListScreen(),
      ),
      GoRoute(
        path: '/devices/:deviceId',
        name: 'device-details',
        builder: (context, state) {
          final deviceId = state.pathParameters['deviceId']!;
          return DeviceDetailsScreen(deviceId: deviceId);
        },
      ),
      GoRoute(
        path: '/sessions',
        name: 'sessions',
        builder: (context, state) => const SessionListScreen(),
      ),
      GoRoute(
        path: '/sessions/:sessionId',
        name: 'session-detail',
        builder: (context, state) {
          final sessionId = int.parse(state.pathParameters['sessionId']!);
          return SessionDetailScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/events',
        name: 'events',
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/assessments',
        name: 'assessments',
        builder: (context, state) => const AssessmentListScreen(),
      ),
      GoRoute(
        path: '/assessments/:assessmentId',
        name: 'assessment-detail',
        builder: (context, state) {
          final assessmentId = state.pathParameters['assessmentId']!;
          return AssessmentDetailScreen(assessmentId: assessmentId);
        },
      ),
      GoRoute(
        path: '/help',
        name: 'help',
        builder: (context, state) => const HelpScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: IndustrialEmptyView(
        icon: Icons.alt_route_rounded,
        title: 'Diagnostic Route Not Found',
        message: 'Endpoint: ${state.uri}',
        actionLabel: 'Return to Terminal',
        onAction: () => context.go('/'),
      ),
    ),
  );
});
