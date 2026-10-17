import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/one_shot_animated_logo.dart';
import '../../../shared/backgrounds/naadyantra_animated_background.dart';

// ──────────────────────────────────────────────────────────────────────────────
// SPLASH SCREEN — Haze Guard One-Time Logo Assembly Launch Experience
//
// Sequence:
//   1. Screen fades in.
//   2. OneShotAnimatedLogo plays the 45-frame segment-assembly animation once.
//   3. Logo holds briefly as the assembled mark, then settles into resting PNG.
//   4. Screen fades out and navigates to login or home.
//
// No radiation rings, glow, particles, rotations, or looping.
// ──────────────────────────────────────────────────────────────────────────────

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Controls the whole-screen entrance/exit fade.
  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _fadeOut;

  bool _navigationComplete = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // First 600 ms: fade in; last 600 ms reserved for exit.
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInCubic),
      ),
    );

    // Start entrance fade immediately
    _fadeController.animateTo(0.5, duration: const Duration(milliseconds: 600));
  }

  /// Called by [OneShotAnimatedLogo] when the assembly animation and hold finish.
  Future<void> _onLogoCompleted() async {
    if (_navigationComplete || !mounted) return;

    try {
      // Fade out the splash screen
      await _fadeController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInCubic,
      );
    } catch (_) {
      // Ticker cancelled on dispose — ignore
    }

    if (!mounted || _navigationComplete) return;
    _navigationComplete = true;

    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated) {
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0D0E) : AppColors.industrialIvory;

    return Scaffold(
      backgroundColor: bg,
      body: NaadyantraAnimatedBackground(
        kind: NaadyantraBackgroundKind.splash,
        lightScrimOpacity: 0.80,
        darkScrimOpacity: 0.60,
        child: AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            return Opacity(
              // Fade in via _fadeIn then fade out via _fadeOut
              opacity: _fadeController.value <= 0.5
                  ? _fadeIn.value
                  : _fadeOut.value,
              child: child,
            );
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // One-time Haze Guard logo inward assembly animation.
                // Plays 55 frames inward from outside → seamlessly locks into resting mark → static PNG.
                OneShotAnimatedLogo(
                  size: 160,
                  animationDuration: const Duration(milliseconds: 2000),
                  holdDuration: const Duration(milliseconds: 400),
                  onCompleted: _onLogoCompleted,
                ),

                const SizedBox(height: 36),

                // Subtle, honest status text — no decorative effects
                Text(
                  'HAZGUARD',
                  style: AppTypography.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.warmGraphite,
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.burntOrange,
                    ),
                    backgroundColor: isDark
                        ? AppColors.darkBorder
                        : AppColors.warmStone,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
