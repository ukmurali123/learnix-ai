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
  const depth = 14.0;
  // board body (edges) and top
  for (final f in faces3(const Solid3('box', 0, 0, -depth / 2, _bw, _bh, depth, Color(0xFFE7E1D3)))) {
    sc.side.add(f);
  }
  P3 q(double x, double y, [double z = 0.05]) => (x, y, z);
  sc.decor.add(Poly3([q(-_bw / 2, -_bh / 2, 0.01), q(_bw / 2, -_bh / 2, 0.01), q(_bw / 2, _bh / 2, 0.01), q(-_bw / 2, _bh / 2, 0.01)], const Color(0xFFF3EFE6)));
  // centre channel
  sc.decor.add(Poly3([q(-_bw / 2 + 14, _rowY(0.48)), q(_bw / 2 - 14, _rowY(0.48)), q(_bw / 2 - 14, _rowY(0.52)), q(-_bw / 2 + 14, _rowY(0.52))], const Color(0xFFC9C3AF)));
  // rail stripes: red (+) and blue (-)
  for (final e in [(0.065, const Color(0xFFE53935)), (0.165, const Color(0xFF1E88E5)), (0.835, const Color(0xFFE53935)), (0.935, const Color(0xFF1E88E5))]) {
    final y = _rowY(e.$1);
    sc.decor.add(Poly3([q(-_bw / 2 + 16, y - 0.9), q(_bw / 2 - 16, y - 0.9), q(_bw / 2 - 16, y + 0.9), q(-_bw / 2 + 16, y + 0.9)], e.$2.withOpacity(0.8)));
  }
  // holes
  for (var c = 0; c < _cols; c++) {
    for (final rf in _rowFracs) {
      final x = _colX(c), y = _rowY(rf);
      sc.decor.add(Poly3([q(x - 2.3, y - 2.3, 0.08), q(x + 2.3, y - 2.3, 0.08), q(x + 2.3, y + 2.3, 0.08), q(x - 2.3, y + 2.3, 0.08)], const Color(0xFF3F3F46)));
    }
  }

  final c1 = _colX(1), c3 = _colX(3), c5 = _colX(5), c7 = _colX(7), c9 = _colX(9);
  final railPlus = _rowY(0.09), railMinus = _rowY(0.14), rowB = _rowY(0.31), rowC = _rowY(0.36);

  // battery pack in front of the board (5 V)
  const packX = -200.0, packY = -_bh / 2 - 70;
  sc.solids.add(const Solid3('box', packX, packY, 14, 110, 52, 28, Color(0xFF1F2937)));
  sc.solids.add(const Solid3('box', packX - 18, packY, 29, 46, 40, 2, Color(0xFFF59E0B)));
  sc.labels.add(Label3((packX - 18, packY, 34), '5 V', Colors.black87));
  // supply leads (tubes) from the pack to the top rails
  List<P3> arc(P3 a, P3 b, double h) => [for (var i = 0; i <= 12; i++) (a.$1 + (b.$1 - a.$1) * i / 12, a.$2 + (b.$2 - a.$2) * i / 12, a.$3 + (b.$3 - a.$3) * i / 12 + h * math.sin(math.pi * i / 12))];
  sc.cables.add(Cable3(arc((packX + 30, packY + 26, 20), (c1, railMinus, 0.5), 40), const Color(0xFF1E293B), 2.2));
  sc.cables.add(Cable3(arc((packX + 44, packY + 26, 20), (c1 + _colX(2) - _colX(1), railPlus, 0.5), 46), const Color(0xFFDC2626), 2.2));
  // jumper: + rail to row b, column 3
  sc.cables.add(Cable3(arc((c3, railPlus, 0.5), (c3, rowB, 0.5), 16), const Color(0xFFDC2626), 2.0));

  // slide switch SW1 (columns 3 to 5, row c)
  final swX = (c3 + c5) / 2;
  sc.solids.add(Solid3('box', swX, rowC, 6, c5 - c3 + 14, 14, 12, const Color(0xFF475569)));
  sc.solids.add(Solid3('box', switchClosed ? swX + (c5 - c3) / 4 : swX - (c5 - c3) / 4, rowC, 14, 8, 7, 6, switchClosed ? const Color(0xFF16A34A) : const Color(0xFFDC2626)));
  sc.labels.add(Label3((swX, rowC - 14, 0.5), switchClosed ? 'SW ON' : 'SW OFF', const Color(0xFF334155)));

  // 330 ohm resistor (columns 5 to 7), standing a little above the board, legs bent into the holes
  if (hasResistor) {
    final rx = (c5 + c7) / 2, ry = (rowC + rowB) / 2, rz = 9.0;
    final ang = math.atan2(rowB - rowC, c7 - c5);
    final len = math.sqrt(math.pow(c7 - c5, 2) + math.pow(rowB - rowC, 2));
    sc.cables.add(Cable3([(c5, rowC, 0.5), (c5, rowC, rz), (rx - len * 0.3 * math.cos(ang), ry - len * 0.3 * math.sin(ang), rz)], const Color(0xFFB0BEC5), 0.7));
    sc.cables.add(Cable3([(c7, rowB, 0.5), (c7, rowB, rz), (rx + len * 0.3 * math.cos(ang), ry + len * 0.3 * math.sin(ang), rz)], const Color(0xFFB0BEC5), 0.7));
    sc.solids.add(Solid3('cylx', rx, ry, rz, len * 0.55, 6.5, 6.5, const Color(0xFFD8B38A), rot: ang));
    final bands = resistorBands(ohms);
    for (var i = 0; i < 4; i++) {
      final o = (-0.18 + i * 0.11 + (i == 3 ? 0.06 : 0)) * len;
      sc.solids.add(Solid3('cylx', rx + o * math.cos(ang), ry + o * math.sin(ang), rz, 2.2, 6.9, 6.9, bands[i], rot: ang));
    }
    sc.labels.add(Label3((rx, ry - 16, 0.5), '${ohms.round()} Ω', const Color(0xFF0F172A)));
  }

  // red LED (anode column 7, cathode column 9, row b)
  final lit = running && switchClosed && hasResistor;
  final lx = (c7 + c9) / 2, ly = rowB + 6;
  sc.cables.add(Cable3([(c7, rowB, 0.5), (c7, rowB, 8), (lx - 3, ly, 20)], const Color(0xFFB0BEC5), 0.7));
  sc.cables.add(Cable3([(c9, rowB, 0.5), (c9, rowB, 8), (lx + 3, ly, 20)], const Color(0xFFB0BEC5), 0.7));
  final ledCol = lit ? const Color(0xFFFF3B30) : const Color(0xFFE57373);
  sc.solids.add(Solid3('cylz', lx, ly, 22, 13, 13, 4, ledCol));
  sc.solids.add(Solid3('cylz', lx, ly, 29, 11, 11, 10, ledCol.withOpacity(0.92)));
  sc.solids.add(Solid3('dome', lx, ly, 34, 11, 11, 6, ledCol));
  sc.labels.add(Label3((lx, ly + 16, 46), 'LED1', const Color(0xFFB91C1C)));
  if (lit) sc.glows.add(Glow3((lx, ly, 34), const Color(0xFFFF3B30), 46 + 6 * math.sin(progress * 2 * math.pi)));
  return sc;
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
    final sc = math.max(0.2, math.min(size.width / 760, size.height / 470)) * zoom;
    final cy = math.cos(yaw), sy = math.sin(yaw), ce = math.cos(pitch), se = math.sin(pitch);
    const dist = 2100.0;
    (Offset, double) pr(P3 p) {
      final x1 = p.$1 * cy - (p.$2 + 40) * sy, y1 = p.$1 * sy + (p.$2 + 40) * cy;
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
