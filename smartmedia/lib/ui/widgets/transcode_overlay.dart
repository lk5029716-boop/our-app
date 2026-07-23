import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/gif_asset.dart';
import '../../theme/smartmedia_theme.dart';

/// Dim + blur mask with indigo→violet progress ring and pipeline status copy.
class TranscodeOverlay extends StatelessWidget {
  const TranscodeOverlay({
    super.key,
    required this.visible,
    required this.state,
    required this.progress,
    this.onCancel,
  });

  final bool visible;
  final PipelineState state;
  final double progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: const Color(0xCC0B0B0F)),
            ),
            Center(
              child: GlassContainer(
                borderRadius: 24,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                opacity: 0.65,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GradientProgressRing(progress: progress),
                      const SizedBox(height: 22),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: SMColors.muted,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (onCancel != null) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: onCancel,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: SMColors.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GradientProgressRing extends StatefulWidget {
  const GradientProgressRing({super.key, required this.progress});

  final double progress;

  @override
  State<GradientProgressRing> createState() => _GradientProgressRingState();
}

class _GradientProgressRingState extends State<GradientProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, _) {
        return SizedBox(
          width: 72,
          height: 72,
          child: CustomPaint(
            painter: _RingPainter(
              rotation: _spin.value * math.pi * 2,
              progress: widget.progress.clamp(0.0, 1.0),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.rotation, required this.progress});

  final double rotation;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const stroke = 5.0;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0x33FFFFFF)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = (0.25 + progress * 0.75) * math.pi * 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const [
          SMColors.indigo,
          SMColors.violet,
          SMColors.indigo,
        ],
        transform: GradientRotation(rotation),
      ).createShader(rect);

    canvas.drawArc(rect, rotation, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.rotation != rotation || old.progress != progress;
}
