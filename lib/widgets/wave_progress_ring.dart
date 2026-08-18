import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WaveProgressRing extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final int currentMl;
  final int goalMl;
  final double size;

  const WaveProgressRing({
    super.key,
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    this.size = 230,
  });

  @override
  State<WaveProgressRing> createState() => _WaveProgressRingState();
}

class _WaveProgressRingState extends State<WaveProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Defer animation start so the first frame renders immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _waveController.repeat();
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.progress * 100).clamp(0, 100).toInt();
    final currentLters = (widget.currentMl / 1000).toStringAsFixed(2);
    final goalLiters = (widget.goalMl / 1000).toStringAsFixed(1);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Wave Background fill clipped in circle
          ClipOval(
            child: SizedBox(
              width: widget.size - 24,
              height: widget.size - 24,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WaterWavePainter(
                      progress: widget.progress,
                      animationValue: _waveController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // Outer Progress Circular Ring
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: ProgressRingPainter(
              progress: widget.progress,
              ringWidth: 10,
              backgroundColor: const Color(0xFF1E293B),
              progressColor: const Color(0xFF00E5FF),
            ),
          ),

          // Center Text Info
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$percentage%',
                style: GoogleFonts.poppins(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    const Shadow(
                      color: Colors.black45,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Text(
                  '$currentLters / $goalLiters L',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// CustomPainter for rendering animated water wave height inside circular container
class WaterWavePainter extends CustomPainter {
  final double progress;
  final double animationValue;

  WaterWavePainter({
    required this.progress,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint1 = Paint()
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final wavePaint2 = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final baseHeight = size.height * (1.0 - progress.clamp(0.0, 1.0));
    final waveHeight = 7.0;

    final path1 = Path();
    final path2 = Path();

    path1.moveTo(0, size.height);
    path2.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y1 = baseHeight +
          math.sin((x / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) *
              waveHeight;
      final y2 = baseHeight +
          math.cos((x / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) *
              waveHeight;

      path1.lineTo(x, y1);
      path2.lineTo(x, y2);
    }

    path1.lineTo(size.width, size.height);
    path1.close();

    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path1, wavePaint1);
    canvas.drawPath(path2, wavePaint2);
  }

  @override
  bool shouldRepaint(covariant WaterWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue;
  }
}

/// CustomPainter for rendering outer solid color progress ring
class ProgressRingPainter extends CustomPainter {
  final double progress;
  final double ringWidth;
  final Color backgroundColor;
  final Color progressColor;

  ProgressRingPainter({
    required this.progress,
    required this.ringWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - ringWidth) / 2;

    // Background track
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    // Solid Color Arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = ringWidth;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}
