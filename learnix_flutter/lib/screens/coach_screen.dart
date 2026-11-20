import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_card.dart';

class CoachScreen extends StatefulWidget {
  final String baseUrl;
  final int studentId;

  const CoachScreen({
    super.key,
    required this.baseUrl,
    required this.studentId,
  });

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _coachData;
  final TextEditingController _ideaController = TextEditingController(
    text: 'A smart alarm that beeps faster when an intruder walks closer',
  );
  final TextEditingController _questionController = TextEditingController();
  bool _isSparking = false;
  Map<String, dynamic>? _sparkedPlan;

  // Interactive RCA expanded fix state
  final Set<String> _expandedRcaFixes = {};
  int _selectedConceptIndex = 0;

  // Interactive Blueprint Simulation state
  bool _simulatingBlueprint = true;
  double _simIntruderDistanceCm = 14.0;
  bool _simPulseOn = true;
  Timer? _simTimer;

  // Quick Q&A with AI Tutor Zola
  bool _isAskingTutor = false;
  Map<String, String>? _tutorAnswer;

  @override
  void initState() {
    super.initState();
    // Pre-populate the default invention blueprint so the screen starts rich and interactive
    _sparkedPlan = _buildLocalBlueprint(_ideaController.text);
    _fetchCoachData();
    _startSimTimer();
  }

  void _startSimTimer() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted && _simulatingBlueprint) {
        setState(() => _simPulseOn = !_simPulseOn);
      }
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _ideaController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoachData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${widget.baseUrl}/api/coach/${widget.studentId}'));
      if (res.statusCode == 200) {
        _coachData = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error loading tutor data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildLocalBlueprint(String idea) {
    final low = idea.toLowerCase();
    if (low.contains('button') || low.contains('doorbell') || low.contains('switch') || low.contains('chime')) {
      return {
        'experiment_id': 2,
        'title': 'Smart Push-Button Doorbell & Status LED',
        'explanation':
            'Reads a tactile push button on D2 using internal INPUT_PULLUP. Pressing the button triggers a two-tone chime on the D8 Piezo Buzzer and lights the D13 indicator LED.',
        'components': [
          'Arduino Uno',
          'Push Button (BTN1)',
          'Piezo Buzzer (BUZ1)',
          'Green LED (LED1)',
          '220Ω Resistor (R1)',
        ],
        'circuit': [
          {'from': 'D2', 'to': 'BTN1.a', 'note': 'Digital Input (INPUT_PULLUP)'},
          {'from': 'BTN1.b', 'to': 'GND', 'note': 'Pulls D2 LOW when pressed'},
          {'from': 'D8', 'to': 'BUZ1.pos', 'note': 'PWM Tone Output'},
          {'from': 'BUZ1.neg', 'to': 'GND', 'note': 'Buzzer ground return'},
          {'from': 'D13', 'to': 'R1.a', 'note': 'LED signal output'},
          {'from': 'R1.b', 'to': 'LED1.anode', 'note': '220Ω current limiter'},
          {'from': 'LED1.cathode', 'to': 'GND', 'note': 'Common ground return'},
        ],
        'code': '''void setup() {
  pinMode(2, INPUT_PULLUP); // Button active LOW
  pinMode(8, OUTPUT);       // Piezo Buzzer
  pinMode(13, OUTPUT);      // Doorbell Status LED
}

void loop() {
  if (digitalRead(2) == LOW) {
    digitalWrite(13, HIGH);
    tone(8, 880);  // High A5 chime
    delay(200);
    tone(8, 660);  // E5 chime
    delay(250);
    noTone(8);
  } else {
    digitalWrite(13, LOW);
    noTone(8);
  }
}''',
      };
    }

    if (low.contains('night') || low.contains('light') || low.contains('dark') || low.contains('traffic') || low.contains('blink')) {
      return {
        'experiment_id': 1,
        'title': 'Smart Automated Night-Light & Warning Beacon',
        'explanation':
            'Drives a high-brightness LED beacon from Pin D13 through a 220Ω protective resistor with automatic pulse timing and a verified GND return loop.',
        'components': [
          'Arduino Uno',
          '220Ω Resistor (R1)',
          'High-Brightness LED (LED1)',
          'Half-Size Breadboard',
          'Jumper Wires',
        ],
        'circuit': [
          {'from': 'D13', 'to': 'R1.a', 'note': '5V Digital Output Pin'},
          {'from': 'R1.b', 'to': 'LED1.anode', 'note': 'Limits current to safe 13.6 mA'},
          {'from': 'LED1.cathode', 'to': 'GND', 'note': 'Completes closed 0V loop'},
        ],
        'code': '''void setup() {
  pinMode(13, OUTPUT); // Automated LED Beacon
}

void loop() {
  digitalWrite(13, HIGH); // Turn LED ON (5V)
  delay(400);
  digitalWrite(13, LOW);  // Turn LED OFF (0V)
  delay(400);
}''',
      };
    }

    // Default / Intruder / Ultrasonic Distance Alarm
    return {
      'experiment_id': 3,
      'title': 'Smart Ultrasonic Intruder Distance Alarm',
      'explanation':
          'Uses an HC-SR04 Ultrasonic Sensor (TRIG on D9, ECHO on D10) to measure intruder distance in centimeters. As the intruder walks closer (< 35 cm and < 15 cm), the Piezo Buzzer on D8 and Red Alert LED on D13 beep and flash faster!',
      'components': [
        'Arduino Uno',
        'HC-SR04 Ultrasonic Sensor',
        'Piezo Buzzer (BUZ1)',
        'Red Warning LED (LED1)',
        '220Ω Resistor (R1)',
      ],
      'circuit': [
        {'from': '5V', 'to': 'US1.vcc', 'note': '5V Sensor Power'},
        {'from': 'D9', 'to': 'US1.trig', 'note': '10µs Ultrasonic Trigger Pulse'},
        {'from': 'D10', 'to': 'US1.echo', 'note': 'Echo Travel-Time Input'},
        {'from': 'US1.gnd', 'to': 'GND', 'note': 'Sensor Ground Return'},
        {'from': 'D8', 'to': 'BUZ1.pos', 'note': 'Variable-Speed Alarm Buzzer'},
        {'from': 'BUZ1.neg', 'to': 'GND', 'note': 'Buzzer Ground'},
        {'from': 'D13', 'to': 'R1.a', 'note': 'Visual Strobe Alert Output'},
        {'from': 'R1.b', 'to': 'LED1.anode', 'note': '220Ω Current Protection'},
        {'from': 'LED1.cathode', 'to': 'GND', 'note': 'Common Ground Loop'},
      ],
      'code': '''void setup() {
  pinMode(9, OUTPUT);   // HC-SR04 TRIG
  pinMode(10, INPUT);   // HC-SR04 ECHO
  pinMode(8, OUTPUT);   // Piezo Buzzer
  pinMode(13, OUTPUT);  // Red Intruder Strobe LED
}

void loop() {
  long d = readDistance(); // Measure intruder distance in cm
  if (d < 15) {
    // DANGER ZONE (< 15 cm): Rapid 1400 Hz alarm beeps!
    digitalWrite(13, HIGH);
    tone(8, 1400);
    delay(100);
    digitalWrite(13, LOW);
    noTone(8);
    delay(100);
  } else if (d < 35) {
    // WARNING ZONE (15-35 cm): Medium 950 Hz warning pulse
    digitalWrite(13, HIGH);
    tone(8, 950);
    delay(250);
    digitalWrite(13, LOW);
    noTone(8);
    delay(250);
  } else {
    // SAFE ZONE (>= 35 cm): Quiet standby
    digitalWrite(13, LOW);
    noTone(8);
    delay(100);
  }
}''',
    };
  }

  Future<void> _sparkIdea([String? presetIdea]) async {
    if (presetIdea != null) {
      _ideaController.text = presetIdea;
    }
    final text = _ideaController.text.trim();
    if (text.isEmpty) return;

    // Immediately compute local tailored blueprint so user never sees an empty/failed response
    final fallbackPlan = _buildLocalBlueprint(text);
    setState(() {
      _isSparking = true;
      _sparkedPlan = fallbackPlan;
    });

    try {
      final res = await http
          .post(
            Uri.parse('${widget.baseUrl}/api/lab/build-from-words'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idea': text,
              'student_id': widget.studentId,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final plan = data['plan'] != null ? Map<String, dynamic>.from(data['plan'] as Map) : data;
        if ((plan['title'] ?? '').toString().isNotEmpty && (plan['code'] ?? '').toString().isNotEmpty) {
          if (mounted) {
            setState(() => _sparkedPlan = plan);
          }
        }
      }
    } catch (e) {
      debugPrint('Using local invention blueprint fallback: $e');
    } finally {
      if (mounted) setState(() => _isSparking = false);
    }
  }

  Future<void> _askTutorQuestion([String? presetQ]) async {
    if (presetQ != null) {
      _questionController.text = presetQ;
    }
    final q = _questionController.text.trim();
    if (q.isEmpty) return;

    setState(() => _isAskingTutor = true);
    try {
      final res = await http
          .post(
            Uri.parse('${widget.baseUrl}/api/concept-studio/doubt'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'student_id': widget.studentId,
              'concept_title': 'Robotics & Arduino Circuits',
              'question': q,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _tutorAnswer = {
              'question': q,
              'answer': (data['answer'] ?? '').toString(),
              'tip': (data['tip'] ?? '').toString(),
            };
          });
          return;
        }
      }
    } catch (_) {}

    // Local intelligent response fallback
    final low = q.toLowerCase();
    String ans;
    String tip;
    if (low.contains('resistor') || low.contains('ohm') || low.contains('burn')) {
      ans =
          'An LED has almost zero internal resistance once turned on. Without a 220Ω–330Ω series resistor, over 80 mA rushes from the 5V pin and overheats the semiconductor junction in milliseconds!';
      tip = 'Use Ohm\'s Law: R = (5V - 2V) / 0.015A = 200Ω (choose a standard 220Ω or 330Ω resistor).';
    } else if (low.contains('ultrasonic') || low.contains('hc-sr04') || low.contains('distance')) {
      ans =
          'The HC-SR04 sends out an 8-cycle 40 kHz sound ping from TRIG (D9) and listens on ECHO (D10). Distance in cm equals (Echo Time in µs × 0.034) ÷ 2 because the sound wave travels there and back!';
      tip = 'Always divide the round-trip travel distance by 2 to get the one-way distance to the object.';
    } else if (low.contains('pullup') || low.contains('button')) {
      ans =
          'pinMode(2, INPUT_PULLUP) connects an internal 20kΩ resistor inside the Arduino chip to 5V. The pin reads HIGH normally, and drops to LOW when the button connects it to GND.';
      tip = 'Check if (digitalRead(2) == LOW) to detect when the button is pressed!';
    } else {
      ans =
          'Every working Arduino invention combines three parts: an Input Sensor (like a button or HC-SR04), Decision Logic in loop() (if/else), and an Output Actuator (LED or Buzzer) with a complete GND loop.';
      tip = 'Test one component at a time in the Virtual Lab before combining them into a bigger circuit!';
    }
    if (mounted) {
      setState(() {
        _tutorAnswer = {'question': q, 'answer': ans, 'tip': tip};
        _isAskingTutor = false;
      });
    }
  }

  Map<String, dynamic> _describeRcaError(String rawKey, int count) {
    final key = rawKey.trim().toLowerCase().replaceAll(' ', '_');
    switch (key) {
      case 'missing_resistor':
        return {
          'key': key,
          'code_badge': 'MISSING RESISTOR',
          'title': 'Missing Current-Limiting Resistor (220Ω–330Ω)',
          'frequency': '${count}x in Virtual Lab',
          'color': const Color(0xFFDC2626),
          'root_cause': 'Pin D13 (5V) was wired directly to LED1.anode without a resistor in series, drawing 85 mA (max safe is 20 mA).',
          'tip': 'Always place a 220Ω or 330Ω resistor in series with an LED (either before the anode or after the cathode) to limit current to ~13 mA.',
          'fix_snippet': 'Wire: D13 ➔ R1.a (220Ω) ➔ R1.b ➔ LED1.anode (+)',
        };
      case 'missing_ground':
        return {
          'key': key,
          'code_badge': 'MISSING GROUND',
          'title': 'Open Circuit — Incomplete Ground (GND) Return Loop',
          'frequency': '${count}x in Virtual Lab',
          'color': const Color(0xFFD97706),
          'root_cause': 'Power reached the component from 5V/D13, but the negative (−) cathode/GND terminal was left floating.',
          'tip': 'Electricity only flows in a closed loop! Every component powered by 5V or a digital pin must have a return path back to Arduino GND (0V).',
          'fix_snippet': 'Wire: LED1.cathode (−) ➔ Arduino GND   &   BUZ1.neg (−) ➔ Arduino GND',
        };
      case 'code_syntax':
        return {
          'key': key,
          'code_badge': 'CODE SYNTAX',
          'title': 'Arduino C++ Syntax Error (Semicolon / Pin Mode)',
          'frequency': '${count}x in Virtual Lab',
          'color': const Color(0xFF7C3AED),
          'root_cause': 'Compiler stopped due to a missing trailing semicolon `;` after delay(500) or mismatched curly braces `{ }` in void loop().',
          'tip': 'End every C++ statement (`pinMode`, `digitalWrite`, `delay`, `tone`) with `;` and verify every `{` has a matching `}`.',
          'fix_snippet': 'void setup() {\n  pinMode(13, OUTPUT);\n}\nvoid loop() {\n  digitalWrite(13, HIGH);\n  delay(500);\n}',
        };
      case 'code_logic':
        return {
          'key': key,
          'code_badge': 'CODE LOGIC',
          'title': 'Loop Timing or Conditional Logic Bug',
          'frequency': '${count}x in Virtual Lab',
          'color': const Color(0xFF0077B6),
          'root_cause': 'digitalWrite(13, LOW) was followed immediately by loop restart without a second delay(), or the distance threshold condition was inverted (`d > 20` instead of `d < 20`).',
          'tip': 'Always put a delay(500) after BOTH HIGH and LOW so your eye can see the off state, and trigger the alarm when distance `d < 20`.',
          'fix_snippet': 'if (d < 20) {\n  tone(8, 1200);\n} else {\n  noTone(8);\n}',
        };
      case 'wrong_pin':
        return {
          'key': key,
          'code_badge': 'WRONG PIN',
          'title': 'Pin Mismatch Between Breadboard & Code',
          'frequency': '${count}x in Virtual Lab',
          'color': const Color(0xFF0891B2),
          'root_cause': 'The component was wired to physical Pin D12 on the board, while the Arduino sketch toggled Pin 13 in digitalWrite(13, HIGH).',
          'tip': 'Double-check that the pin number printed on the Arduino header matches the exact number inside pinMode() and digitalWrite().',
          'fix_snippet': '// If wired to D13:\npinMode(13, OUTPUT);\ndigitalWrite(13, HIGH);',
        };
      case 'reversed_polarity':
        return {
          'key': key,
          'code_badge': 'REVERSED POLARITY',
          'title': 'LED Anode (+) and Cathode (−) Connected Backwards',
          'frequency': '${count}x in Virtual Lab',
          'color': const Color(0xFFE11D48),
          'root_cause': 'An LED is a one-way PN-junction diode. Current was fed into the short cathode (−) leg instead of the long anode (+) leg.',
          'tip': 'Connect the longer bent leg (Anode +) toward the positive pin/resistor and the shorter flat-edge leg (Cathode −) toward GND.',
          'fix_snippet': 'Positive Pin (D13 / R1.b) ➔ LED1.anode (+)   |   LED1.cathode (−) ➔ GND',
        };
      default:
        return {
          'key': key,
          'code_badge': rawKey.toUpperCase(),
          'title': 'Sensor Terminal or Component Wiring Mismatch',
          'frequency': '${count}x in Virtual Lab',
          'color': const Color(0xFF475569),
          'root_cause': 'HC-SR04 TRIG and ECHO pins were swapped, or the wrong terminal was selected.',
          'tip': 'Verify HC-SR04 has VCC -> 5V, TRIG -> D9, ECHO -> D10, and GND -> GND.',
          'fix_snippet': 'US1.vcc ➔ 5V | US1.trig ➔ D9 | US1.echo ➔ D10 | US1.gnd ➔ GND',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: tokens.primary));
    }

    final coachMsg = _coachData?['coach_message'] ??
        'You have mastered LED basics and resistors! Next, focus on complete Ground (GND) loops and Ultrasonic Sensor if/else logic.';
    final rawLabErrors = (_coachData?['top_lab_errors'] as List?) ?? [];
    final List<Map<String, dynamic>> diagErrors = rawLabErrors.isNotEmpty
        ? rawLabErrors.map((e) {
            final rawType = (e['error_type'] ?? 'missing_ground').toString();
            final count = int.tryParse((e['error_count'] ?? 1).toString()) ?? 1;
            return _describeRcaError(rawType, count);
          }).toList()
        : [
            _describeRcaError('missing_ground', 3),
            _describeRcaError('missing_resistor', 2),
            _describeRcaError('code_syntax', 1),
            _describeRcaError('code_logic', 1),
          ];

    final nextSequence = (_coachData?['next_concepts'] as List?) ?? [];
    final weakConcepts = (_coachData?['weak_concepts'] as List?) ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 860;
        final pad = isNarrow ? tokens.space16 : tokens.space32;

        // LEFT COLUMN: Specific Root Cause Analysis (RCA) per error type
        final rcaCard = InteractiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.stethoscope, color: Color(0xFFDC2626), size: 20),
                  ),
                  SizedBox(width: tokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recurring Virtual Lab Errors (RCA)', style: textTheme.titleMedium),
                        const Text(
                          'AI Root-Cause Diagnosis tailored to each circuit & code failure in your recent runs',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.space16),
              ...diagErrors.map((err) {
                final key = err['key'] as String;
                final Color accent = err['color'] as Color;
                final isExpanded = _expandedRcaFixes.contains(key);
                return Padding(
                  padding: EdgeInsets.only(bottom: tokens.space12),
                  child: Container(
                    padding: EdgeInsets.all(tokens.space16),
                    decoration: BoxDecoration(
                      color: tokens.surfaceBg,
                      borderRadius: tokens.borderRadius16,
                      border: Border.all(color: accent.withOpacity(0.28)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                err['code_badge'] as String,
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                err['frequency'] as String,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          err['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '🔍 Root Cause: ${err['root_cause']}',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💡 ', style: TextStyle(fontSize: 13)),
                              Expanded(
                                child: Text(
                                  'Tutor Advice: ${err['tip']}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedRcaFixes.remove(key);
                                  } else {
                                    _expandedRcaFixes.add(key);
                                  }
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                isExpanded ? LucideIcons.chevronUp : LucideIcons.wrench,
                                size: 14,
                                color: accent,
                              ),
                              label: Text(
                                isExpanded ? 'Hide Verified Fix' : 'Show Verified Fix & Wiring Rule',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                              ),
                            ),
                          ],
                        ),
                        if (isExpanded) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              err['fix_snippet'] as String,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Color(0xFF38BDF8),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );

        // RIGHT COLUMN: Recommended Curriculum Sequence + Mastery Diagnostic + Ask AI Tutor Zola
        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InteractiveCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(LucideIcons.listOrdered, color: tokens.primary, size: 20),
                      ),
                      SizedBox(width: tokens.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Recommended Curriculum Sequence', style: textTheme.titleMedium),
                            const Text(
                              'Tap any concept below to preview its key rule & lab objective',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.space16),
                  if (nextSequence.isEmpty)
                    const Text('All sequence prerequisites completed!')
                  else
                    ...nextSequence.take(4).toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final seq = entry.value;
                      final isSelected = _selectedConceptIndex == idx;
                      return Padding(
                        padding: EdgeInsets.only(bottom: tokens.space12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedConceptIndex = idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEFF6FF) : tokens.surfaceBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF0077B6) : tokens.borderSubtle,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isSelected ? const Color(0xFF0077B6) : tokens.primaryLight,
                                      child: Text(
                                        '${idx + 1}',
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : tokens.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        (seq['title'] ?? '').toString(),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF0077B6) : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(
                                        'Day ${seq['id'] ?? (idx + 3)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.white : const Color(0xFF0077B6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  (seq['summary'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFDBEAFE)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(LucideIcons.sparkles, size: 14, color: Color(0xFF0077B6)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Focus Goal: Complete the ${seq['visual_type'] ?? 'interactive'} simulation and pass the 3-question check.',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E40AF),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            SizedBox(height: tokens.space16),
            // Weak Concept Mastery Breakdown + Ask AI Tutor Zola Direct Q&A Card
            InteractiveCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.messageSquarePlus, color: Color(0xFF16A34A), size: 20),
                      ),
                      SizedBox(width: tokens.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ask AI Tutor Zola a Question', style: textTheme.titleMedium),
                            const Text(
                              'Instant Socratic help on resistors, pins, sensors, or Arduino C++',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (weakConcepts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'TOP FOCUS AREAS FROM QUIZZES:',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: weakConcepts.take(3).map((wc) {
                        final title = (wc['title'] ?? 'Ground & Circuits').toString();
                        final pct = wc['pct'] ?? 33;
                        return InkWell(
                          onTap: () => _askTutorQuestion('Explain $title simply with an example'),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFED7AA)),
                            ),
                            child: Text(
                              '🎯 $title ($pct% quiz)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC2410C),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildQuickChip(
                        'Why does an LED need a 220Ω resistor?',
                        () => _askTutorQuestion('Why does an LED need a 220Ω resistor?'),
                      ),
                      _buildQuickChip(
                        'How does HC-SR04 measure distance?',
                        () => _askTutorQuestion('How does HC-SR04 measure distance?'),
                      ),
                      _buildQuickChip(
                        'What does INPUT_PULLUP do on D2?',
                        () => _askTutorQuestion('What does INPUT_PULLUP do on D2?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _questionController,
                          onSubmitted: (_) => _askTutorQuestion(),
                          decoration: InputDecoration(
                            hintText: 'Ask Zola about any circuit or code doubt...',
                            isDense: true,
                            filled: true,
                            fillColor: tokens.surfaceBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: tokens.borderSubtle),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isAskingTutor ? null : () => _askTutorQuestion(),
                        icon: _isAskingTutor
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(LucideIcons.send, size: 14),
                        label: const Text('Ask'),
                      ),
                    ],
                  ),
                  if (_tutorAnswer != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🤖 Zola on "${_tutorAnswer!['question']}":',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _tutorAnswer!['answer'] ?? '',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                          ),
                          if ((_tutorAnswer!['tip'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '✨ Pro Tip: ${_tutorAnswer!['tip']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                '🤖 AI Tutor Zola — Diagnostic & Invention Engine',
                style: isNarrow ? textTheme.headlineMedium : textTheme.displayLarge,
              ),
              SizedBox(height: tokens.space8),
              Text(
                'Personalized Root Cause Analysis (RCA) on your circuit runs and automated invention blueprint generation.',
                style: textTheme.bodyMedium,
              ),
              SizedBox(height: isNarrow ? tokens.space20 : tokens.space24),

              // Speech Bubble Card
              InteractiveCard(
                backgroundColor: tokens.primaryLight,
                borderColor: tokens.primary.withOpacity(0.2),
                padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(tokens.space12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0077B6),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🤖', style: TextStyle(fontSize: 26)),
                    ),
                    SizedBox(width: tokens.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Tutor Summary',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0077B6)),
                          ),
                          SizedBox(height: tokens.space8),
                          Text(
                            coachMsg,
                            style: textTheme.bodyMedium?.copyWith(color: tokens.textPrimary, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              SizedBox(height: isNarrow ? tokens.space20 : tokens.space24),

              // Two Columns: RCA Lab Errors & Recommended Sequence + Ask Zola
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    rcaCard,
                    SizedBox(height: tokens.space16),
                    rightColumn,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: rcaCard),
                    SizedBox(width: tokens.space24),
                    Expanded(flex: 10, child: rightColumn),
                  ],
                ),

              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // Spark a Project Idea Card + Live Interactive Invention Blueprint
              InteractiveCard(
                padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 24)),
                        SizedBox(width: tokens.space8),
                        Expanded(
                          child: Text(
                            'Have an Invention Idea? Let\'s Build It!',
                            style: textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.space8),
                    Text(
                      'Tell AI Tutor Zola what you want to build (e.g., "A smart alarm that beeps faster when an intruder walks closer") or pick a preset blueprint below:',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickChip(
                          '🚨 Ultrasonic Intruder Alarm',
                          () => _sparkIdea('A smart alarm that beeps faster when an intruder walks closer'),
                        ),
                        _buildQuickChip(
                          '🔔 Smart Push-Button Doorbell',
                          () => _sparkIdea('A smart two-tone doorbell with a push button and status LED'),
                        ),
                        _buildQuickChip(
                          '🌙 Automated Night-Light Beacon',
                          () => _sparkIdea('An automated night light warning beacon with 220 ohm protection'),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.space16),
                    if (isNarrow)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _ideaController,
                            onSubmitted: (_) => _sparkIdea(),
                            decoration: InputDecoration(
                              hintText: 'Enter your invention concept...',
                              filled: true,
                              fillColor: tokens.surfaceBg,
                              border: OutlineInputBorder(
                                borderRadius: tokens.borderRadius16,
                                borderSide: BorderSide(color: tokens.borderSubtle),
                              ),
                            ),
                          ),
                          SizedBox(height: tokens.space12),
                          ElevatedButton.icon(
                            onPressed: _isSparking ? null : () => _sparkIdea(),
                            icon: _isSparking
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(LucideIcons.sparkles, size: 16),
                            label: Text(_isSparking ? 'Generating Blueprint...' : 'Generate Blueprint'),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ideaController,
                              onSubmitted: (_) => _sparkIdea(),
                              decoration: InputDecoration(
                                hintText: 'Enter your invention concept...',
                                filled: true,
                                fillColor: tokens.surfaceBg,
                                border: OutlineInputBorder(
                                  borderRadius: tokens.borderRadius16,
                                  borderSide: BorderSide(color: tokens.borderSubtle),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: tokens.space12),
                          ElevatedButton.icon(
                            onPressed: _isSparking ? null : () => _sparkIdea(),
                            icon: _isSparking
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(LucideIcons.sparkles, size: 16),
                            label: Text(_isSparking ? 'Generating Blueprint...' : 'Generate Blueprint'),
                          ),
                        ],
                      ),
                    if (_sparkedPlan != null) ...[
                      SizedBox(height: tokens.space24),
                      _buildInventionBlueprintWorkspace(_sparkedPlan!, isNarrow, tokens),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        ),
      ),
    );
  }

  Widget _buildInventionBlueprintWorkspace(
    Map<String, dynamic> plan,
    bool isNarrow,
    AppTokens tokens,
  ) {
    final title = (plan['title'] ?? plan['project_title'] ?? 'Smart Ultrasonic Intruder Distance Alarm').toString();
    final explanation = (plan['explanation'] ?? plan['summary'] ?? '').toString();
    final List<String> components = (plan['components'] is List)
        ? (plan['components'] as List).map((e) => e.toString()).toList()
        : ['Arduino Uno', 'HC-SR04 Ultrasonic Sensor', 'Piezo Buzzer', 'Red LED', '220Ω Resistor'];
    final List<Map<String, dynamic>> circuit = (plan['circuit'] is List)
        ? (plan['circuit'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];
    final String code = (plan['code'] ?? plan['code_outline'] ?? '// Arduino C++ Sketch').toString();
    final int expId = int.tryParse((plan['experiment_id'] ?? 3).toString()) ?? 3;

    // Alarm status for interactive test simulation
    final String zoneLabel = _simIntruderDistanceCm < 15
        ? '🚨 DANGER ZONE (< 15 cm) — Fast 1400 Hz Alarm + Red Strobe!'
        : (_simIntruderDistanceCm < 35
            ? '⚠️ WARNING ZONE (15–35 cm) — Medium 950 Hz Beep'
            : '✅ SAFE ZONE (≥ 35 cm) — Standby (Silent)');
    final Color zoneColor = _simIntruderDistanceCm < 15
        ? const Color(0xFFDC2626)
        : (_simIntruderDistanceCm < 35 ? const Color(0xFFD97706) : const Color(0xFF16A34A));

    final leftBlueprintDetails = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Interactive Blueprint Circuit Simulation Canvas
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF09101D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _simulatingBlueprint ? const Color(0xFF22C55E) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE INVENTION CIRCUIT SIMULATOR',
                        style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _simulatingBlueprint = !_simulatingBlueprint),
                    style: TextButton.styleFrom(
                      backgroundColor: _simulatingBlueprint ? const Color(0xFF16A34A) : const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(_simulatingBlueprint ? LucideIcons.pause : LucideIcons.play, size: 12),
                    label: Text(
                      _simulatingBlueprint ? 'Simulating' : 'Paused',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 185,
                width: double.infinity,
                child: CustomPaint(
                  painter: _BlueprintCircuitPainter(
                    experimentId: expId,
                    distanceCm: _simIntruderDistanceCm,
                    pulseOn: _simPulseOn && _simulatingBlueprint,
                  ),
                ),
              ),
              if (expId == 3) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: zoneColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: zoneColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          zoneLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${_simIntruderDistanceCm.round()} cm',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'Intruder Distance:',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    Expanded(
                      child: Slider(
                        value: _simIntruderDistanceCm,
                        min: 5,
                        max: 50,
                        activeColor: const Color(0xFF38BDF8),
                        onChanged: (v) => setState(() => _simIntruderDistanceCm = v),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'REQUIRED COMPONENTS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: components
              .map(
                (c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.cpu, size: 13, color: Color(0xFF0077B6)),
                      const SizedBox(width: 6),
                      Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A))),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        if (circuit.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'STEP-BY-STEP PIN WIRING CONNECTIONS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: circuit.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final wire = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$idx. ${wire['from']} ➔ ${wire['to']}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );

    final rightCodePanel = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.code2, size: 16, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Text(
                    'ARDUINO C++ SKETCH (sketch.ino)',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Arduino C++ sketch copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(LucideIcons.copy, size: 12),
                label: const Text('Copy Code', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 20),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFFE2E8F0),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: tokens.borderRadius16,
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0077B6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '✓ AI BLUEPRINT READY',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: tokens.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4),
          ),
          const SizedBox(height: 16),
          if (isNarrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftBlueprintDetails,
                const SizedBox(height: 16),
                rightCodePanel,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: leftBlueprintDetails),
                const SizedBox(width: 20),
                Expanded(flex: 10, child: rightCodePanel),
              ],
            ),
        ],
      ),
    );
  }
}

class _BlueprintCircuitPainter extends CustomPainter {
  final int experimentId;
  final double distanceCm;
  final bool pulseOn;

  _BlueprintCircuitPainter({
    required this.experimentId,
    required this.distanceCm,
    required this.pulseOn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)), bgPaint);

    // Subtle grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1;
    for (double x = 16; x < size.width; x += 20) {
      for (double y = 16; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1, gridPaint);
      }
    }

    // Left: Arduino Uno Board
    final unoRect = RRect.fromRectAndRadius(const Rect.fromLTWH(16, 22, 118, 140), const Radius.circular(8));
    canvas.drawRRect(unoRect, Paint()..color = const Color(0xFF0284C7));
    canvas.drawRRect(
      unoRect,
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawLabel(canvas, 'ARDUINO UNO', const Offset(30, 34), const Color(0xFFE0F2FE), 11, FontWeight.w800);
    _drawLabel(canvas, 'D13  (LED)', const Offset(28, 60), Colors.white, 10, FontWeight.w700);
    _drawLabel(canvas, 'D9   (TRIG)', const Offset(28, 80), const Color(0xFFFDE047), 10, FontWeight.w700);
    _drawLabel(canvas, 'D10  (ECHO)', const Offset(28, 100), const Color(0xFF86EFAC), 10, FontWeight.w700);
    _drawLabel(canvas, 'D8   (BUZ)', const Offset(28, 120), const Color(0xFFFCA5A5), 10, FontWeight.w700);
    _drawLabel(canvas, 'GND (0V)', const Offset(28, 140), const Color(0xFFCBD5E1), 10, FontWeight.w700);

    final isAlarmActive = distanceCm < 35 && pulseOn;

    // Wires from Arduino to Components
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // D13 -> 220Ω Resistor -> Red LED
    wirePaint.color = isAlarmActive ? const Color(0xFFEF4444) : const Color(0xFF64748B);
    canvas.drawLine(const Offset(134, 65), const Offset(205, 45), wirePaint);

    // Resistor body
    final resRect = RRect.fromRectAndRadius(const Rect.fromLTWH(205, 36, 44, 18), const Radius.circular(4));
    canvas.drawRRect(resRect, Paint()..color = const Color(0xFFD97706));
    _drawLabel(canvas, '220Ω', const Offset(213, 39), Colors.white, 9.5, FontWeight.bold);

    // LED1 body
    final ledCenter = const Offset(290, 45);
    if (isAlarmActive) {
      canvas.drawCircle(ledCenter, 20, Paint()..color = const Color(0xFFEF4444).withOpacity(0.35));
    }
    canvas.drawCircle(
      ledCenter,
      11,
      Paint()..color = isAlarmActive ? const Color(0xFFEF4444) : const Color(0xFF7F1D1D),
    );
    _drawLabel(canvas, 'LED1', const Offset(276, 60), Colors.white, 9.5, FontWeight.bold);

    // HC-SR04 Ultrasonic Sensor
    final usRect = RRect.fromRectAndRadius(const Rect.fromLTWH(200, 78, 110, 46), const Radius.circular(6));
    canvas.drawRRect(usRect, Paint()..color = const Color(0xFF1E3A8A));
    canvas.drawRRect(
      usRect,
      Paint()
        ..color = const Color(0xFF60A5FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(const Offset(228, 101), 13, Paint()..color = const Color(0xFF94A3B8));
    canvas.drawCircle(const Offset(282, 101), 13, Paint()..color = const Color(0xFF94A3B8));
    _drawLabel(canvas, 'HC-SR04', const Offset(233, 81), const Color(0xFFBFDBFE), 9, FontWeight.w800);

    // TRIG/ECHO wires
    canvas.drawLine(const Offset(134, 85), const Offset(200, 92), Paint()..color = const Color(0xFFFACC15)..strokeWidth = 2);
    canvas.drawLine(const Offset(134, 105), const Offset(200, 110), Paint()..color = const Color(0xFF4ADE80)..strokeWidth = 2);

    // Piezo Buzzer (BUZ1)
    final buzCenter = const Offset(255, 152);
    if (isAlarmActive) {
      canvas.drawCircle(buzCenter, 22, Paint()..color = const Color(0xFFF59E0B).withOpacity(0.3));
    }
    canvas.drawCircle(buzCenter, 14, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(
      buzCenter,
      14,
      Paint()
        ..color = isAlarmActive ? const Color(0xFFF59E0B) : const Color(0xFF64748B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawLabel(canvas, isAlarmActive ? '🔊 BEEP!' : 'BUZ1 (D8)', const Offset(280, 145), const Color(0xFFFDE047), 10, FontWeight.bold);
    canvas.drawLine(const Offset(134, 125), const Offset(241, 152), Paint()..color = const Color(0xFFF87171)..strokeWidth = 2);

    // Ultrasonic sound wave arcs & Intruder Target on the right
    final double targetX = 335 + ((distanceCm - 5) / 45.0) * (math.max(30.0, size.width - 375));
    final wavePaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(pulseOn ? 0.85 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 1; i <= 3; i++) {
      final r = i * 16.0;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(310, 101), radius: r),
        -0.55,
        1.1,
        false,
        wavePaint,
      );
    }

    // Intruder badge
    final targetRect = RRect.fromRectAndRadius(Rect.fromLTWH(targetX, 76, 56, 50), const Radius.circular(8));
    canvas.drawRRect(
      targetRect,
      Paint()..color = distanceCm < 15 ? const Color(0xFF991B1B) : const Color(0xFF1E293B),
    );
    canvas.drawRRect(
      targetRect,
      Paint()
        ..color = distanceCm < 15 ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _drawLabel(canvas, '🚶', Offset(targetX + 18, 80), Colors.white, 15, FontWeight.normal);
    _drawLabel(
      canvas,
      '${distanceCm.round()} cm',
      Offset(targetX + 9, 104),
      const Color(0xFF38BDF8),
      10,
      FontWeight.w800,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color, double fontSize, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _BlueprintCircuitPainter oldDelegate) {
    return oldDelegate.distanceCm != distanceCm ||
        oldDelegate.pulseOn != pulseOn ||
        oldDelegate.experimentId != experimentId;
  }
}
