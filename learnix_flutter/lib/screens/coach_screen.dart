import 'dart:convert';
import 'package:flutter/material.dart';
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
  bool _isSparking = false;
  Map<String, dynamic>? _sparkedPlan;

  @override
  void initState() {
    super.initState();
    _fetchCoachData();
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

  Future<void> _sparkIdea() async {
    final text = _ideaController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSparking = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/lab/build-from-words'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idea': text,
          'student_id': widget.studentId,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _sparkedPlan = data['plan'] != null ? Map<String, dynamic>.from(data['plan'] as Map) : data);
      }
    } catch (e) {
      debugPrint('Error sparking idea: $e');
    } finally {
      if (mounted) setState(() => _isSparking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: tokens.primary));
    }

    final coachMsg = _coachData?['coach_message'] ?? 'Circuit safety is key to great inventions.';
    final rawLabErrors = (_coachData?['top_lab_errors'] as List?) ?? [];
    final diagErrors = rawLabErrors.isNotEmpty
        ? rawLabErrors.map((e) {
            final etype = (e['error_type'] ?? 'missing_ground').toString().replaceAll('_', ' ').toUpperCase();
            final count = e['error_count'] ?? 1;
            return {
              'error_type': etype,
              'frequency': '${count}x in Virtual Lab',
              'tip': 'Check your pin connections, current-limiting resistor, and complete GND loop.',
            };
          }).toList()
        : [
            {
              'error_type': 'Missing Ground (GND) Return Loop',
              'frequency': '3x in Virtual Lab',
              'tip': 'Every electron leaving 5V or a digital pin must have a complete closed path back to GND.',
            },
            {
              'error_type': 'LED Over-current without Resistor',
              'frequency': '2x in Virtual Lab',
              'tip': 'Always add a 220Ω or 330Ω resistor in series with diodes to protect the semiconductor.',
            },
          ];

    final nextSequence = (_coachData?['next_concepts'] as List?) ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;
        final pad = isNarrow ? tokens.space16 : tokens.space32;

        final rcaCard = InteractiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.stethoscope, color: tokens.accent, size: 20),
                  SizedBox(width: tokens.space8),
                  Expanded(child: Text('Recurring Virtual Lab Errors (RCA)', style: textTheme.titleMedium)),
                ],
              ),
              SizedBox(height: tokens.space8),
              const Text(
                'AI diagnoses the exact points where circuits broke in your recent lab runs:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: tokens.space16),
              ...diagErrors.map((err) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.space16),
                    child: Container(
                      padding: EdgeInsets.all(tokens.space16),
                      decoration: BoxDecoration(
                        color: tokens.surfaceBg,
                        borderRadius: tokens.borderRadius16,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Text(
                                err['error_type'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  err['frequency'] ?? '',
                                  style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: tokens.space8),
                          Text(
                            '💡 Tutor Advice: ${err['tip'] ?? ''}',
                            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        );

        final sequenceCard = InteractiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.listOrdered, color: tokens.primary, size: 20),
                  SizedBox(width: tokens.space8),
                  Expanded(child: Text('Recommended Curriculum Sequence', style: textTheme.titleMedium)),
                ],
              ),
              SizedBox(height: tokens.space8),
              const Text(
                'Personalized order to build mastery step-by-step:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: tokens.space16),
              if (nextSequence.isEmpty)
                const Text('All sequence prerequisites completed!')
              else
                ...nextSequence.take(4).map((seq) => Padding(
                      padding: EdgeInsets.only(bottom: tokens.space12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: tokens.primaryLight,
                          child: Text(
                            '${nextSequence.indexOf(seq) + 1}',
                            style: TextStyle(color: tokens.primary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(seq['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          seq['summary'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(LucideIcons.chevronRight, size: 16),
                        dense: true,
                      ),
                    )),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                '🤖 AI Tutor Alex — Diagnostic & Invention Engine',
                style: isNarrow ? textTheme.headlineMedium : textTheme.displayLarge,
              ),
              SizedBox(height: tokens.space8),
              Text(
                'Personalized Root Cause Analysis (RCA) on your circuit runs and automated invention blueprint generation.',
                style: textTheme.bodyMedium,
              ),
              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

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
                        color: Color(0xFF2563EB),
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2563EB)),
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

              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // Two Columns: RCA Lab Errors & Recommended Sequence
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    rcaCard,
                    SizedBox(height: tokens.space16),
                    sequenceCard,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: rcaCard),
                    SizedBox(width: tokens.space24),
                    Expanded(child: sequenceCard),
                  ],
                ),

              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // Spark a Project Idea Card
              InteractiveCard(
                padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 24)),
                        SizedBox(width: tokens.space8),
                        Expanded(child: Text('Have an Invention Idea? Let\'s Build It!', style: textTheme.titleMedium)),
                      ],
                    ),
                    SizedBox(height: tokens.space8),
                    Text(
                      'Tell AI Tutor Alex what you want to build (e.g., "a night light that turns on in the dark" or "a burglar alarm").',
                      style: textTheme.bodyMedium,
                    ),
                    SizedBox(height: tokens.space16),
                    if (isNarrow)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _ideaController,
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
                            onPressed: _isSparking ? null : _sparkIdea,
                            icon: _isSparking
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(LucideIcons.sparkles, size: 16),
                            label: Text(_isSparking ? 'Sparking...' : 'Generate Blueprint'),
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
                            onPressed: _isSparking ? null : _sparkIdea,
                            icon: _isSparking
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(LucideIcons.sparkles, size: 16),
                            label: Text(_isSparking ? 'Sparking...' : 'Generate Blueprint'),
                          ),
                        ],
                      ),
                    if (_sparkedPlan != null) ...[
                      SizedBox(height: tokens.space24),
                      Container(
                        padding: EdgeInsets.all(tokens.space20),
                        decoration: BoxDecoration(
                          color: tokens.primaryLight.withOpacity(0.5),
                          borderRadius: tokens.borderRadius16,
                          border: Border.all(color: tokens.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_sparkedPlan?['title'] ?? _sparkedPlan?['project_title'] ?? 'Custom Project').toString(),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: tokens.primary),
                            ),
                            SizedBox(height: tokens.space8),
                            Text(
                              (_sparkedPlan?['explanation'] ?? _sparkedPlan?['summary'] ?? '').toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: tokens.space12),
                            Text(
                              'Components: ${(_sparkedPlan?['components'] is List) ? (_sparkedPlan!['components'] as List).join(', ') : (_sparkedPlan?['components'] ?? 'Arduino, Ultrasonic Sensor, Buzzer')}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: tokens.space8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(tokens.space12),
                              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                (_sparkedPlan?['code'] ?? _sparkedPlan?['code_outline'] ?? '// Void setup and loop').toString(),
                                style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
