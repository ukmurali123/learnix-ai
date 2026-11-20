import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_card.dart';

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

class _LearningPathScreenState extends State<LearningPathScreen> {
  bool _isLoading = true;
  List<dynamic> _days = [];
  int _completedCount = 0;
  int _currentDay = 1;

  @override
  void initState() {
    super.initState();
    _fetchLearningPath();
  }

  Future<void> _fetchLearningPath() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${widget.baseUrl}/api/path/${widget.studentId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _days = data['days'] ?? [];
        _completedCount = data['completed_count'] ?? 0;
        _currentDay = data['current_day'] ?? 1;
      }
    } catch (e) {
      debugPrint('Error fetching path: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        _fetchLearningPath();

        final revision = data['revision'];
        if (revision != null && revision['needed'] == true) {
          _showRevisionDialog(revision);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text('🎉 Day $dayNumber completed with full score! Day ${dayNumber + 1} unlocked.'),
            ),
          );
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
            Text('AI Tutor: Quick Revision Step'),
          ],
        ),
        content: Column(
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
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it! Continue Journey'),
          ),
        ],
      ),
    );
  }

  void _openMissionModal(Map<String, dynamic> day) {
    final dayNum = day['day_number'];
    final title = day['title'] ?? 'Mission';
    final vType = day['visual_type'] ?? 'animated_steps';
    final conceptSummary = day['concept']?['summary'] ?? '';
    final exp = day['experiment'];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 720,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'DAY $dayNum',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Step 1: Learn
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.bookOpen, color: Color(0xFF2563EB)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Step 1: Learn with Visual Diagram', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(conceptSummary, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text('Visual Model Type: [$vType]', style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Step 2: Try in Lab (if exists)
              if (exp != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.flaskConical, color: Color(0xFFF97316)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Step 2: Try in Virtual Lab — ${exp['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(exp['goal'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Step 3: Check Quiz
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.checkSquare, color: Color(0xFF16A34A)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Step 3: Check Mastery with 3-Question Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Score 3/3 to unlock the next day, or receive encouragement and hints from AI Tutor Alex.', style: TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _completeDay(dayNum, 3);
                    },
                    icon: const Icon(LucideIcons.checkCheck, size: 18),
                    label: const Text('Finish Mission & Quiz (Score: 3/3)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: tokens.primary));
    }

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
                  Text('🗺️ 10-Day Robotics Curriculum Roadmap', style: textTheme.displayLarge),
                  SizedBox(height: tokens.space8),
                  Text('Progress along the connected journey path. Master each day to unlock the next.', style: textTheme.bodyMedium),
                ],
              ),
              // Progress pill
              Container(
                padding: EdgeInsets.symmetric(horizontal: tokens.space16, vertical: tokens.space8),
                decoration: BoxDecoration(
                  color: tokens.primaryLight,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: tokens.primary.withOpacity(0.3)),
                ),
                child: Text(
                  '$_completedCount of ${_days.length} Days Mastered (${((_completedCount / (_days.isEmpty ? 1 : _days.length)) * 100).toInt()}%)',
                  style: TextStyle(color: tokens.primary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),

          SizedBox(height: tokens.space32),

          // Journey Grid with Connecting Visual Flow
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: tokens.space24,
                  mainAxisSpacing: tokens.space24,
                  childAspectRatio: 1.35,
                ),
                itemCount: _days.length,
                itemBuilder: (context, index) {
                  final day = _days[index];
                  final status = day['status'];
                  final isDone = status == 'done';
                  final isCurrent = status == 'current';
                  final isLocked = status == 'locked';

                  Color cardBg = Colors.white;
                  Color borderColor = tokens.borderSubtle;
                  if (isCurrent) {
                    cardBg = tokens.accentLight.withOpacity(0.5);
                    borderColor = tokens.accent;
                  } else if (isDone) {
                    cardBg = tokens.successLight.withOpacity(0.4);
                    borderColor = tokens.success.withOpacity(0.4);
                  }

                  return InteractiveCard(
                    backgroundColor: cardBg,
                    borderColor: borderColor,
                    onTap: isLocked ? null : () => _openMissionModal(day),
                    padding: EdgeInsets.all(tokens.space24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Top Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: tokens.space8, vertical: tokens.space4),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? tokens.success
                                    : (isCurrent ? tokens.accent : Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'DAY ${day['day_number']}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                              ),
                            ),
                            if (isDone)
                              Row(
                                children: [
                                  Icon(LucideIcons.checkCircle2, color: tokens.success, size: 16),
                                  SizedBox(width: tokens.space4),
                                  Text(
                                    'Score: ${day['quiz_score'] ?? 3}/3',
                                    style: TextStyle(color: tokens.success, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              )
                            else if (isCurrent)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: tokens.space8, vertical: tokens.space4),
                                decoration: BoxDecoration(
                                  color: tokens.accent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Text('🔥', style: TextStyle(fontSize: 10)),
                                    SizedBox(width: 4),
                                    Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            else
                              const Row(
                                children: [
                                  Icon(LucideIcons.lock, size: 14, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text('Locked', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                          ],
                        ),
                        SizedBox(height: tokens.space12),

                        // Title
                        Text(
                          day['title'] ?? '',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isLocked ? Colors.grey : tokens.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: tokens.space8),

                        // Summary
                        Text(
                          day['concept']?['summary'] ?? '',
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: isLocked ? Colors.grey : tokens.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const Spacer(),

                        // Footer Tags & Action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: tokens.space8, vertical: tokens.space4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${day['visual_type']}'.replaceAll('_', ' '),
                                style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (isCurrent)
                              ElevatedButton(
                                onPressed: () => _openMissionModal(day),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tokens.accent,
                                  padding: EdgeInsets.symmetric(horizontal: tokens.space16, vertical: tokens.space8),
                                ),
                                child: const Text('Start &rarr;', style: TextStyle(fontSize: 12)),
                              )
                            else if (isDone)
                              TextButton(
                                onPressed: () => _openMissionModal(day),
                                child: const Text('Review', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (index * 40).ms, duration: 300.ms).slideY(begin: 0.05, end: 0);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
