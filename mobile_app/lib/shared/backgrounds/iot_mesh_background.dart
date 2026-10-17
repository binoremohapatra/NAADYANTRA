import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';

/// IoT Sensor Mesh Background
///
/// Draws a dynamic, floating industrial sensor node network.
/// Nodes represent distributed acoustic IoT listening nodes across a pipeline plant,
/// connected by data transmission vectors with moving telemetry packets.
class IoTMeshBackground extends StatefulWidget {
  final double opacity;
  final bool isScanning;

  const IoTMeshBackground({
    super.key,
    this.opacity = 1.0,
    this.isScanning = true,
  });

  @override
  State<IoTMeshBackground> createState() => _IoTMeshBackgroundState();
}

class _IoTMeshBackgroundState extends State<IoTMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Fixed pseudo-random seed distribution for nodes
  final List<_MeshNode> _nodes = [
    _MeshNode(0.12, 0.18, 5.0, 1.2),
    _MeshNode(0.35, 0.12, 4.0, 0.8),
    _MeshNode(0.68, 0.15, 6.0, 1.4),
    _MeshNode(0.88, 0.28, 4.5, 0.9),
    _MeshNode(0.22, 0.42, 6.5, 1.1),
    _MeshNode(0.52, 0.38, 5.0, 1.5),
    _MeshNode(0.78, 0.48, 7.0, 1.0),
    _MeshNode(0.15, 0.68, 4.0, 0.7),
    _MeshNode(0.42, 0.65, 6.0, 1.3),
    _MeshNode(0.82, 0.72, 5.5, 1.2),
    _MeshNode(0.30, 0.88, 4.5, 0.9),
    _MeshNode(0.65, 0.85, 6.0, 1.1),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );

    if (widget.isScanning) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReduced = MotionTokens.isReducedMotion(context);

    if (isReduced) {
      return RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _IoTMeshPainter(
            progress: 0.0,
            nodes: _nodes,
            isDark: isDark,
            opacity: widget.opacity,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _IoTMeshPainter(
            progress: _controller.value,
            nodes: _nodes,
            isDark: isDark,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

class _MeshNode {
  final double xRatio;
  final double yRatio;
  final double radius;
  final double speed;

  const _MeshNode(this.xRatio, this.yRatio, this.radius, this.speed);
}

class _IoTMeshPainter extends CustomPainter {
  final double progress;
  final List<_MeshNode> nodes;
  final bool isDark;
  final double opacity;

  _IoTMeshPainter({
    required this.progress,
    required this.nodes,
    required this.isDark,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final nodeFillPaint = Paint()..style = PaintingStyle.fill;
    final nodeRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final packetPaint = Paint()..style = PaintingStyle.fill;

    // Calculate dynamic node positions with smooth harmonic drift
    final positions = <Offset>[];
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final angle = (progress * 2 * math.pi * node.speed) + (i * 0.8);
      final dx = size.width * node.xRatio + math.cos(angle) * 12.0;
      final dy = size.height * node.yRatio + math.sin(angle) * 14.0;
      positions.add(Offset(dx, dy));
    }

    // Maximum distance to draw connection edge
    final maxDist = size.width * 0.42;

    // Draw connection edges and moving telemetry packets
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final p1 = positions[i];
        final p2 = positions[j];
        final dist = (p1 - p2).distance;

        if (dist < maxDist) {
          final edgeAlpha = (1.0 - (dist / maxDist)) * 0.28 * opacity;
          linePaint.color = isDark
              ? AppColors.darkBorder.withValues(alpha: edgeAlpha * 1.5)
              : AppColors.warmStone.withValues(alpha: edgeAlpha * 1.4);

          canvas.drawLine(p1, p2, linePaint);

          // Moving telemetry signal packet along the vector
          final packetT = (progress * 1.5 + (i * 0.2) + (j * 0.15)) % 1.0;
          final packetPos = Offset.lerp(p1, p2, packetT)!;
          packetPaint.color = AppColors.burntOrange.withValues(
            alpha: edgeAlpha * 1.8 * math.sin(packetT * math.pi),
          );
          canvas.drawCircle(packetPos, 2.2, packetPaint);
        }
      }
    }

    // Draw nodes
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final node = nodes[i];
      final pulse = 1.0 + 0.2 * math.sin((progress * 2 * math.pi) + (i * 1.2));

      // Node subtle glowing aura
      nodeFillPaint.color = AppColors.burntOrange.withValues(
        alpha: (isDark ? 0.08 : 0.05) * opacity * pulse,
      );
      canvas.drawCircle(pos, node.radius * 2.8 * pulse, nodeFillPaint);

      // Node ring
      nodeRingPaint.color = isDark
          ? AppColors.burntOrange.withValues(alpha: 0.5 * opacity)
          : AppColors.burntOrange.withValues(alpha: 0.4 * opacity);
      canvas.drawCircle(pos, node.radius * pulse, nodeRingPaint);

      // Node center core
      nodeFillPaint.color = isDark ? AppColors.pureWhite : AppColors.carbon;
      canvas.drawCircle(pos, 2.0, nodeFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IoTMeshPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
