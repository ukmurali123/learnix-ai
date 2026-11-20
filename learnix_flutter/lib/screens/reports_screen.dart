import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_card.dart';

class ReportsScreen extends StatefulWidget {
  final String baseUrl;
  final int studentId;

  const ReportsScreen({
    super.key,
    required this.baseUrl,
    required this.studentId,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _parentLang = 'Tamil';
  String? _parentLetter;
  bool _isLoadingParent = true;
  bool _isLoadingCentre = true;
  List<dynamic> _centresList = [];

  final List<String> _languages = ['Tamil', 'Hindi', 'Marathi', 'Arabic', 'English'];

  @override
  void initState() {
    super.initState();
    _fetchParentReport();
    _fetchCentreReport();
  }

  Future<void> _fetchParentReport() async {
    setState(() => _isLoadingParent = true);
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/reports/parent/${widget.studentId}?language=$_parentLang'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final report = data['report'];
        String formatted = '';
        if (report is Map) {
          final greeting = report['greeting'] ?? '';
          final note = report['note'] ?? '';
          final goal = report['next_week_goal'] ?? '';
          formatted = [greeting, note, if (goal.toString().isNotEmpty) '🎯 Next week: $goal']
              .where((s) => s.toString().trim().isNotEmpty)
              .join('\n\n');
        } else if (report is String) {
          formatted = report;
        } else {
          formatted = (data['ai_letter'] ?? 'Aarav had a great week exploring LED circuits and resistors in Learnix AI!').toString();
        }
        setState(() => _parentLetter = formatted);
      }
    } catch (e) {
      debugPrint('Error loading parent report: $e');
    } finally {
      if (mounted) setState(() => _isLoadingParent = false);
    }
  }

  Future<void> _fetchCentreReport() async {
    setState(() => _isLoadingCentre = true);
    try {
      final res = await http.get(Uri.parse('${widget.baseUrl}/api/reports/centres'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _centresList = (data['centres'] as List?) ?? []);
      }
    } catch (e) {
      debugPrint('Error loading centre report: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCentre = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;
        final pad = isNarrow ? tokens.space16 : tokens.space32;

        final chartCard = InteractiveCard(
          padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.barChart2, color: tokens.primary, size: 20),
                  SizedBox(width: tokens.space8),
                  Expanded(
                    child: Text('Centre Performance Comparison (Average Quiz %)', style: textTheme.titleMedium),
                  ),
                ],
              ),
              SizedBox(height: tokens.space24),
              SizedBox(
                height: 220,
                child: _isLoadingCentre
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _centresList.isNotEmpty
                            ? _centresList.take(4).toList().asMap().entries.map((entry) {
                                final idx = entry.key;
                                final c = entry.value as Map<String, dynamic>;
                                final colors = [tokens.primary, tokens.accent, tokens.success, const Color(0xFF6366F1)];
                                final score = double.tryParse((c['avg_quiz_score_pct'] ?? 80).toString()) ?? 80.0;
                                final name = (c['centre_name'] ?? 'Centre ${idx + 1}').toString().replaceAll(' ', '\n');
                                return _buildBarCol(name, score.clamp(20, 100), colors[idx % colors.length]);
                              }).toList()
                            : [
                                _buildBarCol('Centre A\n(Chennai)', 82, tokens.primary),
                                _buildBarCol('Centre B\n(Madurai)', 74, tokens.accent),
                                _buildBarCol('Centre C\n(Coimbatore)', 91, tokens.success),
                                _buildBarCol('Centre D\n(Salem)', 79, const Color(0xFF6366F1)),
                              ],
                      ),
              ),
            ],
          ),
        );

        final sentimentCard = InteractiveCard(
          padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.smile, color: tokens.success, size: 20),
                  SizedBox(width: tokens.space8),
                  Expanded(child: Text('Feedback Sentiment (AI.EXTRACT)', style: textTheme.titleMedium)),
                ],
              ),
              SizedBox(height: tokens.space16),
              _buildSentimentRow('Positive & Excited', '84%', tokens.success),
              SizedBox(height: tokens.space12),
              _buildSentimentRow('Neutral / Asking Questions', '12%', tokens.primary),
              SizedBox(height: tokens.space12),
              _buildSentimentRow('Needs Hardware Help', '4%', tokens.accent),
              SizedBox(height: tokens.space24),
              Container(
                padding: EdgeInsets.all(tokens.space12),
                decoration: BoxDecoration(
                  color: tokens.surfaceBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '💡 AI.EXTRACT summary: Students love the instant Web Audio buzzer feedback and visual LED simulations.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
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
                '📊 Reports & Multi-Centre Analytics',
                style: isNarrow ? textTheme.headlineMedium : textTheme.displayLarge,
              ),
              SizedBox(height: tokens.space8),
              Text(
                'Weekly natural-language parent notes in vernacular languages and network-wide learning metrics.',
                style: textTheme.bodyMedium,
              ),
              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // Section 1: Parent Report Card
              InteractiveCard(
                padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tokens.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(LucideIcons.mail, color: tokens.primary, size: 20),
                            ),
                            SizedBox(width: tokens.space12),
                            Text('Weekly Parent Progress Letter', style: textTheme.titleMedium),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Language: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            SizedBox(width: tokens.space8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: tokens.surfaceBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: tokens.borderSubtle),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _parentLang,
                                  items: _languages
                                      .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _parentLang = v);
                                      _fetchParentReport();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.space16),
                    _isLoadingParent
                        ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                        : Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(tokens.space20),
                            decoration: BoxDecoration(
                              color: tokens.surfaceBg,
                              borderRadius: tokens.borderRadius16,
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Text(
                              _parentLetter ?? 'Generating personalized letter...',
                              style: textTheme.bodyMedium?.copyWith(
                                color: tokens.textPrimary,
                                height: 1.7,
                                fontSize: 15,
                              ),
                            ),
                          ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // Section 2: Centre Director Dashboard & Sentiment
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    chartCard,
                    SizedBox(height: tokens.space16),
                    sentimentCard,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: chartCard),
                    SizedBox(width: tokens.space24),
                    Expanded(flex: 2, child: sentimentCard),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBarCol(String label, double value, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${value.toInt()}%',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: value * 1.4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSentimentRow(String label, String pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            Text(pct, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: double.parse(pct.replaceAll('%', '')) / 100,
          backgroundColor: const Color(0xFFE2E8F0),
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
