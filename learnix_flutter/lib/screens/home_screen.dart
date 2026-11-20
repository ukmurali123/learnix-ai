import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/zola_avatar.dart';
import '../widgets/interactive_card.dart';
import '../widgets/picture_card.dart';

class HomeScreen extends StatefulWidget {
  final String baseUrl;
  final int studentId;
  final Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({
    super.key,
    required this.baseUrl,
    required this.studentId,
    this.onNavigateToTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _coachData;
  Map<String, dynamic>? _pathData;

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    setState(() => _isLoading = true);
    try {
      final coachRes = await http.get(Uri.parse('${widget.baseUrl}/api/coach/${widget.studentId}'));
      final pathRes = await http.get(Uri.parse('${widget.baseUrl}/api/path/${widget.studentId}'));

      if (coachRes.statusCode == 200) {
        _coachData = jsonDecode(coachRes.body);
      }
      if (pathRes.statusCode == 200) {
        _pathData = jsonDecode(pathRes.body);
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: tokens.primary),
      );
    }

    final student = _coachData?['student'] ?? {};
    final studentName = student['first_name'] ?? 'Aarav';
    final completedDays = _pathData?['completed_count'] ?? 0;
    final currentDay = _pathData?['current_day'] ?? 1;
    final totalDays = _pathData?['total_days'] ?? 10;
    final progressPct = (completedDays / totalDays).clamp(0.0, 1.0);
    final coachMsg = _coachData?['coach_message'] ?? 'Keep building! Focus on completing closed circuit loops with safe resistors.';
    final weakConcepts = (_coachData?['weak_concepts'] as List?) ?? [];
    final nextConcepts = (_coachData?['next_concepts'] as List?) ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;
        final pad = isNarrow ? tokens.space16 : tokens.space32;

        final missionCard = InteractiveCard(
          backgroundColor: tokens.primaryLight,
          borderColor: tokens.primary.withOpacity(0.2),
          padding: EdgeInsets.all(tokens.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: tokens.space12, vertical: tokens.space4),
                    decoration: BoxDecoration(
                      color: tokens.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'TODAY\'S MISSION',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ),
                  Icon(LucideIcons.arrowUpRight, color: tokens.primary, size: 20),
                ],
              ),
              SizedBox(height: tokens.space16),
              Text(
                'Continue Day $currentDay: Circuit Exploration',
                style: textTheme.headlineMedium?.copyWith(color: tokens.primary),
              ),
              SizedBox(height: tokens.space8),
              Text(
                'Explore interactive animated diagrams, wire your components in the simulator, and test your knowledge with a 3-question visual quiz.',
                style: textTheme.bodyMedium,
              ),
              SizedBox(height: tokens.space24),
              Wrap(
                spacing: tokens.space12,
                runSpacing: tokens.space12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => widget.onNavigateToTab?.call(1),
                    icon: const Icon(LucideIcons.playCircle, size: 18),
                    label: Text('Launch Day $currentDay Mission'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => widget.onNavigateToTab?.call(3),
                    icon: const Icon(LucideIcons.flaskConical, size: 18),
                    label: const Text('Open Virtual Lab'),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);

        final progressRingCard = InteractiveCard(
          padding: EdgeInsets.all(tokens.space24),
          child: Column(
            children: [
              Text(
                'Curriculum Progress',
                style: textTheme.titleMedium,
              ),
              SizedBox(height: tokens.space16),
              SizedBox(
                height: 130,
                width: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 130,
                      width: 130,
                      child: CircularProgressIndicator(
                        value: progressPct,
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        backgroundColor: tokens.borderSubtle,
                        color: tokens.primary,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progressPct * 100).toInt()}%',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: tokens.primary,
                          ),
                        ),
                        Text(
                          '$completedDays/$totalDays Days',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              SizedBox(height: tokens.space16),
              Text(
                'Keep going! ${totalDays - completedDays} days remaining to earn your Robotics Master Certificate.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms);

        final nextStepsCard = InteractiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.compass, color: tokens.primary, size: 20),
                  SizedBox(width: tokens.space8),
                  Expanded(child: Text('Recommended Next Concepts', style: textTheme.titleMedium)),
                ],
              ),
              SizedBox(height: tokens.space16),
              if (nextConcepts.isEmpty)
                const Text('Great job! You are up to date on all foundational concepts.')
              else
                ...nextConcepts.take(3).map((nc) => Padding(
                      padding: EdgeInsets.only(bottom: tokens.space12),
                      child: InkWell(
                        onTap: () => widget.onNavigateToTab?.call(2),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(tokens.space12),
                          decoration: BoxDecoration(
                            color: tokens.surfaceBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: tokens.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(LucideIcons.bookOpen, size: 16, color: tokens.primary),
                              ),
                              SizedBox(width: tokens.space12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nc['title'] ?? 'Concept',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    Text(
                                      nc['summary'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        );

        final weakConceptsCard = InteractiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.alertTriangle, color: tokens.accent, size: 20),
                  SizedBox(width: tokens.space8),
                  Expanded(child: Text('Concepts to Reinforce', style: textTheme.titleMedium)),
                ],
              ),
              SizedBox(height: tokens.space16),
              if (weakConcepts.isEmpty)
                Container(
                  padding: EdgeInsets.all(tokens.space16),
                  decoration: BoxDecoration(
                    color: tokens.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.checkCircle2, color: tokens.success),
                      SizedBox(width: tokens.space12),
                      const Expanded(child: Text('High confidence across all tested concepts! 🎉')),
                    ],
                  ),
                )
              else
                ...weakConcepts.map((wc) => Padding(
                      padding: EdgeInsets.only(bottom: tokens.space12),
                      child: InkWell(
                        onTap: () => widget.onNavigateToTab?.call(2),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(tokens.space12),
                          decoration: BoxDecoration(
                            color: tokens.accentLight.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.accent.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.refreshCw, size: 16, color: tokens.accent),
                              SizedBox(width: tokens.space12),
                              Expanded(
                                child: Text(
                                  wc['title'] ?? 'Concept to review',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: tokens.textPrimary),
                                ),
                              ),
                              Text(
                                'Review →',
                                style: TextStyle(fontSize: 12, color: tokens.accent, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
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
              // 1. Top Greeting & Streak
              Wrap(
                spacing: tokens.space16,
                runSpacing: tokens.space16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, $studentName! Ready to invent? 🚀',
                        style: isNarrow ? textTheme.headlineMedium : textTheme.displayLarge,
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
                      SizedBox(height: tokens.space8),
                      Text(
                        'Welcome to your personal robotics lab. Today is Day $currentDay on your learning path.',
                        style: textTheme.bodyMedium,
                      ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                    ],
                  ),
                ],
              ),

              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // Explore: illustrated cards like the live Learnix labs
              Text('Explore Learnix', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              SizedBox(height: tokens.space12),
              GridView.count(
                crossAxisCount: constraints.maxWidth < 560 ? 1 : (constraints.maxWidth < 980 ? 2 : 4),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: 1.05,
                children: [
                  PictureCard(image: 'assets/labs/space.jpg', title: 'My Learning Path', subtitle: 'Day $currentDay of 10', color: const Color(0xFF3949AB), badge: 'Day $currentDay', onTap: () => widget.onNavigateToTab?.call(1)),
                  PictureCard(image: 'assets/labs/math.jpg', title: 'Concept Studio', subtitle: 'Textbook to visuals', color: const Color(0xFFF59E0B), onTap: () => widget.onNavigateToTab?.call(2)),
                  PictureCard(image: 'assets/labs/robotics.jpg', title: 'Virtual Lab', subtitle: 'Build circuits, no kit needed', color: const Color(0xFF1E88E5), onTap: () => widget.onNavigateToTab?.call(3)),
                  PictureCard(image: 'assets/labs/ai.jpg', title: 'AI Tutor Zola', subtitle: 'Ask, invent, get unstuck', color: const Color(0xFF7E57C2), onTap: () => widget.onNavigateToTab?.call(4)),
                ],
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // 2. Hero Mission Card & Animated Progress Ring
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    missionCard,
                    SizedBox(height: tokens.space16),
                    progressRingCard,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: missionCard),
                    SizedBox(width: tokens.space24),
                    Expanded(flex: 2, child: progressRingCard),
                  ],
                ),

              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // 3. AI Tutor Speech Card
              InteractiveCard(
                padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space24),
                borderColor: tokens.accent.withOpacity(0.3),
                backgroundColor: Colors.white,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ZolaAvatar(size: 52),
                    SizedBox(width: tokens.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'AI Tutor Zola — Diagnostic Feedback',
                                style: textTheme.titleMedium?.copyWith(color: tokens.accent),
                              ),
                              TextButton.icon(
                                onPressed: () => widget.onNavigateToTab?.call(4),
                                icon: const Icon(LucideIcons.arrowRight, size: 16),
                                label: const Text('Deep Diagnostic'),
                              ),
                            ],
                          ),
                          SizedBox(height: tokens.space8),
                          Text(
                            coachMsg,
                            style: textTheme.bodyMedium?.copyWith(color: tokens.textPrimary, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // 4. Two Columns: Recommended Concepts & Weak Spot Diagnostics
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nextStepsCard,
                    SizedBox(height: tokens.space16),
                    weakConceptsCard,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: nextStepsCard),
                    SizedBox(width: tokens.space24),
                    Expanded(child: weakConceptsCard),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
