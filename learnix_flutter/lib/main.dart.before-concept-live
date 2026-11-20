import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'screens/coach_screen.dart';
import 'screens/concept_studio_screen.dart';
import 'screens/home_screen.dart';
import 'screens/learning_path_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/virtual_lab_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LearnixApp());
}

class LearnixApp extends StatelessWidget {
  const LearnixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learnix AI — Modern STEM & Robotics Learning',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final isCompactHeader = constraints.maxWidth < 680;

        return Scaffold(
          appBar: _buildAppBar(context, tokens, isWide, isCompactHeader),
          drawer: isWide ? null : _buildDrawer(tokens),
          bottomNavigationBar: isWide ? null : _buildBottomNavigationBar(tokens),
          body: Stack(
            children: [
              Row(
                children: [
                  if (isWide) ...[
                    _buildSidebar(tokens),
                    VerticalDivider(thickness: 1, width: 1, color: tokens.borderSubtle),
                  ],
                  Expanded(
                    child: Container(
                      color: tokens.surfaceBg,
                      child: _buildCurrentScreen(),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: pi / 2,
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 50,
                  gravity: 0.1,
                  colors: const [
                    Color(0xFF2563EB),
                    Color(0xFFF97316),
                    Color(0xFF16A34A),
                    Colors.amber,
                    Colors.purple,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppTokens tokens,
    bool isWide,
    bool isCompactHeader,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleSpacing: isCompactHeader ? 4 : 16,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: tokens.borderSubtle, height: 1),
      ),
      leading: isWide
          ? null
          : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(LucideIcons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tokens.primary, const Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.zap, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Learnix AI',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompactHeader ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (!isCompactHeader)
                  const Text(
                    'Robotics Lab For Every Child • Google Cloud & Gemini',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Backend Environment Switcher
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.symmetric(horizontal: isCompactHeader ? 6 : 10),
          decoration: BoxDecoration(
            color: tokens.surfaceBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _baseUrl,
              isDense: true,
              icon: Icon(LucideIcons.cloud, size: 14, color: tokens.success),
              style: TextStyle(
                fontSize: isCompactHeader ? 11 : 12,
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              items: [
                DropdownMenuItem(
                  value: 'https://learnix-ai-248424564253.asia-southeast1.run.app',
                  child: Text(isCompactHeader ? '☁️ Cloud' : '☁️ Cloud Run Live'),
                ),
                DropdownMenuItem(
                  value: 'http://localhost:8000',
                  child: Text(isCompactHeader ? '💻 Local' : '💻 Localhost:8000'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _baseUrl = val);
              },
            ),
          ),
        ),
        SizedBox(width: isCompactHeader ? 6 : tokens.space12),
        // Student Profile Badge
        Padding(
          padding: EdgeInsets.only(right: isCompactHeader ? 10 : tokens.space24),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompactHeader ? 8 : tokens.space12,
              vertical: tokens.space4,
            ),
            decoration: BoxDecoration(
              color: tokens.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: tokens.primary,
                  child: const Text('A', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Text(
                  isCompactHeader ? 'Aarav' : 'Aarav (Grade 8)',
                  style: TextStyle(
                    fontSize: isCompactHeader ? 11 : 12,
                    fontWeight: FontWeight.bold,
                    color: tokens.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(AppTokens tokens) {
    return Container(
      width: 240,
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: tokens.space24, horizontal: tokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space12, vertical: tokens.space8),
            child: Text(
              'NAVIGATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tokens.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: tokens.space8),
          _buildSidebarNavItem(0, LucideIcons.home, 'Home Dashboard', tokens),
          _buildSidebarNavItem(1, LucideIcons.milestone, 'My Learning Path', tokens),
          _buildSidebarNavItem(2, LucideIcons.camera, 'Concept Studio', tokens),
          _buildSidebarNavItem(3, LucideIcons.flaskConical, 'Virtual Lab', tokens),
          _buildSidebarNavItem(4, LucideIcons.bot, 'AI Tutor', tokens),
          _buildSidebarNavItem(5, LucideIcons.barChart2, 'Reports', tokens),
          const Spacer(),
          Container(
            padding: EdgeInsets.all(tokens.space16),
            decoration: BoxDecoration(
              color: tokens.surfaceBg,
              borderRadius: tokens.borderRadius16,
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 20)),
                SizedBox(width: tokens.space12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AlloyDB + Gemini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Cloud Native Lab', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, IconData icon, String label, AppTokens tokens) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space4),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: tokens.space16, vertical: tokens.space12),
          decoration: BoxDecoration(
            color: isSelected ? tokens.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? tokens.primary : tokens.textSecondary,
              ),
              SizedBox(width: tokens.space12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? tokens.primary : tokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(AppTokens tokens) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.all(tokens.space16),
        children: [
          DrawerHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: tokens.primary, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(LucideIcons.zap, color: Colors.white),
                    ),
                    SizedBox(width: tokens.space12),
                    const Text('Learnix AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Robotics Lab For Every Child',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          ListTile(leading: const Icon(LucideIcons.home), title: const Text('Home'), onTap: () => _selectAndClose(0)),
          ListTile(leading: const Icon(LucideIcons.milestone), title: const Text('My Learning Path'), onTap: () => _selectAndClose(1)),
          ListTile(leading: const Icon(LucideIcons.camera), title: const Text('Concept Studio'), onTap: () => _selectAndClose(2)),
          ListTile(leading: const Icon(LucideIcons.flaskConical), title: const Text('Virtual Lab'), onTap: () => _selectAndClose(3)),
          ListTile(leading: const Icon(LucideIcons.bot), title: const Text('AI Tutor'), onTap: () => _selectAndClose(4)),
          ListTile(leading: const Icon(LucideIcons.barChart2), title: const Text('Reports'), onTap: () => _selectAndClose(5)),
        ],
      ),
    );
  }

  void _selectAndClose(int idx) {
    setState(() => _selectedIndex = idx);
    Navigator.of(context).pop();
  }

  Widget _buildBottomNavigationBar(AppTokens tokens) {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
      backgroundColor: Colors.white,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(icon: Icon(LucideIcons.home, size: 20), label: 'Home'),
        NavigationDestination(icon: Icon(LucideIcons.milestone, size: 20), label: 'Path'),
        NavigationDestination(icon: Icon(LucideIcons.camera, size: 20), label: 'Studio'),
        NavigationDestination(icon: Icon(LucideIcons.flaskConical, size: 20), label: 'Lab'),
        NavigationDestination(icon: Icon(LucideIcons.bot, size: 20), label: 'Tutor'),
        NavigationDestination(icon: Icon(LucideIcons.barChart2, size: 20), label: 'Reports'),
      ],
    );
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return HomeScreen(
          baseUrl: _baseUrl,
          studentId: _studentId,
          onNavigateToTab: (idx) => setState(() => _selectedIndex = idx),
        );
      case 1:
        return LearningPathScreen(
          baseUrl: _baseUrl,
          studentId: _studentId,
          confettiController: _confettiController,
        );
      case 2:
        return ConceptStudioScreen(
          baseUrl: _baseUrl,
          studentId: _studentId,
        );
      case 3:
        return VirtualLabScreen(
          baseUrl: _baseUrl,
        );
      case 4:
        return CoachScreen(
          baseUrl: _baseUrl,
          studentId: _studentId,
        );
      case 5:
        return ReportsScreen(
          baseUrl: _baseUrl,
          studentId: _studentId,
        );
      default:
        return const Center(child: Text('Screen not found'));
    }
  }
}
