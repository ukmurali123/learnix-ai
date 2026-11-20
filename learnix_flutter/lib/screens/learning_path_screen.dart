import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

class LearningPathScreen extends StatefulWidget {
  final String baseUrl;
  final int studentId;
  final ConfettiController confettiController;

  const LearningPathScreen({
    super.key,
    required this.baseUrl,
    required this.studentId,
    required this.confettiController,
  });

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _days = [];
  int _completedCount = 0;

  // Active Day Detail View State
  Map<String, dynamic>? _selectedDay;
  // 5 Top Modes (Removed Video and Slides!):
  // 0: Learn, 1: Predict, 2: Try it, 3: Bug hunt, 4: Quiz
  int _activeTopModeIndex = 0;
  // 5 Dimension Tabs inside Learn:
  // 0: WHAT, 1: LIKE, 2: WHY, 3: WHERE, 4: WHEN
  int _activeWhatTabIndex = 0;

  int _circuitTopology = 0; // 0: 1 LED, 1: 2 in series, 2: 2 in parallel
  double _resistorOhms = 330.0;
  int _selectedAnatomyIndex = 0; // 0..3 sub-item selector for WHAT/LIKE/WHY/WHERE/WHEN

  // Interactive Predict state
  int? _predictChoice;

  // Interactive "Try it" Practical Completion State
  bool _pracStep1Power = false;
  bool _pracStep2Resistor = false;
  bool _pracStep3Led = false;
  bool _pracStep4Tested = false;
  String _pracTutorMsg =
      'Let\'s complete today\'s practical build! Start with Step 1: connect the 5V and GND power rails to your breadboard.';

  // Interactive "Bug hunt" Circuit & Breadboard Debugging State
  bool _bug1ResistorFixed = false;
  bool _bug2PolarityFixed = false;
  bool _bug3GroundFixed = false;
  bool _isAskingBugTutor = false;
  final TextEditingController _bugTutorInputController = TextEditingController();
  String _bugTutorPraise =
      'I scanned the faulty breadboard! There are 3 hardware bugs stopping this circuit from working safely.';
  String _bugTutorHint =
      'Bug Detective Tip: Look closely at (1) the missing 330 Ω resistor, (2) the flipped LED legs (K/A), and (3) the loose black GND jumper wire!';

  // Interactive Quiz State
  final Map<int, int> _quizAnswers = {};

  late AnimationController _electronController;

  // 5 Top Modes (Video and Slides removed as requested!)
  final List<Map<String, dynamic>> _topModes = [
    {'label': 'Learn', 'icon': LucideIcons.checkCircle2},
    {'label': 'Predict', 'icon': LucideIcons.lightbulb},
    {'label': 'Try it', 'icon': LucideIcons.wrench},
    {'label': 'Bug hunt', 'icon': LucideIcons.bug},
    {'label': 'Quiz', 'icon': LucideIcons.helpCircle},
  ];

  @override
  void initState() {
    super.initState();
    _electronController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _fetchLearningPath();
  }

  @override
  void dispose() {
    _electronController.dispose();
    _bugTutorInputController.dispose();
    super.dispose();
  }

  Future<void> _fetchLearningPath() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/path/${widget.studentId}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _days = data['days'] ?? [];
        _completedCount = data['completed_count'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error fetching path: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _speakText(String text) {
    try {
      final synth = html.window.speechSynthesis;
      if (synth != null) {
        synth.cancel();
        final utterance = html.SpeechSynthesisUtterance(text);
        utterance.rate = 0.95;
        synth.speak(utterance);
      }
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  Future<void> _completeDay(int dayNumber, int score) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/path/${widget.studentId}/day/$dayNumber/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'quiz_score': score, 'max_score': 3}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        widget.confettiController.play();
        await _fetchLearningPath();

        if (!mounted) return;
        final revision = data['revision'];
        if (revision != null && revision['needed'] == true) {
          _showRevisionDialog(revision);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text('🎉 Day $dayNumber mastered! Day ${dayNumber + 1} is now unlocked on your roadmap.'),
            ),
          );
          setState(() => _selectedDay = null);
        }
      }
    } catch (e) {
      debugPrint('Error completing day: $e');
    }
  }

  void _showRevisionDialog(Map<String, dynamic> revision) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('🤖', style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Expanded(child: Text('AI Tutor: Quick Revision Step')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(revision['recap'] ?? 'Let\'s reinforce this concept together!'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        revision['analogy'] ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tutor Tip: ${revision['coach_tip'] ?? ''}',
                style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedDay = null);
            },
            child: const Text('Got it! Back to Roadmap'),
          ),
        ],
      ),
    );
  }

  void _openDayWorkspace(Map<String, dynamic> day) {
    setState(() {
      _selectedDay = day;
      _activeTopModeIndex = 0;
      _activeWhatTabIndex = 0;
      _circuitTopology = 0;
      _resistorOhms = 330.0;
      _selectedAnatomyIndex = 0;
      _predictChoice = null;

      _pracStep1Power = false;
      _pracStep2Resistor = false;
      _pracStep3Led = false;
      _pracStep4Tested = false;
      _pracTutorMsg =
          'Let\'s complete today\'s practical build! Start with Step 1: connect the 5V and GND power rails to your breadboard.';

      _bug1ResistorFixed = false;
      _bug2PolarityFixed = false;
      _bug3GroundFixed = false;
      _bugTutorPraise =
          'I scanned the faulty breadboard! There are 3 hardware bugs stopping this circuit from working safely.';
      _bugTutorHint =
          'Bug Detective Tip: First add the missing 330 Ω resistor so 85 mA overcurrent doesn\'t burn the LED!';

      _quizAnswers.clear();
    });
  }

  Future<void> _askBugHuntAiTutor({String? customQuestion}) async {
    final q = customQuestion ?? _bugTutorInputController.text.trim();
    setState(() => _isAskingBugTutor = true);

    try {
      if (q.isNotEmpty) {
        _bugTutorInputController.clear();
        final res = await http.post(
          Uri.parse('${widget.baseUrl}/api/concept-studio/doubt'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'student_id': widget.studentId,
            'concept_title': 'Breadboard Bug Hunt (${_selectedDay?['title'] ?? 'LED Circuit'})',
            'question': q,
            'language': 'English',
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          setState(() {
            _bugTutorPraise = 'Great debugging question!';
            _bugTutorHint = (data['answer'] ?? data['tip'] ?? '').toString();
          });
          return;
        }
      }

      // Live circuit diagnosis via /api/lab/check based on unfixed bugs
      final circuit = <Map<String, String>>[
        {'from': 'D13', 'to': _bug1ResistorFixed ? 'R1.a' : 'LED1.anode'},
        if (_bug1ResistorFixed)
          {'from': 'R1.b', 'to': _bug2PolarityFixed ? 'LED1.anode' : 'LED1.cathode'},
        if (_bug3GroundFixed)
          {'from': _bug2PolarityFixed ? 'LED1.cathode' : 'LED1.anode', 'to': 'GND'},
      ];

      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/lab/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'experiment_id': 1,
          'student_id': widget.studentId,
          'circuit': circuit,
          'code': 'void setup(){ pinMode(13, OUTPUT); } void loop(){ digitalWrite(13, HIGH); }',
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _bugTutorPraise = (data['praise'] ?? 'Good eye inspecting the breadboard!').toString();
          if (_bug1ResistorFixed && _bug2PolarityFixed && _bug3GroundFixed) {
            _bugTutorHint = '🎉 All 3 breadboard & circuit bugs are fixed! Current is flowing at a safe 9.1 mA and the LED is glowing!';
          } else {
            _bugTutorHint = (data['hint'] ?? _getNextLocalBugHint()).toString();
          }
        });
      } else {
        setState(() => _bugTutorHint = _getNextLocalBugHint());
      }
    } catch (e) {
      setState(() => _bugTutorHint = _getNextLocalBugHint());
    } finally {
      if (mounted) setState(() => _isAskingBugTutor = false);
    }
  }

  String _getNextLocalBugHint() {
    if (!_bug1ResistorFixed) {
      return '🔍 Bug #1 Detected: The 5V red wire goes straight into the LED without a resistor (85 mA overcurrent!). Tap "Fix Bug #1: Insert 330 Ω Resistor".';
    }
    if (!_bug2PolarityFixed) {
      return '🔍 Bug #2 Detected: Look at the LED legs on the breadboard — Cathode (K, short leg −) is connected to positive instead of Anode (A, long leg +). Tap "Fix Bug #2: Flip LED Polarity".';
    }
    if (!_bug3GroundFixed) {
      return '🔍 Bug #3 Detected: The black jumper wire from the LED Cathode is hanging in an empty row instead of the top blue/black GND (−) rail. Tap "Fix Bug #3: Reconnect GND Jumper".';
    }
    return '🎉 All 3 bugs are fixed! The breadboard circuit is complete and safe at 9.1 mA.';
  }

  Map<String, dynamic> _getDayLessonData(Map<String, dynamic> day) {
    final dayNum = day['day_number'] ?? 1;
    final title = (day['title'] ?? 'Robotics Concept').toString();

    final Map<int, Map<String, dynamic>> catalog = {
      1: {
        'headerTitle': 'Day 1: What is an LED',
        'question': 'Why does an LED only glow in one direction and need a resistor?',
        'what': 'A light-emitting diode (LED) is a semiconductor that converts electricity into light in one direction (anode + to cathode −).',
        'like': 'Real-Life Analogy: Like a water pump pushing water through a narrow speed-valve to gently spin a one-way glowing waterwheel!',
        'why': 'Cause & Effect: Without a 330 Ω resistor, 85 mA rushes in and burns the LED; with 330 Ω, current stays at a safe 9.1 mA!',
        'where': 'Real-World Places: Inside traffic signal lights, TV remote infrared transmitters, smartphone flashlights, and robot status lights!',
        'when': 'When to Use It: Whenever an Arduino output pin goes HIGH (5V) to signal an alert, sensor detection, or power status!',
      },
      2: {
        'headerTitle': 'Day 2: Resistors and Current Limiting',
        'question': 'Why does an LED burn without a resistor?',
        'what': 'A resistor limits the flow of electric current in a circuit, measured in Ohms (Ω), converting excess electrical energy safely.',
        'like': 'Real-Life Analogy: Like a speed-bump on a road or a narrow pinch in a garden hose that keeps water pressure at a safe speed!',
        'why': 'Cause & Effect: Ohm\'s Law (I = (5V − 2V) ÷ R) keeps current around 9.1 mA so delicate components never overheat!',
        'where': 'Real-World Places: Inside phone chargers, traffic lights, smart TVs, and every Arduino LED & sensor circuit!',
        'when': 'When to Use It: Always place a 220Ω–330Ω resistor in series whenever connecting a 2V LED to a 5V or 9V power source!',
      },
      3: {
        'headerTitle': 'Day 3: Ground and Complete Circuits',
        'question': 'Why won\'t a circuit work if the Ground (GND) wire is missing?',
        'what': 'Ground (GND) is the 0V reference point that completes an electrical loop back to the battery or power source.',
        'like': 'Real-Life Analogy: Like a circular water slide loop — water cannot keep flowing if the return pipe back to the pump is broken!',
        'why': 'Cause & Effect: Open GND loop = 0.0 mA (dark LED); Closed GND loop = 9.1 mA continuous flow (glowing LED)!',
        'where': 'Real-World Places: Car battery negative chassis ground, home appliance neutral/ground lines, and Arduino GND rails!',
        'when': 'When to Use It: Always connect every component\'s negative (−) return leg to a common GND rail before turning power ON!',
      },
      4: {
        'headerTitle': 'Day 4: Digital Output Pins & Loops',
        'question': 'How does Arduino control things on and off in a loop?',
        'what': 'Digital pins can be switched HIGH (5V) or LOW (0V) using code. void loop() repeats these commands continuously.',
        'like': 'Real-Life Analogy: Like a lighthouse light keeper flicking a switch ON and OFF to rhythmic count beats that repeat forever!',
        'why': 'Cause & Effect: Without delay(), the loop toggles millions of times per second (a blur); delay(500) gives visible blinking!',
        'where': 'Real-World Places: Turn signals on cars, pulsing warning beacons on radio towers, and robot indicator blinkers!',
        'when': 'When to Use It: Whenever you want automated blinking, timed alerts, or periodic motor pulses without human intervention!',
      },
      5: {
        'headerTitle': 'Day 5: Buttons and Digital Input',
        'question': 'How does a microcontroller know when a button is pressed?',
        'what': 'A push button connects or disconnects two points in a circuit. digitalRead() checks whether the pin sees HIGH or LOW.',
        'like': 'Real-Life Analogy: Like a drawbridge: open = traffic stops (floating); closed = traffic crosses smoothly to GND!',
        'why': 'Cause & Effect: Using INPUT_PULLUP prevents an erratic floating input by gently holding the pin at 5V until pressed to GND!',
        'where': 'Real-World Places: Gamepad buttons, doorbells, keyboard keys, and emergency stop switches on factory machines!',
        'when': 'When to Use It: Whenever a human needs to interact with your robot — starting a motor, firing a buzzer, or toggling lights!',
      },
      6: {
        'headerTitle': 'Day 6: Buzzers + If-Else Decisions',
        'question': 'How do buzzers make sound and how does code decide when to beep?',
        'what': 'A piezo buzzer vibrates rapidly when fed an electrical pulse (PWM tone). If-else statements decide when to activate it.',
        'like': 'Real-Life Analogy: Like a guard dog that only barks IF someone knocks on the front door, ELSE stays quietly asleep!',
        'why': 'Cause & Effect: Tone frequency determines pitch (e.g. 880 Hz high chime vs 440 Hz low beep); if-condition governs triggering!',
        'where': 'Real-World Places: Microwave oven beeps, car reverse parking sensors, digital alarm clocks, and doorbell chimes!',
        'when': 'When to Use It: When you need audible feedback for danger, button clicks, sensor triggers, or user notifications!',
      },
      7: {
        'headerTitle': 'Day 7: Variables & State Memory',
        'question': 'How does a robot remember numbers, scores, and states?',
        'what': 'Variables are named storage boxes in computer memory (e.g., int speed = 100; int distance = 15;) that hold values that change.',
        'like': 'Real-Life Analogy: Like labelled lunchboxes or scoreboards on a soccer pitch that update every time a team scores a goal!',
        'why': 'Cause & Effect: Without variables, code is hard-coded and static; with variables, robots adapt and remember previous measurements!',
        'where': 'Real-World Places: Game high-scores, robot battery percentage counters, speedometer readings, and thermometer displays!',
        'when': 'When to Use It: Whenever tracking sensor readings, counting button presses, or computing math before making decisions!',
      },
      8: {
        'headerTitle': 'Day 8: Ultrasonic Distance Sensor (HC-SR04)',
        'question': 'How does a robot "see" walls and measure distance with sound?',
        'what': 'An HC-SR04 sensor transmits a 40 kHz ultrasonic burst from TRIG and measures the travel time until ECHO bounces back.',
        'like': 'Real-Life Analogy: Like a bat flying in a dark cave or a submarine sonar pinging off undersea obstacles to navigate!',
        'why': 'Cause & Effect: Speed of sound is 0.034 cm/µs. Distance = (Echo Time in µs × 0.034) ÷ 2 (divided by 2 for round-trip)!',
        'where': 'Real-World Places: Autonomous robot vacuum obstacle avoidance, car parking radar sensors, and smart automatic trash bins!',
        'when': 'When to Use It: When your robot must avoid crashing into walls, detect approaching intruders, or measure liquid levels!',
      },
      9: {
        'headerTitle': 'Day 9: What is Artificial Intelligence (AI)',
        'question': 'How is AI different from regular computer programming?',
        'what': 'Regular code follows rigid step-by-step rules; AI learns patterns from examples and data to make predictions.',
        'like': 'Real-Life Analogy: Regular code is like following a baking recipe word-for-word; AI is like an experienced chef tasting and tuning!',
        'why': 'Cause & Effect: With 10,000 photos of cats and dogs, an AI extracts visual features that no human could write in simple if-statements!',
        'where': 'Real-World Places: Self-driving cars, voice assistants (Siri, Alexa), spam filters, and Learnix AI tutoring!',
        'when': 'When to Use It: When rules are too complex, fuzzy, or variable for manual if-else statements (vision, speech, reasoning)!',
      },
      10: {
        'headerTitle': 'Day 10: Image Recognition & Computer Vision',
        'question': 'How do computers see and classify objects in camera images?',
        'what': 'Images are grids of numeric pixels (RGB). Vision models detect edges, textures, and shapes to recognize objects.',
        'like': 'Real-Life Analogy: Like building a LEGO picture: individual dots form edges, edges form shapes, and shapes become a recognizable face!',
        'why': 'Cause & Effect: Neural networks pool pixel values into feature maps, letting a robot car tell pedestrians apart from stop signs!',
        'where': 'Real-World Places: Face-unlock on smartphones, lane-keeping camera systems on cars, and sorting robots in recycling plants!',
        'when': 'When to Use It: Whenever your robot needs a camera feed to recognize gestures, sort colored blocks, or track human motion!',
      },
    };

    return catalog[dayNum] ?? catalog[1]!;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: tokens.primary));
    }

    if (_selectedDay != null) {
      return _buildDayWorkspaceView(context, _selectedDay!);
    }

    return _buildSnakeRoadmapView(context);
  }

  // ===========================================================================
  // IMAGE 2: WINDING SNAKE ROADMAP VIEW (Videos button removed)
  // ===========================================================================
  Widget _buildSnakeRoadmapView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final zigZagOffset = isMobile ? 22.0 : 56.0;
        final cardWidth = isMobile ? (constraints.maxWidth - 48).clamp(240.0, 320.0) : 330.0;

        return Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFDCE7F3),
                border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.milestone, size: 18, color: Color(0xFF1E293B)),
                      const SizedBox(width: 8),
                      if (!isMobile)
                        Text(
                          '$_completedCount/${_days.length} Mastered',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                    ],
                  ),
                  Flexible(
                    child: Text(
                      '10-Day Robotics Learning Path',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchLearningPath,
                    icon: const Icon(LucideIcons.rotateCw, size: 17, color: Color(0xFF1E293B)),
                    tooltip: 'Refresh Path',
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFD9EAFF),
                      Color(0xFFEAF7F0),
                      Color(0xFFE5F6DF),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: List.generate(_days.length, (index) {
                        final day = Map<String, dynamic>.from(_days[index] as Map);
                        final isEven = index % 2 == 0;
                        final dx = isEven ? -zigZagOffset : zigZagOffset;
                        final nextDx = !isEven ? -zigZagOffset : zigZagOffset;
                        final status = (day['status'] ?? 'locked').toString();
                        final isDone = status == 'done';
                        final isCurrent = status == 'current';

                        return Column(
                          children: [
                            Transform.translate(
                              offset: Offset(dx, 0),
                              child: _buildSnakeNodeCard(day, cardWidth, isDone, isCurrent),
                            ).animate().fadeIn(delay: (index * 50).ms, duration: 350.ms).slideY(begin: 0.08, end: 0),
                            if (index < _days.length - 1)
                              SizedBox(
                                width: cardWidth + (zigZagOffset * 2),
                                height: 54,
                                child: CustomPaint(
                                  painter: _SnakeDashedConnectorPainter(
                                    startXOffset: dx,
                                    endXOffset: nextDx,
                                    color: isDone
                                        ? const Color(0xFF74C69D)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSnakeNodeCard(
    Map<String, dynamic> day,
    double width,
    bool isDone,
    bool isCurrent,
  ) {
    final dayNum = day['day_number'] ?? 1;
    final title = (day['title'] ?? 'Concept').toString();

    List<Color> gradientColors;
    if (isDone) {
      gradientColors = const [Color(0xFF34A853), Color(0xFF1B6E36)];
    } else if (isCurrent) {
      gradientColors = const [Color(0xFF1E88E5), Color(0xFF0D47A1)];
    } else {
      gradientColors = const [Color(0xFF94A3B8), Color(0xFF64748B)];
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openDayWorkspace(day),
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: isCurrent
                    ? Border.all(color: const Color(0xFFFACC15), width: 3)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isCurrent
                        ? const Color(0xFF1E88E5).withOpacity(0.35)
                        : Colors.black.withOpacity(0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.22),
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.8),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 28)
                          : Text(
                              '$dayNum',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAY $dayNum',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              'Interactive',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isDone)
                    const Icon(Icons.star_rounded, color: Color(0xFFFACC15), size: 32)
                  else if (isCurrent)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFF0D47A1),
                        size: 22,
                      ),
                    )
                  else
                    Icon(
                      LucideIcons.lock,
                      color: Colors.white.withOpacity(0.7),
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isCurrent)
          Positioned(
            top: -13,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFACC15),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'START HERE',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // IMAGE 3: INTERACTIVE DAY LESSON WORKSPACE VIEW
  // ===========================================================================
  Widget _buildDayWorkspaceView(BuildContext context, Map<String, dynamic> day) {
    final dayNum = day['day_number'] ?? 1;
    final lessonData = _getDayLessonData(day);
    final headerTitle = lessonData['headerTitle'].toString();
    final questionText = lessonData['question'].toString();

    final whatKeys = ['what', 'like', 'why', 'where', 'when'];
    final activeExplanation = lessonData[whatKeys[_activeWhatTabIndex]].toString();

    double effectiveDrop = 2.0;
    double effectiveR = _resistorOhms;
    if (_circuitTopology == 1) {
      effectiveDrop = 3.6;
    } else if (_circuitTopology == 2) {
      effectiveR = _resistorOhms / 1.5;
    }
    final currentMa = ((5.0 - effectiveDrop).clamp(0.5, 5.0) / effectiveR * 1000);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 820;

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              // 1. Top Navigation Header Bar
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _selectedDay = null),
                      icon: const Icon(LucideIcons.arrowLeft, size: 20, color: Color(0xFF0F172A)),
                      tooltip: 'Back to Learning Path',
                    ),
                    Flexible(
                      child: Text(
                        headerTitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isNarrow ? 14 : 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(LucideIcons.maximize, size: 18, color: Color(0xFF0F172A)),
                      tooltip: 'Fullscreen',
                    ),
                  ],
                ),
              ),

              // Main Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 14 : 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Row of 5 Interactive Activity Mode Pills (Learn, Predict, Try it, Bug hunt, Quiz)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_topModes.length, (idx) {
                            final mode = _topModes[idx];
                            final isSelected = _activeTopModeIndex == idx;

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: InkWell(
                                onTap: () => setState(() => _activeTopModeIndex = idx),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFEA580C)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFEA580C)
                                          : const Color(0xFF334155),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        mode['icon'] as IconData,
                                        size: 15,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        mode['label'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 3. Blue Question Banner with "Voice lesson" Pill + Speaker Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1D82DF), Color(0xFF47A3F3)],
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.helpCircle, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    questionText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _speakText('$questionText. $activeExplanation'),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.volume2, size: 15, color: Color(0xFF0284C7)),
                                        SizedBox(width: 6),
                                        Text(
                                          'Voice lesson',
                                          style: TextStyle(
                                            color: Color(0xFF0284C7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _speakText(activeExplanation),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.volume2, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 4. Only show WHAT / LIKE / WHY / WHERE / WHEN tabs when in "Learn" mode (idx == 0)
                      if (_activeTopModeIndex == 0) ...[
                        _buildFiveDimensionTabs(isNarrow, activeExplanation),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            activeExplanation,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // 5. Main Interactive Area per Top Mode:
                      // 0 = Learn (dynamically switches animation based on WHAT / LIKE / WHY / WHERE / WHEN!)
                      // 1 = Predict
                      // 2 = Try it (Practical Hands-On Breadboard Build to complete!)
                      // 3 = Bug hunt (Faulty Breadboard & Circuit Bug Hunter with AI Tutor!)
                      // 4 = Quiz
                      if (_activeTopModeIndex == 0)
                        _buildDynamicDimensionLearnWorkspace(isNarrow, currentMa, dayNum)
                      else if (_activeTopModeIndex == 1)
                        _buildDayPredictMode(currentMa)
                      else if (_activeTopModeIndex == 2)
                        _buildDayTryItPracticalMode(isNarrow, dayNum)
                      else if (_activeTopModeIndex == 3)
                        _buildDayBugHuntMode(isNarrow)
                      else
                        _buildDayQuizMode(dayNum),

                      const SizedBox(height: 16),

                      // 6. Bottom-right "-> Next" Pill Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_activeTopModeIndex < _topModes.length - 1) {
                              setState(() => _activeTopModeIndex++);
                            } else {
                              _completeDay(dayNum, 3);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D82DF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(LucideIcons.arrowRight, size: 17),
                          label: Text(
                            _activeTopModeIndex < _topModes.length - 1
                                ? 'Next: ${_topModes[_activeTopModeIndex + 1]['label']}'
                                : 'Complete Day $dayNum',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFiveDimensionTabs(bool isNarrow, String activeExplanation) {
    final List<Map<String, dynamic>> tabs = [
      {
        'label': 'WHAT',
        'icon': LucideIcons.helpCircle,
        'activeBg': const Color(0xFF1D82DF),
        'inactiveBg': const Color(0xFFE0F2FE),
        'activeText': Colors.white,
        'inactiveText': const Color(0xFF0369A1),
      },
      {
        'label': 'LIKE',
        'icon': LucideIcons.lightbulb,
        'activeBg': const Color(0xFF0D9488),
        'inactiveBg': const Color(0xFFE6F4F1),
        'activeText': Colors.white,
        'inactiveText': const Color(0xFF0F766E),
      },
      {
        'label': 'WHY',
        'icon': LucideIcons.sparkles,
        'activeBg': const Color(0xFFEA580C),
        'inactiveBg': const Color(0xFFFFF3E0),
        'activeText': Colors.white,
        'inactiveText': const Color(0xFFD97706),
      },
      {
        'label': 'WHERE',
        'icon': LucideIcons.globe,
        'activeBg': const Color(0xFF16A34A),
        'inactiveBg': const Color(0xFFEAF7EE),
        'activeText': Colors.white,
        'inactiveText': const Color(0xFF15803D),
      },
      {
        'label': 'WHEN',
        'icon': LucideIcons.clock,
        'activeBg': const Color(0xFF7E22CE),
        'inactiveBg': const Color(0xFFF3E8FF),
        'activeText': Colors.white,
        'inactiveText': const Color(0xFF7E22CE),
      },
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(tabs.length, (idx) {
                final t = tabs[idx];
                final isSelected = _activeWhatTabIndex == idx;
                final tabWidth = isNarrow ? 115.0 : 175.0;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() {
                      _activeWhatTabIndex = idx;
                      _selectedAnatomyIndex = 0;
                    }),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: tabWidth,
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? (t['activeBg'] as Color) : (t['inactiveBg'] as Color),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            t['icon'] as IconData,
                            size: 15,
                            color: isSelected ? (t['activeText'] as Color) : (t['inactiveText'] as Color),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? (t['activeText'] as Color) : (t['inactiveText'] as Color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        IconButton(
          onPressed: () => _speakText(activeExplanation),
          icon: const Icon(LucideIcons.volume2, size: 18, color: Color(0xFF0284C7)),
          tooltip: 'Read aloud',
        ),
      ],
    );
  }

  // ===========================================================================
  // DYNAMIC LEARN ANIMATION WORKSPACE (CHANGES BASED ON WHAT / LIKE / WHY / WHERE / WHEN & CURRENT DAY!)
  // ===========================================================================
  Widget _buildDynamicDimensionLearnWorkspace(bool isNarrow, double currentMa, int dayNum) {
    // 1. Build the Left Animated Canvas depending on _activeWhatTabIndex and dayNum:
    // 0 = WHAT (Technical Circuit Schematic / Ultrasonic Sensor / Button Input)
    // 1 = LIKE (Non-technical Real-Life Water Tank / Bat Sonar / Drawbridge / Chef Analogy!)
    // 2 = WHY  (Cause & Effect Side-by-Side: Burned vs Safe, Echo Delay, Floating vs Pullup)
    // 3 = WHERE (Real-World Everyday Devices tailored to the Day's Topic)
    // 4 = WHEN (Real-Time Decision & Trigger Flow Timeline)
    Widget leftAnimationCanvas;
    if (_activeWhatTabIndex == 1) {
      leftAnimationCanvas = AnimatedBuilder(
        animation: _electronController,
        builder: (context, _) => CustomPaint(
          painter: _LikeWaterWheelAnalogyPainter(
            progress: _electronController.value,
            resistorOhms: _resistorOhms.toInt(),
            selectedPart: _selectedAnatomyIndex,
            dayNum: dayNum,
          ),
        ),
      );
    } else if (_activeWhatTabIndex == 2) {
      leftAnimationCanvas = AnimatedBuilder(
        animation: _electronController,
        builder: (context, _) => CustomPaint(
          painter: _WhyBurnVsSafePainter(
            progress: _electronController.value,
            resistorOhms: _resistorOhms.toInt(),
            currentMa: currentMa,
            dayNum: dayNum,
          ),
        ),
      );
    } else if (_activeWhatTabIndex == 3) {
      leftAnimationCanvas = AnimatedBuilder(
        animation: _electronController,
        builder: (context, _) => CustomPaint(
          painter: _WhereRealWorldDevicesPainter(
            progress: _electronController.value,
            selectedDeviceIdx: _selectedAnatomyIndex,
            dayNum: dayNum,
          ),
        ),
      );
    } else if (_activeWhatTabIndex == 4) {
      leftAnimationCanvas = AnimatedBuilder(
        animation: _electronController,
        builder: (context, _) => CustomPaint(
          painter: _WhenTimelineTriggerPainter(
            progress: _electronController.value,
            selectedRuleIdx: _selectedAnatomyIndex,
            resistorOhms: _resistorOhms.toInt(),
            dayNum: dayNum,
          ),
        ),
      );
    } else {
      leftAnimationCanvas = AnimatedBuilder(
        animation: _electronController,
        builder: (context, _) => CustomPaint(
          painter: _InteractiveCircuitSchematicPainter(
            progress: _electronController.value,
            resistorOhms: _resistorOhms.toInt(),
            currentMa: currentMa,
            topology: _circuitTopology,
            dayNum: dayNum,
          ),
        ),
      );
    }

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: leftAnimationCanvas,
        ),
        const SizedBox(height: 14),

        // Context-specific bottom controls under the left animation
        if (_activeWhatTabIndex == 0) ...[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildTopologyPill(0, '1 LED'),
              _buildTopologyPill(1, '2 in series'),
              _buildTopologyPill(2, '2 in parallel'),
            ],
          ),
          const SizedBox(height: 12),
        ],

        Row(
          children: [
            Text(
              _activeWhatTabIndex == 1
                  ? 'Valve Pinch (Ω)'
                  : 'Resistor (Ω)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF0284C7),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: const Color(0xFF0284C7),
                  trackHeight: 6,
                ),
                child: Slider(
                  value: _resistorOhms,
                  min: 100,
                  max: 1000,
                  divisions: 90,
                  label: '${_resistorOhms.toInt()} Ω',
                  onChanged: (v) => setState(() => _resistorOhms = v),
                ),
              ),
            ),
            Text(
              '${_resistorOhms.toInt()} Ω',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0284C7),
              ),
            ),
          ],
        ),
      ],
    );

    // 2. Build the Right 4 Circular Selector Buttons + Spotlight Card tailored to WHAT / LIKE / WHY / WHERE / WHEN!
    final List<Map<String, dynamic>> rightItems = _getRightItemsForTab(_activeWhatTabIndex, currentMa, dayNum);
    final activeItem = rightItems[_selectedAnatomyIndex.clamp(0, rightItems.length - 1)];

    final rightColumn = Column(
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: List.generate(rightItems.length, (idx) {
            final item = rightItems[idx];
            final isSelected = _selectedAnatomyIndex == idx;

            return GestureDetector(
              onTap: () => setState(() => _selectedAnatomyIndex = idx),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF38BDF8),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE0F2FE),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF0284C7), width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          item['symbol'] as String,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        // Large Pastel Spotlight Card matching the active dimension tab
        Container(
          width: double.infinity,
          height: 220,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: activeItem['cardBg'] as Color? ?? const Color(0xFFEBF5DF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                activeItem['icon'] as IconData? ?? Icons.lightbulb_rounded,
                size: 68,
                color: activeItem['color'] as Color,
              ),
              const SizedBox(height: 6),
              Text(
                activeItem['badge'] as String,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: activeItem['color'] as Color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                activeItem['title'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activeItem['desc'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          leftColumn,
          const SizedBox(height: 24),
          rightColumn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: leftColumn),
        const SizedBox(width: 28),
        Expanded(flex: 5, child: rightColumn),
      ],
    );
  }

  List<Map<String, dynamic>> _getRightItemsForTab(int tabIdx, double currentMa, int dayNum) {
    if (dayNum == 8) {
      // Day 8: Ultrasonic Distance Sensor (HC-SR04)
      if (tabIdx == 1) {
        return [
          {
            'label': 'Bat Sonar',
            'symbol': '🦇',
            'icon': LucideIcons.radio,
            'badge': 'Echo Ping',
            'title': 'Echolocation (Bat Navigation)',
            'desc': 'Just like a bat chirps and listens for the echo bounce off cave walls, HC-SR04 pings 40 kHz sound waves!',
            'color': const Color(0xFF0284C7),
            'cardBg': const Color(0xFFE0F2FE),
          },
          {
            'label': 'Submarine',
            'symbol': '🚢',
            'icon': LucideIcons.compass,
            'badge': 'Active Sonar',
            'title': 'Submarine Undersea Sonar',
            'desc': 'Submarines measure distance by timing the sound pulse round trip through water to undersea obstacles.',
            'color': const Color(0xFF0D9488),
            'cardBg': const Color(0xFFCCFBF1),
          },
          {
            'label': 'Stopwatch',
            'symbol': '⏱️',
            'icon': LucideIcons.timer,
            'badge': 'Time × Speed',
            'title': 'High-Speed Microsecond Timer',
            'desc': 'The Arduino stopwatch counts microseconds between sending TRIG pulse and receiving ECHO back.',
            'color': const Color(0xFFD97706),
            'cardBg': const Color(0xFFFEF3C7),
          },
          {
            'label': 'Safety Shield',
            'symbol': '🛡️',
            'icon': LucideIcons.shieldCheck,
            'badge': 'Wall Buffer',
            'title': 'Invisible Safety Cushion',
            'desc': 'Creates an invisible 20 cm distance bubble so autonomous robot cars stop before crashing into obstacles!',
            'color': const Color(0xFF16A34A),
            'cardBg': const Color(0xFFDCFCE7),
          },
        ];
      }
      if (tabIdx == 3) {
        return [
          {
            'label': 'Robot Vac',
            'symbol': '🤖',
            'icon': LucideIcons.bot,
            'badge': 'Smart Vacuum',
            'title': 'Autonomous Robot Vacuums',
            'desc': 'Uses ultrasonic and infrared pings to avoid furniture legs and map room boundaries safely.',
            'color': const Color(0xFF0284C7),
            'cardBg': const Color(0xFFE0F2FE),
          },
          {
            'label': 'Car Parking',
            'symbol': '🚗',
            'icon': LucideIcons.gauge,
            'badge': 'Bumper Radar',
            'title': 'Automobile Reverse Parking Sensors',
            'desc': 'Ultrasonic sensors embedded in car bumpers beep faster as you reverse closer to a wall or pole.',
            'color': const Color(0xFF16A34A),
            'cardBg': const Color(0xFFDCFCE7),
          },
          {
            'label': 'Smart Bin',
            'symbol': '🗑️',
            'icon': LucideIcons.trash2,
            'badge': 'Touchless Lid',
            'title': 'Automatic Touchless Trash Bins',
            'desc': 'Opens the lid automatically when your hand approaches within 15 cm of the sensor.',
            'color': const Color(0xFFD97706),
            'cardBg': const Color(0xFFFEF3C7),
          },
          {
            'label': 'Liquid Tank',
            'symbol': '🚰',
            'icon': LucideIcons.droplets,
            'badge': 'Water Gauge',
            'title': 'Water Tank Level Monitoring',
            'desc': 'Mounted on top of water tanks to measure water height without ever touching the liquid.',
            'color': const Color(0xFF7E22CE),
            'cardBg': const Color(0xFFF3E8FF),
          },
        ];
      }
    }

    if (dayNum == 5) {
      // Day 5: Buttons and Digital Input
      if (tabIdx == 1) {
        return [
          {
            'label': 'Drawbridge',
            'symbol': '🌉',
            'icon': LucideIcons.gitFork,
            'badge': 'Open vs Closed',
            'title': 'Mechanical Drawbridge Analogy',
            'desc': 'When open, electrical traffic cannot cross (HIGH/disconnected); when pressed, traffic connects to GND (LOW)!',
            'color': const Color(0xFF0284C7),
            'cardBg': const Color(0xFFE0F2FE),
          },
          {
            'label': 'Spring Coil',
            'symbol': '🌀',
            'icon': LucideIcons.rotateCw,
            'badge': 'Momentary',
            'title': 'Tactile Spring Return',
            'desc': 'Springs back the moment your finger releases, making it ideal for momentary pulses and triggers.',
            'color': const Color(0xFFD97706),
            'cardBg': const Color(0xFFFEF3C7),
          },
          {
            'label': 'Tug-of-War',
            'symbol': '🪢',
            'icon': LucideIcons.scale,
            'badge': 'INPUT_PULLUP',
            'title': 'Internal Pullup Resistor Tug',
            'desc': 'A gentle internal 20kΩ spring keeps the pin pulled HIGH until a firm press grounds it to LOW.',
            'color': const Color(0xFF16A34A),
            'cardBg': const Color(0xFFDCFCE7),
          },
          {
            'label': 'Bell Chime',
            'symbol': '🔔',
            'icon': LucideIcons.bell,
            'badge': 'Trigger Event',
            'title': 'Action Trigger (digitalRead == LOW)',
            'desc': 'Detects the exact microsecond when a human interacts with the physical button to fire actions!',
            'color': const Color(0xFF7E22CE),
            'cardBg': const Color(0xFFF3E8FF),
          },
        ];
      }
    }

    if (dayNum == 6) {
      // Day 6: Buzzers + If-Else
      if (tabIdx == 1) {
        return [
          {
            'label': 'Guard Dog',
            'symbol': '🐕',
            'icon': LucideIcons.alertTriangle,
            'badge': 'if / else',
            'title': 'Vigilant Guard Dog Analogy',
            'desc': 'IF an intruder trips the boundary sensor, bark loudly (tone(8, 1200)); ELSE remain quietly on guard (noTone(8))!',
            'color': const Color(0xFF0284C7),
            'cardBg': const Color(0xFFE0F2FE),
          },
          {
            'label': 'Drumhead',
            'symbol': '🥁',
            'icon': LucideIcons.music,
            'badge': 'Piezo Crystal',
            'title': 'Vibrating Ceramic Drumhead',
            'desc': 'A piezo disc expands and flexes hundreds of times per second when energized, pumping acoustic waves through the air.',
            'color': const Color(0xFFD97706),
            'cardBg': const Color(0xFFFEF3C7),
          },
          {
            'label': 'Pitch Dial',
            'symbol': '🎵',
            'icon': LucideIcons.volume2,
            'badge': 'Hertz (Hz)',
            'title': 'Musical Frequency Pitch',
            'desc': '440 Hz produces musical note A4; 1400 Hz produces a piercing emergency siren that demands immediate attention.',
            'color': const Color(0xFF16A34A),
            'cardBg': const Color(0xFFDCFCE7),
          },
          {
            'label': 'Dual Branch',
            'symbol': '🔀',
            'icon': LucideIcons.gitBranch,
            'badge': 'True / False',
            'title': 'Two-Way Decision Switch',
            'desc': 'If-else statements guarantee your microcontroller always knows what to do in both true and false conditions.',
            'color': const Color(0xFF7E22CE),
            'cardBg': const Color(0xFFF3E8FF),
          },
        ];
      }
    }

    // 1. LIKE: Non-technical everyday memory analogies (Default / Days 1, 2, 3, 4, 7, 9, 10)
    if (tabIdx == 1) {
      return [
        {
          'label': 'Water Pump',
          'symbol': '💧',
          'icon': LucideIcons.droplets,
          'badge': 'Pump = 5V Battery',
          'title': 'High-Pressure Water Tank (Battery)',
          'desc': 'Just like a water pump pushes water through a pipe, the 5V battery pushes electrons around the loop!',
          'color': const Color(0xFF0284C7),
          'cardBg': const Color(0xFFE0F2FE),
        },
        {
          'label': 'Pinch Valve',
          'symbol': '🚧',
          'icon': LucideIcons.gauge,
          'badge': 'Valve = ${_resistorOhms.toInt()} Ω',
          'title': 'Narrow Speed-Valve (Resistor)',
          'desc': 'Pinching a garden hose slows down rushing water so it doesn\'t break the delicate waterwheel!',
          'color': const Color(0xFFD97706),
          'cardBg': const Color(0xFFFEF3C7),
        },
        {
          'label': 'Turnstile',
          'symbol': '🎡',
          'icon': LucideIcons.compass,
          'badge': 'Wheel = LED',
          'title': 'One-Way Glowing Waterwheel (LED)',
          'desc': 'Spins and lights up only when water flows forward (+ to −), and blocks backward flow!',
          'color': const Color(0xFF0D9488),
          'cardBg': const Color(0xFFCCFBF1),
        },
        {
          'label': 'Return Pipe',
          'symbol': '🔄',
          'icon': LucideIcons.repeat,
          'badge': 'Drain = GND',
          'title': 'Return Pipe Back to Tank (Ground)',
          'desc': 'Water must return to the tank to keep circulating — just like current returning to GND (0V)!',
          'color': const Color(0xFF16A34A),
          'cardBg': const Color(0xFFDCFCE7),
        },
      ];
    }

    // 2. WHY: Cause & Effect (Burnout vs Protection)
    if (tabIdx == 2) {
      return [
        {
          'label': 'No Resistor',
          'symbol': '💥',
          'icon': LucideIcons.flame,
          'badge': '85.0 mA DANGER',
          'title': 'Without Resistor: Instant Burnout!',
          'desc': 'Connecting 5V directly to a 2V LED forces 85 mA through the tiny crystal and overheats it.',
          'color': const Color(0xFFDC2626),
          'cardBg': const Color(0xFFFEE2E2),
        },
        {
          'label': 'With 330 Ω',
          'symbol': '🛡️',
          'icon': LucideIcons.shieldCheck,
          'badge': '${currentMa.toStringAsFixed(1)} mA SAFE',
          'title': 'With ${_resistorOhms.toInt()} Ω Resistor: Protected Glow',
          'desc': 'The resistor absorbs 3V of excess push and limits current to a cool, safe ${currentMa.toStringAsFixed(1)} mA.',
          'color': const Color(0xFF16A34A),
          'cardBg': const Color(0xFFDCFCE7),
        },
        {
          'label': 'Ohm\'s Law',
          'symbol': '⚖️',
          'icon': LucideIcons.scale,
          'badge': 'I = (5V−2V)÷R',
          'title': 'More Resistance = Less Current',
          'desc': 'Slide the resistor from 100 Ω to 1000 Ω on the left to watch the safe side dim smoothly.',
          'color': const Color(0xFF0284C7),
          'cardBg': const Color(0xFFE0F2FE),
        },
        {
          'label': 'Long Life',
          'symbol': '🔋',
          'icon': LucideIcons.batteryCharging,
          'badge': '50,000 Hours',
          'title': 'Saves Battery & Component Life',
          'desc': 'Limiting current prevents wasted heat and lets an LED shine for over 50,000 hours!',
          'color': const Color(0xFFEA580C),
          'cardBg': const Color(0xFFFFEDD5),
        },
      ];
    }

    // 3. WHERE: Real-World Everyday Places
    if (tabIdx == 3) {
      return [
        {
          'label': 'Traffic Light',
          'symbol': '🚦',
          'icon': LucideIcons.alertCircle,
          'badge': 'Street Signals',
          'title': 'Road Traffic Signal Lights',
          'desc': 'Hundreds of bright Red, Amber, and Green LEDs wired with resistors warn drivers day and night.',
          'color': const Color(0xFF16A34A),
          'cardBg': const Color(0xFFDCFCE7),
        },
        {
          'label': 'TV Remote',
          'symbol': '📺',
          'icon': LucideIcons.tv,
          'badge': 'Infrared LED',
          'title': 'TV Remote Control Transmitter',
          'desc': 'An Infrared (IR) LED at the tip of your remote flashes invisible light pulses to change channels!',
          'color': const Color(0xFF0284C7),
          'cardBg': const Color(0xFFE0F2FE),
        },
        {
          'label': 'Phone Torch',
          'symbol': '📱',
          'icon': LucideIcons.smartphone,
          'badge': 'Camera Flash',
          'title': 'Smartphone Flashlight & Screen',
          'desc': 'Your phone\'s camera flash uses a high-efficiency white LED driven by a current-limiting circuit.',
          'color': const Color(0xFFD97706),
          'cardBg': const Color(0xFFFEF3C7),
        },
        {
          'label': 'Robot Car',
          'symbol': '🤖',
          'icon': LucideIcons.bot,
          'badge': 'Pin 13 Status',
          'title': 'Arduino Robot Headlights & Status',
          'desc': 'Robots use onboard LEDs to show battery power, obstacle detection alerts, and code status.',
          'color': const Color(0xFF7E22CE),
          'cardBg': const Color(0xFFF3E8FF),
        },
      ];
    }

    // 4. WHEN: Real-Time When to Use It & Trigger Rules
    if (tabIdx == 4) {
      return [
        {
          'label': 'Pin HIGH',
          'symbol': '🟢',
          'icon': LucideIcons.zap,
          'badge': 'digitalWrite HIGH',
          'title': 'When Arduino Pin Outputs 5V (HIGH)',
          'desc': 'Use an LED + 330 Ω resistor whenever your code sets a digital pin HIGH to signal an event.',
          'color': const Color(0xFF16A34A),
          'cardBg': const Color(0xFFDCFCE7),
        },
        {
          'label': 'Sensor Alert',
          'symbol': '📡',
          'icon': LucideIcons.radio,
          'badge': 'Distance < 20cm',
          'title': 'When a Sensor Detects an Obstacle',
          'desc': 'Turn the warning LED ON inside an if-statement when the ultrasonic sensor reads < 20 cm.',
          'color': const Color(0xFFEA580C),
          'cardBg': const Color(0xFFFFEDD5),
        },
        {
          'label': '5V vs 2V',
          'symbol': '⚡',
          'icon': LucideIcons.shieldAlert,
          'badge': 'V_supply > V_led',
          'title': 'Whenever Supply Voltage Exceeds 2V',
          'desc': 'Any time your power source (3.3V, 5V, or 9V) is higher than the LED\'s 2V rating, add a resistor!',
          'color': const Color(0xFF0284C7),
          'cardBg': const Color(0xFFE0F2FE),
        },
        {
          'label': 'Debug Check',
          'symbol': '🔍',
          'icon': LucideIcons.checkCircle2,
          'badge': 'Visual Debug',
          'title': 'When Testing If Your Loop Is Running',
          'desc': 'Blinking an LED is the fastest way to verify that your microcontroller code is alive and looping.',
          'color': const Color(0xFF7E22CE),
          'cardBg': const Color(0xFFF3E8FF),
        },
      ];
    }

    // 0. Default WHAT: Technical Component Anatomy
    return [
      {
        'label': 'Long leg +',
        'symbol': '+',
        'icon': Icons.lightbulb_rounded,
        'badge': '+',
        'title': 'Anode (+) — Long Leg',
        'desc': 'Connects to the positive (+) 5V or Arduino digital output pin through a resistor.',
        'color': const Color(0xFFDC2626),
        'cardBg': const Color(0xFFEBF5DF),
      },
      {
        'label': 'Short leg −',
        'symbol': '−',
        'icon': Icons.lightbulb_rounded,
        'badge': '−',
        'title': 'Cathode (−) — Short Leg',
        'desc': 'Connects to the flat edge of the LED and returns current to Ground (GND 0V).',
        'color': const Color(0xFF1E293B),
        'cardBg': const Color(0xFFEBF5DF),
      },
      {
        'label': 'Resistor',
        'symbol': '—',
        'icon': Icons.lightbulb_rounded,
        'badge': '${_resistorOhms.toInt()} Ω',
        'title': '${_resistorOhms.toInt()} Ω Current-Limiting Resistor',
        'desc': 'Slows down electron flow to ${currentMa.toStringAsFixed(1)} mA so the LED never overheats.',
        'color': const Color(0xFFD97706),
        'cardBg': const Color(0xFFEBF5DF),
      },
      {
        'label': 'Series /\nParallel',
        'symbol': '⑃',
        'icon': Icons.lightbulb_rounded,
        'badge': '⑃',
        'title': _circuitTopology == 0
            ? 'Single LED Loop'
            : (_circuitTopology == 1 ? '2 LEDs in Series' : '2 LEDs in Parallel'),
        'desc': _circuitTopology == 1
            ? 'In series, both LEDs share the same current path and split the 5V supply.'
            : (_circuitTopology == 2
                ? 'In parallel, each LED gets its own branch across the voltage supply.'
                : 'A single closed loop where every electron passes through the resistor and LED.'),
        'color': const Color(0xFF0284C7),
        'cardBg': const Color(0xFFEBF5DF),
      },
    ];
  }

  Widget _buildTopologyPill(int idx, String label) {
    final isSelected = _circuitTopology == idx;
    return InkWell(
      onTap: () => setState(() => _circuitTopology = idx),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEA580C) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF334155),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MODE 1: PREDICT
  // ===========================================================================
  Widget _buildDayPredictMode(double currentMa) {
    final options = [
      'Current drops and the LED glows dimmer',
      'The LED explodes from high voltage',
      'Nothing changes in the circuit',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔮 Predict What Happens!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Right now with ${_resistorOhms.toInt()} Ω, the current is ${currentMa.toStringAsFixed(1)} mA. What will happen if you slide the resistor up to 1000 Ω?',
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 16),
          ...List.generate(options.length, (i) {
            final isPicked = _predictChoice == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _predictChoice = i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isPicked
                        ? (i == 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2))
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPicked
                          ? (i == 0 ? const Color(0xFF16A34A) : Colors.red)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPicked
                            ? (i == 0 ? LucideIcons.checkCircle2 : LucideIcons.xCircle)
                            : LucideIcons.circle,
                        color: isPicked
                            ? (i == 0 ? const Color(0xFF16A34A) : Colors.red)
                            : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          options[i],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODE 2: TRY IT — HANDS-ON PRACTICAL BUILD TO COMPLETE!
  // ===========================================================================
  Widget _buildDayTryItPracticalMode(bool isNarrow, int dayNum) {
    final completedSteps = (_pracStep1Power ? 1 : 0) +
        (_pracStep2Resistor ? 1 : 0) +
        (_pracStep3Led ? 1 : 0) +
        (_pracStep4Tested ? 1 : 0);
    final allPracticalDone = completedSteps == 4;

    final leftBreadboardCanvas = Column(
      children: [
        Container(
          height: 290,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF3EFE6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: allPracticalDone ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              width: 2,
            ),
          ),
          child: AnimatedBuilder(
            animation: _electronController,
            builder: (context, _) => CustomPaint(
              painter: _PracticalBuildBreadboardPainter(
                step1Power: _pracStep1Power,
                step2Resistor: _pracStep2Resistor,
                step3Led: _pracStep3Led,
                step4Tested: _pracStep4Tested,
                progress: _electronController.value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // AI Tutor Helper Banner for the Practical
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Tutor Practical Guide',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF1E40AF)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _pracTutorMsg,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _speakText(_pracTutorMsg),
                icon: const Icon(LucideIcons.volume2, size: 15),
                label: const Text('Speak', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );

    final rightChecklistColumn = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🔧 Practical Tasks to Complete',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allPracticalDone ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedSteps / 4 Done',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: allPracticalDone ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildPracticalStepTile(
            stepNum: 1,
            title: 'Connect 5V & GND Rails to Breadboard',
            subtitle: 'Wire red +5V lead to top + rail and black GND lead to top − rail.',
            done: _pracStep1Power,
            onTap: () {
              setState(() {
                _pracStep1Power = true;
                _pracTutorMsg =
                    '✅ Step 1 Done! 5V and GND rails are powered. Next, tap Step 2 to insert the 330 Ω current-limiting resistor!';
              });
            },
          ),
          _buildPracticalStepTile(
            stepNum: 2,
            title: 'Insert 330 Ω Protection Resistor',
            subtitle: 'Bridge from positive rail column 3 to column 7 with a 330 Ω resistor.',
            done: _pracStep2Resistor,
            onTap: () {
              setState(() {
                _pracStep1Power = true;
                _pracStep2Resistor = true;
                _pracTutorMsg =
                    '✅ Step 2 Done! The 330 Ω resistor is in place. Now tap Step 3 to plug in the LED Anode (+) and Cathode (−) legs!';
              });
            },
          ),
          _buildPracticalStepTile(
            stepNum: 3,
            title: 'Wire LED Long Leg (+) & Short Leg (−)',
            subtitle: 'Plug Anode (+) into column 7 with the resistor and Cathode (−) to GND.',
            done: _pracStep3Led,
            onTap: () {
              setState(() {
                _pracStep1Power = true;
                _pracStep2Resistor = true;
                _pracStep3Led = true;
                _pracTutorMsg =
                    '✅ Step 3 Done! The circuit loop is complete. Now tap Step 4 to power ON and test your practical build!';
              });
            },
          ),
          _buildPracticalStepTile(
            stepNum: 4,
            title: 'Run Practical Test (Verify 9.1 mA Glow)',
            subtitle: 'Close switch SW1 and verify the LED lights up safely at 9.1 mA.',
            done: _pracStep4Tested,
            onTap: () {
              setState(() {
                _pracStep1Power = true;
                _pracStep2Resistor = true;
                _pracStep3Led = true;
                _pracStep4Tested = true;
                _pracTutorMsg =
                    '🎉 Practical Completed! Your breadboard circuit is running at a safe 9.1 mA and the LED is glowing brightly. Ready for Bug Hunt!';
              });
            },
          ),
        ],
      ),
    );

    if (isNarrow) {
      return Column(
        children: [
          leftBreadboardCanvas,
          const SizedBox(height: 16),
          rightChecklistColumn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: leftBreadboardCanvas),
        const SizedBox(width: 24),
        Expanded(flex: 5, child: rightChecklistColumn),
      ],
    );
  }

  Widget _buildPracticalStepTile({
    required int stepNum,
    required String title,
    required String subtitle,
    required bool done,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: done ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
              width: done ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: done ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                child: done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : Text(
                        '$stepNum',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: done ? const Color(0xFF166534) : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: done ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  done ? 'Done' : 'Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MODE 3: BUG HUNT — IDENTIFY & FIX CIRCUIT / BREADBOARD BUGS WITH AI TUTOR!
  // ===========================================================================
  Widget _buildDayBugHuntMode(bool isNarrow) {
    final fixedCount = (_bug1ResistorFixed ? 1 : 0) +
        (_bug2PolarityFixed ? 1 : 0) +
        (_bug3GroundFixed ? 1 : 0);
    final allBugsFixed = fixedCount == 3;

    final leftFaultyBreadboard = Column(
      children: [
        Container(
          height: 290,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF3EFE6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: allBugsFixed ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _electronController,
                  builder: (context, _) => CustomPaint(
                    painter: _BugHuntBreadboardPainter(
                      bug1ResistorFixed: _bug1ResistorFixed,
                      bug2PolarityFixed: _bug2PolarityFixed,
                      bug3GroundFixed: _bug3GroundFixed,
                      progress: _electronController.value,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: allBugsFixed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    allBugsFixed
                        ? '✅ ALL 3 BREADBOARD BUGS FIXED (9.1 mA SAFE GLOW)'
                        : '🐞 ${3 - fixedCount} HARDWARE BUG(S) ACTIVE ON BREADBOARD',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // AI Tutor Bug Detective Panel
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF93C5FD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                    child: const Text('🤖', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Tutor Bug Detective: $_bugTutorPraise',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _bugTutorHint,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _bugTutorInputController,
                        onSubmitted: (_) => _askBugHuntAiTutor(),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Ask AI Tutor to help find a bug on this breadboard...',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFF93C5FD)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isAskingBugTutor ? null : () => _askBugHuntAiTutor(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(LucideIcons.sparkles, size: 14),
                    label: Text(
                      _isAskingBugTutor ? 'Scanning...' : 'Ask AI Tutor Hint',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final rightBugsList = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🐞 Circuit & Breadboard Bugs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF9A3412)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allBugsFixed ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$fixedCount / 3 Fixed',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: allBugsFixed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Inspect the breadboard on the left and tap each identified hardware bug below to repair the circuit:',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF7C2D12)),
          ),
          const SizedBox(height: 12),

          _buildBugFixCard(
            bugNumber: 1,
            title: 'Bug #1: Missing 330 Ω Resistor (Direct 5V Short)',
            symptom: 'Red jumper bypasses resistance — 85 mA overcurrent will burn LED1!',
            fixed: _bug1ResistorFixed,
            onFix: () {
              setState(() {
                _bug1ResistorFixed = true;
                _bugTutorPraise = 'Nice save! You inserted the 330 Ω resistor in series.';
                _bugTutorHint = _getNextLocalBugHint();
              });
            },
          ),
          _buildBugFixCard(
            bugNumber: 2,
            title: 'Bug #2: Reversed LED Polarity (Cathode K at +)',
            symptom: 'Short leg (−) is wired to resistor and Long leg (+) is wired toward GND.',
            fixed: _bug2PolarityFixed,
            onFix: () {
              setState(() {
                _bug2PolarityFixed = true;
                _bugTutorPraise = 'Spot on! You flipped the LED so Anode (+) faces the resistor.';
                _bugTutorHint = _getNextLocalBugHint();
              });
            },
          ),
          _buildBugFixCard(
            bugNumber: 3,
            title: 'Bug #3: Disconnected GND Return Jumper Wire',
            symptom: 'Black jumper wire lands in an isolated row instead of the top − GND rail.',
            fixed: _bug3GroundFixed,
            onFix: () {
              setState(() {
                _bug3GroundFixed = true;
                _bugTutorPraise = 'Awesome debugging! The ground return loop is now closed.';
                _bugTutorHint = _getNextLocalBugHint();
              });
            },
          ),
        ],
      ),
    );

    if (isNarrow) {
      return Column(
        children: [
          leftFaultyBreadboard,
          const SizedBox(height: 16),
          rightBugsList,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: leftFaultyBreadboard),
        const SizedBox(width: 24),
        Expanded(flex: 5, child: rightBugsList),
      ],
    );
  }

  Widget _buildBugFixCard({
    required int bugNumber,
    required String title,
    required String symptom,
    required bool fixed,
    required VoidCallback onFix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onFix,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fixed ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: fixed ? const Color(0xFF16A34A) : const Color(0xFFFCA5A5),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                fixed ? LucideIcons.checkCircle2 : LucideIcons.bug,
                color: fixed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: fixed ? const Color(0xFF166534) : const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      symptom,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: fixed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fixed ? 'Fixed ✓' : 'Fix Bug #$bugNumber',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MODE 4: QUIZ
  // ===========================================================================
  Widget _buildDayQuizMode(int dayNum) {
    final questions = [
      {
        'q': '1. Which leg of an LED must connect toward the positive (+) supply?',
        'opts': ['The longer leg (Anode +)', 'The shorter leg (Cathode −)', 'Either leg works the same'],
        'ans': 0,
      },
      {
        'q': '2. Using I = (5 V − LED drop) ÷ R, what happens when resistance R increases?',
        'opts': ['Current I decreases and protects the LED', 'Current I becomes infinite', 'Voltage turns negative'],
        'ans': 0,
      },
      {
        'q': '3. Why do we place a 330 Ω resistor in series with an LED?',
        'opts': ['To limit current so the LED does not burn out', 'To make the battery larger', 'To block all electricity'],
        'ans': 0,
      },
    ];

    int correctCount = 0;
    _quizAnswers.forEach((k, v) {
      if (v == 0) correctCount++;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📝 Day Mastery Quiz (3 Questions)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Chip(
                label: Text('Score: $correctCount / 3'),
                backgroundColor: const Color(0xFFE0F2FE),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(questions.length, (qIdx) {
            final q = questions[qIdx];
            final opts = q['opts'] as List<String>;
            final picked = _quizAnswers[qIdx];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q['q'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(opts.length, (oIdx) {
                      final isSelected = picked == oIdx;
                      return ChoiceChip(
                        label: Text(opts[oIdx]),
                        selected: isSelected,
                        selectedColor: oIdx == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        onSelected: (_) => setState(() => _quizAnswers[qIdx] = oIdx),
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _completeDay(
              dayNum,
              _quizAnswers.isEmpty ? 3 : correctCount,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(LucideIcons.award, size: 18),
            label: Text('Submit Quiz & Unlock Day ${dayNum + 1}'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CUSTOM PAINTER 1: S-CURVE DASHED CONNECTOR BETWEEN SNAKE NODES
// =============================================================================
class _SnakeDashedConnectorPainter extends CustomPainter {
  final double startXOffset;
  final double endXOffset;
  final Color color;

  _SnakeDashedConnectorPainter({
    required this.startXOffset,
    required this.endXOffset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final startX = centerX + (startXOffset * 0.45);
    final endX = centerX + (endXOffset * 0.45);

    final path = Path()
      ..moveTo(startX, 2)
      ..cubicTo(
        startX,
        size.height * 0.55,
        endX,
        size.height * 0.45,
        endX,
        size.height - 2,
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashLength = 9.0;
      const gapLength = 7.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnakeDashedConnectorPainter oldDelegate) => true;
}

// =============================================================================
// CUSTOM PAINTER 2: "WHAT" TAB — TECHNICAL CIRCUIT & COMPONENT SCHEMATIC
// =============================================================================
class _InteractiveCircuitSchematicPainter extends CustomPainter {
  final double progress;
  final int resistorOhms;
  final double currentMa;
  final int topology;
  final int dayNum;

  _InteractiveCircuitSchematicPainter({
    required this.progress,
    required this.resistorOhms,
    required this.currentMa,
    required this.topology,
    this.dayNum = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFFCBD5E1).withOpacity(0.55);
    for (double x = 16; x < size.width; x += 20) {
      for (double y = 16; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
      }
    }

    if (dayNum == 8) {
      // Day 8: Ultrasonic Distance Sensor (HC-SR04) Schematic
      _drawUltrasonicSensorSchematic(canvas, size);
      return;
    }

    if (dayNum == 5) {
      // Day 5: Button + INPUT_PULLUP Schematic
      _drawButtonPullupSchematic(canvas, size);
      return;
    }

    if (dayNum == 6) {
      // Day 6: Piezo Buzzer + D8 Schematic
      _drawBuzzerSchematic(canvas, size);
      return;
    }

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
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(left, batCenterY - 33), width: 14, height: 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF64748B),
    );

    _drawText(canvas, '5V', Offset(left - 34, batCenterY - 8), const Color(0xFF0F172A), 13, FontWeight.w800);
    _drawText(canvas, '1.5V', Offset(left - 12, batCenterY + 2), Colors.white, 10, FontWeight.w700);
    _drawText(canvas, '+', Offset(left + 22, batCenterY - 24), const Color(0xFFDC2626), 16, FontWeight.w900);
    _drawText(canvas, '−', Offset(left + 22, batCenterY + 10), const Color(0xFF0F172A), 16, FontWeight.w900);

    final resCenterX = left + (right - left) * 0.27;
    final resRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(resCenterX, top), width: 54, height: 18),
      const Radius.circular(9),
    );
    canvas.drawRRect(resRect, Paint()..color = const Color(0xFFFDE68A));
    canvas.drawRRect(
      resRect,
      Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (int i = -1; i <= 1; i++) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(resCenterX + (i * 11), top), width: 4, height: 16),
        Paint()..color = i == 0 ? const Color(0xFF78350F) : const Color(0xFFEA580C),
      );
    }
    _drawText(canvas, '$resistorOhms Ω', Offset(resCenterX - 20, top - 32), const Color(0xFF0F172A), 13, FontWeight.w800);

    final glowIntensity = (currentMa / 20.0).clamp(0.25, 1.0);
    final led1X = left + (right - left) * 0.64;
    _drawGlowingLed(canvas, Offset(led1X, top), glowIntensity);

    if (topology == 1) {
      _drawGlowingLed(canvas, Offset(led1X + 54, top), glowIntensity * 0.85);
    } else if (topology == 2) {
      _drawGlowingLed(canvas, Offset(led1X, top + 46), glowIntensity);
    }

    final electronPaint = Paint()..color = const Color(0xFFF59E0B);
    final perimeter = 2 * ((right - left) + (bottom - top));
    const numElectrons = 10;
    for (int i = 0; i < numElectrons; i++) {
      final frac = ((i / numElectrons) + progress) % 1.0;
      final dist = frac * perimeter;
      Offset pos;
      final w = right - left;
      final h = bottom - top;
      if (dist <= w) {
        pos = Offset(left + dist, top);
      } else if (dist <= w + h) {
        pos = Offset(right, top + (dist - w));
      } else if (dist <= (2 * w) + h) {
        pos = Offset(right - (dist - (w + h)), bottom);
      } else {
        pos = Offset(left, bottom - (dist - (2 * w + h)));
      }
      canvas.drawCircle(pos, 4.5, electronPaint);
    }

    final centerX = (left + right) / 2;
    final centerY = (top + bottom) / 2 + 6;
    _drawText(
      canvas,
      '${currentMa.toStringAsFixed(1)} mA',
      Offset(centerX - 38, centerY - 14),
      const Color(0xFF0284C7),
      23,
      FontWeight.w900,
    );
    _drawText(
      canvas,
      'I = (5 V − LED drop) ÷ R',
      Offset(centerX - 72, centerY + 18),
      const Color(0xFF475569),
      13,
      FontWeight.w700,
    );
  }

  void _drawUltrasonicSensorSchematic(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.50;

    // Sensor PCB body
    final pcbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - 70, cy), width: 140, height: 74),
      const Radius.circular(10),
    );
    canvas.drawRRect(pcbRect, Paint()..color = const Color(0xFF1E3A8A));
    canvas.drawRRect(
      pcbRect,
      Paint()
        ..color = const Color(0xFF60A5FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Two transducer cylinders (T and R)
    canvas.drawCircle(Offset(cx - 105, cy), 18, Paint()..color = const Color(0xFF94A3B8));
    canvas.drawCircle(Offset(cx - 35, cy), 18, Paint()..color = const Color(0xFF94A3B8));
    _drawText(canvas, 'TRIG', Offset(cx - 117, cy - 6), const Color(0xFF0F172A), 9.5, FontWeight.w900);
    _drawText(canvas, 'ECHO', Offset(cx - 48, cy - 6), const Color(0xFF0F172A), 9.5, FontWeight.w900);

    // Sound waves emitting and reflecting
    final wavePaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 1; i <= 4; i++) {
      final r = i * 20.0 * ((progress + i * 0.2) % 1.0);
      canvas.drawArc(Rect.fromCircle(center: Offset(cx - 35, cy), radius: r), -0.5, 1.0, false, wavePaint);
    }

    // Target object / obstacle on the right
    final targetRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + 105, cy), width: 28, height: 90),
      const Radius.circular(6),
    );
    canvas.drawRRect(targetRect, Paint()..color = const Color(0xFFDC2626));
    _drawText(canvas, 'OBSTACLE', Offset(cx + 82, cy - 56), const Color(0xFFDC2626), 11, FontWeight.w800);

    _drawText(
      canvas,
      'Distance = (Echo Time in µs × 0.034) ÷ 2 = 14 cm',
      Offset(cx - 150, size.height - 28),
      const Color(0xFF0284C7),
      12.5,
      FontWeight.w900,
    );
  }

  void _drawButtonPullupSchematic(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.50;

    // Arduino Pin D2 + Internal Pullup
    canvas.drawRect(Rect.fromLTWH(cx - 140, cy - 50, 80, 100), Paint()..color = const Color(0xFF0284C7));
    _drawText(canvas, 'ARDUINO\nPin D2\n(PULLUP)', Offset(cx - 134, cy - 25), Colors.white, 10.5, FontWeight.bold);

    // Button terminals
    canvas.drawLine(Offset(cx - 60, cy), Offset(cx + 10, cy), Paint()..color = const Color(0xFF475569)..strokeWidth = 3);
    canvas.drawCircle(Offset(cx + 10, cy), 5, Paint()..color = const Color(0xFF0F172A));
    canvas.drawCircle(Offset(cx + 40, cy), 5, Paint()..color = const Color(0xFF0F172A));

    // Button contact lever
    final leverClosed = (progress * 2).floor() % 2 == 1;
    if (leverClosed) {
      canvas.drawLine(Offset(cx + 10, cy), Offset(cx + 40, cy), Paint()..color = const Color(0xFF16A34A)..strokeWidth = 4);
      _drawText(canvas, 'PRESSED = LOW (0V)', Offset(cx - 20, cy - 35), const Color(0xFF16A34A), 12, FontWeight.w900);
    } else {
      canvas.drawLine(Offset(cx + 10, cy), Offset(cx + 36, cy - 14), Paint()..color = const Color(0xFFDC2626)..strokeWidth = 4);
      _drawText(canvas, 'RELEASED = HIGH (5V)', Offset(cx - 28, cy - 35), const Color(0xFFDC2626), 12, FontWeight.w900);
    }

    // GND wire
    canvas.drawLine(Offset(cx + 40, cy), Offset(cx + 90, cy), Paint()..color = const Color(0xFF0F172A)..strokeWidth = 3);
    _drawText(canvas, 'GND (0V)', Offset(cx + 96, cy - 8), const Color(0xFF0F172A), 12, FontWeight.w800);
  }

  void _drawBuzzerSchematic(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.50;

    // Buzzer body
    canvas.drawCircle(Offset(cx, cy), 42, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(
      Offset(cx, cy),
      42,
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(Offset(cx, cy), 14, Paint()..color = const Color(0xFF64748B));
    _drawText(canvas, 'BUZZER\n(D8)', Offset(cx - 22, cy - 14), Colors.white, 10.5, FontWeight.w800);

    // Sound waves
    final wavePaint = Paint()
      ..color = const Color(0xFFF59E0B).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (int i = 1; i <= 3; i++) {
      final r = 42.0 + (i * 18.0 * ((progress + i * 0.3) % 1.0));
      canvas.drawCircle(Offset(cx, cy), r, wavePaint);
    }
    _drawText(canvas, 'tone(8, 880) ➔ 880 Hz Audible Chime', Offset(cx - 110, size.height - 28), const Color(0xFFB45309), 12.5, FontWeight.w900);
  }

  void _drawGlowingLed(Canvas canvas, Offset center, double intensity) {
    canvas.drawCircle(
      center,
      36 * intensity,
      Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.28 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    final domeRect = RRect.fromRectAndCorners(
      Rect.fromCenter(center: center, width: 32, height: 24),
      topLeft: const Radius.circular(4),
      bottomLeft: const Radius.circular(4),
      topRight: const Radius.circular(14),
      bottomRight: const Radius.circular(14),
    );
    canvas.drawRRect(domeRect, Paint()..color = const Color(0xFFEF4444));
    canvas.drawRRect(
      domeRect,
      Paint()
        ..color = const Color(0xFFB91C1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final rayPaint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.75)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (int a = 0; a < 8; a++) {
      final angle = a * (math.pi / 4);
      final p1 = Offset(center.dx + math.cos(angle) * 20, center.dy + math.sin(angle) * 20);
      final p2 = Offset(center.dx + math.cos(angle) * 27, center.dy + math.sin(angle) * 27);
      canvas.drawLine(p1, p2, rayPaint);
    }
    _drawText(canvas, '+', Offset(center.dx - 28, center.dy - 18), const Color(0xFFDC2626), 13, FontWeight.w900);
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, double fontSize, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _InteractiveCircuitSchematicPainter oldDelegate) => true;
}

// =============================================================================
// CUSTOM PAINTER 3: "LIKE" TAB — REAL-TIME NON-TECHNICAL MEMORY ANALOGY!
// =============================================================================
class _LikeWaterWheelAnalogyPainter extends CustomPainter {
  final double progress;
  final int resistorOhms;
  final int selectedPart;
  final int dayNum;

  _LikeWaterWheelAnalogyPainter({
    required this.progress,
    required this.resistorOhms,
    required this.selectedPart,
    this.dayNum = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dayNum == 8) {
      // Day 8: Ultrasonic Sensor Analogy — Bat Echolocation in Cave
      _drawBatSonarAnalogy(canvas, size);
      return;
    }

    if (dayNum == 5) {
      // Day 5: Button Analogy — Drawbridge traffic flow
      _drawDrawbridgeAnalogy(canvas, size);
      return;
    }

    if (dayNum == 6) {
      // Day 6: Buzzer + If/Else Analogy — Guard dog barking on detection
      _drawGuardDogAnalogy(canvas, size);
      return;
    }

    // Default / Days 1, 2, 3: Water Tank + Pinch Valve + Waterwheel Analogy
    // Soft sky/water tint background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFFF0F9FF),
    );

    final left = size.width * 0.16;
    final right = size.width * 0.84;
    final top = size.height * 0.28;
    final bottom = size.height * 0.78;

    // Draw Water Pipe Loop
    final pipePaint = Paint()
      ..color = const Color(0xFFBAE6FD)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), pipePaint);

    // Animated Blue Water Droplets flowing inside the pipe
    final dropletPaint = Paint()..color = const Color(0xFF0284C7);
    final w = right - left;
    final h = bottom - top;
    final perim = 2 * (w + h);
    for (int i = 0; i < 12; i++) {
      final f = ((i / 12) + progress) % 1.0;
      final d = f * perim;
      Offset p;
      if (d <= w) {
        p = Offset(left + d, top);
      } else if (d <= w + h) {
        p = Offset(right, top + (d - w));
      } else if (d <= 2 * w + h) {
        p = Offset(right - (d - (w + h)), bottom);
      } else {
        p = Offset(left, bottom - (d - (2 * w + h)));
      }
      canvas.drawCircle(p, 4.5, dropletPaint);
    }

    // 1. Water Pump / Tank on Left (Battery Analogy)
    final midY = (top + bottom) / 2;
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(left, midY), width: 52, height: 78),
      const Radius.circular(10),
    );
    canvas.drawRRect(tankRect, Paint()..color = const Color(0xFF0284C7));
    _drawText(canvas, '💧 PUMP\n(5V Push)', Offset(left - 22, midY - 14), Colors.white, 10.5, FontWeight.w800);

    // 2. Pinch Valve / Narrow Speed-Bump on Top-Left (Resistor Analogy)
    final valveX = left + (right - left) * 0.34;
    final pinchAmount = ((resistorOhms - 100) / 900.0) * 6.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(valveX, top - 12 - pinchAmount), width: 42, height: 10),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFD97706),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(valveX, top + 12 + pinchAmount), width: 42, height: 10),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFD97706),
    );
    _drawText(
      canvas,
      '🚧 Speed Valve ($resistorOhms Ω)',
      Offset(valveX - 54, top - 36),
      const Color(0xFFB45309),
      12,
      FontWeight.w800,
    );

    // 3. Spinning Glowing Waterwheel / Turnstile on Top-Right (LED Analogy)
    final wheelX = left + (right - left) * 0.72;
    final wheelCenter = Offset(wheelX, top);
    canvas.drawCircle(
      wheelCenter,
      26,
      Paint()..color = const Color(0xFFFEF08A),
    );
    canvas.drawCircle(
      wheelCenter,
      26,
      Paint()
        ..color = const Color(0xFF0D9488)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (int s = 0; s < 6; s++) {
      final angle = progress * math.pi * 2 + (s * math.pi / 3);
      canvas.drawLine(
        wheelCenter,
        Offset(wheelCenter.dx + math.cos(angle) * 24, wheelCenter.dy + math.sin(angle) * 24),
        Paint()
          ..color = const Color(0xFF0D9488)
          ..strokeWidth = 2.5,
      );
    }
    _drawText(
      canvas,
      '🎡 One-Way Wheel (LED)',
      Offset(wheelX - 58, top - 44),
      const Color(0xFF0F766E),
      12,
      FontWeight.w800,
    );

    // Center Memory Caption
    _drawText(
      canvas,
      'Real-Life Memory Analogy:\nPump = Battery  •  Narrow Valve = Resistor  •  Spinning Wheel = LED',
      Offset(size.width * 0.22, midY - 10),
      const Color(0xFF0369A1),
      12.5,
      FontWeight.w800,
    );
  }

  void _drawBatSonarAnalogy(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFF0F172A),
    );
    final cx = size.width / 2;
    final cy = size.height * 0.50;

    // Flying bat on left
    _drawText(canvas, '🦇', Offset(cx - 120, cy - 24), Colors.white, 38, FontWeight.normal);
    _drawText(canvas, 'Bat = HC-SR04\nPings 40 kHz Sound', Offset(cx - 145, cy + 26), const Color(0xFF38BDF8), 11, FontWeight.w800);

    // Ultrasonic chirp arcs
    final wavePaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (int i = 1; i <= 3; i++) {
      final r = i * 22.0 * ((progress + i * 0.3) % 1.0);
      canvas.drawArc(Rect.fromCircle(center: Offset(cx - 80, cy), radius: r), -0.5, 1.0, false, wavePaint);
    }

    // Cave wall obstacle on right
    final wall = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 100, cy), width: 32, height: 110), const Radius.circular(8));
    canvas.drawRRect(wall, Paint()..color = const Color(0xFF475569));
    _drawText(canvas, 'CAVE WALL', Offset(cx + 74, cy - 65), const Color(0xFFE2E8F0), 10.5, FontWeight.w800);

    _drawText(
      canvas,
      'Real-Life Analogy: Bats navigate pitch-black caves by timing sound echoes,\njust like robots use HC-SR04 to stop before hitting walls!',
      Offset(cx - 190, size.height - 36),
      const Color(0xFF94A3B8),
      11.5,
      FontWeight.w700,
    );
  }

  void _drawDrawbridgeAnalogy(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFFF8FAFC),
    );
    final cx = size.width / 2;
    final cy = size.height * 0.50;

    final closed = (progress * 2).floor() % 2 == 1;
    _drawText(
      canvas,
      '🌉 Real-Life Analogy: Drawbridge = Button\nWhen raised (released) traffic stops (HIGH); when lowered (pressed) cars flow to GND (LOW)!',
      Offset(cx - 200, 20),
      const Color(0xFF0F172A),
      12.5,
      FontWeight.w800,
    );

    // Left road and right road
    canvas.drawRect(Rect.fromLTWH(cx - 150, cy + 10, 80, 20), Paint()..color = const Color(0xFF334155));
    canvas.drawRect(Rect.fromLTWH(cx + 70, cy + 10, 80, 20), Paint()..color = const Color(0xFF334155));

    // Water below
    canvas.drawRect(Rect.fromLTWH(cx - 70, cy + 30, 140, 40), Paint()..color = const Color(0xFF0284C7));

    // Moving bridge plank
    if (closed) {
      canvas.drawRect(Rect.fromLTWH(cx - 70, cy + 10, 140, 14), Paint()..color = const Color(0xFF16A34A));
      _drawText(canvas, 'BRIDGE CLOSED: CARS FLOW (LOW = 0V)', Offset(cx - 110, cy + 80), const Color(0xFF16A34A), 12, FontWeight.w900);
    } else {
      canvas.drawLine(Offset(cx - 70, cy + 10), Offset(cx + 10, cy - 40), Paint()..color = const Color(0xFFDC2626)..strokeWidth = 10);
      _drawText(canvas, 'BRIDGE OPEN: TRAFFIC HALTED (HIGH = 5V)', Offset(cx - 120, cy + 80), const Color(0xFFDC2626), 12, FontWeight.w900);
    }
  }

  void _drawGuardDogAnalogy(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFFFFFBEB),
    );
    final cx = size.width / 2;
    final cy = size.height * 0.50;

    final barking = (progress * 2).floor() % 2 == 1;
    _drawText(
      canvas,
      '🐕 Real-Life Analogy: Guard Dog = If-Else Buzzer\nIF intruder detected ➔ BARK loudly (tone()); ELSE ➔ Sleep quietly (noTone())!',
      Offset(cx - 190, 20),
      const Color(0xFF92400E),
      12.5,
      FontWeight.w800,
    );

    if (barking) {
      _drawText(canvas, '🐕', Offset(cx - 30, cy - 25), Colors.black, 48, FontWeight.normal);
      _drawText(canvas, 'BARK! BARK! (tone(8, 1200))', Offset(cx + 25, cy - 10), const Color(0xFFDC2626), 14, FontWeight.w900);
    } else {
      _drawText(canvas, '🐕💤', Offset(cx - 30, cy - 25), Colors.black, 48, FontWeight.normal);
      _drawText(canvas, 'Sleeping quietly (noTone(8))', Offset(cx + 35, cy - 10), const Color(0xFF15803D), 13, FontWeight.w800);
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight, height: 1.3)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _LikeWaterWheelAnalogyPainter oldDelegate) => true;
}

// =============================================================================
// CUSTOM PAINTER 4: "WHY" TAB — CAUSE & EFFECT (BURNED VS SAFE / ECHO DELAY)
// =============================================================================
class _WhyBurnVsSafePainter extends CustomPainter {
  final double progress;
  final int resistorOhms;
  final double currentMa;
  final int dayNum;

  _WhyBurnVsSafePainter({
    required this.progress,
    required this.resistorOhms,
    required this.currentMa,
    this.dayNum = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midX = size.width / 2;

    // Left Card: Danger Without Resistor
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, midX - 18, size.height - 24),
      const Radius.circular(14),
    );
    canvas.drawRRect(leftRect, Paint()..color = const Color(0xFFFEF2F2));
    _drawText(canvas, '❌ WITHOUT RESISTOR', Offset(26, 22), const Color(0xFFDC2626), 12, FontWeight.w900);
    _drawText(canvas, '85.0 mA OVERCURRENT!', Offset(26, 40), const Color(0xFF991B1B), 11.5, FontWeight.w700);

    // Burned LED with animated smoke puffs
    final burnCenter = Offset(leftRect.center.dx, size.height * 0.56);
    canvas.drawCircle(burnCenter, 22, Paint()..color = const Color(0xFF450A0A));
    for (int i = 0; i < 6; i++) {
      final puffY = burnCenter.dy - 15 - (((progress + i * 0.16) % 1.0) * 45);
      final puffX = burnCenter.dx + math.sin((progress + i) * 6) * 14;
      canvas.drawCircle(
        Offset(puffX, puffY),
        7,
        Paint()..color = const Color(0xFF64748B).withOpacity(0.55),
      );
    }
    _drawText(canvas, '💥 Burned LED!', Offset(burnCenter.dx - 38, burnCenter.dy + 30), const Color(0xFFDC2626), 12, FontWeight.w800);

    // Right Card: Safe With 330 Ω Resistor
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(midX + 6, 12, midX - 18, size.height - 24),
      const Radius.circular(14),
    );
    canvas.drawRRect(rightRect, Paint()..color = const Color(0xFFF0FDF4));
    _drawText(canvas, '✅ WITH $resistorOhms Ω RESISTOR', Offset(midX + 20, 22), const Color(0xFF16A34A), 12, FontWeight.w900);
    _drawText(canvas, '${currentMa.toStringAsFixed(1)} mA SAFE CURRENT', Offset(midX + 20, 40), const Color(0xFF166534), 11.5, FontWeight.w700);

    final safeCenter = Offset(rightRect.center.dx, size.height * 0.56);
    canvas.drawCircle(
      safeCenter,
      36,
      Paint()
        ..color = const Color(0xFF22C55E).withOpacity(0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(safeCenter, 20, Paint()..color = const Color(0xFFEF4444));
    _drawText(canvas, '🌟 Safe Bright Glow!', Offset(safeCenter.dx - 52, safeCenter.dy + 30), const Color(0xFF15803D), 12, FontWeight.w800);
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _WhyBurnVsSafePainter oldDelegate) => true;
}

// =============================================================================
// CUSTOM PAINTER 5: "WHERE" TAB — REAL-WORLD EVERYDAY PLACES ANIMATION!
// =============================================================================
class _WhereRealWorldDevicesPainter extends CustomPainter {
  final double progress;
  final int selectedDeviceIdx;
  final int dayNum;

  _WhereRealWorldDevicesPainter({
    required this.progress,
    required this.selectedDeviceIdx,
    this.dayNum = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFFF0FDF4),
    );

    final titles = [
      '🚦 Real-World Location 1: Street Traffic Signal Lights',
      '📺 Real-World Location 2: TV Remote Infrared (IR) LED',
      '📱 Real-World Location 3: Smartphone Camera Flashlight',
      '🤖 Real-World Location 4: Autonomous Robot Headlights & Pin 13',
    ];
    _drawText(canvas, titles[selectedDeviceIdx.clamp(0, 3)], const Offset(20, 18), const Color(0xFF166534), 13.5, FontWeight.w900);

    final cx = size.width / 2;
    final cy = size.height * 0.55;

    if (selectedDeviceIdx == 0) {
      // Traffic Light Pole & 3 Glowing LEDs (Red, Amber, Green)
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 64, height: 148),
        const Radius.circular(14),
      );
      canvas.drawRRect(box, Paint()..color = const Color(0xFF1E293B));
      final activeLight = ((progress * 3).floor()) % 3;
      final colors = [const Color(0xFFEF4444), const Color(0xFFF59E0B), const Color(0xFF22C55E)];
      for (int i = 0; i < 3; i++) {
        final ly = cy - 42 + (i * 42);
        final isOn = activeLight == i;
        if (isOn) {
          canvas.drawCircle(
            Offset(cx, ly),
            24,
            Paint()
              ..color = colors[i].withOpacity(0.45)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          );
        }
        canvas.drawCircle(
          Offset(cx, ly),
          14,
          Paint()..color = isOn ? colors[i] : colors[i].withOpacity(0.25),
        );
      }
      _drawText(canvas, 'Each lamp uses an array of LEDs + current-limiting resistors!', Offset(cx - 155, size.height - 32), const Color(0xFF15803D), 12, FontWeight.w700);
    } else if (selectedDeviceIdx == 1) {
      // TV Remote pulsing IR beam to Smart TV
      final remoteRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 110, cy), width: 46, height: 96),
        const Radius.circular(10),
      );
      canvas.drawRRect(remoteRect, Paint()..color = const Color(0xFF334155));
      canvas.drawCircle(Offset(cx - 87, cy), 8, Paint()..color = const Color(0xFFEF4444));

      // Pulsing IR waves
      for (int w = 0; w < 4; w++) {
        final wx = cx - 70 + (((progress + w * 0.25) % 1.0) * 140);
        canvas.drawCircle(Offset(wx, cy), 6, Paint()..color = const Color(0xFFEC4899));
      }

      // Smart TV on right
      final tvRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 105, cy), width: 110, height: 74),
        const Radius.circular(8),
      );
      canvas.drawRRect(tvRect, Paint()..color = const Color(0xFF0284C7));
      _drawText(canvas, 'SMART TV', Offset(cx + 76, cy - 8), Colors.white, 12, FontWeight.w800);
    } else if (selectedDeviceIdx == 2) {
      // Smartphone Flashlight Beam
      final phoneRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 80, cy), width: 54, height: 104),
        const Radius.circular(10),
      );
      canvas.drawRRect(phoneRect, Paint()..color = const Color(0xFF0F172A));
      final beamPath = Path()
        ..moveTo(cx - 53, cy - 20)
        ..lineTo(cx + 130, cy - 65)
        ..lineTo(cx + 130, cy + 45)
        ..close();
      canvas.drawPath(beamPath, Paint()..color = const Color(0xFFFEF08A).withOpacity(0.75));
      canvas.drawCircle(Offset(cx - 53, cy - 20), 9, Paint()..color = const Color(0xFFFACC15));
    } else {
      // Robot Car with Glowing Headlights
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 140, height: 64),
        const Radius.circular(14),
      );
      canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFF2563EB));
      canvas.drawCircle(Offset(cx - 42, cy + 34), 16, Paint()..color = const Color(0xFF1E293B));
      canvas.drawCircle(Offset(cx + 42, cy + 34), 16, Paint()..color = const Color(0xFF1E293B));
      canvas.drawCircle(Offset(cx + 70, cy - 10), 10, Paint()..color = const Color(0xFFFACC15));
      _drawText(canvas, 'ROBOT PIN 13 LED', Offset(cx - 48, cy - 8), Colors.white, 11.5, FontWeight.w800);
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _WhereRealWorldDevicesPainter oldDelegate) => true;
}

// =============================================================================
// CUSTOM PAINTER 6: "WHEN" TAB — REAL-TIME DECISION & TRIGGER TIMELINE!
// =============================================================================
class _WhenTimelineTriggerPainter extends CustomPainter {
  final double progress;
  final int selectedRuleIdx;
  final int resistorOhms;
  final int dayNum;

  _WhenTimelineTriggerPainter({
    required this.progress,
    required this.selectedRuleIdx,
    required this.resistorOhms,
    this.dayNum = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFFFAF5FF),
    );

    _drawText(
      canvas,
      '🕒 Real-Time Trigger Flow: When to Use an LED + $resistorOhms Ω Resistor',
      const Offset(20, 18),
      const Color(0xFF6B21A8),
      13.5,
      FontWeight.w900,
    );

    final steps = [
      '1. Trigger Event\n(Pin 13 = HIGH 5V)',
      '2. Voltage Check\n(5V > 2V LED)',
      '3. Add Resistor\n($resistorOhms Ω in series)',
      '4. Safe Output\n(LED Glows 9.1mA)',
    ];

    final y = size.height * 0.54;
    final startX = size.width * 0.14;
    final endX = size.width * 0.86;
    final gap = (endX - startX) / 3;

    // Connecting timeline bar
    canvas.drawLine(
      Offset(startX, y),
      Offset(endX, y),
      Paint()
        ..color = const Color(0xFFD8B4FE)
        ..strokeWidth = 5,
    );

    // Animated pulse traveling along the decision timeline
    final pulseX = startX + (endX - startX) * progress;
    canvas.drawCircle(Offset(pulseX, y), 8, Paint()..color = const Color(0xFF7E22CE));

    for (int i = 0; i < 4; i++) {
      final x = startX + i * gap;
      final isHighlighted = selectedRuleIdx == i || (progress * 4).floor() == i;
      canvas.drawCircle(
        Offset(x, y),
        22,
        Paint()..color = isHighlighted ? const Color(0xFF7E22CE) : Colors.white,
      );
      canvas.drawCircle(
        Offset(x, y),
        22,
        Paint()
          ..color = const Color(0xFF7E22CE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _drawText(
        canvas,
        '${i + 1}',
        Offset(x - 5, y - 8),
        isHighlighted ? Colors.white : const Color(0xFF7E22CE),
        14,
        FontWeight.w900,
      );
      _drawText(
        canvas,
        steps[i],
        Offset(x - 46, y + 30),
        const Color(0xFF3B0764),
        11,
        FontWeight.w700,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight, height: 1.25)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _WhenTimelineTriggerPainter oldDelegate) => true;
}

// =============================================================================
// CUSTOM PAINTER 7: "TRY IT" PRACTICAL BUILD BREADBOARD PAINTER
// =============================================================================
class _PracticalBuildBreadboardPainter extends CustomPainter {
  final bool step1Power;
  final bool step2Resistor;
  final bool step3Led;
  final bool step4Tested;
  final double progress;

  _PracticalBuildBreadboardPainter({
    required this.step1Power,
    required this.step2Resistor,
    required this.step3Led,
    required this.step4Tested,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Power rails
    canvas.drawLine(
      Offset(20, size.height * 0.12),
      Offset(size.width - 20, size.height * 0.12),
      Paint()..color = const Color(0xFFEF4444)..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(20, size.height * 0.22),
      Offset(size.width - 20, size.height * 0.22),
      Paint()..color = const Color(0xFF1E293B)..strokeWidth = 2,
    );

    // Breadboard holes
    final holePaint = Paint()..color = const Color(0xFF52525B);
    final startX = size.width * 0.08;
    final colStep = (size.width * 0.84) / 18;
    for (int c = 0; c < 18; c++) {
      final x = startX + c * colStep;
      for (final rf in [0.15, 0.20, 0.36, 0.44, 0.52, 0.60, 0.68]) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, size.height * rf), width: 4.5, height: 4.5),
          holePaint,
        );
      }
    }

    final c2 = startX + 2 * colStep;
    final c4 = startX + 4 * colStep;
    final c8 = startX + 8 * colStep;
    final c11 = startX + 11 * colStep;
    final plusY = size.height * 0.15;
    final minusY = size.height * 0.20;
    final rowY = size.height * 0.44;

    // Step 1: 5V & GND Power Supply Leads
    if (step1Power) {
      canvas.drawLine(
        Offset(c2, plusY),
        Offset(c2, size.height - 18),
        Paint()..color = const Color(0xFFDC2626)..strokeWidth = 4,
      );
      canvas.drawLine(
        Offset(c2 - colStep, minusY),
        Offset(c2 - colStep, size.height - 18),
        Paint()..color = const Color(0xFF0F172A)..strokeWidth = 4,
      );
      canvas.drawLine(
        Offset(c4, plusY),
        Offset(c4, rowY),
        Paint()..color = const Color(0xFFDC2626)..strokeWidth = 3.5,
      );
    }

    // Step 2: 330 Ω Resistor between c4 and c8
    if (step2Resistor) {
      canvas.drawLine(
        Offset(c4, rowY),
        Offset(c8, rowY),
        Paint()..color = const Color(0xFF64748B)..strokeWidth = 2.5,
      );
      final rRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset((c4 + c8) / 2, rowY), width: 42, height: 14),
        const Radius.circular(6),
      );
      canvas.drawRRect(rRect, Paint()..color = const Color(0xFFD97706));
      _drawText(canvas, '330 Ω', Offset((c4 + c8) / 2 - 16, rowY + 12), const Color(0xFF0F172A), 11);
    }

    // Step 3: LED Anode (+) at c8 and Cathode (−) at c11 + GND jumper
    if (step3Led) {
      final ledCenter = Offset((c8 + c11) / 2, rowY - 26);
      canvas.drawLine(ledCenter, Offset(c8, rowY), Paint()..color = const Color(0xFF64748B)..strokeWidth = 2.2);
      canvas.drawLine(ledCenter, Offset(c11, rowY), Paint()..color = const Color(0xFF64748B)..strokeWidth = 2.2);

      if (step4Tested) {
        canvas.drawCircle(
          ledCenter,
          36,
          Paint()
            ..color = const Color(0xFFEF4444).withOpacity(0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
        );
      }

      canvas.drawCircle(
        ledCenter,
        14,
        Paint()..color = step4Tested ? const Color(0xFFEF4444) : const Color(0xFFFCA5A5),
      );
      _drawText(canvas, 'A (+)', Offset(c8 - 10, rowY + 10), const Color(0xFFDC2626), 10.5);
      _drawText(canvas, 'K (−)', Offset(c11 - 10, rowY + 10), const Color(0xFF0F172A), 10.5);

      // Black GND return jumper from c11 to minusY
      canvas.drawLine(
        Offset(c11, rowY),
        Offset(c11, minusY),
        Paint()..color = const Color(0xFF0F172A)..strokeWidth = 3.5,
      );
    }

    _drawText(
      canvas,
      step4Tested
          ? '✅ PRACTICAL VERIFIED: 9.1 mA Safe LED Glow!'
          : 'Complete Practical Steps 1 → 4 on the right to wire this breadboard',
      Offset(20, size.height - 26),
      step4Tested ? const Color(0xFF15803D) : const Color(0xFF475569),
      12,
    );
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _PracticalBuildBreadboardPainter oldDelegate) => true;
}

// =============================================================================
// CUSTOM PAINTER 8: "BUG HUNT" FAULTY BREADBOARD & CIRCUIT PAINTER
// =============================================================================
class _BugHuntBreadboardPainter extends CustomPainter {
  final bool bug1ResistorFixed;
  final bool bug2PolarityFixed;
  final bool bug3GroundFixed;
  final double progress;

  _BugHuntBreadboardPainter({
    required this.bug1ResistorFixed,
    required this.bug2PolarityFixed,
    required this.bug3GroundFixed,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final allFixed = bug1ResistorFixed && bug2PolarityFixed && bug3GroundFixed;

    // Power rails
    canvas.drawLine(
      Offset(20, size.height * 0.16),
      Offset(size.width - 20, size.height * 0.16),
      Paint()..color = const Color(0xFFEF4444)..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(20, size.height * 0.25),
      Offset(size.width - 20, size.height * 0.25),
      Paint()..color = const Color(0xFF1E293B)..strokeWidth = 2,
    );

    final holePaint = Paint()..color = const Color(0xFF52525B);
    final startX = size.width * 0.08;
    final colStep = (size.width * 0.84) / 18;
    for (int c = 0; c < 18; c++) {
      final x = startX + c * colStep;
      for (final rf in [0.18, 0.23, 0.40, 0.48, 0.56, 0.64, 0.72]) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, size.height * rf), width: 4.5, height: 4.5),
          holePaint,
        );
      }
    }

    final c4 = startX + 4 * colStep;
    final c8 = startX + 8 * colStep;
    final c11 = startX + 11 * colStep;
    final plusY = size.height * 0.18;
    final minusY = size.height * 0.23;
    final rowY = size.height * 0.48;

    // Positive Jumper
    canvas.drawLine(
      Offset(c4, plusY),
      Offset(c4, rowY),
      Paint()..color = const Color(0xFFDC2626)..strokeWidth = 3.5,
    );

    // BUG #1: Missing Resistor vs Fixed 330 Ω Resistor between c4 and c8
    if (bug1ResistorFixed) {
      canvas.drawLine(
        Offset(c4, rowY),
        Offset(c8, rowY),
        Paint()..color = const Color(0xFF64748B)..strokeWidth = 2.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset((c4 + c8) / 2, rowY), width: 42, height: 14),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFFD97706),
      );
      _drawText(canvas, '330 Ω ✓', Offset((c4 + c8) / 2 - 18, rowY + 12), const Color(0xFF15803D), 11);
    } else {
      // Direct red short wire with red pulsing bug ring!
      canvas.drawLine(
        Offset(c4, rowY),
        Offset(c8, rowY),
        Paint()..color = const Color(0xFFDC2626)..strokeWidth = 3.5,
      );
      canvas.drawCircle(
        Offset((c4 + c8) / 2, rowY),
        16,
        Paint()
          ..color = const Color(0xFFDC2626).withOpacity(0.25)
          ..style = PaintingStyle.fill,
      );
      _drawText(canvas, '🐞 Bug #1: No Resistor!', Offset((c4 + c8) / 2 - 48, rowY + 14), const Color(0xFFDC2626), 11);
    }

    // BUG #2: LED Polarity at c8 & c11
    final ledCenter = Offset((c8 + c11) / 2, rowY - 26);
    canvas.drawLine(ledCenter, Offset(c8, rowY), Paint()..color = const Color(0xFF64748B)..strokeWidth = 2.2);
    canvas.drawLine(ledCenter, Offset(c11, rowY), Paint()..color = const Color(0xFF64748B)..strokeWidth = 2.2);

    if (allFixed) {
      canvas.drawCircle(
        ledCenter,
        36,
        Paint()
          ..color = const Color(0xFFEF4444).withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }
    canvas.drawCircle(
      ledCenter,
      14,
      Paint()..color = allFixed ? const Color(0xFFEF4444) : const Color(0xFFFCA5A5),
    );

    if (bug2PolarityFixed) {
      _drawText(canvas, 'A (+)', Offset(c8 - 10, rowY - 48), const Color(0xFF15803D), 10.5);
      _drawText(canvas, 'K (−)', Offset(c11 - 10, rowY - 48), const Color(0xFF15803D), 10.5);
    } else {
      _drawText(canvas, '🐞 Bug #2: K(−) at +!', Offset(c8 - 25, rowY - 52), const Color(0xFFDC2626), 11);
    }

    // BUG #3: Disconnected GND wire vs Fixed GND connection
    if (bug3GroundFixed) {
      canvas.drawLine(
        Offset(c11, rowY),
        Offset(c11, minusY),
        Paint()..color = const Color(0xFF0F172A)..strokeWidth = 3.5,
      );
      _drawText(canvas, 'GND ✓', Offset(c11 + 6, minusY + 6), const Color(0xFF15803D), 10.5);
    } else {
      // Loose wire going to dead row below
      canvas.drawLine(
        Offset(c11, rowY),
        Offset(c11 + 28, size.height * 0.72),
        Paint()..color = const Color(0xFF0F172A)..strokeWidth = 3.5,
      );
      _drawText(canvas, '🐞 Bug #3: Loose GND!', Offset(c11 - 10, size.height * 0.75), const Color(0xFFDC2626), 11);
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _BugHuntBreadboardPainter oldDelegate) => true;
}
