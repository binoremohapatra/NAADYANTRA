import 'package:flutter/material.dart';

/// Permanent Haze Guard static brand logo widget.
///
/// Complies strictly with brand directives:
/// - Static PNG only (`Haze_Guard_Logo_Static_Transparent.png`).
/// - Never animated GIF/WebP, never rotating, scaling, or pulsating in permanent branding.
/// - Preserves original logo geometry, proportions, orientation, and colours.
/// - Preserves transparency without artificial backgrounds, borders, circular frames,
///   badges, glows, or artificial drop shadows.
/// - Uses [FilterQuality.high] for crisp rendering across display densities.
class HazeGuardLogo extends StatelessWidget {
  /// Primary transparent Haze Guard PNG asset path.
  static const String assetPath =
      'assets/icons/Haze_Guard_Logo_Static_Transparent.png';

  /// Fallback asset path if stored in images.
  static const String fallbackAssetPath =
      'assets/images/Haze_Guard_Logo_Static_Transparent.png';

  /// Dimension applied to both width and height when square scaling is desired.
  final double? size;

  /// Explicit width (overrides [size] if provided).
  final double? width;

  /// Explicit height (overrides [size] if provided).
  final double? height;

  /// Semantic label for screen readers.
  final String semanticLabel;

  const HazeGuardLogo({
    super.key,
    this.size,
    this.width,
    this.height,
    this.semanticLabel = 'Haze Guard Logo',
  });

  @override
  Widget build(BuildContext context) {
    final double? effectiveWidth = width ?? size;
    final double? effectiveHeight = height ?? size;

    return Image.asset(
      assetPath,
      width: effectiveWidth,
      height: effectiveHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          fallbackAssetPath,
          width: effectiveWidth,
          height: effectiveHeight,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: semanticLabel,
        );
      },
    );
  }
}
