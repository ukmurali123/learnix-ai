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

  // Active Day Detail View State (Image 3 pattern)
  Map<String, dynamic>? _selectedDay;
  int _activeTopModeIndex = 0; // 0: Learn, 1: Video, 2: Slides, 3: Predict, 4: Try it, 5: Bug hunt, 6: Quiz
  int _activeWhatTabIndex = 0; // 0: WHAT, 1: LIKE, 2: WHY, 3: WHERE, 4: WHEN
  int _circuitTopology = 0; // 0: 1 LED, 1: 2 in series, 2: 2 in parallel
  double _resistorOhms = 330.0;
  int _selectedAnatomyIndex = 0; // 0: Long leg +, 1: Short leg -, 2: Resistor, 3: Series / Parallel

  // Interactive Predict / Bug hunt / Quiz state inside the Day Workspace
  int? _predictChoice;
  int? _bugHuntChoice;
  final Map<int, int> _quizAnswers = {};

  late AnimationController _electronController;

  final List<Map<String, dynamic>> _topModes = [
    {'label': 'Learn', 'icon': LucideIcons.checkCircle2},
    {'label': 'Video', 'icon': LucideIcons.playSquare},
    {'label': 'Slides', 'icon': LucideIcons.presentation},
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
      _bugHuntChoice = null;
      _quizAnswers.clear();
    });
  }

  // Generate dynamic content per day for the 5 WHAT/LIKE/WHY/WHERE/WHEN tabs
  Map<String, dynamic> _getDayLessonData(Map<String, dynamic> day) {
    final dayNum = day['day_number'] ?? 1;
    final title = (day['title'] ?? 'LED and its application').toString();

    final Map<int, Map<String, dynamic>> catalog = {
      1: {
        'headerTitle': 'Day 1: $title & Series and Parallel',
        'question': 'Why does an LED only glow in one direction and need a resistor?',
        'what': 'A tiny semiconductor light that works one way (anode + to cathode −) and needs a resistor',
        'like': 'Like a one-way turnstile gate at a metro station that glows when people walk through',
        'why': 'Without a resistor, too much current rushes through the LED and burns it out instantly',
        'where': 'Used in TV remotes, traffic signals, phone flashlights, and Arduino pin 13 indicators',
        'when': 'Use whenever your robot needs a fast, low-power visual status light or indicator',
      },
      2: {
        'headerTitle': 'Day 2: $title & Current Limiting',
        'question': 'Why does an LED burn without a resistor?',
        'what': 'A passive component measured in Ohms (Ω) that slows down electric current in a circuit',
        'like': 'Like a narrow speed-bump or pinch in a garden hose that keeps water pressure safe',
        'why': 'Ohm\'s Law (I = V ÷ R): higher resistance keeps current around 9–15 mA so LEDs stay safe',
        'where': 'Found inside every phone charger, sensor board, and LED strip to protect delicate chips',
        'when': 'Always place a 220Ω–330Ω resistor in series before connecting an LED to a 5V pin',
      },
      3: {
        'headerTitle': 'Day 3: $title & Closed Loops',
        'question': 'Why won\'t a circuit work if the Ground (GND) wire is missing?',
        'what': 'Ground (GND) is the 0V return path that completes an electrical loop back to the battery',
        'like': 'Like a circular racing track — cars cannot keep moving if the return road is blocked',
        'why': 'Electrons only flow when there is a complete, unbroken closed loop from +5V back to GND',
        'where': 'Every Arduino sensor, motor, buzzer, and LED shares a common GND pin on the board',
        'when': 'Always connect every component\'s negative (−) leg back to Arduino GND before pressing Run',
      },
    };

    return catalog[dayNum] ??
        {
          'headerTitle': 'Day $dayNum: $title & Series and Parallel',
          'question': 'Why does an LED burn without a resistor in a $title circuit?',
          'what': day['concept']?['summary'] ?? 'A tiny light that works one way and needs a resistor',
          'like': 'Like a water pipe loop where voltage pushes electrons through components in order',
          'why': 'Resistors limit current (I = (5 V − LED drop) ÷ R) so components operate safely',
          'where': 'Used across robotics controllers, smart alarms, and automated sensor kits',
          'when': 'Use whenever wiring outputs or sensors between an Arduino digital pin and GND',
        };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: tokens.primary));
    }

    // If a day is clicked, show the Image 3 Interactive Day Lesson Workspace
    if (_selectedDay != null) {
      return _buildDayWorkspaceView(context, _selectedDay!);
    }

    // Otherwise, show the Image 2 Winding Snake Roadmap
    return _buildSnakeRoadmapView(context);
  }

  // ===========================================================================
  // IMAGE 2: WINDING SNAKE ROADMAP VIEW
  // ===========================================================================
  Widget _buildSnakeRoadmapView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final zigZagOffset = isMobile ? 22.0 : 56.0;
        final cardWidth = isMobile ? (constraints.maxWidth - 48).clamp(240.0, 320.0) : 330.0;

        return Column(
          children: [
            // Top Sub-header Bar matching Image 2 ("Robotics Level 1: Robo Starter" | Videos | Refresh)
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
                      const Icon(LucideIcons.arrowLeft, size: 18, color: Color(0xFF1E293B)),
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
                      'Robotics Level 1: Robo Starter',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          if (_days.isNotEmpty) {
                            _openDayWorkspace(Map<String, dynamic>.from(_days.first as Map));
                            setState(() => _activeTopModeIndex = 1);
                          }
                        },
                        icon: const Icon(LucideIcons.playSquare, size: 16, color: Color(0xFF0284C7)),
                        label: const Text(
                          'Videos',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
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
                ],
              ),
            ),

            // Soft Blue-to-Mint Gradient Canvas with Winding Snake Nodes
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
                            // Shifted Day Node Card
                            Transform.translate(
                              offset: Offset(dx, 0),
                              child: _buildSnakeNodeCard(day, cardWidth, isDone, isCurrent),
                            ).animate().fadeIn(delay: (index * 50).ms, duration: 350.ms).slideY(begin: 0.08, end: 0),

                            // S-Curve Dashed Connector Line to Next Node
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
    final isLocked = !isDone && !isCurrent;

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
                  // Left Circle Badge (Checkmark for done, Day Number for current/locked)
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

                  // Middle Texts: DAY N, Title, Play Interactive
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

                  // Right Indicator: Gold Star (Done), White Play Circle (Current), or Lock (Locked)
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

        // Floating "START HERE" Yellow Pill Badge on Current Day
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

    // Calculate live current in mA based on circuit topology and resistor slider
    double effectiveDrop = 2.0;
    double effectiveR = _resistorOhms;
    if (_circuitTopology == 1) {
      // 2 LEDs in series: ~4.0V drop
      effectiveDrop = 3.6;
    } else if (_circuitTopology == 2) {
      // 2 LEDs in parallel: double total current
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
              // 1. Top Navigation Header Bar ("<-" | "Day N: LED and its application & Series and Parallel" | "[ ]")
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
                      // 2. Row of 7 Interactive Activity Mode Pills (Learn, Video, Slides, Predict, Try it, Bug hunt, Quiz)
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

                      // 4. Five Colorful Concept Dimension Tabs (WHAT, LIKE, WHY, WHERE, WHEN) + Speaker
                      _buildFiveDimensionTabs(isNarrow, activeExplanation),

                      const SizedBox(height: 10),

                      // 5. Centered Explanation Strip
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

                      // 6. Main Interactive Area (switches on _activeTopModeIndex or shows full split schematic)
                      if (_activeTopModeIndex == 6)
                        _buildDayQuizMode(dayNum)
                      else if (_activeTopModeIndex == 3)
                        _buildDayPredictMode(currentMa)
                      else if (_activeTopModeIndex == 5)
                        _buildDayBugHuntMode()
                      else
                        _buildSplitCircuitAndAnatomyWorkspace(isNarrow, currentMa),

                      const SizedBox(height: 16),

                      // 7. Bottom-right "-> Next" Pill Button
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
                                ? 'Next'
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
                    onTap: () => setState(() => _activeWhatTabIndex = idx),
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

  Widget _buildSplitCircuitAndAnatomyWorkspace(bool isNarrow, double currentMa) {
    // Left Column: Circuit Schematic + 1 LED / 2 in series / 2 in parallel pills + Resistor Slider
    final leftCircuitColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Animated Schematic Canvas Card
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: AnimatedBuilder(
            animation: _electronController,
            builder: (context, _) {
              return CustomPaint(
                painter: _InteractiveCircuitSchematicPainter(
                  progress: _electronController.value,
                  resistorOhms: _resistorOhms.toInt(),
                  currentMa: currentMa,
                  topology: _circuitTopology,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // 3 Circuit Topology Pills: "✓ 1 LED" | "2 in series" | "2 in parallel"
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

        // Resistor (Ω) Slider Row
        Row(
          children: [
            const Text(
              'Resistor (Ω)',
              style: TextStyle(
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

    // Right Column: 4 Circular Anatomy Buttons + Pastel Green Visual Spotlight Card
    final List<Map<String, dynamic>> anatomyItems = [
      {
        'label': 'Long leg +',
        'symbol': '+',
        'title': 'Anode (+) — Long Leg',
        'desc': 'Connects to the positive (+) 5V or Arduino digital output pin through a resistor.',
        'polarity': '+',
        'color': const Color(0xFFDC2626),
      },
      {
        'label': 'Short leg −',
        'symbol': '−',
        'title': 'Cathode (−) — Short Leg',
        'desc': 'Connects to the flat edge of the LED and returns current to Ground (GND 0V).',
        'polarity': '−',
        'color': const Color(0xFF1E293B),
      },
      {
        'label': 'Resistor',
        'symbol': '—',
        'title': '${_resistorOhms.toInt()} Ω Current-Limiting Resistor',
        'desc': 'Slows down electron flow to ${currentMa.toStringAsFixed(1)} mA so the LED never overheats.',
        'polarity': '${_resistorOhms.toInt()} Ω',
        'color': const Color(0xFFD97706),
      },
      {
        'label': 'Series /\nParallel',
        'symbol': '⑃',
        'title': _circuitTopology == 0
            ? 'Single LED Loop'
            : (_circuitTopology == 1 ? '2 LEDs in Series' : '2 LEDs in Parallel'),
        'desc': _circuitTopology == 1
            ? 'In series, both LEDs share the same current path and split the 5V supply.'
            : (_circuitTopology == 2
                ? 'In parallel, each LED gets its own branch across the voltage supply.'
                : 'A single closed loop where every electron passes through the resistor and LED.'),
        'polarity': '⑃',
        'color': const Color(0xFF0284C7),
      },
    ];

    final activeAnatomy = anatomyItems[_selectedAnatomyIndex];

    final rightAnatomyColumn = Column(
      children: [
        // Row of 4 Circular Anatomy Buttons
        Wrap(
          spacing: 18,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: List.generate(anatomyItems.length, (idx) {
            final item = anatomyItems[idx];
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
                            fontSize: 22,
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

        // Large Pastel Green Visual Spotlight Card
        Container(
          width: double.infinity,
          height: 220,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEBF5DF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lightbulb_rounded,
                size: 74,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(height: 6),
              Text(
                activeAnatomy['polarity'] as String,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: activeAnatomy['color'] as Color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                activeAnatomy['title'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activeAnatomy['desc'] as String,
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
          leftCircuitColumn,
          const SizedBox(height: 24),
          rightAnatomyColumn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: leftCircuitColumn),
        const SizedBox(width: 28),
        Expanded(flex: 5, child: rightAnatomyColumn),
      ],
    );
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

  Widget _buildDayBugHuntMode() {
    final bugs = [
      'The LED long leg (+) is wired to GND instead of 5V (Reversed Polarity)',
      'The battery has too many electrons',
      'The wire color is blue instead of red',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🐞 Bug Hunt Challenge: Spot the Circuit Mistake!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF9A3412)),
          ),
          const SizedBox(height: 8),
          const Text(
            'A student wired a 5V battery and a 330 Ω resistor to an LED, but the LED stays completely dark. What is the bug?',
            style: TextStyle(fontSize: 14, color: Color(0xFF431407)),
          ),
          const SizedBox(height: 16),
          ...List.generate(bugs.length, (i) {
            final isPicked = _bugHuntChoice == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _bugHuntChoice = i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isPicked
                        ? (i == 0 ? const Color(0xFFF0FDF4) : Colors.white)
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
                            : LucideIcons.bug,
                        color: isPicked
                            ? (i == 0 ? const Color(0xFF16A34A) : Colors.red)
                            : const Color(0xFFEA580C),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bugs[i],
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
// CUSTOM PAINTER 1: S-CURVE DASHED CONNECTOR BETWEEN SNAKE NODES (IMAGE 2)
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

    // Draw dashed segments along the cubic path
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
  bool shouldRepaint(covariant _SnakeDashedConnectorPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.startXOffset != startXOffset ||
        oldDelegate.endXOffset != endXOffset;
  }
}

// =============================================================================
// CUSTOM PAINTER 2: INTERACTIVE CIRCUIT SCHEMATIC WITH FLOWING ELECTRONS (IMAGE 3)
// =============================================================================
class _InteractiveCircuitSchematicPainter extends CustomPainter {
  final double progress;
  final int resistorOhms;
  final double currentMa;
  final int topology; // 0: 1 LED, 1: 2 in series, 2: 2 in parallel

  _InteractiveCircuitSchematicPainter({
    required this.progress,
    required this.resistorOhms,
    required this.currentMa,
    required this.topology,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle Dot Grid Background
    final dotPaint = Paint()..color = const Color(0xFFCBD5E1).withOpacity(0.55);
    const step = 20.0;
    for (double x = 16; x < size.width; x += step) {
      for (double y = 16; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
      }
    }

    final left = size.width * 0.16;
    final right = size.width * 0.86;
    final top = size.height * 0.25;
    final bottom = size.height * 0.78;

    // 2. Circuit Wire Loop
    final wirePaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final loopRect = Rect.fromLTRB(left, top, right, bottom);
    canvas.drawRect(loopRect, wirePaint);

    // Parallel branch wire if topology == 2
    if (topology == 2) {
      final parallelY = top + 46;
      canvas.drawLine(Offset(size.width * 0.52, top), Offset(size.width * 0.52, parallelY), wirePaint);
      canvas.drawLine(Offset(size.width * 0.52, parallelY), Offset(size.width * 0.78, parallelY), wirePaint);
      canvas.drawLine(Offset(size.width * 0.78, parallelY), Offset(size.width * 0.78, top), wirePaint);
    }

    // 3. Draw 5V Battery on Left Vertical Wire
    final batCenterY = (top + bottom) / 2;
    final batRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(left, batCenterY), width: 32, height: 64),
      const Radius.circular(6),
    );
    canvas.drawRRect(batRect, Paint()..color = const Color(0xFF15803D));
    // Battery gold top band
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(left, batCenterY - 22), width: 32, height: 14),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFFACC15),
    );
    // Battery terminal nub
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

    // 4. Draw Resistor on Top Wire (Left side)
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
    // Color bands on resistor
    for (int i = -1; i <= 1; i++) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(resCenterX + (i * 11), top), width: 4, height: 16),
        Paint()..color = i == 0 ? const Color(0xFF78350F) : const Color(0xFFEA580C),
      );
    }
    _drawText(
      canvas,
      '$resistorOhms Ω',
      Offset(resCenterX - 20, top - 32),
      const Color(0xFF0F172A),
      13,
      FontWeight.w800,
    );

    // 5. Draw Glowing Red LED(s) on Top Wire (Right side)
    final glowIntensity = (currentMa / 20.0).clamp(0.25, 1.0);
    final led1X = left + (right - left) * 0.64;
    _drawGlowingLed(canvas, Offset(led1X, top), glowIntensity);

    if (topology == 1) {
      // Second LED in series
      _drawGlowingLed(canvas, Offset(led1X + 54, top), glowIntensity * 0.85);
    } else if (topology == 2) {
      // Second LED in parallel branch
      _drawGlowingLed(canvas, Offset(led1X, top + 46), glowIntensity);
    }

    // 6. Animated Yellow Electron Dots Flowing Around the Loop
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

    // 7. Center Current Readout ("9.1 mA") & Formula ("I = (5 V - LED drop) ÷ R")
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

  void _drawGlowingLed(Canvas canvas, Offset center, double intensity) {
    // Radial red glow
    canvas.drawCircle(
      center,
      36 * intensity,
      Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.28 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // LED Dome
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

    // Ray ticks around LED
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

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize,
    FontWeight weight,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _InteractiveCircuitSchematicPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.resistorOhms != resistorOhms ||
        oldDelegate.topology != topology;
  }
}
