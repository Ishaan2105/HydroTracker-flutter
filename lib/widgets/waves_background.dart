import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class Grad {
  final double x;
  final double y;
  final double z;
  const Grad(this.x, this.y, this.z);
  double dot2(double dx, double dy) => x * dx + y * dy;
}

class PerlinNoise {
  static const List<Grad> _grad3 = [
    Grad(1, 1, 0),
    Grad(-1, 1, 0),
    Grad(1, -1, 0),
    Grad(-1, -1, 0),
    Grad(1, 0, 1),
    Grad(-1, 0, 1),
    Grad(1, 0, -1),
    Grad(-1, 0, -1),
    Grad(0, 1, 1),
    Grad(0, -1, 1),
    Grad(0, 1, -1),
    Grad(0, -1, -1),
  ];

  static const List<int> _p = [
    151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240,
    21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88,
    237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83,
    111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216,
    80, 73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186,
    3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58,
    17, 182, 189, 28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
    129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193,
    238, 210, 144, 12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157,
    184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128,
    195, 78, 66, 215, 61, 156, 180
  ];

  late final List<int> perm;
  late final List<Grad> gradP;

  PerlinNoise([double? seed]) {
    perm = List<int>.filled(512, 0);
    gradP = List<Grad>.filled(512, const Grad(0, 0, 0));
    _seed(seed ?? math.Random().nextDouble());
  }

  void _seed(double s) {
    int seed = (s > 0 && s < 1) ? (s * 65536).floor() : s.floor();
    if (seed < 256) seed |= seed << 8;
    for (int i = 0; i < 256; i++) {
      final v = (i & 1 != 0) ? (_p[i] ^ (seed & 255)) : (_p[i] ^ ((seed >> 8) & 255));
      perm[i] = perm[i + 256] = v;
      gradP[i] = gradP[i + 256] = _grad3[v % 12];
    }
  }

  double _fade(double t) => t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
  double _lerp(double a, double b, double t) => (1.0 - t) * a + t * b;

  double perlin2(double x, double y) {
    int X = x.floor() & 255;
    int Y = y.floor() & 255;
    final xFrac = x - x.floor();
    final yFrac = y - y.floor();

    final n00 = gradP[X + perm[Y]].dot2(xFrac, yFrac);
    final n01 = gradP[X + perm[Y + 1]].dot2(xFrac, yFrac - 1.0);
    final n10 = gradP[X + 1 + perm[Y]].dot2(xFrac - 1.0, yFrac);
    final n11 = gradP[X + 1 + perm[Y + 1]].dot2(xFrac - 1.0, yFrac - 1.0);

    final u = _fade(xFrac);
    final v = _fade(yFrac);

    return _lerp(_lerp(n00, n10, u), _lerp(n01, n11, u), v);
  }
}

class WavePoint {
  final double x;
  final double y;
  double waveX = 0;
  double waveY = 0;
  double cursorX = 0;
  double cursorY = 0;
  double cursorVx = 0;
  double cursorVy = 0;

  WavePoint({required this.x, required this.y});
}

class MouseState {
  double x = -1000;
  double y = -1000;
  double lx = 0;
  double ly = 0;
  double sx = -1000;
  double sy = -1000;
  double v = 0;
  double vs = 0;
  double a = 0;
  bool isSet = false;
}

/// A Flutter port of the React Bits `<Waves />` interactive background component.
class WavesBackground extends StatefulWidget {
  final Color lineColor;
  final Color backgroundColor;
  final double waveSpeedX;
  final double waveSpeedY;
  final double waveAmpX;
  final double waveAmpY;
  final double friction;
  final double tension;
  final double maxCursorMove;
  final double xGap;
  final double yGap;
  final Widget? child;

  const WavesBackground({
    super.key,
    this.lineColor = const Color(0x1F00E5FF),
    this.backgroundColor = const Color(0xFF0B1329),
    this.waveSpeedX = 0.0125,
    this.waveSpeedY = 0.005,
    this.waveAmpX = 32.0,
    this.waveAmpY = 16.0,
    this.friction = 0.925,
    this.tension = 0.005,
    this.maxCursorMove = 100.0,
    this.xGap = 12.0,
    this.yGap = 36.0,
    this.child,
  });

  @override
  State<WavesBackground> createState() => _WavesBackgroundState();
}

class _WavesBackgroundState extends State<WavesBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final PerlinNoise _noise = PerlinNoise();
  final MouseState _mouse = MouseState();

  List<List<WavePoint>> _lines = [];
  Size _lastSize = Size.zero;
  double _elapsedTimeMs = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((Duration elapsed) {
      _elapsedTimeMs = elapsed.inMilliseconds.toDouble();
      _tick(_elapsedTimeMs);
      if (mounted) setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _initLines(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _lastSize = size;
    _lines = [];

    final oWidth = size.width + 200.0;
    final oHeight = size.height + 40.0;
    final totalLines = (oWidth / widget.xGap).ceil();
    final totalPoints = (oHeight / widget.yGap).ceil();
    final xStart = (size.width - widget.xGap * totalLines) / 2.0;
    final yStart = (size.height - widget.yGap * totalPoints) / 2.0;

    for (int i = 0; i <= totalLines; i++) {
      final pts = <WavePoint>[];
      for (int j = 0; j <= totalPoints; j++) {
        pts.add(WavePoint(
          x: xStart + widget.xGap * i,
          y: yStart + widget.yGap * j,
        ));
      }
      _lines.add(pts);
    }
  }

  void _tick(double time) {
    if (_lines.isEmpty) return;

    // Smooth cursor interpolation
    _mouse.sx += (_mouse.x - _mouse.sx) * 0.1;
    _mouse.sy += (_mouse.y - _mouse.sy) * 0.1;
    final dx = _mouse.x - _mouse.lx;
    final dy = _mouse.y - _mouse.ly;
    final d = math.sqrt(dx * dx + dy * dy);
    _mouse.v = d;
    _mouse.vs += (d - _mouse.vs) * 0.1;
    _mouse.vs = math.min(100.0, _mouse.vs);
    _mouse.lx = _mouse.x;
    _mouse.ly = _mouse.y;
    _mouse.a = math.atan2(dy, dx);

    // Update Wave Points
    for (final pts in _lines) {
      for (final p in pts) {
        final move = _noise.perlin2(
              (p.x + time * widget.waveSpeedX) * 0.002,
              (p.y + time * widget.waveSpeedY) * 0.0015,
            ) *
            12.0;
        p.waveX = math.cos(move) * widget.waveAmpX;
        p.waveY = math.sin(move) * widget.waveAmpY;

        final pdx = p.x - _mouse.sx;
        final pdy = p.y - _mouse.sy;
        final dist = math.sqrt(pdx * pdx + pdy * pdy);
        final l = math.max(175.0, _mouse.vs);

        if (dist < l) {
          final s = 1.0 - dist / l;
          final f = math.cos(dist * 0.001) * s;
          p.cursorVx += math.cos(_mouse.a) * f * l * _mouse.vs * 0.00065;
          p.cursorVy += math.sin(_mouse.a) * f * l * _mouse.vs * 0.00065;
        }

        p.cursorVx += (0.0 - p.cursorX) * widget.tension;
        p.cursorVy += (0.0 - p.cursorY) * widget.tension;
        p.cursorVx *= widget.friction;
        p.cursorVy *= widget.friction;
        p.cursorX += p.cursorVx * 2.0;
        p.cursorY += p.cursorVy * 2.0;
        p.cursorX = p.cursorX.clamp(-widget.maxCursorMove, widget.maxCursorMove);
        p.cursorY = p.cursorY.clamp(-widget.maxCursorMove, widget.maxCursorMove);
      }
    }
  }

  void _updateMouse(Offset localPos) {
    _mouse.x = localPos.dx;
    _mouse.y = localPos.dy;
    if (!_mouse.isSet) {
      _mouse.sx = _mouse.x;
      _mouse.sy = _mouse.y;
      _mouse.lx = _mouse.x;
      _mouse.ly = _mouse.y;
      _mouse.isSet = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (currentSize != _lastSize && currentSize.width > 0 && currentSize.height > 0) {
            _initLines(currentSize);
          }

          return MouseRegion(
            onHover: (event) => _updateMouse(event.localPosition),
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) => _updateMouse(event.localPosition),
              onPointerMove: (event) => _updateMouse(event.localPosition),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      size: currentSize,
                      painter: _WavesPainter(
                        lines: _lines,
                        lineColor: widget.lineColor,
                      ),
                    ),
                  ),
                  if (widget.child != null) widget.child!,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  final List<List<WavePoint>> lines;
  final Color lineColor;
  late final Paint _paint;

  _WavesPainter({
    required this.lines,
    required this.lineColor,
  }) {
    _paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
  }

  Offset _moved(WavePoint p, bool withCursor) {
    final x = p.x + p.waveX + (withCursor ? p.cursorX : 0.0);
    final y = p.y + p.waveY + (withCursor ? p.cursorY : 0.0);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;

    final path = Path();
    for (final points in lines) {
      if (points.isEmpty) continue;

      var p1 = _moved(points[0], false);
      path.moveTo(p1.dx, p1.dy);

      for (int idx = 0; idx < points.length; idx++) {
        final isLast = idx == points.length - 1;
        p1 = _moved(points[idx], !isLast);
        path.lineTo(p1.dx, p1.dy);

        if (isLast && idx + 1 < points.length) {
          final p2 = _moved(points[idx + 1], false);
          path.moveTo(p2.dx, p2.dy);
        }
      }
    }

    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) => true;
}
