import 'package:flutter/material.dart';
import 'lx_explain_panel.dart';
import 'lx_html_view.dart';
import 'lx_lesson_lite.dart';

/// Shows what Concept Studio made for a request: the AI-designed visual, filling the whole page. No fixed cards,
/// tabs, practical or quiz. (If an older result has several screens, a slim Back / Next bar appears.)
class LxVisualView extends StatefulWidget {
  final LxLesson lesson;
  final VoidCallback? onFinished; // called when the student presses Finish on the last screen
  final String? scanId, shareToken; // set for a lesson saved in History: enables Save and Share
  final bool saved;
  final Future<void> Function()? onSaveDraft; // staff preview: no scan id, so offer "Save as a draft lesson" instead
  final bool fullscreen; // shown on its own page, covering the app bar and menu
  const LxVisualView({super.key, required this.lesson, this.onFinished, this.scanId, this.shareToken, this.saved = false, this.onSaveDraft, this.fullscreen = false});
  @override
  State<LxVisualView> createState() => _LxVisualViewState();
}

class _LxVisualViewState extends State<LxVisualView> {
  static const _bg = Color(0xFF0F172A);
  late final List<LxBlock> screens = [for (final b in widget.lesson.blocks) if (b.type == 'interactive' && b.s('html').isNotEmpty) b];
  late final List<String> pages = [for (final b in screens) lxKick(b.s('html'))];
  /// The written explanation that goes with the visual (an 'explain' block). Empty for older results.
  late final String explain = [for (final b in widget.lesson.blocks) if (b.type == 'explain' && b.s('text').trim().isNotEmpty) b.s('text')].firstOrNull ?? '';
  bool showExplain = false; // narrow screens switch between the visual and the explanation
  bool panelOpen = true; // wide screens: the explanation panel can be collapsed

  void _toggleFullscreen() {
    if (widget.fullscreen) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: LxVisualView(lesson: widget.lesson, onFinished: widget.onFinished, scanId: widget.scanId, shareToken: widget.shareToken, saved: saved, onSaveDraft: widget.onSaveDraft, fullscreen: true),
        ),
      ),
    ));
  }
  int at = 0;
  bool finished = false;
  late bool saved = widget.saved;
  bool draftSaved = false, draftBusy = false;

  /// Save and Share live in the full Learnix app (Supabase); this project shows the visual only.
  List<Widget> _actions() => const [];

  void _go(int i) {
    if (i < 0 || i >= screens.length) return;
    setState(() => at = i);
  }

  @override
  Widget build(BuildContext context) {
    if (screens.isEmpty) return const Center(child: Text('This lesson has no screens.'));
    // The usual case: one visual made for the request. Show only that, filling the page (no bar, no steps).
    if (screens.length == 1) {
      final wide = MediaQuery.of(context).size.width >= 900;
      final acts = _actions();
      final header = Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 6, 0),
        child: Row(children: [
          Expanded(child: Text(widget.lesson.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13))),
          Tooltip(
            message: 'Made by AI. It can make mistakes, so please verify important facts.',
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome, size: 12, color: Colors.white70),
                SizedBox(width: 4),
                Text('AI-made · verify', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          ...acts,
          if (explain.isNotEmpty && wide)
            IconButton(
              tooltip: panelOpen ? 'Hide explanation' : 'Show explanation',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => panelOpen = !panelOpen),
              icon: Icon(panelOpen ? Icons.last_page_rounded : Icons.menu_book_rounded, color: Colors.white),
            ),
          IconButton(
            tooltip: widget.fullscreen ? 'Exit full screen' : 'Full screen',
            visualDensity: VisualDensity.compact,
            onPressed: _toggleFullscreen,
            icon: Icon(widget.fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white),
          ),
        ]),
      );
      // While the Save dialog is open the animation is stopped (it is rebuilt afterwards), so a heavy 3D visual cannot slow the page.
      final Widget visual = draftBusy ? const SizedBox.expand() : LxHtmlView(html: pages.first);
      if (explain.isEmpty) {
        return Container(color: _bg, child: Column(children: [header, Expanded(child: visual)]));
      }
      // Wide screens: the visual and the explanation side by side (the panel can be collapsed). Narrow screens: a switch between the two.
      if (wide) {
        return Container(
          color: _bg,
          child: Row(children: [
            Expanded(child: Column(children: [header, Expanded(child: visual)])),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: panelOpen ? 420 : 0,
              child: panelOpen ? LxExplainPanel(text: explain) : const SizedBox.shrink(),
            ),
          ]),
        );
      }
      return Container(
        color: _bg,
        child: Column(children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white70, selectedBackgroundColor: const Color(0xFF38BDF8), selectedForegroundColor: _bg),
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.play_circle_outline_rounded, size: 18), label: Text('Visual')),
                  ButtonSegment(value: true, icon: Icon(Icons.menu_book_rounded, size: 18), label: Text('Explanation')),
                ],
                selected: {showExplain},
                onSelectionChanged: (s) => setState(() => showExplain = s.first),
              ),
            ),
          ),
          Expanded(child: IndexedStack(index: showExplain ? 1 : 0, children: [visual, LxExplainPanel(text: explain)])),
        ]),
      );
    }
    final last = at == screens.length - 1;
    final narrow = MediaQuery.of(context).size.width < 600;
    return Container(
      color: _bg,
      child: Column(children: [
        // Slim bar: which screen this is, and the way to the others.
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(children: [
            IconButton(
              tooltip: 'Back',
              visualDensity: VisualDensity.compact,
              onPressed: at > 0 ? () => _go(at - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: Colors.white,
              disabledColor: Colors.white24,
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (var i = 0; i < screens.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _go(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: i == at ? const Color(0xFF38BDF8) : Colors.white10, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            narrow && i != at ? '${i + 1}' : '${i + 1}. ${screens[i].s('title', 'Explore it')}',
                            style: TextStyle(color: i == at ? _bg : Colors.white70, fontWeight: FontWeight.w800, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            ..._actions(),
            const SizedBox(width: 6),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: last ? const Color(0xFF22C55E) : const Color(0xFF38BDF8), foregroundColor: _bg, visualDensity: VisualDensity.compact),
              onPressed: last
                  ? (finished
                      ? null
                      : () {
                          setState(() => finished = true);
                          widget.onFinished?.call();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Well done! You finished this lesson.')));
                        })
                  : () => _go(at + 1),
              icon: Icon(last ? Icons.check_rounded : Icons.chevron_right_rounded, size: 18),
              label: Text(last ? (finished ? 'Done' : 'Finish') : 'Next', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        // The AI-built screen, using all the space that is left. Each screen keeps its own state while it is open.
        Expanded(child: LxHtmlView(key: ValueKey('vis$at'), html: pages[at])),
      ]),
    );
  }
}
