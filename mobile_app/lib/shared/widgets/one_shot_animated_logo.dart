import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion_tokens.dart';
import 'haze_guard_logo.dart';

/// A frame-aware, one-shot inward animated logo widget for Haze Guard.
///
/// Complies with Haze Guard launch animation directives:
/// - Exact animated asset: [animatedAssetPath] (`Haze_Guard_Logo_Assembly_Inward.gif`).
/// - Exact static transparent logo: [restingAssetPath] (`Haze_Guard_Logo_Static_Transparent.png`).
/// - Direction: Geometric pieces begin outside the logo silhouette and slide
///   INWARD toward the center to align cleanly into the final mark.
/// - One-Time Playback: Plays strictly once per cold app launch ([hasPlayedOnceThisLaunch]).
///   Never replays on widget rebuilds, screen transitions, or navigating back.
/// - Once complete, holds briefly ([holdDuration]) and settles into the motionless
///   transparent static PNG without any visual jitter or jump.
/// - Zero decorative artifacts: No glow, radiation rings, sonar waves, particles,
///   or artificial backgrounds.
/// - Reduced Motion: Skips animation and renders the static PNG immediately.
/// - Disposes decoded frame bitmaps from memory once complete.
class OneShotAnimatedLogo extends StatefulWidget {
  /// Primary animated GIF asset path (inward assembly).
  static const String animatedAssetPath =
      'assets/icons/Haze_Guard_Logo_Assembly_Inward.gif';

  /// Alternative animated GIF asset path in images directory.
  static const String animatedAssetImagePath =
      'assets/images/Haze_Guard_Logo_Assembly_Inward.gif';

  /// Fallback animated WebP asset path.
  static const String animatedWebpAssetPath =
      'assets/icons/Haze_Guard_Logo_Assembly_Inward.webp';

  /// Static transparent PNG asset path aligned with the animation's final assembled frame.
  static const String restingAssetPath =
      'assets/icons/Haze_Guard_Logo_Static_Transparent.png';

  /// Alternative static PNG path in images directory.
  static const String restingAssetImagePath =
      'assets/images/Haze_Guard_Logo_Static_Transparent.png';

  /// Tracks whether the animation has played once during the current cold launch session.
  static bool hasPlayedOnceThisLaunch = false;

  /// Resets the launch playback state (used for testing or cold simulation).
  static void resetLaunchState() {
    hasPlayedOnceThisLaunch = false;
  }

  /// Width and height of the square logo container.
  final double size;

  /// Optional callback invoked once the assembly animation and hold have completed.
  final VoidCallback? onCompleted;

  /// Duration to hold the assembled logo before invoking [onCompleted].
  final Duration holdDuration;

  /// Total duration for the inward segment-assembly animation phase.
  final Duration animationDuration;

  /// Semantic label for accessibility.
  final String semanticLabel;

  const OneShotAnimatedLogo({
    super.key,
    this.size = 140,
    this.onCompleted,
    this.holdDuration = const Duration(milliseconds: 400),
    this.animationDuration = const Duration(milliseconds: 2000),
    this.semanticLabel = 'HazGuard Inward Logo Assembly',
  });

  @override
  State<OneShotAnimatedLogo> createState() => _OneShotAnimatedLogoState();
}

class _OneShotAnimatedLogoState extends State<OneShotAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  List<ui.Image> _frames = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();

    // Check if the intro has already played once during this app launch
    if (OneShotAnimatedLogo.hasPlayedOnceThisLaunch) {
      _isLoading = false;
      _animationCompleted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onCompleted?.call();
        }
      });
      return;
    }

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // Linear progression maps to the GIF's pre-rendered 55 ease-out inward frames
    _curve = CurvedAnimation(parent: _controller, curve: Curves.linear);

    _controller.addStatusListener(_onAnimationStatusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && !_animationCompleted) {
      if (MotionTokens.isReducedMotion(context)) {
        // Reduced motion: skip animation and display static PNG immediately
        OneShotAnimatedLogo.hasPlayedOnceThisLaunch = true;
        _isLoading = false;
        _animationCompleted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onCompleted?.call();
          }
        });
      } else {
        _loadFrames();
      }
    }
  }

  Future<void> _loadFrames() async {
    try {
      ByteData? data;
      try {
        data = await rootBundle.load(OneShotAnimatedLogo.animatedAssetPath);
      } catch (_) {
        try {
          data = await rootBundle.load(
            OneShotAnimatedLogo.animatedAssetImagePath,
          );
        } catch (_) {
          data = await rootBundle.load(
            OneShotAnimatedLogo.animatedWebpAssetPath,
          );
        }
      }

      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frameCount = codec.frameCount;
      final loadedFrames = <ui.Image>[];

      for (int i = 0; i < frameCount; i++) {
        final frameInfo = await codec.getNextFrame();
        loadedFrames.add(frameInfo.image);
      }

      if (!mounted) {
        for (final img in loadedFrames) {
          img.dispose();
        }
        return;
      }

      setState(() {
        _frames = loadedFrames;
        _isLoading = false;
      });

      // Play intro inward assembly animation strictly once
      _controller.forward();
    } catch (e) {
      if (!mounted) return;
      OneShotAnimatedLogo.hasPlayedOnceThisLaunch = true;
      setState(() {
        _hasError = true;
        _isLoading = false;
        _animationCompleted = true;
      });
      widget.onCompleted?.call();
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Mark as played once for this launch session
      OneShotAnimatedLogo.hasPlayedOnceThisLaunch = true;

      // Hold the final assembled frame briefly, then transition to static PNG
      Future.delayed(widget.holdDuration, () {
        if (!mounted) return;
        setState(() {
          _animationCompleted = true;
        });

        // Free decoded frame buffers from RAM
        for (final img in _frames) {
          img.dispose();
        }
        _frames = [];

        widget.onCompleted?.call();
      });
    }
  }

  @override
  void dispose() {
    if (!OneShotAnimatedLogo.hasPlayedOnceThisLaunch &&
        _controller.isAnimating) {
      OneShotAnimatedLogo.hasPlayedOnceThisLaunch = true;
    }
    _controller.removeStatusListener(_onAnimationStatusChanged);
    _controller.dispose();
    for (final img in _frames) {
      img.dispose();
    }
    _frames = [];
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If completed or failed to load, render the resting static transparent PNG
    if (_animationCompleted || _hasError || _frames.isEmpty) {
      return Semantics(
        label: widget.semanticLabel,
        image: true,
        child: Image.asset(
          OneShotAnimatedLogo.restingAssetPath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            OneShotAnimatedLogo.restingAssetImagePath,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (ctx, err, st) => HazeGuardLogo(size: widget.size),
          ),
        ),
      );
    }

    // While decoding frames, show transparent placeholder sized identically
    if (_isLoading) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    // Playback phase: frame-driven inward motion smoothly locked to frame clock
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final totalFrames = _frames.length;
        final rawIndex = (_curve.value * (totalFrames - 1)).round();
        final frameIndex = rawIndex.clamp(0, totalFrames - 1);
        final currentImage = _frames[frameIndex];

        return Semantics(
          label: widget.semanticLabel,
          image: true,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: RawImage(
              image: currentImage,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        );
      },
    );
  }
}
