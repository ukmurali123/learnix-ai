import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_card.dart';

class VirtualLabScreen extends StatefulWidget {
  final String baseUrl;

  const VirtualLabScreen({super.key, required this.baseUrl});

  @override
  State<VirtualLabScreen> createState() => _VirtualLabScreenState();
}

class _VirtualLabScreenState extends State<VirtualLabScreen> {
  int _selectedExp = 1;
  bool _isRunning = false;
  bool _ledLit = false;
  String _labPartnerMsg = 'Welcome to the workbench! Connect LED Anode to Pin 13 through a 220Ω resistor and Cathode to GND.';

  final String _sampleArduinoCode = '''// Experiment 1: LED Blink
void setup() {
  pinMode(13, OUTPUT);
}

void loop() {
  digitalWrite(13, HIGH); // LED turns on
  delay(1000);
  digitalWrite(13, LOW);  // LED turns off
  delay(1000);
}''';

  void _runSimulation() {
    setState(() {
      _isRunning = true;
      _ledLit = true;
      _labPartnerMsg = '🌟 Great job! Pin 13 is HIGH, and current is safely flowing through the 220Ω resistor to ground. The LED is glowing!';
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isRunning = false);
    });
  }

  void _triggerFaultyCircuit() {
    setState(() {
      _isRunning = true;
      _ledLit = false;
      _labPartnerMsg = '⚠️ AI Lab Partner Hint: The LED didn\'t light up. Check the GND wire — remember, every circuit must form a complete loop back to ground!';
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isRunning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.space32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔬 Virtual Lab — Hardware Workbench', style: textTheme.displayLarge),
                  SizedBox(height: tokens.space8),
                  Text('Wire real circuits, run Arduino code in the simulator, and get real-time debugging hints.', style: textTheme.bodyMedium),
                ],
              ),
              // Experiment Selector Chips
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Exp 1: LED Blink'),
                    selected: _selectedExp == 1,
                    onSelected: (val) => setState(() => _selectedExp = 1),
                  ),
                  SizedBox(width: tokens.space8),
                  ChoiceChip(
                    label: const Text('Exp 2: Buzzer + Button'),
                    selected: _selectedExp == 2,
                    onSelected: (val) => setState(() => _selectedExp = 2),
                  ),
                  SizedBox(width: tokens.space8),
                  ChoiceChip(
                    label: const Text('Exp 3: Ultrasonic Alarm'),
                    selected: _selectedExp == 3,
                    onSelected: (val) => setState(() => _selectedExp = 3),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: tokens.space24),

          // Component Tray
          Container(
            padding: EdgeInsets.symmetric(horizontal: tokens.space24, vertical: tokens.space12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: tokens.borderRadius16,
              border: Border.all(color: tokens.borderSubtle),
              boxShadow: tokens.cardShadow,
            ),
            child: Row(
              children: [
                Text('COMPONENT TRAY:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tokens.textSecondary, letterSpacing: 0.5)),
                SizedBox(width: tokens.space16),
                _buildTrayItem(LucideIcons.cpu, 'Arduino Uno'),
                _buildTrayItem(LucideIcons.lightbulb, 'LED (Red)'),
                _buildTrayItem(LucideIcons.minus, '220Ω Resistor'),
                _buildTrayItem(LucideIcons.volume2, 'Piezo Buzzer'),
                _buildTrayItem(LucideIcons.radio, 'Ultrasonic Sensor'),
                _buildTrayItem(LucideIcons.toggleLeft, 'Push Button'),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          SizedBox(height: tokens.space24),

          // Main Workbench Split: Dark Canvas Board (Left) & Code Editor (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dark Canvas Workbench
              Expanded(
                flex: 3,
                child: Container(
                  height: 480,
                  padding: EdgeInsets.all(tokens.space24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: tokens.borderRadius16,
                    border: Border.all(color: const Color(0xFF334155), width: 1.5),
                    boxShadow: tokens.cardShadow,
                  ),
                  child: Stack(
                    children: [
                      // Canvas Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _isRunning ? Colors.greenAccent : Colors.amberAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: tokens.space8),
                              Text(
                                _isRunning ? 'SIMULATION RUNNING' : 'BREADBOARD READY',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(onPressed: () {}, icon: const Icon(LucideIcons.zoomIn, color: Colors.white70, size: 16)),
                              IconButton(onPressed: () {}, icon: const Icon(LucideIcons.zoomOut, color: Colors.white70, size: 16)),
                              IconButton(onPressed: () {}, icon: const Icon(LucideIcons.rotateCcw, color: Colors.white70, size: 16)),
                            ],
                          ),
                        ],
                      ),

                      // Circuit Visual Simulation
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // LED Glow Visual
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _ledLit ? const Color(0xFFFF3366) : const Color(0xFF475569),
                                boxShadow: _ledLit
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFF3366).withOpacity(0.8),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Icon(
                                  LucideIcons.lightbulb,
                                  color: _ledLit ? Colors.white : Colors.white24,
                                  size: 40,
                                ),
                              ),
                            ),
                            SizedBox(height: tokens.space16),
                            Text(
                              _ledLit ? 'LED State: HIGH (Glowing)' : 'LED State: LOW (Off)',
                              style: TextStyle(
                                color: _ledLit ? Colors.greenAccent : Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: tokens.space8),
                            const Text(
                              'Wiring: Arduino Pin 13 ──[220Ω]──► LED Anode | Cathode ────► GND',
                              style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),

                      // Canvas Bottom Action Bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _runSimulation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.success,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(LucideIcons.play, size: 16),
                              label: const Text('Run Circuit'),
                            ),
                            SizedBox(width: tokens.space12),
                            OutlinedButton.icon(
                              onPressed: _triggerFaultyCircuit,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: tokens.accent,
                                side: BorderSide(color: tokens.accent),
                              ),
                              icon: const Icon(LucideIcons.bug, size: 16),
                              label: const Text('Test Faulty Wire'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: tokens.space24),

              // Code Editor & AI Lab Partner (Right)
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Code Editor Panel
                    Container(
                      height: 310,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: tokens.borderRadius16,
                        border: Border.all(color: const Color(0xFF334155)),
                        boxShadow: tokens.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: tokens.space16, vertical: tokens.space8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F172A),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(LucideIcons.fileCode, size: 14, color: Colors.white70),
                                SizedBox(width: 8),
                                Text('sketch.ino (Arduino C++)', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(tokens.space12),
                              child: SelectableText.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: '// Experiment 1: LED Blink\n', style: TextStyle(color: Colors.green.shade400, fontStyle: FontStyle.italic)),
                                    TextSpan(text: 'void ', style: TextStyle(color: Colors.purple.shade300, fontWeight: FontWeight.bold)),
                                    const TextSpan(text: 'setup() {\n  ', style: TextStyle(color: Colors.white)),
                                    TextSpan(text: 'pinMode', style: TextStyle(color: Colors.cyan.shade300)),
                                    const TextSpan(text: '(13, ', style: TextStyle(color: Colors.white)),
                                    TextSpan(text: 'OUTPUT', style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold)),
                                    const TextSpan(text: ');\n}\n\n', style: TextStyle(color: Colors.white)),
                                    TextSpan(text: 'void ', style: TextStyle(color: Colors.purple.shade300, fontWeight: FontWeight.bold)),
                                    const TextSpan(text: 'loop() {\n  ', style: TextStyle(color: Colors.white)),
                                    TextSpan(text: 'digitalWrite', style: TextStyle(color: Colors.cyan.shade300)),
                                    const TextSpan(text: '(13, ', style: TextStyle(color: Colors.white)),
                                    TextSpan(text: 'HIGH', style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold)),
                                    TextSpan(text: '); ', style: const TextStyle(color: Colors.white)),
                                    TextSpan(text: '// LED turns on\n  ', style: TextStyle(color: Colors.green.shade400, fontStyle: FontStyle.italic)),
                                    TextSpan(text: 'delay', style: TextStyle(color: Colors.cyan.shade300)),
                                    TextSpan(text: '(1000);\n  ', style: TextStyle(color: Colors.orange.shade300)),
                                    TextSpan(text: 'digitalWrite', style: TextStyle(color: Colors.cyan.shade300)),
                                    const TextSpan(text: '(13, ', style: TextStyle(color: Colors.white)),
                                    TextSpan(text: 'LOW', style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold)),
                                    TextSpan(text: ');  ', style: const TextStyle(color: Colors.white)),
                                    TextSpan(text: '// LED turns off\n  ', style: TextStyle(color: Colors.green.shade400, fontStyle: FontStyle.italic)),
                                    TextSpan(text: 'delay', style: TextStyle(color: Colors.cyan.shade300)),
                                    TextSpan(text: '(1000);\n}', style: TextStyle(color: Colors.orange.shade300)),
                                  ],
                                ),
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: tokens.space16),

                    // AI Lab Partner Chat Bubble
                    InteractiveCard(
                      backgroundColor: Colors.white,
                      borderColor: tokens.primary.withOpacity(0.3),
                      padding: EdgeInsets.all(tokens.space16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tokens.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🤖', style: TextStyle(fontSize: 22)),
                          ),
                          SizedBox(width: tokens.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI Lab Partner',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                                ),
                                SizedBox(height: tokens.space4),
                                Text(
                                  _labPartnerMsg,
                                  style: const TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrayItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Placed $label on breadboard canvas!')));
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
