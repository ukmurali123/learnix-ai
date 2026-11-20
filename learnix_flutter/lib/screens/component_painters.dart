import 'dart:math' as math;
import 'package:flutter/material.dart';

// =============================================================================
// 1. WHAT: INTERACTIVE COMPONENT SCHEMATIC PAINTER
// =============================================================================
class InteractiveComponentSchematicPainter extends CustomPainter {
  final String component; // 'battery', 'led', 'resistor', 'buzzer', 'ssd'
  final double progress;
  final int resistorOhms;
  final double currentMa;
  final int topology; // 0: 1 LED, 1: series, 2: parallel
  final int resistorBand1;
  final int resistorBand2;
  final int resistorMultiplier;
  final int selectedResistorBandTab;
  final List<bool> ssdSegments; // A, B, C, D, E, F, G, DP
  final int ssdDigit;
  final double buzzerFrequency;
  final double batteryVoltage;

  InteractiveComponentSchematicPainter({
    required this.component,
    required this.progress,
    required this.resistorOhms,
    required this.currentMa,
    required this.topology,
    this.resistorBand1 = 1,
    this.resistorBand2 = 0,
    this.resistorMultiplier = 2,
    this.selectedResistorBandTab = 0,
    this.ssdSegments = const [true, true, true, true, true, true, true, false],
    this.ssdDigit = 8,
    this.buzzerFrequency = 880.0,
    this.batteryVoltage = 9.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background dot grid
    final dotPaint = Paint()..color = const Color(0xFFCBD5E1).withOpacity(0.55);
    for (double x = 16; x < size.width; x += 20) {
      for (double y = 16; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
      }
    }

    switch (component) {
      case 'battery':
        _drawBatterySchematic(canvas, size);
        break;
      case 'resistor':
        _drawResistorColorCodeSchematic(canvas, size);
        break;
      case 'buzzer':
        _drawBuzzerSchematic(canvas, size);
        break;
      case 'ssd':
        _drawSsdSchematic(canvas, size);
        break;
      case 'led':
      default:
        _drawLedSchematic(canvas, size);
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // A. BATTERY SCHEMATIC (9V / DC Chemical Cell)
  // ---------------------------------------------------------------------------
  void _drawBatterySchematic(Canvas canvas, Size size) {
    final centerX = size.width * 0.40;
    final centerY = size.height * 0.50;
    final batWidth = 160.0;
    final batHeight = 110.0;
    final batRect = Rect.fromCenter(center: Offset(centerX, centerY), width: batWidth, height: batHeight);

    // Battery Body
    final casingPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(batRect);
    canvas.drawRRect(RRect.fromRectAndRadius(batRect, const Radius.circular(16)), casingPaint);

    // Left Copper/Gold Header Band
    final bandRect = Rect.fromLTWH(batRect.left, batRect.top, 48, batHeight);
    final bandPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFFBBF24), Color(0xFFB45309)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bandRect);
    canvas.drawRRect(
      RRect.fromRectAndCorners(bandRect, topLeft: const Radius.circular(16), bottomLeft: const Radius.circular(16)),
      bandPaint,
    );

    // Terminals
    final anodePos = Offset(batRect.left + 45, batRect.top - 12);
    final cathodePos = Offset(batRect.right - 45, batRect.top - 10);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: anodePos, width: 22, height: 24), const Radius.circular(4)),
      Paint()..color = const Color(0xFFDC2626),
    );
    canvas.drawCircle(anodePos, 6, Paint()..color = const Color(0xFFFACC15));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: cathodePos, width: 26, height: 20), const Radius.circular(3)),
      Paint()..color = const Color(0xFF475569),
    );
    canvas.drawCircle(cathodePos, 7, Paint()..color = const Color(0xFF94A3B8));

    // Labels inside battery
    final tpBatTitle = TextPainter(
      text: const TextSpan(
        text: 'LEARNIX 9V',
        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpBatTitle.paint(canvas, Offset(batRect.left + 58, centerY - 28));

    final tpBatSub = TextPainter(
      text: const TextSpan(
        text: 'DC POWER CELL · 100% HEALTH',
        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpBatSub.paint(canvas, Offset(batRect.left + 58, centerY - 10));

    // Voltage Gauge Box
    final gaugeRect = Rect.fromLTWH(batRect.left + 58, centerY + 8, 88, 26);
    canvas.drawRRect(RRect.fromRectAndRadius(gaugeRect, const Radius.circular(6)), Paint()..color = const Color(0xFF020617));
    canvas.drawRRect(
      RRect.fromRectAndRadius(gaugeRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 1.2,
    );
    final tpVolt = TextPainter(
      text: TextSpan(
        text: '${batteryVoltage.toStringAsFixed(1)} V DC',
        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpVolt.paint(canvas, Offset(gaugeRect.left + 12, gaugeRect.top + 5));

    // Wire Loop connecting through a load
    final wirePaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final wirePath = Path()
      ..moveTo(anodePos.dx, anodePos.dy)
      ..lineTo(anodePos.dx, 32)
      ..lineTo(size.width * 0.86, 32)
      ..lineTo(size.width * 0.86, size.height - 32)
      ..lineTo(cathodePos.dx, size.height - 32)
      ..lineTo(cathodePos.dx, batRect.bottom);
    canvas.drawPath(wirePath, wirePaint);

    // Animated electron flow
    final pathMetrics = wirePath.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final totalLen = metric.length;
      final electronPaint = Paint()..color = const Color(0xFF38BDF8);
      for (int i = 0; i < 9; i++) {
        final dist = ((i / 9 + progress) % 1.0) * totalLen;
        final pos = metric.getTangentForOffset(dist)?.position;
        if (pos != null) {
          canvas.drawCircle(pos, 4.5, electronPaint);
          canvas.drawCircle(pos, 2.0, Paint()..color = Colors.white);
        }
      }
    }

    // Load indicator (Glowing Lamp on right wire)
    final loadCenter = Offset(size.width * 0.86, size.height * 0.50);
    canvas.drawCircle(loadCenter, 18, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(loadCenter, 18, Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(loadCenter, 10, Paint()..color = const Color(0xFFFBBF24));

    // Badges
    _drawBadge(canvas, Offset(anodePos.dx - 22, anodePos.dy - 22), 'ANODE (+)', const Color(0xFFDC2626));
    _drawBadge(canvas, Offset(cathodePos.dx + 4, cathodePos.dy - 22), 'CATHODE (−)', const Color(0xFF0F172A));
  }

  // ---------------------------------------------------------------------------
  // B. LED SCHEMATIC (Light Emitting Diode Circuit)
  // ---------------------------------------------------------------------------
  void _drawLedSchematic(Canvas canvas, Size size) {
    final left = size.width * 0.16;
    final right = size.width * 0.86;
    final top = size.height * 0.25;
    final bottom = size.height * 0.78;

    final wirePaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), wirePaint);

    if (topology == 2) {
      final parallelY = top + 46;
      canvas.drawLine(Offset(size.width * 0.52, top), Offset(size.width * 0.52, parallelY), wirePaint);
      canvas.drawLine(Offset(size.width * 0.52, parallelY), Offset(size.width * 0.78, parallelY), wirePaint);
      canvas.drawLine(Offset(size.width * 0.78, parallelY), Offset(size.width * 0.78, top), wirePaint);
    }

    // Battery on left wire
    final batCenterY = (top + bottom) / 2;
    final batRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(left, batCenterY), width: 32, height: 64),
      const Radius.circular(6),
    );
    canvas.drawRRect(batRect, Paint()..color = const Color(0xFF15803D));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(left, batCenterY - 22), width: 32, height: 14),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFFACC15),
    );

    // 330 Ω Resistor on top wire
    final resCenterX = size.width * 0.32;
    final resRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(resCenterX, top), width: 62, height: 24),
      const Radius.circular(10),
    );
    canvas.drawRRect(resRect, Paint()..color = const Color(0xFFFDE68A));
    canvas.drawRRect(
      resRect,
      Paint()..color = const Color(0xFFB45309)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
    // Bands
    final bandColors = [
      const Color(0xFF92400E),
      const Color(0xFF92400E),
      const Color(0xFF991B1B),
      const Color(0xFFEAB308),
    ];
    for (int b = 0; b < 4; b++) {
      final bx = resCenterX - 18 + b * 12;
      canvas.drawRect(Rect.fromLTWH(bx, top - 11, 4.5, 22), Paint()..color = bandColors[b]);
    }

    // LED Diode symbol & glow
    final ledCenterX = size.width * 0.65;
    final ledGlow = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(Offset(ledCenterX, top), 22, ledGlow);

    final ledBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(ledCenterX, top), width: 34, height: 34),
      const Radius.circular(8),
    );
    canvas.drawRRect(ledBody, Paint()..color = const Color(0xFFDC2626));
    canvas.drawRRect(
      ledBody,
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    // Diode triangle icon inside LED
    final path = Path()
      ..moveTo(ledCenterX - 8, top - 9)
      ..lineTo(ledCenterX - 8, top + 9)
      ..lineTo(ledCenterX + 8, top)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawLine(Offset(ledCenterX + 8, top - 9), Offset(ledCenterX + 8, top + 9), Paint()..color = Colors.white..strokeWidth = 2.5);

    // Emitting photon light rays
    final rayPaint = Paint()..color = const Color(0xFFF87171)..strokeWidth = 2;
    canvas.drawLine(Offset(ledCenterX + 16, top - 14), Offset(ledCenterX + 28, top - 24), rayPaint);
    canvas.drawLine(Offset(ledCenterX + 22, top - 8), Offset(ledCenterX + 34, top - 18), rayPaint);

    // Animated electron flow
    final w = right - left;
    final h = bottom - top;
    final perim = 2 * (w + h);
    final electronPaint = Paint()..color = const Color(0xFFEAB308);

    for (int i = 0; i < 10; i++) {
      final f = ((i / 10) + progress) % 1.0;
      final d = f * perim;
      Offset pt;
      if (d < w) {
        pt = Offset(left + d, top);
      } else if (d < w + h) {
        pt = Offset(right, top + (d - w));
      } else if (d < 2 * w + h) {
        pt = Offset(right - (d - (w + h)), bottom);
      } else {
        pt = Offset(left, bottom - (d - (2 * w + h)));
      }
      canvas.drawCircle(pt, 4.5, electronPaint);
      canvas.drawCircle(pt, 2.0, Paint()..color = Colors.white);
    }

    // Telemetry text
    final tpCurrent = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${currentMa.toStringAsFixed(1)} mA\n',
            style: const TextStyle(color: Color(0xFF0284C7), fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const TextSpan(
            text: 'I = (5 V − LED drop) ÷ R',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tpCurrent.paint(canvas, Offset(size.width * 0.40, size.height * 0.44));
  }

  // ---------------------------------------------------------------------------
  // C. RESISTOR & 4-COLOR BAND CODE SCHEMATIC (Day 2 / Resistor Explorer)
  // ---------------------------------------------------------------------------
  void _drawResistorColorCodeSchematic(Canvas canvas, Size size) {
    final centerX = size.width * 0.35;
    final centerY = size.height * 0.45;

    // Ceramic body dimensions
    final bodyWidth = 190.0;
    final bodyHeight = 72.0;

    // Ceramic lead wires
    final leadPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centerX - 170, centerY), Offset(centerX - (bodyWidth / 2), centerY), leadPaint);
    canvas.drawLine(Offset(centerX + (bodyWidth / 2), centerY), Offset(centerX + 170, centerY), leadPaint);

    // Ceramic bone shape
    final ceramicRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, centerY), width: bodyWidth, height: bodyHeight),
      const Radius.circular(36),
    );
    final ceramicFill = Paint()..color = const Color(0xFFDEC39B);
    canvas.drawRRect(ceramicRect, ceramicFill);
    canvas.drawRRect(
      ceramicRect,
      Paint()..color = const Color(0xFF785536)..style = PaintingStyle.stroke..strokeWidth = 3,
    );

    // 4 Color bands
    final List<Color> resistorColorPalette = [
      const Color(0xFF0F172A), // 0: Black
      const Color(0xFF78350F), // 1: Brown
      const Color(0xFFDC2626), // 2: Red
      const Color(0xFFE65100), // 3: Orange
      const Color(0xFFCA8A04), // 4: Yellow
      const Color(0xFF16A34A), // 5: Green
      const Color(0xFF0077B6), // 6: Blue
      const Color(0xFF7C3AED), // 7: Violet
      const Color(0xFF64748B), // 8: Grey
      const Color(0xFFFFFFFF), // 9: White
    ];

    final b1Color = resistorColorPalette[resistorBand1.clamp(0, 9)];
    final b2Color = resistorColorPalette[resistorBand2.clamp(0, 9)];
    final multColor = resistorColorPalette[resistorMultiplier.clamp(0, 9)];
    final tolColor = const Color(0xFFF59E0B); // Gold ±5%

    final bandXOffsets = [-55.0, -22.0, 18.0, 58.0];
    final bandColors = [b1Color, b2Color, multColor, tolColor];

    for (int i = 0; i < 4; i++) {
      final bx = centerX + bandXOffsets[i];
      final bandRect = Rect.fromCenter(center: Offset(bx, centerY), width: 17, height: bodyHeight - 4);
      canvas.drawRect(bandRect, Paint()..color = bandColors[i]);

      if (i == selectedResistorBandTab) {
        canvas.drawRect(
          bandRect.inflate(3),
          Paint()..color = const Color(0xFF0284C7)..style = PaintingStyle.stroke..strokeWidth = 2.5,
        );
      }
    }

    // Calculated Ohm Resistance Value
    final double rawVal = ((resistorBand1 * 10) + resistorBand2) * math.pow(10, resistorMultiplier).toDouble();
    String formattedVal;
    if (rawVal >= 1000000) {
      formattedVal = '${(rawVal / 1000000).toStringAsFixed(2)} MΩ';
    } else if (rawVal >= 1000) {
      formattedVal = '${(rawVal / 1000).toStringAsFixed(2)} kΩ';
    } else {
      formattedVal = '${rawVal.toInt()} Ω';
    }

    final tpVal = TextPainter(
      text: TextSpan(
        text: formattedVal,
        style: const TextStyle(color: Color(0xFF0284C7), fontSize: 34, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpVal.paint(canvas, Offset(centerX - tpVal.width / 2, centerY + 58));

    final colorNames = ['Black', 'Brown', 'Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Violet', 'Grey', 'White'];
    final tpBands = TextPainter(
      text: TextSpan(
        text: '${colorNames[resistorBand1]} · ${colorNames[resistorBand2]} · ${colorNames[resistorMultiplier]} · Gold (±5%)',
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpBands.paint(canvas, Offset(centerX - tpBands.width / 2, centerY + 104));
  }

  // ---------------------------------------------------------------------------
  // D. BUZZER SCHEMATIC (Piezo Sounder & Alerts)
  // ---------------------------------------------------------------------------
  void _drawBuzzerSchematic(Canvas canvas, Size size) {
    final centerX = size.width * 0.40;
    final centerY = size.height * 0.50;

    // Cylindrical Piezo Casing
    final radius = 58.0;
    canvas.drawCircle(Offset(centerX, centerY), radius, Paint()..color = const Color(0xFF0F172A));
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius,
      Paint()..color = const Color(0xFF334155)..style = PaintingStyle.stroke..strokeWidth = 3,
    );

    // Sound aperture hole in center
    canvas.drawCircle(Offset(centerX, centerY), 16, Paint()..color = const Color(0xFF020617));

    // Vibrating Piezo Diaphragm ring
    final pulseScale = 1.0 + (math.sin(progress * 2 * math.pi) * 0.08);
    canvas.drawCircle(
      Offset(centerX, centerY),
      32 * pulseScale,
      Paint()..color = const Color(0xFF9333EA).withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 3,
    );

    // Radiating Acoustic Sound Waves (expanding arcs)
    final arcPaint = Paint()
      ..color = const Color(0xFFA855F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (int i = 1; i <= 4; i++) {
      final arcRadius = radius + 14 + (i * 22) + (progress * 18);
      final alpha = (1.0 - ((i * 22 + progress * 18) / 110)).clamp(0.0, 1.0);
      arcPaint.color = const Color(0xFFA855F7).withOpacity(alpha * 0.85);

      canvas.drawArc(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: arcRadius),
        -math.pi / 4,
        math.pi / 2,
        false,
        arcPaint,
      );
    }

    // Leads (+ Red and - Black)
    final leadPaint = Paint()..strokeWidth = 4..strokeCap = StrokeCap.round;
    leadPaint.color = const Color(0xFFDC2626); // +5V Red
    canvas.drawLine(Offset(centerX - 35, centerY + radius), Offset(centerX - 35, centerY + radius + 32), leadPaint);
    leadPaint.color = const Color(0xFF0F172A); // GND Black
    canvas.drawLine(Offset(centerX + 35, centerY + radius), Offset(centerX + 35, centerY + radius + 32), leadPaint);

    _drawBadge(canvas, Offset(centerX - 65, centerY + radius + 36), 'PIN D8 (+)', const Color(0xFFDC2626));
    _drawBadge(canvas, Offset(centerX + 15, centerY + radius + 36), 'GND (−)', const Color(0xFF0F172A));

    // Live Frequency Readout
    final tpFreq = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${buzzerFrequency.toInt()} Hz\n',
            style: const TextStyle(color: Color(0xFF9333EA), fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const TextSpan(
            text: 'Arduino tone(BUZZER, 880)',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tpFreq.paint(canvas, Offset(size.width * 0.70, centerY - 25));
  }

  // ---------------------------------------------------------------------------
  // E. SSD SCHEMATIC (Seven-Segment Display)
  // ---------------------------------------------------------------------------
  void _drawSsdSchematic(Canvas canvas, Size size) {
    final centerX = size.width * 0.38;
    final centerY = size.height * 0.50;
    final chipWidth = 140.0;
    final chipHeight = 190.0;
    final chipRect = Rect.fromCenter(center: Offset(centerX, centerY), width: chipWidth, height: chipHeight);

    // Casing
    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(16)),
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(16)),
      Paint()..color = const Color(0xFF334155)..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    // Inner dark display window
    final innerRect = Rect.fromCenter(center: Offset(centerX, centerY), width: chipWidth - 24, height: chipHeight - 28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(10)),
      Paint()..color = const Color(0xFF020617),
    );

    // 7-Segment Bar Dimensions
    final segW = 46.0;
    final segH = 9.0;
    final vertW = 9.0;
    final vertH = 40.0;
    final cx = centerX;
    final cy = centerY;

    // A, B, C, D, E, F, G Rectangles
    final segARect = Rect.fromCenter(center: Offset(cx, cy - 50), width: segW, height: segH);
    final segBRect = Rect.fromCenter(center: Offset(cx + 26, cy - 26), width: vertW, height: vertH);
    final segCRect = Rect.fromCenter(center: Offset(cx + 26, cy + 26), width: vertW, height: vertH);
    final segDRect = Rect.fromCenter(center: Offset(cx, cy + 50), width: segW, height: segH);
    final segERect = Rect.fromCenter(center: Offset(cx - 26, cy + 26), width: vertW, height: vertH);
    final segFRect = Rect.fromCenter(center: Offset(cx - 26, cy - 26), width: vertW, height: vertH);
    final segGRect = Rect.fromCenter(center: Offset(cx, cy), width: segW, height: segH);
    final dpCenter = Offset(cx + 38, cy + 52);

    final segRects = [segARect, segBRect, segCRect, segDRect, segERect, segFRect, segGRect];
    final segLabels = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

    // Draw the 7 segments
    for (int i = 0; i < 7; i++) {
      final isOn = (i < ssdSegments.length) ? ssdSegments[i] : true;
      final rect = segRects[i];

      if (isOn) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = const Color(0xFFEF4444).withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = const Color(0xFFEF4444),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(2)),
          Paint()..color = const Color(0xFFFCA5A5),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = const Color(0xFF1E293B).withOpacity(0.4),
        );
      }
    }

    // Decimal Point (DP)
    final dpOn = ssdSegments.length > 7 ? ssdSegments[7] : false;
    if (dpOn) {
      canvas.drawCircle(dpCenter, 5, Paint()..color = const Color(0xFFEF4444));
      canvas.drawCircle(dpCenter, 2.5, Paint()..color = Colors.white);
    } else {
      canvas.drawCircle(dpCenter, 4, Paint()..color = const Color(0xFF1E293B).withOpacity(0.4));
    }

    // Right Telemetry Panel
    final rightX = size.width * 0.62;
    final tpDigitTitle = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(text: 'SSD DIGIT: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w700)),
          TextSpan(text: '$ssdDigit', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 28, fontWeight: FontWeight.w900)),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpDigitTitle.paint(canvas, Offset(rightX, centerY - 62));

    final activeNames = <String>[];
    for (int i = 0; i < 7; i++) {
      if (i < ssdSegments.length && ssdSegments[i]) {
        activeNames.add(segLabels[i]);
      }
    }
    if (dpOn) activeNames.add('DP');

    final tpSegActive = TextPainter(
      text: TextSpan(
        text: 'Active: ${activeNames.join(', ')}',
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpSegActive.paint(canvas, Offset(rightX, centerY - 28));

    final tpDesc = TextPainter(
      text: const TextSpan(
        text: '• Common Cathode: Pin 3 & 8 to GND (0V)\n• High (5V) on Pin lights segment\n• Controlled via 7 digital Arduino pins',
        style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600, height: 1.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.35);
    tpDesc.paint(canvas, Offset(rightX, centerY - 2));
  }

  void _drawBadge(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx, pos.dy, tp.width + 10, tp.height + 6),
      const Radius.circular(5),
    );
    canvas.drawRRect(badgeRect, Paint()..color = color);
    tp.paint(canvas, Offset(pos.dx + 5, pos.dy + 3));
  }

  @override
  bool shouldRepaint(covariant InteractiveComponentSchematicPainter oldDelegate) => true;
}

// =============================================================================
// 2. LIKE: COMPONENT REAL-TIME ANALOGY PAINTER
// =============================================================================
class ComponentLikeAnalogyPainter extends CustomPainter {
  final String component;
  final double progress;
  final int resistorOhms;
  final int selectedPart;

  ComponentLikeAnalogyPainter({
    required this.component,
    required this.progress,
    required this.resistorOhms,
    required this.selectedPart,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Soft sky blue/water background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFFF0F9FF),
    );

    if (component == 'battery') {
      _drawWaterTowerPump(canvas, size);
    } else if (component == 'buzzer') {
      _drawGuardDogCricket(canvas, size);
    } else if (component == 'ssd') {
      _drawScoreboardElevator(canvas, size);
    } else if (component == 'resistor') {
      _drawPinchPipe(canvas, size);
    } else {
      _drawTurnstileGate(canvas, size);
    }
  }

  void _drawWaterTowerPump(Canvas canvas, Size size) {
    // Water Pump (Battery) pushing water up to rooftop tank
    final centerX = size.width * 0.5;
    final topTankY = size.height * 0.22;
    final botTankY = size.height * 0.78;

    // Top high pressure tank (High Voltage)
    final topTankRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX - 80, topTankY), width: 90, height: 50),
      const Radius.circular(10),
    );
    canvas.drawRRect(topTankRect, Paint()..color = const Color(0xFF0284C7));

    // Bottom reservoir (GND 0V)
    final botTankRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX + 80, botTankY), width: 110, height: 44),
      const Radius.circular(10),
    );
    canvas.drawRRect(botTankRect, Paint()..color = const Color(0xFF0F172A));

    // Connecting transparent pipes
    final pipePaint = Paint()
      ..color = const Color(0xFFBAE6FD)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final pipePath = Path()
      ..moveTo(centerX + 80, botTankY)
      ..lineTo(size.width * 0.88, botTankY)
      ..lineTo(size.width * 0.88, topTankY)
      ..lineTo(centerX - 40, topTankY);
    canvas.drawPath(pipePath, pipePaint);

    final dropPath = Path()
      ..moveTo(centerX - 80, topTankY + 25)
      ..lineTo(centerX - 80, botTankY)
      ..lineTo(centerX + 30, botTankY);
    canvas.drawPath(dropPath, pipePaint);

    // Droplets
    final dropPaint = Paint()..color = const Color(0xFF0284C7);
    for (int i = 0; i < 8; i++) {
      final f = (i / 8 + progress) % 1.0;
      final dy = (topTankY + 25) + f * (botTankY - (topTankY + 25));
      canvas.drawCircle(Offset(centerX - 80, dy), 5, dropPaint);
    }

    // Pump Symbol in bottom pipe
    final pumpPos = Offset(size.width * 0.88, (topTankY + botTankY) / 2);
    canvas.drawCircle(pumpPos, 22, Paint()..color = const Color(0xFF16A34A));
    canvas.drawCircle(pumpPos, 10, Paint()..color = Colors.white);

    _drawText(canvas, Offset(centerX - 120, topTankY - 32), 'HIGH WATER TOWER (+9V)', const Color(0xFF0284C7));
    _drawText(canvas, Offset(size.width * 0.72, pumpPos.dy - 32), 'ELECTRIC PUMP', const Color(0xFF16A34A));
    _drawText(canvas, Offset(centerX + 35, botTankY + 26), 'GROUND RESERVOIR (0V)', const Color(0xFF0F172A));
  }

  void _drawTurnstileGate(Canvas canvas, Size size) {
    // One-Way Turnstile Analogy for LED
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;

    // Ground walkway
    canvas.drawRect(
      Rect.fromLTRB(40, centerY - 35, size.width - 40, centerY + 35),
      Paint()..color = const Color(0xFFE2E8F0),
    );

    // Turnstile barrier pole
    canvas.drawCircle(Offset(centerX, centerY), 28, Paint()..color = const Color(0xFF1E293B));

    // Rotating one-way green flap
    final angle = progress * math.pi * 2;
    final flapX = centerX + math.cos(angle) * 36;
    final flapY = centerY + math.sin(angle) * 36;
    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(flapX, flapY),
      Paint()..color = const Color(0xFF16A34A)..strokeWidth = 6..strokeCap = StrokeCap.round,
    );

    // Glowing victory lamp above the gate
    final lampPos = Offset(centerX, centerY - 65);
    canvas.drawCircle(lampPos, 18, Paint()..color = const Color(0xFFFBBF24));
    canvas.drawCircle(lampPos, 26, Paint()..color = const Color(0xFFFBBF24).withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    _drawText(canvas, Offset(centerX - 90, centerY - 100), 'ONE-WAY THEME PARK GATE (LED)', const Color(0xFFDC2626));
    _drawText(canvas, Offset(centerX - 80, centerY + 50), 'Electrons pass forward & light victory lamp!', const Color(0xFF475569));
  }

  void _drawPinchPipe(Canvas canvas, Size size) {
    // Wide pipe into narrow constriction for Resistor
    final centerY = size.height * 0.50;
    final path = Path()
      ..moveTo(40, centerY - 38)
      ..lineTo(size.width * 0.35, centerY - 38)
      ..lineTo(size.width * 0.45, centerY - 12)
      ..lineTo(size.width * 0.55, centerY - 12)
      ..lineTo(size.width * 0.65, centerY - 38)
      ..lineTo(size.width - 40, centerY - 38)
      ..lineTo(size.width - 40, centerY + 38)
      ..lineTo(size.width * 0.65, centerY + 38)
      ..lineTo(size.width * 0.55, centerY + 12)
      ..lineTo(size.width * 0.45, centerY + 12)
      ..lineTo(size.width * 0.35, centerY + 38)
      ..lineTo(40, centerY + 38)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFFBAE6FD));
    canvas.drawPath(path, Paint()..color = const Color(0xFF0284C7)..style = PaintingStyle.stroke..strokeWidth = 3);

    // Particles rushing in wide pipe then slowing down
    for (int i = 0; i < 14; i++) {
      final f = (i / 14 + progress) % 1.0;
      final px = 50 + f * (size.width - 100);
      double py = centerY;
      if (px >= size.width * 0.45 && px <= size.width * 0.55) {
        py = centerY + (math.sin(i.toDouble()) * 5);
      } else {
        py = centerY + (math.sin(i.toDouble()) * 22);
      }
      canvas.drawCircle(Offset(px, py), 4.5, Paint()..color = const Color(0xFF0284C7));
    }

    _drawText(canvas, Offset(size.width * 0.28, centerY - 70), 'NARROW PINCH IN WATER PIPE (RESISTOR)', const Color(0xFF0284C7));
    _drawText(canvas, Offset(size.width * 0.30, centerY + 55), 'Restricts flood into a safe, controlled flow!', const Color(0xFF475569));
  }

  void _drawGuardDogCricket(Canvas canvas, Size size) {
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.48;

    // Doghouse / Bell enclosure
    canvas.drawCircle(Offset(centerX, centerY), 42, Paint()..color = const Color(0xFF7E22CE));

    // Flapping vibrating sound waves
    for (int i = 1; i <= 3; i++) {
      final r = 50.0 + (i * 24) + (progress * 15);
      canvas.drawCircle(
        Offset(centerX, centerY),
        r,
        Paint()..color = const Color(0xFFA855F7).withOpacity(0.4 - (i * 0.1))..style = PaintingStyle.stroke..strokeWidth = 3,
      );
    }

    _drawText(canvas, Offset(centerX - 100, centerY - 85), 'GUARD DOG ALERT BELL (BUZZER)', const Color(0xFF7E22CE));
    _drawText(canvas, Offset(centerX - 120, centerY + 65), 'Flaps and barks instantly to grab human attention!', const Color(0xFF475569));
  }

  void _drawScoreboardElevator(Canvas canvas, Size size) {
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.48;

    // Stadium Scoreboard Frame
    final boardRect = Rect.fromCenter(center: Offset(centerX, centerY), width: 180, height: 110);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(12)),
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(12)),
      Paint()..color = const Color(0xFFE11D48)..style = PaintingStyle.stroke..strokeWidth = 2.5,
    );

    // Glowing Neon Bars forming number 8
    _drawText(canvas, Offset(centerX - 35, centerY - 28), '8 8', const Color(0xFFEF4444), fontSize: 44);

    _drawText(canvas, Offset(centerX - 110, centerY - 80), 'STADIUM SCOREBOARD (7-SEGMENT)', const Color(0xFFE11D48));
    _drawText(canvas, Offset(centerX - 125, centerY + 70), '7 glowing neon bars assemble into crisp numbers!', const Color(0xFF475569));
  }

  void _drawText(Canvas canvas, Offset pos, String text, Color color, {double fontSize = 12.5}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant ComponentLikeAnalogyPainter oldDelegate) => true;
}

// =============================================================================
// 3. WHY: CAUSE & EFFECT (BURN VS SAFE / NECESSITY)
// =============================================================================
class ComponentWhyBurnVsSafePainter extends CustomPainter {
  final String component;
  final double progress;
  final int resistorOhms;
  final double currentMa;

  ComponentWhyBurnVsSafePainter({
    required this.component,
    required this.progress,
    required this.resistorOhms,
    required this.currentMa,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final splitX = size.width * 0.5;

    // Left Panel: DANGER / PROBLEM
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, splitX, size.height),
        topLeft: const Radius.circular(18),
        bottomLeft: const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFFFEF2F2),
    );

    // Right Panel: SAFE / SOLUTION
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(splitX, 0, splitX, size.height),
        topRight: const Radius.circular(18),
        bottomRight: const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFFF0FDF4),
    );

    // Divider
    canvas.drawLine(
      Offset(splitX, 10),
      Offset(splitX, size.height - 10),
      Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 2,
    );

    if (component == 'battery') {
      _drawWhyBattery(canvas, size, splitX);
    } else if (component == 'buzzer') {
      _drawWhyBuzzer(canvas, size, splitX);
    } else if (component == 'ssd') {
      _drawWhySsd(canvas, size, splitX);
    } else {
      // Default: LED & Resistor burn vs safe
      _drawWhyLedResistor(canvas, size, splitX);
    }
  }

  void _drawWhyLedResistor(Canvas canvas, Size size, double splitX) {
    final leftX = splitX * 0.5;
    final rightX = splitX + (splitX * 0.5);
    final cy = size.height * 0.48;

    // Left: 85 mA Burned LED
    canvas.drawCircle(Offset(leftX, cy), 28, Paint()..color = const Color(0xFF451A03));
    // Smoke puffs
    for (int s = 0; s < 3; s++) {
      final smokeY = cy - 35 - (s * 14) - (progress * 10);
      canvas.drawCircle(Offset(leftX + (s * 6), smokeY), 9, Paint()..color = const Color(0xFF94A3B8).withOpacity(0.5));
    }
    _drawPill(canvas, Offset(leftX - 60, cy + 45), '85 mA: BURNS OUT!', const Color(0xFFDC2626));

    // Right: 9.1 mA Protected LED with Resistor
    canvas.drawCircle(
      Offset(rightX, cy),
      28,
      Paint()..color = const Color(0xFF16A34A).withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(Offset(rightX, cy), 24, Paint()..color = const Color(0xFF16A34A));
    canvas.drawCircle(Offset(rightX, cy), 12, Paint()..color = const Color(0xFF86EFAC));
    _drawPill(canvas, Offset(rightX - 65, cy + 45), '9.1 mA: SAFE FOREVER', const Color(0xFF16A34A));
  }

  void _drawWhyBattery(Canvas canvas, Size size, double splitX) {
    final leftX = splitX * 0.5;
    final rightX = splitX + (splitX * 0.5);
    final cy = size.height * 0.48;

    // Left: 0V Dead Battery (No push)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(leftX, cy), width: 70, height: 45), const Radius.circular(8)),
      Paint()..color = const Color(0xFF64748B),
    );
    _drawPill(canvas, Offset(leftX - 55, cy + 45), '0V: ZERO FLOW (DEAD)', const Color(0xFF64748B));

    // Right: 9V Live Battery (Steady push)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rightX, cy), width: 70, height: 45), const Radius.circular(8)),
      Paint()..color = const Color(0xFF15803D),
    );
    _drawPill(canvas, Offset(rightX - 65, cy + 45), '9V: ENERGIZED DC PUSH', const Color(0xFF16A34A));
  }

  void _drawWhyBuzzer(Canvas canvas, Size size, double splitX) {
    final leftX = splitX * 0.5;
    final rightX = splitX + (splitX * 0.5);
    final cy = size.height * 0.48;

    // Left: Silent light missed by operator
    canvas.drawCircle(Offset(leftX, cy), 22, Paint()..color = const Color(0xFFCBD5E1));
    _drawPill(canvas, Offset(leftX - 70, cy + 45), 'SILENT: MISSED IN CRASH', const Color(0xFFDC2626));

    // Right: 360° Sonic Alarm
    canvas.drawCircle(Offset(rightX, cy), 24, Paint()..color = const Color(0xFF7E22CE));
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        Offset(rightX, cy),
        32.0 + i * 14,
        Paint()..color = const Color(0xFFA855F7).withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 2,
      );
    }
    _drawPill(canvas, Offset(rightX - 70, cy + 45), 'SONIC: 360° ALERT REACH', const Color(0xFF7E22CE));
  }

  void _drawWhySsd(Canvas canvas, Size size, double splitX) {
    final leftX = splitX * 0.5;
    final rightX = splitX + (splitX * 0.5);
    final cy = size.height * 0.48;

    // Left: 7 scattered messy loose LEDs
    for (int i = 0; i < 7; i++) {
      final angle = (i / 7) * math.pi * 2;
      final px = leftX + math.cos(angle) * 22;
      final py = cy + math.sin(angle) * 16;
      canvas.drawCircle(Offset(px, py), 5, Paint()..color = const Color(0xFFF59E0B));
    }
    _drawPill(canvas, Offset(leftX - 75, cy + 45), 'MESSY WIRES: HARD TO READ', const Color(0xFFDC2626));

    // Right: Clean unified 7-segment digit
    final boardRect = Rect.fromCenter(center: Offset(rightX, cy), width: 55, height: 75);
    canvas.drawRRect(RRect.fromRectAndRadius(boardRect, const Radius.circular(8)), Paint()..color = const Color(0xFF0F172A));
    _drawText(canvas, Offset(rightX - 12, cy - 20), '8', const Color(0xFFEF4444), fontSize: 32);
    _drawPill(canvas, Offset(rightX - 70, cy + 45), 'UNIFIED: READABLE IN 1s', const Color(0xFF16A34A));
  }

  void _drawPill(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx, pos.dy, tp.width + 14, tp.height + 8),
      const Radius.circular(12),
    );
    canvas.drawRRect(rrect, Paint()..color = color);
    tp.paint(canvas, Offset(pos.dx + 7, pos.dy + 4));
  }

  void _drawText(Canvas canvas, Offset pos, String text, Color color, {double fontSize = 12.0}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant ComponentWhyBurnVsSafePainter oldDelegate) => true;
}

// =============================================================================
// 4. WHERE: REAL-WORLD EVERYDAY DEVICES PAINTER
// =============================================================================
class ComponentWhereRealWorldPainter extends CustomPainter {
  final String component;
  final double progress;
  final int selectedDeviceIdx;

  ComponentWhereRealWorldPainter({
    required this.component,
    required this.progress,
    required this.selectedDeviceIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Clean modern workshop canvas
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFFF8FAFC),
    );

    final centerX = size.width * 0.50;
    final centerY = size.height * 0.48;

    if (component == 'battery') {
      // Draw Mars Rover with Solar Battery Pack
      _drawMarsRover(canvas, centerX, centerY);
    } else if (component == 'buzzer') {
      // Draw Microwave Countdown Timer
      _drawMicrowaveTimer(canvas, centerX, centerY);
    } else if (component == 'ssd') {
      // Draw Digital Bedside Alarm Clock
      _drawDigitalAlarmClock(canvas, centerX, centerY);
    } else if (component == 'resistor') {
      // Draw Smartphone Motherboard PCB
      _drawMotherboardPcb(canvas, centerX, centerY);
    } else {
      // Draw Traffic Light with glowing LEDs
      _drawTrafficLight(canvas, centerX, centerY);
    }
  }

  void _drawTrafficLight(Canvas canvas, double cx, double cy) {
    final boxRect = Rect.fromCenter(center: Offset(cx, cy), width: 70, height: 160);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(14)), Paint()..color = const Color(0xFF0F172A));

    // Red, Yellow, Green bulbs
    final colors = [const Color(0xFFEF4444), const Color(0xFFF59E0B), const Color(0xFF10B981)];
    for (int i = 0; i < 3; i++) {
      final by = cy - 45 + (i * 45);
      canvas.drawCircle(Offset(cx, by), 16, Paint()..color = colors[i]);
      if (i == 0) {
        // Glowing red light
        canvas.drawCircle(
          Offset(cx, by),
          24,
          Paint()..color = const Color(0xFFEF4444).withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }
    _drawLabel(canvas, Offset(cx - 75, cy - 100), 'TRAFFIC SIGNAL LED ARRAYS');
  }

  void _drawMarsRover(Canvas canvas, double cx, double cy) {
    // Rover body
    final roverRect = Rect.fromCenter(center: Offset(cx, cy), width: 140, height: 60);
    canvas.drawRRect(RRect.fromRectAndRadius(roverRect, const Radius.circular(10)), Paint()..color = const Color(0xFFD97706));

    // Wheels
    canvas.drawCircle(Offset(cx - 50, cy + 35), 16, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(Offset(cx + 50, cy + 35), 16, Paint()..color = const Color(0xFF1E293B));

    // Battery pack on roof
    final batRect = Rect.fromCenter(center: Offset(cx, cy - 38), width: 70, height: 26);
    canvas.drawRRect(RRect.fromRectAndRadius(batRect, const Radius.circular(6)), Paint()..color = const Color(0xFF15803D));

    _drawLabel(canvas, Offset(cx - 95, cy - 75), 'ROBOT ROVER & EV BATTERY PACK');
  }

  void _drawMicrowaveTimer(Canvas canvas, double cx, double cy) {
    final mwRect = Rect.fromCenter(center: Offset(cx, cy), width: 170, height: 110);
    canvas.drawRRect(RRect.fromRectAndRadius(mwRect, const Radius.circular(12)), Paint()..color = const Color(0xFF334155));

    // Glass door
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mwRect.left + 12, mwRect.top + 14, 95, 82), const Radius.circular(8)),
      Paint()..color = const Color(0xFF0F172A),
    );

    // Beeping buzzer sound ripples at timer 00:00
    _drawLabel(canvas, Offset(cx - 95, cy - 80), 'MICROWAVE COOK TIMER (00:00 BEEP!)');
  }

  void _drawDigitalAlarmClock(Canvas canvas, double cx, double cy) {
    final clockRect = Rect.fromCenter(center: Offset(cx, cy), width: 180, height: 95);
    canvas.drawRRect(RRect.fromRectAndRadius(clockRect, const Radius.circular(14)), Paint()..color = const Color(0xFF0F172A));

    // Display
    final tp = TextPainter(
      text: const TextSpan(
        text: '07:30',
        style: TextStyle(color: Color(0xFFEF4444), fontSize: 40, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    _drawLabel(canvas, Offset(cx - 95, cy - 75), 'DIGITAL BEDSIDE ALARM CLOCK');
  }

  void _drawMotherboardPcb(Canvas canvas, double cx, double cy) {
    final pcbRect = Rect.fromCenter(center: Offset(cx, cy), width: 180, height: 110);
    canvas.drawRRect(RRect.fromRectAndRadius(pcbRect, const Radius.circular(10)), Paint()..color = const Color(0xFF14532D));

    // Resistor chips
    for (int i = 0; i < 4; i++) {
      final rx = pcbRect.left + 30 + (i * 35);
      final ry = cy - 15 + (i % 2 * 30);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rx, ry), width: 22, height: 12), const Radius.circular(3)),
        Paint()..color = const Color(0xFF0284C7),
      );
    }
    _drawLabel(canvas, Offset(cx - 95, cy - 75), 'SMARTPHONE MOTHERBOARD PCB');
  }

  void _drawLabel(Canvas canvas, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant ComponentWhereRealWorldPainter oldDelegate) => true;
}

// =============================================================================
// 5. WHEN: DECISION & TRIGGER FLOW TIMELINE PAINTER
// =============================================================================
class ComponentWhenTriggerPainter extends CustomPainter {
  final String component;
  final double progress;
  final int selectedRuleIdx;

  ComponentWhenTriggerPainter({
    required this.component,
    required this.progress,
    required this.selectedRuleIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFFFAF5FF),
    );

    final centerX = size.width * 0.50;
    final cy = size.height * 0.50;

    // Trigger Box
    final boxRect = Rect.fromCenter(center: Offset(centerX, cy), width: 260, height: 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect, const Radius.circular(14)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect, const Radius.circular(14)),
      Paint()..color = const Color(0xFF7E22CE)..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    String codeRule;
    String condition;
    if (component == 'battery') {
      condition = 'WHEN: Robot is mobile & untethered';
      codeRule = 'power_mode = BATTERY_PACK_9V;';
    } else if (component == 'buzzer') {
      condition = 'WHEN: Distance < 10 cm (Obstacle!)';
      codeRule = 'tone(BUZZER_PIN, 880); // Beep alarm!';
    } else if (component == 'ssd') {
      condition = 'WHEN: Displaying live score / seconds';
      codeRule = 'ssd.display(counter); // Show digit';
    } else if (component == 'resistor') {
      condition = 'WHEN: Wiring any LED to +5V Pin';
      codeRule = 'insert_in_series(330_OHM_RESISTOR);';
    } else {
      condition = 'WHEN: Power ON or Alert Flag set';
      codeRule = 'digitalWrite(LED_PIN, HIGH); // Light up!';
    }

    final tpCond = TextPainter(
      text: TextSpan(
        text: condition,
        style: const TextStyle(color: Color(0xFF7E22CE), fontSize: 13, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpCond.paint(canvas, Offset(centerX - tpCond.width / 2, cy - 30));

    final tpCode = TextPainter(
      text: TextSpan(
        text: codeRule,
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpCode.paint(canvas, Offset(centerX - tpCode.width / 2, cy + 5));
  }

  @override
  bool shouldRepaint(covariant ComponentWhenTriggerPainter oldDelegate) => true;
}
