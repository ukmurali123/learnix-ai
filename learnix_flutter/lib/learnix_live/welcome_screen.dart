import 'package:flutter/material.dart';
import 'lx_brand.dart';
import 'auth_dark_theme.dart';

/// Welcome / landing page, written for students: what they will do inside Learnix (interactive lessons,
/// virtual labs, the Zola AI tutor, projects...) instead of the centre-management features.
/// Layout: an elevated hero card, a grid of colourful elevated cards, then a closing call-to-action card.
///
/// Login/Sign Up/Set Password/Forgot Password share the same palette (auth_dark_theme.dart).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthTheme.bg,
      body: Stack(
        children: [
          ...AuthTheme.backgroundLayers(),
          SafeArea(
            child: Column(
              children: [
                AuthTheme.topBar(context),
                const Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: _WelcomeBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Show the "New parent? Sign up your child" link on the welcome page. Off: the sign-up page and its
/// route stay, only the link is hidden.
const kShowParentSignupLink = false;

const _elevated = [
  BoxShadow(color: Color(0x1A063A5C), blurRadius: 30, offset: Offset(0, 14)),
  BoxShadow(color: Color(0x0D063A5C), blurRadius: 6, offset: Offset(0, 2)),
];

class _WelcomeBody extends StatelessWidget {
  const _WelcomeBody();

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 600;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 28, vertical: narrow ? 20 : 36),
          child: const Column(
            children: [
              _HeroCard(),
              SizedBox(height: 40),
              _SectionHeading(),
              SizedBox(height: 24),
              _ActivityGrid(),
              SizedBox(height: 44),
              _LabsSection(),
              SizedBox(height: 40),
              _StartCard(),
              SizedBox(height: 28),
              _Tagline(),
              SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  static const _chips = [
    (Icons.touch_app_rounded, 'Learn by doing', Color(0xFF7C3AED)),
    (Icons.science_rounded, 'Virtual labs', Color(0xFF0891B2)),
    (Icons.smart_toy_rounded, 'AI tutor', Color(0xFFEA580C)),
    (Icons.translate_rounded, 'English · தமிழ் · हिन्दी', Color(0xFF16A34A)),
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 860;
    final align = isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = isWide ? TextAlign.left : TextAlign.center;

    final text = Column(
      crossAxisAlignment: align,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AuthTheme.blue.withOpacity(0.10), borderRadius: BorderRadius.circular(30)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, size: 15, color: AuthTheme.blue),
            SizedBox(width: 6),
            Text('AI-powered learning', style: TextStyle(color: AuthTheme.blue, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Welcome to', textAlign: textAlign, style: const TextStyle(color: AuthTheme.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
        Text(
          BrandConfig.appName,
          textAlign: textAlign,
          style: TextStyle(color: AuthTheme.blue, fontSize: isWide ? 60 : 44, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1),
        ),
        const SizedBox(height: 10),
        Text(
          'Build robots. Explore AI. Learn by doing.',
          textAlign: textAlign,
          style: TextStyle(color: AuthTheme.ink, fontSize: isWide ? 24 : 20, fontWeight: FontWeight.w800, height: 1.25),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Text(
            'Step-by-step lessons, virtual labs where you wire real circuits, and Zola, your AI tutor, '
            'ready to help whenever you get stuck.',
            textAlign: textAlign,
            style: const TextStyle(color: AuthTheme.textMuted, fontSize: 14.5, height: 1.6),
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [AuthTheme.blue, Color(0xFF7C3AED)]),
                boxShadow: const [BoxShadow(color: Color(0x400077B6), blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: ElevatedButton.icon(
                onPressed: () => lxGetStarted(context),
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text('Get Started'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        if (kShowParentSignupLink) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => lxGetStarted(context),
            icon: const Icon(Icons.family_restroom, size: 18),
            label: const Text('New parent? Sign up your child'),
          ),
        ],
        const SizedBox(height: 26),
        Wrap(
          alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _chips)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: c.$3.withOpacity(0.10), borderRadius: BorderRadius.circular(30)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(c.$1, size: 15, color: c.$3),
                  const SizedBox(width: 6),
                  Text(c.$2, style: TextStyle(color: c.$3, fontSize: 12.5, fontWeight: FontWeight.w800)),
                ]),
              ),
          ],
        ),
      ],
    );

    final robot = SizedBox(
      width: isWide ? 340 : 220,
      height: (isWide ? 340 : 220) * (920 / 756),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/hero_robot.png', fit: BoxFit.contain)),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 40 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AuthTheme.cardBorder),
        boxShadow: _elevated,
      ),
      child: isWide
          ? Row(children: [
              Expanded(flex: 6, child: text),
              const SizedBox(width: 20),
              Expanded(flex: 4, child: Center(child: robot)),
            ])
          : Column(children: [robot, const SizedBox(height: 20), text]),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('What you will do in Learnix', textAlign: TextAlign.center, style: TextStyle(color: AuthTheme.ink, fontSize: 28, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Text('Everything a young maker needs, in one place.', textAlign: TextAlign.center, style: TextStyle(color: AuthTheme.textMuted, fontSize: 14.5)),
      ],
    );
  }
}

class _Activity {
  final IconData icon;
  final String title, desc, tag;
  final Color a, b;
  const _Activity(this.icon, this.title, this.desc, this.tag, this.a, this.b);
}

class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid();

  static const _items = [
    _Activity(Icons.touch_app_rounded, 'Interactive Learning', 'Day-by-day lessons with pictures, quizzes and a voice tutor. New days open as you finish class.', 'Lessons', Color(0xFF7C3AED), Color(0xFFA855F7)),
    _Activity(Icons.science_rounded, 'Virtual Labs', 'Wire LEDs, buzzers, sensors and motors on a breadboard and watch your circuit come alive.', 'Hands-on', Color(0xFF0891B2), Color(0xFF22D3EE)),
    _Activity(Icons.smart_toy_rounded, 'Zola, your AI tutor', 'Stuck on something? Ask Zola any question and get a simple, friendly answer.', 'AI', Color(0xFFEA580C), Color(0xFFFB923C)),
    _Activity(Icons.document_scanner_rounded, 'Concept Studio', 'Scan or upload a page and turn it into a visual lesson you can explore.', 'AI', Color(0xFFDB2777), Color(0xFFF472B6)),
    _Activity(Icons.collections_rounded, 'Project Gallery', 'Show the projects you built and see what other students are making.', 'Create', Color(0xFF16A34A), Color(0xFF4ADE80)),
    _Activity(Icons.emoji_events_rounded, 'Levels & Progress', 'Complete levels, track every day you finish and see how far you have come.', 'Grow', Color(0xFF0077B6), Color(0xFF4CC9F0)),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 20.0;
      final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
      final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final a in _items) SizedBox(width: cardW, child: _ActivityCard(a))],
      );
    });
  }
}

class _ActivityCard extends StatefulWidget {
  final _Activity a;
  const _ActivityCard(this.a);

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AuthTheme.cardBorder),
          boxShadow: _hover
              ? [BoxShadow(color: a.a.withOpacity(0.28), blurRadius: 34, offset: const Offset(0, 18))]
              : _elevated,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 6, decoration: BoxDecoration(gradient: LinearGradient(colors: [a.a, a.b]))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a.a, a.b]),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: a.a.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
                        ),
                        child: Icon(a.icon, color: Colors.white, size: 28),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: a.a.withOpacity(0.10), borderRadius: BorderRadius.circular(30)),
                        child: Text(a.tag, style: TextStyle(color: a.a, fontSize: 11.5, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(a.title, style: const TextStyle(color: AuthTheme.ink, fontSize: 18.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(a.desc, style: const TextStyle(color: AuthTheme.textMuted, fontSize: 13.5, height: 1.55)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The labs inside Virtual Lab (same names and colours as virtual_lab_screen.dart). Keep the two lists in step.
class _LabsSection extends StatelessWidget {
  const _LabsSection();

  static const _labs = [
    (Icons.precision_manufacturing_rounded, 'Robotics Lab', 'Levels 1 to 7', Color(0xFF1E88E5)),
    (Icons.psychology_rounded, 'AI Lab', 'Levels 1 to 5', Color(0xFF7E57C2)),
    (Icons.code_rounded, 'Code Lab', 'Python and C', Color(0xFF00897B)),
    (Icons.science_rounded, 'Science Lab', 'Physics, Chemistry, Biology', Color(0xFFFB8C00)),
    (Icons.calculate_rounded, 'Math Lab', 'Numbers, shapes and graphs', Color(0xFFF9A825)),
    (Icons.bolt_rounded, 'Vedic Maths Lab', 'Quick mental-maths tricks', Color(0xFF7C3AED)),
    (Icons.grid_on_rounded, 'Abacus Lab', 'Levels 1 to 7 by age', Color(0xFFEF6C00)),
    (Icons.rocket_launch_rounded, 'Space Lab', 'Planets, rockets and stars', Color(0xFF3949AB)),
    (Icons.extension_rounded, 'Chess Lab', 'Play in 3D and learn', Color(0xFF455A64)),
    (Icons.self_improvement_rounded, 'Yoga Lab', 'Poses and breathing', Color(0xFF16A34A)),
    (Icons.translate_rounded, 'Tamil Lab', 'Read, write and speak', Color(0xFF8D2B3A)),
    (Icons.menu_book_rounded, 'English Lab', 'Words, grammar and stories', Color(0xFFE5557A)),
    (Icons.public_rounded, 'Social Lab', 'Maps, history and civics', Color(0xFF6D5A3C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${_labs.length} labs to explore', textAlign: TextAlign.center, style: const TextStyle(color: AuthTheme.ink, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('From robots and code to maths, science and languages.', textAlign: TextAlign.center, style: TextStyle(color: AuthTheme.textMuted, fontSize: 14.5)),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          const gap = 16.0;
          final cols = c.maxWidth >= 960 ? 4 : (c.maxWidth >= 680 ? 3 : (c.maxWidth >= 380 ? 2 : 1));
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final l in _labs)
                Container(
                  width: w,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AuthTheme.cardBorder),
                    boxShadow: _elevated,
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: l.$4,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: l.$4.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
                        ),
                        child: Icon(l.$1, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AuthTheme.ink, fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(l.$3, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AuthTheme.textMuted, fontSize: 12, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

/// Closing call-to-action: a gradient elevated card.
class _StartCard extends StatelessWidget {
  const _StartCard();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final text = Column(
      crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text('Ready to build something?', textAlign: isWide ? TextAlign.left : TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          'Jump in and continue your lessons, labs and projects.',
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14.5, height: 1.5),
        ),
      ],
    );
    final button = ElevatedButton(
      onPressed: () => lxGetStarted(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AuthTheme.blueDeep,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Get Started', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 36 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AuthTheme.blueDeep, AuthTheme.blue, Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Color(0x400077B6), blurRadius: 34, offset: Offset(0, 16))],
      ),
      child: isWide
          ? Row(children: [Expanded(child: text), const SizedBox(width: 20), button])
          : Column(children: [text, const SizedBox(height: 20), button]),
    );
  }
}

/// App tagline at the foot of the page. Change the wording here only.
class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AuthTheme.ink),
        children: [
          TextSpan(text: 'Learnix: '),
          TextSpan(text: 'AI-powered', style: TextStyle(color: AuthTheme.blue)),
          TextSpan(text: ' learning'),
        ],
      ),
    );
  }
}
