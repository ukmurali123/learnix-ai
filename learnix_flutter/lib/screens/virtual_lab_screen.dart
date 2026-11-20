import '../widgets/bubble_background.dart';
import '../widgets/breadboard_3d_view.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/zola_avatar.dart';

class VirtualLabScreen extends StatefulWidget {
  final String baseUrl;
  final int initialSection; // 0 = Schematic (Circuit builder), 2 = Breadboard
  final bool isBugHunt;
  final String? goalTitle;

  const VirtualLabScreen({
    super.key,
    required this.baseUrl,
    this.initialSection = 2,
    this.isBugHunt = false,
    this.goalTitle,
  });

  @override
  State<VirtualLabScreen> createState() => _VirtualLabScreenState();
}

class _VirtualLabScreenState extends State<VirtualLabScreen>
    with SingleTickerProviderStateMixin {
  // 4 Top Sections: 0 = Schematic, 1 = Real components, 2 = Breadboard, 3 = IoT app
  int _activeSectionTab = 2; // Default or switchable between Schematic(0), Real components(1), Breadboard(2), IoT app(3)

  // Simulation & Circuit State
  bool _isRunning = false;
  bool _hasResistor = true;
  bool _switchClosed = true;
  double _batteryVoltage = 5.0;
  double _resistorOhms = 330.0;
  String _ledColorName = 'Red';

  // Real Components Tab Controls (Image 2)
  bool _showElectrons = true;
  bool _showCurrent = true;
  bool _showVoltage = true;
  int _simSpeed = 1; // 0 = Slow, 1 = Normal, 2 = Fast

  // Breadboard Tab Controls (Image 3: 2D & 3D Toggle!)
  bool _is3DMode = false;
  double _zoomLevel = 1.0;
  double _rotX = -0.45;
  double _rotZ = 0.25;
  String _selectedProject = 'Free build';

  // Components Right Drawer State
  bool _showComponentsDrawer = true;
  String _searchQuery = '';
  int _selectedCategoryIdx = 0; // 0: All, 1: Power, 2: Passive, 3: Output

  // AI Tutor Helper State
  bool _showAiTutorPanel = true;
  bool _isAskingTutor = false;
  final TextEditingController _tutorInputController = TextEditingController();
  String _tutorPraise = 'Great circuit layout! Your 5V power rails and LED anode/cathode placement look clean.';
  String _tutorHint = 'Press "▶ Start" to power the circuit, or toggle between 2D and 3D Breadboard views to inspect the component legs!';
  List<String> _eventLogs = [
    '> waiting for simulation',
    '> B1 (5.0 V) connected to breadboard rails',
    '> R1 (330 Ω) placed in series with LED1 (Red)',
  ];

  late AnimationController _electronController;

  final List<Map<String, dynamic>> _allParts = [
    {'name': 'Battery', 'category': 'Power', 'icon': LucideIcons.batteryCharging, 'color': const Color(0xFFEF4444), 'value': '5.0 V'},
    {'name': 'Resistor', 'category': 'Passive', 'icon': LucideIcons.activity, 'color': const Color(0xFF78350F), 'value': '330 Ω'},
    {'name': 'LED', 'category': 'Output', 'icon': LucideIcons.lightbulb, 'color': const Color(0xFFF59E0B), 'value': 'Red'},
    {'name': 'RGB LED', 'category': 'Output', 'icon': LucideIcons.palette, 'color': const Color(0xFFD97706), 'value': 'RGB'},
    {'name': 'Push Button', 'category': 'Passive', 'icon': LucideIcons.toggleLeft, 'color': const Color(0xFF6366F1), 'value': 'Momentary'},
    {'name': 'Multimeter', 'category': 'Tools & wiring', 'icon': LucideIcons.gauge, 'color': const Color(0xFF0284C7), 'value': 'V / mA'},
    {'name': 'Piezo Buzzer', 'category': 'Output', 'icon': LucideIcons.volume2, 'color': const Color(0xFF0D9488), 'value': '2 kHz'},
    {'name': 'Ultrasonic', 'category': 'Output', 'icon': LucideIcons.radio, 'color': const Color(0xFF7E22CE), 'value': 'HC-SR04'},
  ];

  @override
  void initState() {
    super.initState();
    _activeSectionTab = widget.initialSection;
    if (widget.isBugHunt) {
      _hasResistor = false; // The bug! Missing resistor
      _switchClosed = true;
      _tutorPraise = 'Bug Hunt Mission: The LED does not light safely! Inspect the missing component.';
      _tutorHint = 'Add the 330 Ω resistor to protect the circuit and press "Start"!';
    }
    _electronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _electronController.dispose();
    _tutorInputController.dispose();
    super.dispose();
  }

  double get _currentMa {
    if (!_isRunning || !_switchClosed) return 0.0;
    if (!_hasResistor) return 85.0; // Overcurrent!
    return ((_batteryVoltage - 2.0).clamp(0.5, 10.0) / _resistorOhms) * 1000.0;
  }

  bool get _isLedGlowing => _isRunning && _switchClosed && _hasResistor;
  bool get _isLedBurned => _isRunning && _switchClosed && !_hasResistor;

  void _toggleSimulation() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        if (!_hasResistor) {
          _eventLogs.add('> ⚠️ OVERCURRENT: 85.0 mA without resistor! LED1 at risk of burning!');
          _tutorPraise = 'You connected the battery and LED in a complete loop!';
          _tutorHint = '⚠️ Watch out! Without a 330 Ω resistor, 85 mA rushes through the LED and burns it. Tap "Resistor" in the Components drawer to protect it!';
        } else if (!_switchClosed) {
          _eventLogs.add('> simulation started — switch SW1 is OFF (open circuit, 0.0 mA)');
          _tutorPraise = 'Your 330 Ω resistor and LED polarity are wired safely.';
          _tutorHint = '💡 The slide switch on the breadboard is currently OFF. Click the switch or toggle it ON to close the loop!';
        } else {
          final ma = _currentMa.toStringAsFixed(1);
          _eventLogs.add('> simulation started: B1=${_batteryVoltage}V, R1=${_resistorOhms.toInt()}Ω, I=$ma mA, LED1=ON');
          _tutorPraise = '🌟 Awesome job! Your LED is glowing safely at $ma mA!';
          _tutorHint = 'Try switching between Schematic, Real components, and Breadboard (2D / 3D) to see how the exact same circuit looks in every engineering view!';
        }
      } else {
        _eventLogs.add('> simulation stopped');
      }
    });
  }

  void _setSpeed(int speedIdx) {
    setState(() {
      _simSpeed = speedIdx;
      final ms = speedIdx == 0 ? 4500 : (speedIdx == 1 ? 2400 : 1100);
      _electronController.duration = Duration(milliseconds: ms);
      if (_electronController.isAnimating) {
        _electronController.repeat();
      }
    });
  }

  Future<void> _askAiTutor({String? customQuestion}) async {
    final question = customQuestion ?? _tutorInputController.text.trim();
    setState(() => _isAskingTutor = true);

    try {
      if (question.isNotEmpty) {
        _tutorInputController.clear();
        final res = await http.post(
          Uri.parse('${widget.baseUrl}/api/concept-studio/doubt'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'student_id': 1,
            'concept_title': 'Virtual Lab Circuit ($_selectedProject)',
            'question': question,
            'language': 'English',
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          setState(() {
            _tutorPraise = 'Great question!';
            _tutorHint = (data['answer'] ?? data['tip'] ?? 'Current flows from 5V through the 330Ω resistor and LED anode (+) to cathode (−) and GND.').toString();
            _eventLogs.add('> AI Tutor answered: "$question"');
          });
          return;
        }
      }

      // Otherwise run AI Lab Partner circuit check (/api/lab/check)
      final circuitList = <Map<String, String>>[
        {'from': 'D13', 'to': _hasResistor ? 'R1.a' : 'LED1.anode'},
        if (_hasResistor) {'from': 'R1.b', 'to': 'LED1.anode'},
        if (_switchClosed) {'from': 'LED1.cathode', 'to': 'GND'},
      ];

      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/lab/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'experiment_id': 1,
          'student_id': 1,
          'circuit': circuitList,
          'code': 'void setup(){ pinMode(13, OUTPUT); } void loop(){ digitalWrite(13, HIGH); }',
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _tutorPraise = (data['praise'] ?? 'Good progress on your workbench!').toString();
          _tutorHint = (data['hint'] ?? 'Verify that your 330 Ω resistor is in series with the LED and GND is connected.').toString();
          _eventLogs.add('> AI Tutor diagnostic check completed');
        });
      }
    } catch (e) {
      setState(() {
        _tutorPraise = 'Your circuit components are placed on the board!';
        _tutorHint = _hasResistor
            ? 'With a ${_resistorOhms.toInt()} Ω resistor on a ${_batteryVoltage}V supply, current is safely limited to ${_currentMa.toStringAsFixed(1)} mA (I = (V − 2.0V) ÷ R).'
            : 'Add a 330 Ω resistor in series with the LED so excessive current doesn\'t burn it out!';
      });
    } finally {
      if (mounted) setState(() => _isAskingTutor = false);
    }
  }

  /// The circuit as a 3D scene (live Learnix renderer). Reads the current switch / resistor / run state each frame.
  Scene3 _board3DScene() => buildCircuitBoardScene(
        running: _isRunning,
        hasResistor: _hasResistor,
        switchClosed: _switchClosed,
        ohms: _resistorOhms.toDouble(),
        progress: _electronController.value,
      );

  @override
  Widget build(BuildContext context) {
    // Material ancestor: this screen is also pushed as its own route from the
    // Learning Path, where there is no Scaffold above it.
    // Own bubble background too, because the Learning Path opens this screen as a separate page.
    return BubbleBackground(
      child: Material(
      color: Colors.transparent,
      child: LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        return Container(
          color: Colors.transparent,
          child: Column(
            children: [
              // 1. Top 4-Tab Section Bar (Schematic | Real components | Breadboard | IoT app)
              _buildTopSectionTabBar(isNarrow),

              // Try It & Bug Hunt Mission Goal & Achievement Bar
              if (widget.goalTitle != null || widget.isBugHunt)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isLedGlowing
                        ? const Color(0xFFDCFCE7)
                        : (widget.isBugHunt ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                    border: Border(
                      bottom: BorderSide(
                        color: _isLedGlowing
                            ? const Color(0xFF16A34A)
                            : (widget.isBugHunt ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isLedGlowing
                            ? Icons.check_circle_rounded
                            : (widget.isBugHunt ? LucideIcons.bug : LucideIcons.target),
                        color: _isLedGlowing
                            ? const Color(0xFF16A34A)
                            : (widget.isBugHunt ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isLedGlowing
                              ? (widget.isBugHunt
                                  ? '🎉 Bug Solved! The circuit is running safely at ${_currentMa.toStringAsFixed(1)} mA.'
                                  : '🎉 Practical Goal Complete! Current is safe at ${_currentMa.toStringAsFixed(1)} mA.')
                              : (widget.goalTitle ??
                                  (widget.isBugHunt
                                      ? 'LED stays dark. Fix missing resistor or connections and press Start!'
                                      : 'Power an LED through a resistor at a safe current.')),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isLedGlowing
                                ? const Color(0xFF166534)
                                : (widget.isBugHunt ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                          ),
                        ),
                      ),
                      if (_isLedGlowing) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Finish Goal & Return ✓', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasResistor = true;
                              _switchClosed = true;
                              _isRunning = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isBugHunt ? const Color(0xFFDC2626) : const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.flash_on_rounded, size: 15),
                          label: Text(
                            widget.isBugHunt ? 'Auto-Fix & Test' : 'Connect & Test',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // 2. Context-Sensitive Sub-Toolbar (matches Image 1, Image 2, or Image 3)
              _buildSectionSubToolbar(isNarrow),

              // 3. AI Tutor Collapsible Helper Strip (Always accessible in Virtual Lab!)
              if (_showAiTutorPanel) _buildAiTutorBanner(isNarrow),

              // 4. Main Section Content Workspace
              Expanded(
                child: _buildActiveSectionBody(isNarrow),
              ),
            ],
          ),
        );
      },
      ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP 4-TAB SECTION BAR (Schematic | Real components | Breadboard | IoT app)
  // ===========================================================================
  Widget _buildTopSectionTabBar(bool isNarrow) {
    final tabs = [
      {'label': 'Schematic', 'icon': LucideIcons.share2},
      {'label': 'Real components', 'icon': LucideIcons.cpu},
      {'label': 'Breadboard', 'icon': LucideIcons.grid},
      {'label': 'IoT app', 'icon': LucideIcons.cloud},
    ];

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else if (_activeSectionTab > 0) {
                setState(() => _activeSectionTab--);
              }
            },
            icon: const Icon(LucideIcons.arrowLeft, size: 18, color: Color(0xFF0F172A)),
            tooltip: 'Back',
          ),
          Expanded(
            child: Row(
              children: List.generate(tabs.length, (idx) {
                final tab = tabs[idx];
                final isSelected = _activeSectionTab == idx;

                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeSectionTab = idx),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tab['icon'] as IconData,
                            size: 16,
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF334155),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              tab['label'] as String,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isNarrow ? 12 : 13.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                              ),
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
          // AI Tutor Toggle Pill in Top Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              onTap: () => setState(() => _showAiTutorPanel = !_showAiTutorPanel),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _showAiTutorPanel ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF0077B6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.smart_toy_rounded, size: 15, color: Color(0xFF0077B6)),
                    if (!isNarrow) ...[
                      const SizedBox(width: 4),
                      const Text(
                        'AI Tutor',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0077B6)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. SUB-TOOLBAR PER SECTION (Image 1, Image 2, Image 3)
  // ===========================================================================
  Widget _buildSectionSubToolbar(bool isNarrow) {
    // IMAGE 2 SUB-TOOLBAR: Real components (Start | Electrons | Current | Voltage | Slow/Normal/Fast)
    if (_activeSectionTab == 1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildBackGreyButton(),
              const SizedBox(width: 10),
              _buildGreenStartButton(),
              const SizedBox(width: 10),
              _buildOrangeTogglePill(
                label: 'Electrons',
                active: _showElectrons,
                onTap: () => setState(() => _showElectrons = !_showElectrons),
              ),
              const SizedBox(width: 8),
              _buildOrangeTogglePill(
                label: 'Current',
                active: _showCurrent,
                onTap: () => setState(() => _showCurrent = !_showCurrent),
              ),
              const SizedBox(width: 8),
              _buildOrangeTogglePill(
                label: 'Voltage',
                active: _showVoltage,
                onTap: () => setState(() => _showVoltage = !_showVoltage),
              ),
              const SizedBox(width: 12),
              // Segmented Slow | Normal | Fast
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSpeedSegment(0, 'Slow', isFirst: true),
                    _buildSpeedSegment(1, 'Normal'),
                    _buildSpeedSegment(2, 'Fast', isLast: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _askAiTutor(),
                icon: const Icon(LucideIcons.bot, size: 15),
                label: const Text('Ask AI Tutor', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    // IMAGE 3 SUB-TOOLBAR: Breadboard (Back | Free build | 2D / 3D toggle | Wire tool | Zoom | Start)
    if (_activeSectionTab == 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildBackGreyButton(),
              const SizedBox(width: 12),
              // Project Dropdown ("Free build" / "Light an LED" / "Buzzer + Button")
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProject,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  items: ['Free build', 'Light an LED', 'Buzzer + Button', 'Distance Alarm']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedProject = v);
                  },
                ),
              ),
              const SizedBox(width: 16),

              // 2D / 3D Segmented Toggle Pill (Matches Image 3!)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF334155), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _build2D3DButton(is3D: false, label: '2D', icon: LucideIcons.grid),
                    _build2D3DButton(is3D: true, label: '3D', icon: LucideIcons.box),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Hint Bulb Circle Button
              InkWell(
                onTap: () {
                  setState(() => _showAiTutorPanel = true);
                  _askAiTutor();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE65100),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.lightbulb, color: Colors.white, size: 17),
                ),
              ),
              const SizedBox(width: 10),

              // Wire tool pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.gitCommit, size: 14, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Text('Wire tool', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Zoom controls
              IconButton(
                onPressed: () => setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.7, 1.5)),
                icon: const Icon(LucideIcons.zoomOut, size: 16),
                visualDensity: VisualDensity.compact,
              ),
              Text('${(_zoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              IconButton(
                onPressed: () => setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.7, 1.5)),
                icon: const Icon(LucideIcons.zoomIn, size: 16),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),

              // Trash / Reset
              IconButton(
                onPressed: () {
                  setState(() {
                    _isRunning = false;
                    _hasResistor = true;
                    _switchClosed = true;
                    _rotX = -0.45;
                    _rotZ = 0.25;
                  });
                },
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                tooltip: 'Reset Board',
              ),
              const SizedBox(width: 8),
              _buildGreenStartButton(),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _showComponentsDrawer = !_showComponentsDrawer),
                icon: Icon(
                  LucideIcons.layoutGrid,
                  size: 18,
                  color: _showComponentsDrawer ? const Color(0xFF0284C7) : Colors.grey,
                ),
                tooltip: 'Toggle Components Drawer',
              ),
            ],
          ),
        ),
      );
    }

    // IMAGE 1 SUB-TOOLBAR: Schematic (Light an LED title + subtitle | Toolbar icons | Green Start button)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Light an LED',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Text(
                'Make an LED glow from the battery at 5–30 mA without burning it out. Something must limit the current!',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _showAiTutorPanel = true);
                  _askAiTutor();
                },
                icon: const Icon(LucideIcons.lightbulb, size: 18, color: Color(0xFFE65100)),
                tooltip: 'AI Tutor Hint',
              ),
              IconButton(
                onPressed: () => setState(() => _hasResistor = !_hasResistor),
                icon: Icon(
                  LucideIcons.activity,
                  size: 18,
                  color: _hasResistor ? const Color(0xFF16A34A) : Colors.grey,
                ),
                tooltip: 'Toggle 330Ω Resistor',
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isRunning = false;
                    _hasResistor = true;
                    _switchClosed = true;
                  });
                },
                icon: const Icon(LucideIcons.trash2, size: 17, color: Color(0xFF475569)),
                tooltip: 'Reset Circuit',
              ),
              const SizedBox(width: 8),
              _buildGreenStartButton(),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _showComponentsDrawer = !_showComponentsDrawer),
                icon: Icon(
                  LucideIcons.layoutGrid,
                  size: 18,
                  color: _showComponentsDrawer ? const Color(0xFF0284C7) : Colors.grey,
                ),
                tooltip: 'Toggle Components Drawer',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackGreyButton() {
    return InkWell(
      onTap: () {
        if (_activeSectionTab > 0) {
          setState(() => _activeSectionTab--);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF78716C),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Back',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildGreenStartButton() {
    return ElevatedButton.icon(
      onPressed: _toggleSimulation,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isRunning ? const Color(0xFFDC2626) : const Color(0xFF43A047),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      icon: Icon(_isRunning ? LucideIcons.square : LucideIcons.play, size: 15),
      label: Text(
        _isRunning ? 'Stop' : 'Start',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildOrangeTogglePill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE65100) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? const Color(0xFFE65100) : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.check_rounded : Icons.close_rounded,
              size: 14,
              color: active ? Colors.white : const Color(0xFF334155),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedSegment(int idx, String label, {bool isFirst = false, bool isLast = false}) {
    final active = _simSpeed == idx;
    return InkWell(
      onTap: () => _setSpeed(idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE65100) : Colors.white,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(19) : Radius.zero,
            right: isLast ? const Radius.circular(19) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _build2D3DButton({required bool is3D, required String label, required IconData icon}) {
    final active = _is3DMode == is3D;
    return InkWell(
      onTap: () => setState(() => _is3DMode = is3D),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE65100) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : const Color(0xFF0F172A)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. AI TUTOR INTERACTIVE HELPER BANNER
  // ===========================================================================
  Widget _buildAiTutorBanner(bool isNarrow) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        border: Border(bottom: BorderSide(color: Color(0xFFBFDBFE))),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ZolaAvatar(size: 30),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Tutor Zola: $_tutorPraise',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                    ),
                    Text(
                      _tutorHint,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: isNarrow ? 180 : 240,
                height: 34,
                child: TextField(
                  controller: _tutorInputController,
                  onSubmitted: (_) => _askAiTutor(),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Ask AI Tutor about this circuit...',
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
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isAskingTutor ? null : () => _askAiTutor(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0077B6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(60, 34),
                ),
                child: Text(
                  _isAskingTutor ? '...' : 'Check Circuit',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. SECTION BODY SWITCHER
  // ===========================================================================
  Widget _buildActiveSectionBody(bool isNarrow) {
    switch (_activeSectionTab) {
      case 0:
        return _buildSchematicSection(isNarrow);
      case 1:
        return _buildRealComponentsSection(isNarrow);
      case 2:
        return _buildBreadboardSection(isNarrow);
      case 3:
        return _buildIotAppSection(isNarrow);
      default:
        return _buildBreadboardSection(isNarrow);
    }
  }

  // ---------------------------------------------------------------------------
  // SECTION 0: SCHEMATIC VIEW + COMPONENTS DRAWER (IMAGE 1)
  // ---------------------------------------------------------------------------
  Widget _buildSchematicSection(bool isNarrow) {
    final canvasArea = Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _electronController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _SchematicTabPainter(
                        isRunning: _isRunning,
                        hasResistor: _hasResistor,
                        batteryV: _batteryVoltage,
                        resistorOhms: _resistorOhms.toInt(),
                        currentMa: _currentMa,
                        progress: _electronController.value,
                      ),
                    );
                  },
                ),
                // Bottom-left Help (?) Floating Circle
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: FloatingActionButton.small(
                    heroTag: 'schematic_help',
                    backgroundColor: const Color(0xFF0077B6),
                    onPressed: () {
                      setState(() => _showAiTutorPanel = true);
                      _askAiTutor(customQuestion: 'How do I wire the schematic so the LED does not burn out?');
                    },
                    child: const Text('?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'To wire: tap one end dot, then tap another end dot (or drag between them). Add a 330 Ω Resistor from the Components panel on the right, then press Start to run.',
            style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ),
      ],
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 360, child: canvasArea),
            if (_showComponentsDrawer)
              SizedBox(height: 420, child: _buildRightComponentsDrawer()),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(flex: 7, child: canvasArea),
        if (_showComponentsDrawer)
          SizedBox(width: 320, child: _buildRightComponentsDrawer()),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 1: REAL COMPONENTS + DARK OUTPUT CONSOLE (IMAGE 2)
  // ---------------------------------------------------------------------------
  Widget _buildRealComponentsSection(bool isNarrow) {
    final realCanvas = Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 14,
            left: 16,
            child: Text(
              'REAL COMPONENTS (live from the schematic)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.4,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _electronController,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _RealComponentsTabPainter(
                  isRunning: _isRunning,
                  hasResistor: _hasResistor,
                  showElectrons: _showElectrons,
                  showCurrent: _showCurrent,
                  showVoltage: _showVoltage,
                  batteryV: _batteryVoltage,
                  resistorOhms: _resistorOhms.toInt(),
                  currentMa: _currentMa,
                  progress: _electronController.value,
                ),
              );
            },
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: FloatingActionButton.small(
              heroTag: 'real_help',
              backgroundColor: const Color(0xFF7C3AED),
              onPressed: () {
                setState(() => _showAiTutorPanel = true);
                _askAiTutor(customQuestion: 'Explain what the electrons, current, and voltage colors show in Real Components view.');
              },
              child: const Text('?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ),
        ],
      ),
    );

    final outputConsole = Container(
      margin: EdgeInsets.fromLTRB(isNarrow ? 12 : 0, 12, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Console Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isRunning ? const Color(0xFF22C55E) : const Color(0xFF64748B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'OUTPUT CONSOLE',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                  ),
                ],
              ),
              Text(
                _isRunning ? 'RUNNING' : 'STOPPED',
                style: TextStyle(
                  color: _isRunning ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 24),

          // Live Telemetry Table Header
          const Row(
            children: [
              Expanded(flex: 2, child: Text('PART', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('VALUE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('VOLTAGE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('CURRENT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('STATE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 10),
          _buildConsolePartRow(
            'B1',
            '${_batteryVoltage.toStringAsFixed(1)} V',
            _isRunning ? '${_batteryVoltage.toStringAsFixed(1)} V' : '-',
            _isRunning ? '${_currentMa.toStringAsFixed(1)} mA' : '-',
            _isRunning ? 'supplying' : '-',
          ),
          if (_hasResistor)
            _buildConsolePartRow(
              'R1',
              '${_resistorOhms.toInt()} Ω',
              _isRunning ? '${(_batteryVoltage - 2.0).toStringAsFixed(1)} V' : '-',
              _isRunning ? '${_currentMa.toStringAsFixed(1)} mA' : '-',
              _isRunning ? 'limiting' : '-',
            ),
          _buildConsolePartRow(
            'LED1',
            _ledColorName,
            _isRunning ? '2.0 V' : '-',
            _isRunning ? '${_currentMa.toStringAsFixed(1)} mA' : '-',
            _isLedBurned ? 'BURNED!' : (_isLedGlowing ? 'ON (glow)' : 'off'),
            isAlert: _isLedBurned,
          ),

          const SizedBox(height: 20),
          const Text(
            'EVENT LOG',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _eventLogs.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _eventLogs[i],
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 360, child: realCanvas),
            SizedBox(height: 290, child: outputConsole),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(flex: 7, child: realCanvas),
        Expanded(flex: 4, child: outputConsole),
      ],
    );
  }

  Widget _buildConsolePartRow(
    String part,
    String val,
    String volt,
    String curr,
    String state, {
    bool isAlert = false,
  }) {
    final stateColor = isAlert
        ? const Color(0xFFEF4444)
        : (_isRunning ? const Color(0xFF4ADE80) : const Color(0xFFCBD5E1));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(part, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
          Expanded(flex: 2, child: Text(val, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
          Expanded(flex: 2, child: Text(volt, style: TextStyle(color: stateColor, fontSize: 12))),
          Expanded(flex: 2, child: Text(curr, style: TextStyle(color: stateColor, fontSize: 12))),
          Expanded(flex: 2, child: Text(state, style: TextStyle(color: stateColor, fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 2: BREADBOARD 2D & 3D VIEW + COMPONENTS DRAWER (IMAGE 3)
  // ---------------------------------------------------------------------------
  Widget _buildBreadboardSection(bool isNarrow) {
    final breadboardWorkspace = Column(
      children: [
        // 3D Mode Rotation Bar when 3D is active
        if (_is3DMode)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.box, size: 16, color: Color(0xFFE65100)),
                    SizedBox(width: 8),
                    Text(
                      '3D Isometric Breadboard View — Drag on board or use sliders to rotate 3D angle:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF9A3412)),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tilt:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: _rotX,
                        min: -0.85,
                        max: 0.0,
                        activeColor: const Color(0xFFE65100),
                        onChanged: (v) => setState(() => _rotX = v),
                      ),
                    ),
                    const Text('Spin:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: _rotZ,
                        min: -0.6,
                        max: 0.6,
                        activeColor: const Color(0xFFE65100),
                        onChanged: (v) => setState(() => _rotZ = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Left Tray: "Power and tools"
                if (!isNarrow)
                  Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Power and tools',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                        ),
                        Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('SW1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              value: _switchClosed,
                              activeColor: const Color(0xFF16A34A),
                              onChanged: (v) => setState(() => _switchClosed = v),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF475569), width: 2),
                              ),
                              child: Text(
                                '${_batteryVoltage.toInt()} V',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Center Solderless Breadboard (2D or 3D Perspective Transform)
                Expanded(
                  child: GestureDetector(
                    onPanUpdate: _is3DMode
                        ? (details) {
                            setState(() {
                              _rotZ = (_rotZ + details.delta.dx * 0.005).clamp(-0.65, 0.65);
                              _rotX = (_rotX + details.delta.dy * 0.005).clamp(-0.85, 0.0);
                            });
                          }
                        : null,
                    onTap: () => setState(() => _switchClosed = !_switchClosed),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      // 3D: the live Learnix 3D breadboard renderer (lit solids, tube wires, glowing LED).
                      child: _is3DMode
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: Scene3Painter(
                                      build: _board3DScene,
                                      yaw: _rotZ * 1.6,
                                      pitch: 1.25 + _rotX * 0.7,
                                      zoom: _zoomLevel,
                                      repaint: _electronController,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: FilledButton.icon(
                                    onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                                      fullscreenDialog: true,
                                      builder: (_) => Board3DFullScreen(build: _board3DScene, repaint: _electronController, yaw: _rotZ * 1.6, pitch: 1.25 + _rotX * 0.7),
                                    )),
                                    icon: const Icon(Icons.fullscreen_rounded, size: 18),
                                    label: const Text('Full screen'),
                                    style: FilledButton.styleFrom(backgroundColor: Colors.black54, visualDensity: VisualDensity.compact),
                                  ),
                                ),
                              ]),
                            )
                          : Center(
                        child: Transform.scale(
                          scale: _zoomLevel,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            transformAlignment: Alignment.center,
                            transform: _is3DMode
                                ? (Matrix4.identity()
                                  ..setEntry(3, 2, 0.0012)
                                  ..rotateX(_rotX)
                                  ..rotateZ(_rotZ))
                                : Matrix4.identity(),
                            child: AspectRatio(
                              aspectRatio: 1.55,
                              child: Container(
                                margin: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3EFE6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF94A3B8), width: 1.8),
                                  boxShadow: _is3DMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.28),
                                            blurRadius: 28,
                                            offset: const Offset(12, 22),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: AnimatedBuilder(
                                  animation: _electronController,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      painter: _Breadboard2D3DPainter(
                                        is3D: _is3DMode,
                                        isRunning: _isRunning,
                                        hasResistor: _hasResistor,
                                        switchClosed: _switchClosed,
                                        resistorOhms: _resistorOhms.toInt(),
                                        currentMa: _currentMa,
                                        progress: _electronController.value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Right Tray: "Parts"
                if (!isNarrow)
                  Container(
                    width: 110,
                    margin: const EdgeInsets.only(left: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Parts',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          _is3DMode ? '🧊 3D Active' : '⊞ 2D Active',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_currentMa.toStringAsFixed(1)} mA',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Bottom instruction caption
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _is3DMode
                ? '3D Breadboard Mode: Drag anywhere on the breadboard or use the Tilt/Spin sliders above to inspect the 3D LED, resistor, and jumper wire arches!'
                : 'Plug a component\'s legs into breadboard holes. Holes in the same column strip (a–e or f–j) are joined; the rails run the full length. Tap the switch or press Start to run.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ),
      ],
    );

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 430, child: breadboardWorkspace),
            if (_showComponentsDrawer)
              SizedBox(height: 420, child: _buildRightComponentsDrawer()),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(flex: 7, child: breadboardWorkspace),
        if (_showComponentsDrawer)
          SizedBox(width: 310, child: _buildRightComponentsDrawer()),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 3: IOT APP & ARDUINO CODE WORKBENCH
  // ---------------------------------------------------------------------------
  Widget _buildIotAppSection(bool isNarrow) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '☁️ IoT App & Arduino Firmware Controller',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Control your breadboard remotely and inspect the live C++ firmware running on the microcontroller.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // Remote Switch Card
              Container(
                width: isNarrow ? double.infinity : 300,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Remote LED & Power Control', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Master Simulation Power'),
                      value: _isRunning,
                      activeColor: const Color(0xFF16A34A),
                      onChanged: (_) => _toggleSimulation(),
                    ),
                    SwitchListTile(
                      title: const Text('330 Ω Protection Resistor'),
                      value: _hasResistor,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (v) => setState(() => _hasResistor = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Live Telemetry: ${_currentMa.toStringAsFixed(1)} mA @ ${_batteryVoltage.toStringAsFixed(1)} V',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
              ),
              // Code Panel
              Container(
                width: isNarrow ? double.infinity : 480,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '// sketch.ino — Connected IoT Firmware',
                      style: TextStyle(color: Color(0xFF4ADE80), fontFamily: 'monospace', fontSize: 12),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'void setup() {\n  pinMode(13, OUTPUT);\n}\n\nvoid loop() {\n  digitalWrite(13, HIGH); // 5V -> 330Ω -> LED1\n  delay(1000);\n  digitalWrite(13, LOW);\n  delay(1000);\n}',
                      style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RIGHT DRAWER: "Components (43)" WITH SEARCH, FILTERS & SUGGESTED NEXT
  // ===========================================================================
  Widget _buildRightComponentsDrawer() {
    final categories = ['All', 'Power', 'Passive', 'Output'];
    final filteredParts = _allParts.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategoryIdx == 0 ||
          p['category'].toString().toLowerCase().contains(categories[_selectedCategoryIdx].toLowerCase());
      return matchesSearch && matchesCat;
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "⊞ Components   43   ✕"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                const Icon(LucideIcons.layoutGrid, size: 17, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Components',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ),
                Text('43', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => setState(() => _showComponentsDrawer = false),
                  icon: const Icon(LucideIcons.x, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Search Bar: "🔍 Search parts (led, servo, wifi...)"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Search parts (led, servo, wifi...)',
                  prefixIcon: const Icon(LucideIcons.search, size: 15),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Filter Chips: "✓ All" | "⚡ Power" | "~ Passive" | "△ Output"
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: List.generate(categories.length, (idx) {
                final isSelected = _selectedCategoryIdx == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategoryIdx = idx),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE65100) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE65100) : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            categories[idx],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF0F172A),
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
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Parts Grid ("✨ Suggested next" + "All parts")
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.sparkles, size: 14, color: Color(0xFFF59E0B)),
                      SizedBox(width: 6),
                      Text(
                        'Suggested next',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPartCard(
                          name: 'Resistor',
                          category: _hasResistor ? '330 Ω Active' : 'Tap to Add',
                          icon: LucideIcons.activity,
                          color: const Color(0xFF78350F),
                          highlighted: !_hasResistor,
                          onTap: () {
                            setState(() {
                              _hasResistor = !_hasResistor;
                              _eventLogs.add(_hasResistor
                                  ? '> Added 330 Ω Resistor in series'
                                  : '> Removed 330 Ω Resistor');
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildPartCard(
                          name: 'Multimeter',
                          category: '${_currentMa.toStringAsFixed(1)} mA',
                          icon: LucideIcons.gauge,
                          color: const Color(0xFF0284C7),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Multimeter Probe: V = ${_batteryVoltage}V, I = ${_currentMa.toStringAsFixed(1)} mA'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'All parts',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 106,
                    ),
                    itemCount: filteredParts.length,
                    itemBuilder: (ctx, i) {
                      final part = filteredParts[i];
                      return _buildPartCard(
                        name: part['name'] as String,
                        category: part['category'] as String,
                        icon: part['icon'] as IconData,
                        color: part['color'] as Color,
                        onTap: () {
                          final pName = part['name'] as String;
                          setState(() {
                            if (pName == 'Resistor') {
                              _hasResistor = !_hasResistor;
                            } else if (pName == 'RGB LED') {
                              _ledColorName = _ledColorName == 'Red' ? 'Cyan' : 'Red';
                            } else if (pName == 'Push Button') {
                              _switchClosed = !_switchClosed;
                            }
                            _eventLogs.add('> Interacted with $pName (${part['value']})');
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 2),
                              content: Text('Updated $pName on workbench!'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartCard({
    required String name,
    required String category,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted ? const Color(0xFFE65100) : const Color(0xFFE2E8F0),
            width: highlighted ? 1.8 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: 0,
              right: 0,
              child: Icon(LucideIcons.info, size: 13, color: Color(0xFF94A3B8)),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PAINTER 1: SCHEMATIC TAB (IMAGE 1)
// =============================================================================
class _SchematicTabPainter extends CustomPainter {
  final bool isRunning;
  final bool hasResistor;
  final double batteryV;
  final int resistorOhms;
  final double currentMa;
  final double progress;

  _SchematicTabPainter({
    required this.isRunning,
    required this.hasResistor,
    required this.batteryV,
    required this.resistorOhms,
    required this.currentMa,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dot grid
    final dotPaint = Paint()..color = const Color(0xFFCBD5E1).withOpacity(0.6);
    for (double x = 16; x < size.width; x += 18) {
      for (double y = 16; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }

    final left = size.width * 0.24;
    final right = size.width * 0.62;
    final top = size.height * 0.30;
    final bottom = size.height * 0.64;

    final wirePaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), wirePaint);

    // Voltage source box on left wire
    final midY = (top + bottom) / 2;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(left, midY), width: 28, height: 50),
      const Radius.circular(4),
    );
    canvas.drawRRect(boxRect, Paint()..color = const Color(0xFFFEF08A));
    canvas.drawRRect(
      boxRect,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawLabel(canvas, '+', Offset(left + 10, top + 6), const Color(0xFFDC2626), 13);
    _drawLabel(canvas, '−', Offset(left + 10, bottom - 22), const Color(0xFF0F172A), 13);
    _drawLabel(canvas, '${batteryV.toStringAsFixed(1)} V', Offset(left - 18, bottom - 18), const Color(0xFF0F172A), 12);

    // Optional Resistor symbol on top-left wire
    if (hasResistor) {
      final rx = left + (right - left) * 0.32;
      final rRect = Rect.fromCenter(center: Offset(rx, top), width: 44, height: 14);
      canvas.drawRect(rRect, Paint()..color = const Color(0xFFFDE68A));
      canvas.drawRect(
        rRect,
        Paint()
          ..color = const Color(0xFF78350F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      _drawLabel(canvas, '$resistorOhms Ω', Offset(rx - 18, top - 24), const Color(0xFF78350F), 11.5);
    }

    // LED schematic diode symbol on top-right wire
    final lx = left + (right - left) * 0.72;
    if (isRunning) {
      canvas.drawCircle(
        Offset(lx, top),
        32,
        Paint()
          ..color = const Color(0xFFEF4444).withOpacity(0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    final tri = Path()
      ..moveTo(lx - 12, top - 12)
      ..lineTo(lx - 12, top + 12)
      ..lineTo(lx + 10, top)
      ..close();
    canvas.drawPath(tri, Paint()..color = const Color(0xFFFECACA));
    canvas.drawPath(
      tri,
      Paint()
        ..color = const Color(0xFF7F1D1D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Cathode bar
    canvas.drawLine(
      Offset(lx + 10, top - 12),
      Offset(lx + 10, top + 12),
      Paint()
        ..color = const Color(0xFF7F1D1D)
        ..strokeWidth = 2.2,
    );
    _drawLabel(canvas, 'Red', Offset(lx - 12, top + 20), const Color(0xFF0F172A), 12);

    // Blue connection terminal circles
    final nodes = [
      Offset(left, top),
      Offset(left, bottom),
      Offset(lx - 32, top),
      Offset(right, top),
    ];
    for (final n in nodes) {
      canvas.drawCircle(n, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        n,
        5.5,
        Paint()
          ..color = const Color(0xFF0284C7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    if (isRunning) {
      _drawLabel(
        canvas,
        hasResistor ? 'I = ${currentMa.toStringAsFixed(1)} mA (Safe Glow)' : '⚠️ 85.0 mA OVERCURRENT! Add Resistor!',
        Offset(left + 20, midY - 8),
        hasResistor ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        13,
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _SchematicTabPainter oldDelegate) => true;
}

// =============================================================================
// PAINTER 2: REAL COMPONENTS TAB (IMAGE 2)
// =============================================================================
class _RealComponentsTabPainter extends CustomPainter {
  final bool isRunning;
  final bool hasResistor;
  final bool showElectrons;
  final bool showCurrent;
  final bool showVoltage;
  final double batteryV;
  final int resistorOhms;
  final double currentMa;
  final double progress;

  _RealComponentsTabPainter({
    required this.isRunning,
    required this.hasResistor,
    required this.showElectrons,
    required this.showCurrent,
    required this.showVoltage,
    required this.batteryV,
    required this.resistorOhms,
    required this.currentMa,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFFCBD5E1);
    for (double x = 24; x < size.width; x += 44) {
      for (double y = 36; y < size.height; y += 44) {
        canvas.drawCircle(Offset(x, y), 1.6, dotPaint);
      }
    }

    final left = size.width * 0.28;
    final right = size.width * 0.68;
    final top = size.height * 0.36;
    final bottom = size.height * 0.72;

    // Positive Top Wire (Red when Voltage view is enabled)
    canvas.drawLine(
      Offset(left, top),
      Offset(left + (right - left) * 0.45, top),
      Paint()
        ..color = showVoltage ? const Color(0xFFDC2626) : const Color(0xFF475569)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(left + (right - left) * 0.45, top),
      Offset(right, top),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 4,
    );
    // Right & Bottom Return Wire (Dark Grey)
    final returnPath = Path()
      ..moveTo(right, top)
      ..lineTo(right, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left, top);
    canvas.drawPath(
      returnPath,
      Paint()
        ..color = const Color(0xFF334155)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // 3V / 5V Cylinder Battery
    final midY = (top + bottom) / 2;
    final batRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(left, midY), width: 46, height: 84),
      const Radius.circular(8),
    );
    canvas.drawRRect(batRect, Paint()..color = const Color(0xFF334155));
    canvas.drawRRect(
      batRect,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawLabel(canvas, '${batteryV.toInt()}V', Offset(left - 13, midY - 10), Colors.white, 15);
    _drawLabel(canvas, '+', Offset(left + 26, top + 8), const Color(0xFFDC2626), 16);
    _drawLabel(canvas, '−', Offset(left + 26, bottom - 22), const Color(0xFF0F172A), 16);

    // White pill label "B1 5.0 V"
    _drawWhitePill(canvas, Offset(left, bottom + 24), 'B1  ${batteryV.toStringAsFixed(1)} V');

    // Optional Resistor on top wire
    if (hasResistor) {
      final rx = left + (right - left) * 0.35;
      final rRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(rx, top), width: 46, height: 16),
        const Radius.circular(8),
      );
      canvas.drawRRect(rRect, Paint()..color = const Color(0xFFFDE68A));
      canvas.drawRRect(
        rRect,
        Paint()
          ..color = const Color(0xFFB45309)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // Physical Translucent Red LED Circle & Flat Cathode Bar
    final lx = left + (right - left) * 0.72;
    if (isRunning) {
      canvas.drawCircle(
        Offset(lx, top),
        42,
        Paint()
          ..color = const Color(0xFFEF4444).withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    canvas.drawRect(
      Rect.fromCenter(center: Offset(lx - 18, top), width: 6, height: 36),
      Paint()..color = const Color(0xFFD97777),
    );
    canvas.drawCircle(
      Offset(lx, top),
      19,
      Paint()..color = isRunning ? const Color(0xFFEF4444) : const Color(0xFFFCA5A5),
    );
    canvas.drawCircle(
      Offset(lx, top),
      19,
      Paint()
        ..color = const Color(0xFF450A0A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // White pill label "LED1 Red"
    _drawWhitePill(canvas, Offset(lx, top + 56), 'LED1  Red');

    // Terminal circles
    for (final pt in [Offset(left, top), Offset(left, bottom), Offset(right, top)]) {
      canvas.drawCircle(pt, 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        pt,
        6,
        Paint()
          ..color = const Color(0xFF475569)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Flowing Electrons when enabled
    if (showElectrons && isRunning) {
      final w = right - left;
      final h = bottom - top;
      final perim = 2 * (w + h);
      for (int i = 0; i < 10; i++) {
        final f = ((i / 10) + progress) % 1.0;
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
        canvas.drawCircle(p, 4.5, Paint()..color = const Color(0xFFFACC15));
      }
    }

    if (showCurrent && isRunning) {
      _drawLabel(
        canvas,
        'I = ${currentMa.toStringAsFixed(1)} mA',
        Offset((left + right) / 2 - 36, midY),
        const Color(0xFFE65100),
        14,
      );
    }
  }

  void _drawWhitePill(Canvas canvas, Offset center, String text) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 88, height: 28),
      const Radius.circular(10),
    );
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke,
    );
    _drawLabel(canvas, text, Offset(center.dx - 32, center.dy - 8), const Color(0xFF0F172A), 12);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _RealComponentsTabPainter oldDelegate) => true;
}

// =============================================================================
// PAINTER 3: BREADBOARD 2D & 3D VIEW (IMAGE 3)
// =============================================================================
class _Breadboard2D3DPainter extends CustomPainter {
  final bool is3D;
  final bool isRunning;
  final bool hasResistor;
  final bool switchClosed;
  final int resistorOhms;
  final double currentMa;
  final double progress;

  _Breadboard2D3DPainter({
    required this.is3D,
    required this.isRunning,
    required this.hasResistor,
    required this.switchClosed,
    required this.resistorOhms,
    required this.currentMa,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 3D Extruded Board Base Side Shadow if in 3D mode
    if (is3D) {
      final depthPath = Path()
        ..moveTo(0, size.height)
        ..lineTo(10, size.height + 14)
        ..lineTo(size.width + 10, size.height + 14)
        ..lineTo(size.width + 10, 14)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(depthPath, Paint()..color = const Color(0xFFCBD5E1));
    }

    // Power rail red & blue/black lines (top and bottom)
    final redLinePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.5;
    final darkLinePaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(24, size.height * 0.06), Offset(size.width - 24, size.height * 0.06), redLinePaint);
    canvas.drawLine(Offset(24, size.height * 0.17), Offset(size.width - 24, size.height * 0.17), darkLinePaint);

    canvas.drawLine(Offset(24, size.height * 0.83), Offset(size.width - 24, size.height * 0.83), redLinePaint);
    canvas.drawLine(Offset(24, size.height * 0.94), Offset(size.width - 24, size.height * 0.94), darkLinePaint);

    // Center trench divider
    canvas.drawRect(
      Rect.fromLTRB(16, size.height * 0.48, size.width - 16, size.height * 0.52),
      Paint()..color = const Color(0xFFDDD6C7),
    );

    // Breadboard Holes Grid (30 columns)
    final holePaint = Paint()..color = const Color(0xFF3F3F46);
    const cols = 28;
    final startX = size.width * 0.06;
    final endX = size.width * 0.94;
    final colStep = (endX - startX) / (cols - 1);

    final rowFracs = <double>[
      0.09, 0.14, // Top power rails (+ / -)
      0.26, 0.31, 0.36, 0.41, 0.45, // Rows a, b, c, d, e
      0.55, 0.59, 0.64, 0.69, 0.74, // Rows f, g, h, i, j
      0.86, 0.91, // Bottom power rails (+ / -)
    ];

    for (int c = 0; c < cols; c++) {
      final x = startX + c * colStep;
      for (final rf in rowFracs) {
        final y = size.height * rf;
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: 4.5, height: 4.5),
          holePaint,
        );
      }
    }

    // Placed Components on Upper Left (matching Image 3!)
    final c1X = startX + 1 * colStep;
    final c3X = startX + 3 * colStep;
    final c5X = startX + 5 * colStep;
    final c7X = startX + 7 * colStep;
    final c9X = startX + 9 * colStep;

    final railPlusY = size.height * 0.09;
    final railMinusY = size.height * 0.14;
    final rowBY = size.height * 0.31;
    final rowCY = size.height * 0.36;

    // Red & Black power supply wires going down to 5V bottom left
    final wireRed = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final wireBlack = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(c1X, railMinusY), Offset(c1X - 4, size.height), wireBlack);
    canvas.drawLine(Offset(c1X + colStep, railPlusY), Offset(c1X + colStep - 4, size.height), wireRed);

    // Jumper wire from top + rail to row B col 3
    canvas.drawLine(Offset(c3X, railPlusY), Offset(c3X, rowBY), wireRed);

    // Slide Switch (SW1) at col 3-5
    final swRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset((c3X + c5X) / 2, rowCY), width: 28, height: 15),
      const Radius.circular(3),
    );
    canvas.drawRRect(swRect, Paint()..color = const Color(0xFFCBD5E1));
    canvas.drawRRect(
      swRect,
      Paint()
        ..color = const Color(0xFF16A34A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(switchClosed ? c5X - 6 : c3X + 6, rowCY),
        width: 8,
        height: 9,
      ),
      Paint()..color = switchClosed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
    );

    // 330 Ω Resistor angled between col 5 and col 7 (with 3D elevation offset if is3D)
    final lift = is3D ? -10.0 : 0.0;
    if (hasResistor) {
      canvas.drawLine(
        Offset(c5X, rowCY),
        Offset(c7X, rowBY + lift),
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = 2.2,
      );
      final resCenter = Offset((c5X + c7X) / 2, (rowCY + rowBY) / 2 - 4 + lift);
      final rRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: resCenter, width: 32, height: 12),
        const Radius.circular(6),
      );
      canvas.drawRRect(rRect, Paint()..color = const Color(0xFFD97706));
      _drawSmallText(canvas, '$resistorOhms Ω', Offset(resCenter.dx - 16, resCenter.dy + 14), const Color(0xFF0F172A));
    }

    // Red LED with Anode (A) and Cathode (K) legs at col 7 & col 9
    final ledCenter = Offset((c7X + c9X) / 2, rowBY - 18 + (is3D ? -14 : 0));
    // LED legs
    canvas.drawLine(
      ledCenter,
      Offset(c7X, rowBY),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      ledCenter,
      Offset(c9X, rowBY),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 2,
    );

    final glowing = isRunning && switchClosed && hasResistor;
    if (glowing) {
      canvas.drawCircle(
        ledCenter,
        34,
        Paint()
          ..color = const Color(0xFFEF4444).withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    final ledDome = RRect.fromRectAndCorners(
      Rect.fromCenter(center: ledCenter, width: 18, height: 22),
      topLeft: const Radius.circular(9),
      topRight: const Radius.circular(9),
      bottomLeft: const Radius.circular(3),
      bottomRight: const Radius.circular(3),
    );
    canvas.drawRRect(
      ledDome,
      Paint()..color = glowing ? const Color(0xFFEF4444) : const Color(0xFFFCA5A5),
    );
    canvas.drawRRect(
      ledDome,
      Paint()
        ..color = const Color(0xFF7F1D1D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    _drawSmallText(canvas, 'A', Offset(c7X - 4, rowCY + 8), const Color(0xFFDC2626));
    _drawSmallText(canvas, 'K', Offset(c9X - 4, rowCY + 8), const Color(0xFF0F172A));

    // Curved Black Return Jumper Arch from Cathode col 9 back to top Minus rail
    final archPath = Path()
      ..moveTo(c9X, rowBY)
      ..quadraticBezierTo(
        (c5X + c9X) / 2,
        railMinusY - (is3D ? 28 : 14),
        c5X,
        railMinusY,
      );
    canvas.drawPath(archPath, wireBlack);
  }

  void _drawSmallText(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _Breadboard2D3DPainter oldDelegate) => true;
}
