import 'dart:convert';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_card.dart';

class ConceptStudioScreen extends StatefulWidget {
  final String baseUrl;
  final int studentId;

  const ConceptStudioScreen({
    super.key,
    required this.baseUrl,
    required this.studentId,
  });

  @override
  State<ConceptStudioScreen> createState() => _ConceptStudioScreenState();
}

class _ConceptStudioScreenState extends State<ConceptStudioScreen> {
  final TextEditingController _topicController = TextEditingController(text: 'Resistors and Ohm\'s Law');
  String _selectedLang = 'English';
  bool _isGenerating = false;
  bool _isDragging = false;
  String? _droppedFileName;
  Map<String, dynamic>? _generatedLesson;

  final List<String> _languages = ['English', 'Tamil', 'Hindi', 'Marathi', 'Arabic'];

  Future<void> _generateLesson() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() => _isGenerating = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/concept-studio'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic': topic,
          'language': _selectedLang,
          'student_id': widget.studentId,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _generatedLesson = data['lesson']);
      }
    } catch (e) {
      debugPrint('Error generating lesson: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
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
          Text('📸 Concept Studio — Visual Learning', style: textTheme.displayLarge),
          SizedBox(height: tokens.space8),
          Text(
            'Snap or drop a textbook page, or type any physics topic to see interactive diagrams and simulations.',
            style: textTheme.bodyMedium,
          ),
          SizedBox(height: tokens.space32),

          // Drag and Drop Upload Area
          DropTarget(
            onDragEntered: (_) => setState(() => _isDragging = true),
            onDragExited: (_) => setState(() => _isDragging = false),
            onDragDone: (detail) {
              setState(() {
                _isDragging = false;
                if (detail.files.isNotEmpty) {
                  _droppedFileName = detail.files.first.name;
                  _topicController.text = 'Textbook Page: ${_droppedFileName!}';
                }
              });
            },
            child: InteractiveCard(
              backgroundColor: _isDragging ? tokens.primaryLight : Colors.white,
              borderColor: _isDragging ? tokens.primary : tokens.borderSubtle,
              padding: EdgeInsets.all(tokens.space32),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(tokens.space16),
                    decoration: BoxDecoration(
                      color: tokens.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.camera, size: 36, color: tokens.primary),
                  ),
                  SizedBox(height: tokens.space16),
                  Text(
                    _droppedFileName != null
                        ? '📄 Attached: $_droppedFileName'
                        : 'Snap your textbook page or drag & drop image here',
                    style: textTheme.titleMedium,
                  ),
                  SizedBox(height: tokens.space8),
                  Text(
                    'Supports PNG, JPG, or PDF photos from mobile camera or desktop.',
                    style: textTheme.bodyMedium,
                  ),
                  SizedBox(height: tokens.space16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _droppedFileName = 'electricity_textbook_page.jpg';
                        _topicController.text = 'What is an LED and forward bias';
                      });
                    },
                    icon: const Icon(LucideIcons.uploadCloud, size: 18),
                    label: const Text('Simulate Camera Upload'),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),

          SizedBox(height: tokens.space24),

          // Topic & Language Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    hintText: 'Or type a science topic (e.g. Resistors, Complete Circuits, Ultrasonic Sensor)...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.all(tokens.space16),
                    border: OutlineInputBorder(
                      borderRadius: tokens.borderRadius16,
                      borderSide: BorderSide(color: tokens.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: tokens.borderRadius16,
                      borderSide: BorderSide(color: tokens.borderSubtle),
                    ),
                  ),
                ),
              ),
              SizedBox(width: tokens.space12),
              // Language Selector
              Container(
                padding: EdgeInsets.symmetric(horizontal: tokens.space16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: tokens.borderRadius16,
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLang,
                    icon: const Icon(LucideIcons.globe, size: 16),
                    items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedLang = v);
                    },
                  ),
                ),
              ),
              SizedBox(width: tokens.space12),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateLesson,
                icon: _isGenerating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.sparkles, size: 18),
                label: Text(_isGenerating ? 'Analyzing with Gemini...' : 'Generate Visual Lesson'),
              ),
            ],
          ),

          SizedBox(height: tokens.space32),

          // Generated Visual Lesson Presentation
          if (_generatedLesson != null) ...[
            InteractiveCard(
              padding: EdgeInsets.all(tokens.space32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: tokens.space12, vertical: tokens.space4),
                        decoration: BoxDecoration(
                          color: tokens.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'VISUAL TYPE: ${_generatedLesson?['visual']?['type'] ?? 'animated_steps'}'.toUpperCase(),
                          style: TextStyle(color: tokens.primary, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      Chip(
                        avatar: const Icon(LucideIcons.globe, size: 14),
                        label: Text(_selectedLang),
                        backgroundColor: tokens.surfaceBg,
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.space16),
                  Text(
                    _generatedLesson?['title'] ?? 'Generated Lesson',
                    style: textTheme.headlineMedium?.copyWith(color: tokens.primary),
                  ),
                  SizedBox(height: tokens.space8),
                  Text(
                    _generatedLesson?['summary'] ?? '',
                    style: textTheme.bodyMedium?.copyWith(fontSize: 16),
                  ),
                  SizedBox(height: tokens.space24),

                  // High-fidelity Visual Simulator Card
                  Container(
                    height: 260,
                    width: double.infinity,
                    padding: EdgeInsets.all(tokens.space24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: tokens.borderRadius16,
                      boxShadow: tokens.cardShadow,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.cpu, size: 48, color: Color(0xFF38BDF8)),
                        SizedBox(height: tokens.space12),
                        const Text(
                          '⚡ Interactive Circuit & Physics Simulation Active',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: tokens.space4),
                        Text(
                          'Live electron flows, glowing semiconductor diodes, and responsive slider variables.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        SizedBox(height: tokens.space16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black87),
                              icon: const Icon(LucideIcons.play, size: 16),
                              label: const Text('Play Animation'),
                            ),
                            SizedBox(width: tokens.space12),
                            OutlinedButton.icon(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                              icon: const Icon(LucideIcons.sliders, size: 16),
                              label: const Text('Adjust Resistance: 220Ω'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: tokens.space24),

                  // Ask a Doubt Box
                  Container(
                    padding: EdgeInsets.all(tokens.space16),
                    decoration: BoxDecoration(
                      color: tokens.surfaceBg,
                      borderRadius: tokens.borderRadius16,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.helpCircle, color: Colors.blueGrey),
                        SizedBox(width: tokens.space12),
                        const Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Ask a doubt to AI Tutor Alex about this visual...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('AI Tutor: Current flows from positive anode to negative cathode!')),
                            );
                          },
                          child: const Text('Ask AI'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
          ] else ...[
            // Suggested topics row
            Center(
              child: Column(
                children: [
                  const Icon(LucideIcons.lightbulb, size: 48, color: Colors.amber),
                  SizedBox(height: tokens.space12),
                  const Text('Or try one of these foundational robotics topics:'),
                  SizedBox(height: tokens.space12),
                  Wrap(
                    spacing: 8,
                    children: [
                      'What is an LED',
                      'Resistors and Ohm\'s Law',
                      'Ground and Complete Circuits',
                      'Ultrasonic Distance Sensor',
                      'Variables and Logic',
                    ].map((t) => ActionChip(
                          label: Text(t),
                          onPressed: () {
                            _topicController.text = t;
                            _generateLesson();
                          },
                        )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
