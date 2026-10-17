import 'package:flutter/material.dart';

/// Decorative, screen-specific NAADYANTRA backdrop.
///
/// Bundled under `assets/animations/backgrounds/light/`, `dark/`, and `fallback/`.
/// Keep the owning Scaffold transparent for the backdrop to show.
enum NaadyantraBackgroundKind {
  splash,
  login,
  homeOverview,
  deviceInventory,
  inspection,
  deviceDetails,
  sessions,
  sessionDetails,
  events,
  eventDetails,
  assessments,
  assessmentDetails,
  settings,
  helpFieldGuide,
}

extension NaadyantraBackgroundAssets on NaadyantraBackgroundKind {
  String get fileName => switch (this) {
    NaadyantraBackgroundKind.splash => 'splash',
    NaadyantraBackgroundKind.login => 'login',
    NaadyantraBackgroundKind.homeOverview => 'home_overview',
    NaadyantraBackgroundKind.deviceInventory => 'device_inventory',
    NaadyantraBackgroundKind.inspection => 'inspection',
    NaadyantraBackgroundKind.deviceDetails => 'device_details',
    NaadyantraBackgroundKind.sessions => 'sessions',
    NaadyantraBackgroundKind.sessionDetails => 'session_details',
    NaadyantraBackgroundKind.events => 'events',
    NaadyantraBackgroundKind.eventDetails => 'event_details',
    NaadyantraBackgroundKind.assessments => 'assessments',
    NaadyantraBackgroundKind.assessmentDetails => 'assessment_details',
    NaadyantraBackgroundKind.settings => 'settings',
    NaadyantraBackgroundKind.helpFieldGuide => 'help_field_guide',
  };

  /// Light theme animated background GIF
  String get lightGifAsset =>
      'assets/animations/backgrounds/light/${fileName}_light.gif';

  /// Dark theme animated background GIF
  String get darkGifAsset =>
      'assets/animations/backgrounds/dark/${fileName}_dark.gif';

  /// Light theme static PNG fallback
  String get lightFallbackAsset =>
      'assets/animations/backgrounds/fallback/light/${fileName}_light.png';

  /// Dark theme static PNG fallback
  String get darkFallbackAsset =>
      'assets/animations/backgrounds/fallback/dark/${fileName}_dark.png';

  /// Resolves the theme-specific GIF asset
  String gifAssetFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkGifAsset : lightGifAsset;

  /// Resolves the theme-specific fallback PNG asset
  String fallbackAssetFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkFallbackAsset : lightFallbackAsset;

  /// Backward-compatible legacy getters for testing and compatibility
  bool get isDark => switch (this) {
    NaadyantraBackgroundKind.login ||
    NaadyantraBackgroundKind.deviceInventory ||
    NaadyantraBackgroundKind.inspection ||
    NaadyantraBackgroundKind.sessions ||
    NaadyantraBackgroundKind.events ||
    NaadyantraBackgroundKind.assessments ||
    NaadyantraBackgroundKind.settings => true,
    _ => false,
  };

  String get gifAsset => 'assets/animations/backgrounds/$fileName.gif';
  String get posterAsset =>
      'assets/animations/backgrounds/posters/$fileName.jpg';
}

class NaadyantraAnimatedBackground extends StatelessWidget {
  const NaadyantraAnimatedBackground({
    super.key,
    required this.kind,
    required this.child,
    this.lightScrimOpacity = 0.76,
    this.darkScrimOpacity = 0.48,
  });

  final NaadyantraBackgroundKind kind;
  final Widget child;
  final double lightScrimOpacity;
  final double darkScrimOpacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final primaryAsset = reduceMotion
        ? (isDark ? kind.darkFallbackAsset : kind.lightFallbackAsset)
        : (isDark ? kind.darkGifAsset : kind.lightGifAsset);

    final fallbackAsset = isDark
        ? kind.darkFallbackAsset
        : kind.lightFallbackAsset;

    final scrimOpacity = isDark ? darkScrimOpacity : lightScrimOpacity;
    final scrimColor = isDark
        ? const Color(0xFF0F1113)
        : const Color(0xFFF7F5F0);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  child: Image.asset(
                    primaryAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Image.asset(
                      fallbackAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => ColoredBox(color: scrimColor),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: scrimColor.withValues(alpha: scrimOpacity),
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
