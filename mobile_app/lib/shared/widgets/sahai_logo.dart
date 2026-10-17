import 'package:flutter/material.dart';

/// Permanent SAHAI static brand logo widget.
///
/// Complies strictly with brand directives:
/// - Static PNG only (never animated GIF/WebP, never rotating or scaling).
/// - Preserves original logo geometry, proportions, orientation, and colours.
/// - Preserves transparency without backgrounds, borders, circular frames,
///   badges, or artificial drop shadows.
/// - Uses [FilterQuality.high] for sharp rendering across display densities.
class SahaiLogo extends StatelessWidget {
  /// Path to the official transparent Haze Guard PNG asset.
  static const String assetPath =
      'assets/icons/Haze_Guard_Logo_Static_Transparent.png';

  /// Dimension applied to both width and height when square scaling is desired.
  final double? size;

  /// Explicit width (overrides [size] if provided).
  final double? width;

  /// Explicit height (overrides [size] if provided).
  final double? height;

  /// Semantic label for screen readers.
  final String semanticLabel;

  const SahaiLogo({
    super.key,
    this.size,
    this.width,
    this.height,
    this.semanticLabel = 'HazeGuard Logo',
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
          'assets/images/Haze_Guard_Logo_Static_Transparent.png',
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
