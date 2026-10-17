import 'package:flutter/material.dart';

import 'cinematic_particle_field.dart';
import 'technical_grid_background.dart';
import 'acoustic_signal_field.dart';
import 'live_sonar_background.dart';
import 'data_stream_background.dart';
import 'spectral_matrix_background.dart';
import 'blueprint_iso_background.dart';
import 'circuit_trace_background.dart';
import 'minimal_tuning_background.dart';

/// Semantic Background Themes tailored for each screen's industrial purpose.
enum ScreenBackgroundTheme {
  /// Operator login & secure boot gateway
  auth,

  /// High-level IoT pipeline network & sensor node mesh
  overview,

  /// Real-time ultrasonic acoustic leak detection & sonar radar sweep
  liveSonar,

  /// Historical telemetry waterfall & session audit archive
  dataStream,

  /// Deep forensic FFT spectrogram analysis & harmonic resonance
  spectralMatrix,

  /// Vocational evaluation rubrics & ISO standard blueprint drafting
  blueprintIso,

  /// Hardware ESP32-S3 node PCB copper traces & electrical signal telemetry
  circuitTrace,

  /// Workstation system configuration & optical vernier calibration
  minimalTuning,
}

/// AnimatedScreenBackground
///
/// Wraps any screen body in a specialized, bespoke industrial animation
/// tailored directly to that screen's specific operational context.
class AnimatedScreenBackground extends StatelessWidget {
  final Widget child;

  /// Specific thematic background for the screen
  final ScreenBackgroundTheme theme;

  /// 0.0–1.0 master opacity scale (default 1.0)
  final double intensity;

  const AnimatedScreenBackground({
    super.key,
    required this.child,
    this.theme = ScreenBackgroundTheme.overview,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget backgroundLayer;

    switch (theme) {
      case ScreenBackgroundTheme.auth:
        backgroundLayer = Stack(
          children: [
            Positioned.fill(
              child: CinematicParticleField(opacity: 0.85 * intensity),
            ),
            Positioned.fill(
              child: TechnicalGridBackground(
                gridSpacing: 42.0,
                opacity: 0.3 * intensity,
                showScanLine: true,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AcousticSignalField(
                  opacity: 0.22 * intensity,
                  animate: true,
                ),
              ),
            ),
          ],
        );
        break;

      case ScreenBackgroundTheme.overview:
        backgroundLayer = Positioned.fill(
          child: TechnicalGridBackground(
            gridSpacing: 38.0,
            opacity: 0.20 * intensity,
            showScanLine: false,
          ),
        );
        break;

      case ScreenBackgroundTheme.liveSonar:
        backgroundLayer = Positioned.fill(
          child: LiveSonarBackground(opacity: 0.85 * intensity),
        );
        break;

      case ScreenBackgroundTheme.dataStream:
        backgroundLayer = Positioned.fill(
          child: DataStreamBackground(opacity: 0.75 * intensity),
        );
        break;

      case ScreenBackgroundTheme.spectralMatrix:
        backgroundLayer = Positioned.fill(
          child: SpectralMatrixBackground(opacity: 0.8 * intensity),
        );
        break;

      case ScreenBackgroundTheme.blueprintIso:
        backgroundLayer = Positioned.fill(
          child: BlueprintIsoBackground(opacity: 0.8 * intensity),
        );
        break;

      case ScreenBackgroundTheme.circuitTrace:
        backgroundLayer = Positioned.fill(
          child: CircuitTraceBackground(opacity: 0.85 * intensity),
        );
        break;

      case ScreenBackgroundTheme.minimalTuning:
        backgroundLayer = Positioned.fill(
          child: MinimalTuningBackground(opacity: 0.8 * intensity),
        );
        break;
    }

    return Stack(children: [backgroundLayer, child]);
  }
}
