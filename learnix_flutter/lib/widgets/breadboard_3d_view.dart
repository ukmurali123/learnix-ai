import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================ 3D breadboard (same look as the live Learnix app)
// A small software 3D renderer copied from the live app's breadboard_3d.dart: boxes, cylinders and domes are
// turned into lit polygons and drawn far-to-near, legs and jumper wires are drawn as tubes, lit LEDs glow.
// This file builds the Circuit Lab's LED + resistor + switch circuit in that style.

typedef P3 = (double, double, double);

class Solid3 {
  final String shape; // box | cylz | cylx | dome
  final double x, y, z, sx, sy, sz, rot;
  final Color col;
  const Solid3(this.shape, this.x, this.y, this.z, this.sx, this.sy, this.sz, this.col, {this.rot = 0});
}

class Poly3 {
  final List<P3> p;
  final Color col;
  Poly3(this.p, this.col);
}

class Cable3 {
  final List<P3> pts;
  final Color col;
  final double r;
  Cable3(this.pts, this.col, this.r);
}

class Glow3 {
  final P3 at;
  final Color col;
  final double r;
  Glow3(this.at, this.col, this.r);
}

class Label3 {
  final P3 at;
  final String text;
  final Color col;
  Label3(this.at, this.text, this.col);
}

class Scene3 {
  final labels = <Label3>[];
  final side = <Poly3>[];
  final decor = <Poly3>[];
  final solids = <Solid3>[];
  final cables = <Cable3>[];
  final glows = <Glow3>[];
}

List<Poly3> faces3(Solid3 q) {
  final c = math.cos(q.rot), s = math.sin(q.rot);
  P3 t(double lx, double ly, double lz) => (q.x + lx * c - ly * s, q.y + lx * s + ly * c, q.z + lz);
  final hx = q.sx / 2, hy = q.sy / 2, hz = q.sz / 2;
  if (q.shape == 'box') {
    return [
      Poly3([t(-hx, -hy, hz), t(hx, -hy, hz), t(hx, hy, hz), t(-hx, hy, hz)], q.col),
      Poly3([t(-hx, -hy, -hz), t(hx, -hy, -hz), t(hx, -hy, hz), t(-hx, -hy, hz)], q.col),
      Poly3([t(-hx, hy, -hz), t(hx, hy, -hz), t(hx, hy, hz), t(-hx, hy, hz)], q.col),
      Poly3([t(-hx, -hy, -hz), t(-hx, hy, -hz), t(-hx, hy, hz), t(-hx, -hy, hz)], q.col),
      Poly3([t(hx, -hy, -hz), t(hx, hy, -hz), t(hx, hy, hz), t(hx, -hy, hz)], q.col),
    ];
  }
  if (q.shape == 'dome') {
    const n = 20, m = 6;
    P3 pt(int i, int j) {
      final a = 2 * math.pi * i / n, e = (math.pi / 2) * j / m;
      return t(hx * math.cos(a) * math.cos(e), hy * math.sin(a) * math.cos(e), q.sz * math.sin(e));
    }

    return [
      for (var j = 0; j < m; j++)
        for (var i = 0; i < n; i++) Poly3([pt(i, j), pt((i + 1) % n, j), pt((i + 1) % n, j + 1), pt(i, j + 1)], q.col),
    ];
  }
  const n = 22;
  P3 ring(int i, int end) {
    final a = 2 * math.pi * i / n;
    final ca = math.cos(a), sa = math.sin(a);
    return q.shape == 'cylx' ? t(end * hx, hy * ca, hz * sa) : t(hx * ca, hy * sa, end * hz);
  }

  return [
    Poly3([for (var i = 0; i < n; i++) ring(i, 1)], q.col),
    for (var i = 0; i < n; i++) Poly3([ring(i, -1), ring((i + 1) % n, -1), ring((i + 1) % n, 1), ring(i, 1)], q.col),
  ];
}

/// Colour bands of a resistor value (4-band code), as in the live app.
List<Color> resistorBands(double ohms) {
  const cols = [Color(0xFF000000), Color(0xFF8B4513), Color(0xFFE53935), Color(0xFFFF9800), Color(0xFFFFEB3B), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFF9E9E9E), Color(0xFFFFFFFF)];
  var v = ohms.round().clamp(10, 9900000);
  var exp = 0;
  while (v >= 100) {
    v ~/= 10;
    exp++;
  }
  return [cols[v ~/ 10], cols[v % 10], cols[exp.clamp(0, 9)], const Color(0xFFD4AF37)];
}

// ------------------------------------------------------------ the Circuit Lab board
const _bw = 600.0, _bh = 380.0; // board size in world units
const _cols = 28;
const _rowFracs = [0.09, 0.14, 0.26, 0.31, 0.36, 0.41, 0.45, 0.55, 0.59, 0.64, 0.69, 0.74, 0.86, 0.91];

double _colX(int c) => -_bw / 2 + _bw * 0.06 + c * (_bw * 0.88) / (_cols - 1);
double _rowY(double frac) => _bh / 2 - frac * _bh;

Scene3 buildCircuitBoardScene({required bool running, required bool hasResistor, required bool switchClosed, required double ohms, required double progress}) {
  final sc = Scene3();
  const depth = 16.0;
  final pitch = _colX(1) - _colX(0); // hole spacing (2.54 mm on a real board)
  final mm = pitch / 2.54; // world units per millimetre, so the parts have real proportions
  // board body (edges) and top
  for (final f in faces3(const Solid3('box', 0, 0, -depth / 2, _bw, _bh, depth, Color(0xFFE7E1D3)))) {
    sc.side.add(f);
  }
  P3 q(double x, double y, [double z = 0.05]) => (x, y, z);
  sc.decor.add(Poly3([q(-_bw / 2, -_bh / 2, 0.01), q(_bw / 2, -_bh / 2, 0.01), q(_bw / 2, _bh / 2, 0.01), q(-_bw / 2, _bh / 2, 0.01)], const Color(0xFFF3EFE6)));
  sc.decor.add(Poly3([q(-_bw / 2 + 14, _rowY(0.48)), q(_bw / 2 - 14, _rowY(0.48)), q(_bw / 2 - 14, _rowY(0.52)), q(-_bw / 2 + 14, _rowY(0.52))], const Color(0xFFC9C3AF)));
  for (final e in [(0.065, const Color(0xFFE53935)), (0.165, const Color(0xFF1E88E5)), (0.835, const Color(0xFFE53935)), (0.935, const Color(0xFF1E88E5))]) {
    final y = _rowY(e.$1);
    sc.decor.add(Poly3([q(-_bw / 2 + 16, y - 1.1), q(_bw / 2 - 16, y - 1.1), q(_bw / 2 - 16, y + 1.1), q(-_bw / 2 + 16, y + 1.1)], e.$2.withOpacity(0.85)));
  }
  sc.labels.add(Label3((-_bw / 2 + 22, _rowY(0.09), 0.5), '+', const Color(0xFFE53935)));
  sc.labels.add(Label3((-_bw / 2 + 22, _rowY(0.14), 0.5), '−', const Color(0xFF1E88E5)));
  for (var c = 0; c < _cols; c++) {
    for (final rf in _rowFracs) {
      final x = _colX(c), y = _rowY(rf);
      sc.decor.add(Poly3([q(x - 2.4, y - 2.4, 0.08), q(x + 2.4, y - 2.4, 0.08), q(x + 2.4, y + 2.4, 0.08), q(x - 2.4, y + 2.4, 0.08)], const Color(0xFF3F3F46)));
    }
  }

  // Circuit, centred on the board:  + rail -> jumper -> switch -> resistor -> LED (anode, cathode) -> jumper -> - rail
  final cJ = _colX(10), cS2 = _colX(12), cR2 = _colX(15), cA = cR2, cK = _colX(16);
  final railPlus = _rowY(0.09), railMinus = _rowY(0.14), rowA = _rowY(0.26), rowB = _rowY(0.31), rowC = _rowY(0.36), rowD = _rowY(0.41);
  List<P3> arc(P3 a, P3 b, double h) => [for (var i = 0; i <= 14; i++) (a.$1 + (b.$1 - a.$1) * i / 14, a.$2 + (b.$2 - a.$2) * i / 14, a.$3 + (b.$3 - a.$3) * i / 14 + h * math.sin(math.pi * i / 14))];
  List<P3> jumper(double x1, double y1, double x2, double y2, double h) => [(x1, y1, 0.3), (x1, y1, h), (x2, y2, h), (x2, y2, 0.3)];
  final wireR = 0.75 * mm, legR = 0.45 * mm;

  // battery pack (5 V) in front of the board, leads onto the rails
  const packX = -170.0, packY = -_bh / 2 - 80;
  sc.solids.add(const Solid3('box', packX, packY, 18, 130, 64, 36, Color(0xFF1F2937)));
  sc.solids.add(const Solid3('box', packX - 22, packY, 37, 56, 46, 2, Color(0xFFF59E0B)));
  sc.labels.add(Label3((packX - 22, packY, 42), '5 V', Colors.black87));
  sc.cables.add(Cable3(arc((packX + 40, packY + 30, 26), (_colX(2), railMinus, 0.5), 50), const Color(0xFF1E293B), wireR));
  sc.cables.add(Cable3(arc((packX + 56, packY + 30, 26), (_colX(3), railPlus, 0.5), 58), const Color(0xFFDC2626), wireR));

  // red jumper: + rail -> column 10 (row a)
  sc.cables.add(Cable3(jumper(cJ, railPlus, cJ, rowA, 4 * mm), const Color(0xFFDC2626), wireR));

  // slide switch SW1, pins in columns 10 to 12 (row c)
  final swX = (cJ + cS2) / 2;
  sc.solids.add(Solid3('box', swX, rowC, 3 * mm, cS2 - cJ + 4 * mm, 4.5 * mm, 6 * mm, const Color(0xFF334155)));
  sc.solids.add(Solid3('box', switchClosed ? swX + (cS2 - cJ) / 4 : swX - (cS2 - cJ) / 4, rowC, 7.2 * mm, 2.5 * mm, 2.5 * mm, 3 * mm, switchClosed ? const Color(0xFF22C55E) : const Color(0xFFEF4444)));
  sc.labels.add(Label3((swX, rowD - 4, 0.5), switchClosed ? 'SW1 ON' : 'SW1 OFF', switchClosed ? const Color(0xFF15803D) : const Color(0xFFB91C1C)));

  // resistor, legs in column 12 (row b) and column 15 (row b), lying a little above the board
  if (hasResistor) {
    final rz = 3.2 * mm, rx = (cS2 + cR2) / 2, ry = rowB;
    final body = 6.3 * mm, dia = 2.5 * mm;
    sc.cables.add(Cable3([(cS2, ry, 0.3), (cS2, ry, rz), (rx - body / 2, ry, rz)], const Color(0xFFB0BEC5), legR));
    sc.cables.add(Cable3([(cR2, ry, 0.3), (cR2, ry, rz), (rx + body / 2, ry, rz)], const Color(0xFFB0BEC5), legR));
    sc.solids.add(Solid3('cylx', rx, ry, rz, body, dia, dia, const Color(0xFFD8B38A)));
    final bands = resistorBands(ohms);
    for (var i = 0; i < 4; i++) {
      final o = (-0.32 + i * 0.18 + (i == 3 ? 0.1 : 0)) * body;
      sc.solids.add(Solid3('cylx', rx + o, ry, rz, 0.7 * mm, dia + 0.2, dia + 0.2, bands[i]));
    }
    sc.labels.add(Label3((rx, ry + 4.5 * mm, rz + 2 * mm), '${ohms.round()} Ω', const Color(0xFF0F172A)));
  } else {
    sc.labels.add(Label3(((cS2 + cR2) / 2, rowB, 4 * mm), 'add a resistor!', const Color(0xFFB91C1C)));
  }

  // 5 mm red LED: anode (long leg) in column 15, cathode in column 16 (row a; each column strip a-e is connected)
  final lit = running && switchClosed && hasResistor;
  final lx = (cA + cK) / 2, ly = rowA, base = 4.5 * mm;
  sc.cables.add(Cable3([(cA, ly, 0.3), (cA, ly, base * 0.6), (lx - 0.6 * mm, ly, base)], const Color(0xFFB0BEC5), legR));
  sc.cables.add(Cable3([(cK, ly, 0.3), (cK, ly, base * 0.6), (lx + 0.6 * mm, ly, base)], const Color(0xFFB0BEC5), legR));
  final ledCol = lit ? const Color(0xFFFF2D20) : const Color(0xFFD45A5A);
  sc.solids.add(Solid3('cylz', lx, ly, base + 0.5 * mm, 5.8 * mm, 5.8 * mm, 1 * mm, ledCol));
  sc.solids.add(Solid3('cylz', lx, ly, base + 3.5 * mm, 5 * mm, 5 * mm, 5 * mm, ledCol));
  sc.solids.add(Solid3('dome', lx, ly, base + 6 * mm, 5 * mm, 5 * mm, 2.5 * mm, ledCol));
  sc.labels.add(Label3((lx, ly + 5 * mm, base + 11 * mm), 'LED1', const Color(0xFFB91C1C)));
  if (lit) sc.glows.add(Glow3((lx, ly, base + 6 * mm), const Color(0xFFFF3B30), 16 * mm + 2 * mm * math.sin(progress * 2 * math.pi)));

  // black jumper: LED cathode column 16 (row c) -> - rail at column 18, closing the loop
  sc.cables.add(Cable3(jumper(cK, rowC, _colX(18), railMinus, 9 * mm), const Color(0xFF111827), wireR));

  // current flow dots along the loop while lit
  if (lit) {
    final loop = <P3>[(_colX(3), railPlus, 2), (cJ, railPlus, 2), (cJ, rowA, 2), (cJ, rowC, 2), (cS2, rowC, 2), (cS2, rowB, 2), (cR2, rowB, 2), (cA, rowA, 2), (cK, rowA, 2), (cK, rowC, 2), (_colX(18), railMinus, 2)];
    for (var i = 0; i < 12; i++) {
      final t = ((progress + i / 12) % 1.0) * (loop.length - 1);
      final k = t.floor(), f = t - k;
      final a = loop[k], b = loop[math.min(k + 1, loop.length - 1)];
      sc.glows.add(Glow3((a.$1 + (b.$1 - a.$1) * f, a.$2 + (b.$2 - a.$2) * f, 6), const Color(0xFFFACC15), 2.2 * mm));
    }
  }
  return sc;
}

/// Full-screen 3D view: drag to rotate, scroll or pinch to zoom.
class Board3DFullScreen extends StatefulWidget {
  final Scene3 Function() build;
  final Listenable? repaint;
  final double yaw, pitch;
  const Board3DFullScreen({super.key, required this.build, this.repaint, this.yaw = -0.3, this.pitch = 0.95});
  @override
  State<Board3DFullScreen> createState() => _Board3DFullScreenState();
}

class _Board3DFullScreenState extends State<Board3DFullScreen> {
  late double yaw = widget.yaw, pitch = widget.pitch;
  double zoom = 1.25, _startZoom = 1.25;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262626),
      body: Stack(children: [
        Positioned.fill(
          child: Listener(
            onPointerSignal: (e) {
              final dy = (e as dynamic).scrollDelta?.dy as double?;
              if (dy != null) setState(() => zoom = (zoom * (dy > 0 ? 0.9 : 1.1)).clamp(0.5, 4.0));
            },
            child: GestureDetector(
              onScaleStart: (_) => _startZoom = zoom,
              onScaleUpdate: (d) => setState(() {
                yaw += d.focalPointDelta.dx * 0.006;
                pitch = (pitch - d.focalPointDelta.dy * 0.005).clamp(0.25, 1.5);
                if (d.scale != 1.0) zoom = (_startZoom * d.scale).clamp(0.5, 4.0);
              }),
              child: CustomPaint(painter: Scene3Painter(build: widget.build, yaw: yaw, pitch: pitch, zoom: zoom, repaint: widget.repaint)),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: const Text('Drag to rotate  ·  scroll or pinch to zoom', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Row(children: [
            IconButton.filledTonal(tooltip: 'Zoom in', onPressed: () => setState(() => zoom = (zoom * 1.15).clamp(0.5, 4.0)), icon: const Icon(Icons.zoom_in)),
            const SizedBox(width: 6),
            IconButton.filledTonal(tooltip: 'Zoom out', onPressed: () => setState(() => zoom = (zoom / 1.15).clamp(0.5, 4.0)), icon: const Icon(Icons.zoom_out)),
            const SizedBox(width: 6),
            IconButton.filled(tooltip: 'Exit full screen', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.fullscreen_exit_rounded)),
          ]),
        ),
      ]),
    );
  }
}

/// Draws a [Scene3] with the live app's lighting, depth sorting and tube wires.
class Scene3Painter extends CustomPainter {
  final Scene3 Function() build;
  final double yaw, pitch, zoom;
  Scene3Painter({required this.build, required this.yaw, required this.pitch, required this.zoom, Listenable? repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = const RadialGradient(center: Alignment(0, -0.2), radius: 1.1, colors: [Color(0xFF4A4A4A), Color(0xFF262626)]).createShader(Offset.zero & size));
    final scene = build();
    final sc = math.max(0.2, math.min(size.width / 700, size.height / 430)) * zoom;
    final cy = math.cos(yaw), sy = math.sin(yaw), ce = math.cos(pitch), se = math.sin(pitch);
    const dist = 2100.0;
    (Offset, double) pr(P3 p) {
      final x1 = p.$1 * cy - (p.$2 + 20) * sy, y1 = p.$1 * sy + (p.$2 + 20) * cy;
      final up = y1 * se + p.$3 * ce, depth = y1 * ce - p.$3 * se;
      final k = dist / math.max(dist + depth, 80);
      return (Offset(size.width / 2 + x1 * sc * k, size.height * 0.5 - up * sc * k), depth);
    }

    const lx = 0.35, ly = -0.45, lz = 0.82;
    ({Path path, double depth, Color col}) project(Poly3 f) {
      var depth = 0.0;
      final path = Path();
      for (var i = 0; i < f.p.length; i++) {
        final (o, d) = pr(f.p[i]);
        depth += d;
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      path.close();
      final a = f.p[0], b = f.p[1], c = f.p[2];
      final ux = b.$1 - a.$1, uy = b.$2 - a.$2, uz = b.$3 - a.$3, vx = c.$1 - a.$1, vy = c.$2 - a.$2, vz = c.$3 - a.$3;
      var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
      final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (nl > 0) {
        nx /= nl;
        ny /= nl;
        nz /= nl;
      }
      final br = 0.38 + 0.72 * (nx * lx + ny * ly + nz * lz).abs();
      final col = Color.fromARGB(f.col.alpha, (f.col.red * br).round().clamp(0, 255), (f.col.green * br).round().clamp(0, 255), (f.col.blue * br).round().clamp(0, 255));
      return (path: path, depth: depth / f.p.length, col: col);
    }

    final edge = Paint()
      ..color = const Color(0x30000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final sides = [for (final f in scene.side) project(f)]..sort((a, b) => b.depth.compareTo(a.depth));
    for (final f in sides) {
      canvas.drawPath(f.path, Paint()..color = f.col);
    }
    for (final f in scene.decor) {
      final p = project(f);
      canvas.drawPath(p.path, Paint()..color = f.col.alpha < 255 ? f.col : Color.lerp(f.col, p.col, 0.25)!);
    }
    final polys = <({Path path, double depth, Color col})>[];
    for (final q in scene.solids) {
      for (final f in faces3(q)) {
        polys.add(project(Poly3(f.p, q.col)));
      }
    }
    polys.sort((a, b) => b.depth.compareTo(a.depth));
    for (final f in polys) {
      canvas.drawPath(f.path, Paint()..color = f.col);
      canvas.drawPath(f.path, edge);
    }
    for (final c in scene.cables) {
      final path = Path();
      var kk = 1.0;
      for (var i = 0; i < c.pts.length; i++) {
        final (o, d) = pr(c.pts[i]);
        if (i == c.pts.length ~/ 2) kk = dist / math.max(dist + d, 80);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      final w = math.max(1.2, c.r * 2 * sc * kk);
      canvas.drawPath(path, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = w + 1.2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      canvas.drawPath(path, Paint()..color = c.col..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
    for (final g in scene.glows) {
      final (o, d) = pr(g.at);
      final k = dist / math.max(dist + d, 80);
      final r = g.r * sc * k;
      canvas.drawCircle(o, r, Paint()..shader = RadialGradient(colors: [g.col.withOpacity(0.55), g.col.withOpacity(0)]).createShader(Rect.fromCircle(center: o, radius: r)));
    }
    for (final l in scene.labels) {
      final (o, d) = pr(l.at);
      final k = dist / math.max(dist + d, 80);
      final fs = 9.5 * sc * k;
      if (fs < 4.5) continue;
      final tp = TextPainter(text: TextSpan(text: l.text, style: TextStyle(color: l.col, fontSize: fs, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
      final box = Rect.fromCenter(center: o, width: tp.width + 8, height: tp.height + 3);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), Paint()..color = Colors.white.withOpacity(0.85));
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant Scene3Painter old) => true;
}
