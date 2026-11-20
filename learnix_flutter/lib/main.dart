import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LearnixApp());
}

class LearnixApp extends StatelessWidget {
  const LearnixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learnix AI — Robotics Lab for Every Child',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          primary: const Color(0xFF1A73E8),
          secondary: const Color(0xFFF2994A),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Roboto',
      ),
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  String _baseUrl = 'https://learnix-ai-248424564253.asia-southeast1.run.app';
  final int _studentId = 1;

  final List<String> _navTitles = [
    'Home Dashboard',
    'My Learning Path',
    'Concept Studio',
    'Virtual Lab',
    'AI Tutor',
    'Reports',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learnix AI',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A73E8),
                  ),
                ),
                Text(
                  'Robotics Lab for Every Child • Powered by Gemini & AlloyDB',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Backend URL selector
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _baseUrl,
                icon: const Icon(Icons.cloud_done, size: 16, color: Colors.green),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                items: const [
                  DropdownMenuItem(
                    value: 'https://learnix-ai-248424564253.asia-southeast1.run.app',
                    child: Text('☁️ Cloud Run Live'),
                  ),
                  DropdownMenuItem(
                    value: 'http://localhost:8000',
                    child: Text('💻 Localhost:8000'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _baseUrl = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Student Badge
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const CircleAvatar(
                backgroundColor: Color(0xFF1A73E8),
                child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              label: const Text('Aarav (Grade 8)'),
              backgroundColor: Colors.blue.shade50,
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            elevation: 2,
            indicatorColor: Colors.blue.shade100,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: Color(0xFF1A73E8)),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.alt_route_outlined),
                selectedIcon: Icon(Icons.alt_route, color: Color(0xFF1A73E8)),
                label: Text('Path'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories, color: Color(0xFF1A73E8)),
                label: Text('Studio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.science_outlined),
                selectedIcon: Icon(Icons.science, color: Color(0xFF1A73E8)),
                label: Text('Lab'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.smart_toy, color: Color(0xFF1A73E8)),
                label: Text('AI Tutor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights, color: Color(0xFF1A73E8)),
                label: Text('Reports'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Content Area
          Expanded(
            child: _buildCurrentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0:
        return HomeView(baseUrl: _baseUrl, studentId: _studentId);
      case 1:
        return LearningPathView(baseUrl: _baseUrl, studentId: _studentId);
      case 2:
        return ConceptStudioView(baseUrl: _baseUrl, studentId: _studentId);
      case 3:
        return VirtualLabView(baseUrl: _baseUrl);
      case 4:
        return AITutorView(baseUrl: _baseUrl, studentId: _studentId);
      case 5:
        return ReportsView(baseUrl: _baseUrl, studentId: _studentId);
      default:
        return const Center(child: Text('Select a tab'));
    }
  }
}

// ============================================================================
// 1. HOME VIEW
// ============================================================================
class HomeView extends StatefulWidget {
  final String baseUrl;
  final int studentId;
  const HomeView({super.key, required this.baseUrl, required this.studentId});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
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
      debugPrint('Error fetching home data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final completed = _pathData?['completed_count'] ?? 0;
    final total = _pathData?['total_days'] ?? 10;
    final progressPct = (completed / total * 100).toInt();
    final coachMsg = _coachData?['coach_message'] ?? 'Keep building! Focus on foundational circuit safety.';
    final weakConcepts = (_coachData?['weak_concepts'] as List?) ?? [];
    final nextConcepts = (_coachData?['next_concepts'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '🌟 Welcome to Learnix STEM Lab',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Hi Aarav! Ready to build something awesome? 🚀',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Master electronics day-by-day, explore diagrams, and chat with your AI Tutor.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Progress Circle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$progressPct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$completed/$total Days Done',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // AI Tutor Speech Bubble Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFF2994A),
                    child: Text('🤖', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Tutor Alex Says:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A73E8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          coachMsg,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Weak Concepts and Next Steps Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weak Concepts
              Expanded(
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Concepts to Review',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (weakConcepts.isEmpty)
                          const Text('🎉 All concepts mastered with high confidence!')
                        else
                          ...weakConcepts.map((c) => ListTile(
                                leading: const Icon(Icons.refresh, color: Colors.orange),
                                title: Text(c['title'] ?? 'Concept'),
                                subtitle: Text(c['category'] ?? 'Electronics'),
                                dense: true,
                              )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Next Steps
              Expanded(
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.flag_rounded, color: Color(0xFF1A73E8)),
                            SizedBox(width: 8),
                            Text(
                              'Recommended Next Steps',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (nextConcepts.isEmpty)
                          const Text('You are on track!')
                        else
                          ...nextConcepts.take(3).map((nc) => ListTile(
                                leading: const Icon(Icons.arrow_forward, color: Color(0xFF1A73E8)),
                                title: Text(nc['title'] ?? 'Next Concept'),
                                subtitle: Text(nc['summary'] ?? ''),
                                dense: true,
                              )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. LEARNING PATH VIEW
// ============================================================================
class LearningPathView extends StatefulWidget {
  final String baseUrl;
  final int studentId;
  const LearningPathView({super.key, required this.baseUrl, required this.studentId});

  @override
  State<LearningPathView> createState() => _LearningPathViewState();
}

class _LearningPathViewState extends State<LearningPathView> {
  bool _isLoading = true;
  List<dynamic> _days = [];

  @override
  void initState() {
    super.initState();
    _fetchPath();
  }

  Future<void> _fetchPath() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${widget.baseUrl}/api/path/${widget.studentId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _days = data['days'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading path: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDayDetails(Map<String, dynamic> day) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF1A73E8),
              child: Text('${day['day_number']}', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(day['title'] ?? 'Day Mission')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visual Model: [${day['visual_type']}]', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Text(day['concept']?['summary'] ?? 'Explore this interactive mission.'),
            const SizedBox(height: 12),
            if (day['experiment'] != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text('🔬 Lab Experiment: ${day['experiment']?['title']}'),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Starting Day ${day['day_number']} mission...')),
              );
            },
            child: const Text('Launch Mission'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🗺️ 10-Day Robotics Curriculum Roadmap',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Master electronics and robotics step-by-step: Learn visuals, Try in Lab, and Check quizzes.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _days.length,
              itemBuilder: (ctx, idx) {
                final day = _days[idx];
                final status = day['status'];
                final isDone = status == 'done';
                final isCurrent = status == 'current';

                Color cardColor = Colors.white;
                Color borderColor = Colors.grey.shade300;
                if (isCurrent) {
                  borderColor = const Color(0xFFF2994A);
                  cardColor = Colors.orange.shade50;
                } else if (isDone) {
                  borderColor = Colors.green.shade300;
                  cardColor = Colors.green.shade50;
                }

                return InkWell(
                  onTap: () => _showDayDetails(day),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'DAY ${day['day_number']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
                            ),
                            if (isDone)
                              const Chip(
                                label: Text('Done ⭐', style: TextStyle(fontSize: 10, color: Colors.green)),
                                backgroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              )
                            else if (isCurrent)
                              const Chip(
                                label: Text('Today 🔥', style: TextStyle(fontSize: 10, color: Colors.deepOrange)),
                                backgroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              )
                            else
                              const Icon(Icons.lock, size: 14, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          day['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day['concept']?['summary'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Chip(
                              label: Text('${day['visual_type']}', style: const TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (day['experiment'] != null) ...[
                              const SizedBox(width: 4),
                              const Chip(
                                label: Text('🔬 Lab', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                visualDensity: VisualDensity.compact,
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. CONCEPT STUDIO VIEW
// ============================================================================
class ConceptStudioView extends StatefulWidget {
  final String baseUrl;
  final int studentId;
  const ConceptStudioView({super.key, required this.baseUrl, required this.studentId});

  @override
  State<ConceptStudioView> createState() => _ConceptStudioViewState();
}

class _ConceptStudioViewState extends State<ConceptStudioView> {
  final TextEditingController _topicController = TextEditingController(text: 'Resistors and Ohm\'s Law');
  String _selectedLang = 'English';
  bool _isGenerating = false;
  Map<String, dynamic>? _generatedLesson;

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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📸 Concept Studio — Visual Learning',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Turn any textbook topic into interactive diagrams, simulations, and quizzes in 5 languages.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    hintText: 'Enter a topic (e.g., What is an LED, Ultrasonic Sensor)...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedLang,
                items: ['English', 'Tamil', 'Hindi', 'Marathi', 'Arabic'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setState(() => _selectedLang = v!),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateLesson,
                icon: _isGenerating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                label: const Text('Generate Visuals'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _generatedLesson == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 64, color: Colors.amber),
                        const SizedBox(height: 16),
                        const Text('Enter a topic above or pick a suggested topic below:', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            'What is an LED',
                            'Ohm\'s Law & Resistors',
                            'Ultrasonic Sensor',
                            'Arduino Pins',
                          ].map((t) => ActionChip(label: Text(t), onPressed: () => _topicController.text = t)).toList(),
                        ),
                      ],
                    ),
                  )
                : Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ListView(
                        children: [
                          Text(
                            _generatedLesson?['title'] ?? 'Generated Concept',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _generatedLesson?['summary'] ?? '',
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                          const Divider(height: 32),
                          const Text('Interactive Visual Model:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.animation, size: 48, color: Colors.cyanAccent),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Visual Type: ${_generatedLesson?['visual']?['type'] ?? 'animated_steps'}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  const Text('Interactive SVG Simulation Model Active', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. VIRTUAL LAB VIEW
// ============================================================================
class VirtualLabView extends StatelessWidget {
  final String baseUrl;
  const VirtualLabView({super.key, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔬 Virtual Lab — Hardware Simulator', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Simulate circuits with Arduino, LEDs, Buzzers, and Sensors with real-time AI debugging.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                // Experiment 1
                Expanded(child: _buildExpCard(context, 'Exp #1: LED Blink', 'Wire an LED with a 220Ω resistor to Pin 13 and ground.', Icons.light_mode, Colors.amber)),
                const SizedBox(width: 16),
                // Experiment 2
                Expanded(child: _buildExpCard(context, 'Exp #2: Buzzer + Button', 'Sound alarm on push button with Web Audio tone frequency.', Icons.volume_up, Colors.blue)),
                const SizedBox(width: 16),
                // Experiment 3
                Expanded(child: _buildExpCard(context, 'Exp #3: Distance Alarm', 'Trigger beeps based on ultrasonic slider distance reading.', Icons.radar, Colors.purple)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpCard(BuildContext ctx, String title, String desc, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Launching $title in simulation engine!')),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Open in Canvas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. AI TUTOR VIEW
// ============================================================================
class AITutorView extends StatefulWidget {
  final String baseUrl;
  final int studentId;
  const AITutorView({super.key, required this.baseUrl, required this.studentId});

  @override
  State<AITutorView> createState() => _AITutorViewState();
}

class _AITutorViewState extends State<AITutorView> {
  final TextEditingController _ideaController = TextEditingController();
  bool _isSparking = false;
  Map<String, dynamic>? _sparkedIdea;

  Future<void> _sparkIdea() async {
    final text = _ideaController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSparking = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/coach/spark-idea'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idea': text,
          'student_id': widget.studentId,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _sparkedIdea = data['plan']);
      }
    } catch (e) {
      debugPrint('Error sparking idea: $e');
    } finally {
      if (mounted) setState(() => _isSparking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤖 AI Tutor Alex — Diagnostic & Invention Lab', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Ask questions, get Root Cause Analysis (RCA) on circuit failures, or turn your invention ideas into step-by-step builds.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ideaController,
                  decoration: InputDecoration(
                    hintText: 'Tell AI Tutor what you want to build (e.g., A smart night light or burglar alarm)...',
                    prefixIcon: const Icon(Icons.lightbulb_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSparking ? null : _sparkIdea,
                icon: _isSparking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bolt),
                label: const Text('Spark Invention Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2994A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _sparkedIdea == null
                ? const Center(child: Text('Enter an invention idea above and click Spark Invention Plan!'))
                : Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ListView(
                        children: [
                          Text(_sparkedIdea?['project_title'] ?? 'Invention Blueprint', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                          const SizedBox(height: 8),
                          Text(_sparkedIdea?['summary'] ?? '', style: const TextStyle(fontSize: 14)),
                          const Divider(height: 32),
                          const Text('Required Components:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${_sparkedIdea?['components'] ?? 'Arduino, Resistor, Breadboard'}'),
                          const SizedBox(height: 16),
                          const Text('Code Architecture:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                            child: Text(_sparkedIdea?['code_outline'] ?? '// Void setup and loop outline', style: const TextStyle(fontFamily: 'monospace')),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. REPORTS VIEW
// ============================================================================
class ReportsView extends StatefulWidget {
  final String baseUrl;
  final int studentId;
  const ReportsView({super.key, required this.baseUrl, required this.studentId});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  String _parentLang = 'Tamil';
  String? _parentNote;
  bool _isLoading = false;

  Future<void> _fetchParentReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${widget.baseUrl}/api/reports/parent/${widget.studentId}?language=$_parentLang'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _parentNote = data['ai_letter']);
      }
    } catch (e) {
      debugPrint('Error loading report: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchParentReport();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 Analytics & Vernacular Parent Digest', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Automated progress notes for parents in their native language and multi-centre analytics.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Select Parent Language: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _parentLang,
                items: ['Tamil', 'Hindi', 'Marathi', 'Arabic', 'English'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _parentLang = v);
                    _fetchParentReport();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(backgroundColor: Color(0xFF1A73E8), child: Icon(Icons.mail, color: Colors.white)),
                              const SizedBox(width: 12),
                              Text('Weekly Note for Parents ($_parentLang)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 32),
                          Text(
                            _parentNote ?? 'Loading personalized letter...',
                            style: const TextStyle(fontSize: 15, height: 1.6),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
