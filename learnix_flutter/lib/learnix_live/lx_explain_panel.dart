import 'dart:convert';
import 'package:flutter/material.dart';
import 'lx_support.dart';

/// The written explanation that goes with a Concept Studio visual, drawn as a set of cards: a highlighted answer,
/// a step timeline, key ideas, a real-life example, a common mistake and a "Try it" card. It can be read aloud and
/// switched to Tamil or Hindi (Gemini, saved once).
/// Text format: "## heading", "- bullet", "1. step", **bold**. Anything else is a paragraph.
class _Item {
  final String kind; // h, p, b, n
  final String text;
  final String? num;
  const _Item(this.kind, this.text, [this.num]);
}

List<_Item> _parse(String raw) {
  final out = <_Item>[];
  for (var line in raw.split('\n')) {
    line = line.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('## ')) {
      out.add(_Item('h', line.substring(3).trim()));
    } else if (line.startsWith('# ')) {
      out.add(_Item('h', line.substring(2).trim()));
    } else if (RegExp(r'^\d+[.)]\s+').hasMatch(line)) {
      final m = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(line)!;
      out.add(_Item('n', m.group(2)!, m.group(1)));
    } else if (line.startsWith('- ') || line.startsWith('* ')) {
      out.add(_Item('b', line.substring(2).trim()));
    } else {
      out.add(_Item('p', line));
    }
  }
  return out;
}

/// One card: a heading (index into the items, or -1 before the first heading) and the items under it.
class _Sec {
  final int head;
  final List<int> body = [];
  _Sec(this.head);
}

String _plain(String s) => s.replaceAll('**', '');

/// How each known section looks.
class _Look {
  final IconData icon;
  final Color color, tint;
  const _Look(this.icon, this.color, this.tint);
}

_Look _lookFor(String english) {
  final h = english.toLowerCase();
  if (h.contains('page')) return const _Look(Icons.document_scanner_rounded, Color(0xFFB45309), Color(0xFFFFFBEB));
  if (h.contains('how')) return const _Look(Icons.route_rounded, Color(0xFF0369A1), Colors.white);
  if (h.contains('key')) return const _Look(Icons.key_rounded, Color(0xFF6D28D9), Color(0xFFF5F3FF));
  if (h.contains('real')) return const _Look(Icons.public_rounded, Color(0xFF047857), Color(0xFFECFDF5));
  if (h.contains('mistake')) return const _Look(Icons.error_outline_rounded, Color(0xFFB91C1C), Color(0xFFFEF2F2));
  if (h.contains('try')) return const _Look(Icons.touch_app_rounded, Color(0xFF0F172A), Color(0xFFE0F2FE));
  return const _Look(Icons.notes_rounded, Color(0xFF334155), Colors.white);
}

class _SceneData {
  final String emoji, caption;
  final List<(String, int)> groups;
  const _SceneData(this.emoji, this.caption, this.groups);
  int get total => groups.fold(0, (a, g) => a + g.$2);
}

final _sceneCache = <String, _SceneData?>{};

/// Asks Gemini (gemini-generate, no credits) to turn the real-life example into a tiny scene: one emoji, split into labelled groups.
Future<_SceneData?> _loadScene(String story) async {
  if (_sceneCache.containsKey(story)) return _sceneCache[story];
  _SceneData? out;
  try {
    const system = 'You turn a short real-life example into a tiny animated scene for children. Reply ONLY JSON: '
        '{"emoji":"one emoji for the thing being shared or split","caption":"max 10 words","groups":[{"label":"1 or 2 words","count":int}]}. '
        '2 to 4 groups, each count 1 to 10, total at most 14, use the numbers from the example. '
        'If the example is not about things split, shared or compared in groups, reply {"none":true}.';
    final d = await lxGeminiText(system: system, prompt: story, temperature: 0.3, maxTokens: 400);
    if (d is Map && d['success'] == true) {
      final t = '${d['text']}';
      final a = t.indexOf('{'), b = t.lastIndexOf('}');
      if (a >= 0 && b > a) {
        final j = jsonDecode(t.substring(a, b + 1));
        if (j is Map && j['none'] != true && j['groups'] is List) {
          final gs = <(String, int)>[];
          for (final g in (j['groups'] as List).take(4)) {
            if (g is Map) gs.add(('${g['label']}', ((g['count'] as num?) ?? 0).toInt().clamp(1, 10)));
          }
          final em = '${j['emoji'] ?? ''}'.trim();
          if (gs.length >= 2 && em.isNotEmpty) out = _SceneData(em, '${j['caption'] ?? ''}', gs);
        }
      }
    }
  } catch (_) {}
  _sceneCache[story] = out;
  return out;
}

/// The animation under "Real-life example": the things appear one by one, then move into their labelled groups.
class _RealScene extends StatefulWidget {
  final String story;
  final Color color;
  const _RealScene({required this.story, required this.color});
  @override
  State<_RealScene> createState() => _RealSceneState();
}

class _RealSceneState extends State<_RealScene> with SingleTickerProviderStateMixin {
  // Created in initState, not lazily: a lazy controller was first created inside dispose() when the panel closed before the scene loaded.
  late final AnimationController _c;
  _SceneData? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
    _loadScene(widget.story).then((d) {
      if (!mounted) return;
      setState(() {
        data = d;
        loading = false;
      });
      if (d != null) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _pop(double t, double start, double len) => Curves.elasticOut.transform(((t - start) / len).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: widget.color)), const SizedBox(width: 8), Text('Drawing the example...', style: TextStyle(color: widget.color, fontSize: 12.5))]));
    }
    final d = data;
    if (d == null) return const SizedBox.shrink();
    final total = d.total;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.color.withOpacity(0.25))),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final split = ((t - 0.45) / 0.25).clamp(0.0, 1.0); // 0 = all together, 1 = in groups
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(t < 0.5 ? 'We start with $total' : (d.caption.isEmpty ? 'Now we split them' : d.caption), style: TextStyle(fontWeight: FontWeight.w800, color: widget.color, fontSize: 13))),
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Replay', icon: Icon(Icons.replay_rounded, size: 20, color: widget.color), onPressed: () => _c.forward(from: 0)),
            ]),
            if (split < 1)
              Opacity(
                opacity: 1 - split,
                child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i < total; i++) Transform.scale(scale: _pop(t, 0.02 + i * (0.38 / total), 0.2), child: Text(d.emoji, style: const TextStyle(fontSize: 26))),
                ]),
              )
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var g = 0; g < d.groups.length; g++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(color: widget.color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.color.withOpacity(0.3))),
                      child: Column(children: [
                        Text(d.groups[g].$1, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: widget.color)),
                        const SizedBox(height: 4),
                        Wrap(alignment: WrapAlignment.center, spacing: 3, runSpacing: 3, children: [
                          for (var i = 0; i < d.groups[g].$2; i++) Transform.scale(scale: _pop(t, 0.72 + (g * 0.03) + i * 0.025, 0.2), child: Text(d.emoji, style: const TextStyle(fontSize: 22))),
                        ]),
                        const SizedBox(height: 4),
                        Text('${d.groups[g].$2}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: widget.color)),
                      ]),
                    ),
                  ),
              ]),
          ]);
        },
      ),
    );
  }
}

class LxExplainPanel extends StatefulWidget {
  final String text;
  final Color accent;
  const LxExplainPanel({super.key, required this.text, this.accent = const Color(0xFF0284C7)});
  @override
  State<LxExplainPanel> createState() => _LxExplainPanelState();
}

class _LxExplainPanelState extends State<LxExplainPanel> {
  late final List<_Item> items = _parse(widget.text);
  late final List<_Sec> secs = _sections();
  String lang = 'en';
  String? loading;
  bool speaking = false;
  final _shown = <String, List<String>>{}; // language -> translated item texts

  List<_Sec> _sections() {
    final out = <_Sec>[];
    _Sec? cur;
    for (var i = 0; i < items.length; i++) {
      if (items[i].kind == 'h') {
        cur = _Sec(i);
        out.add(cur);
      } else {
        if (cur == null) {
          cur = _Sec(-1);
          out.add(cur);
        }
        cur.body.add(i);
      }
    }
    return out;
  }

  List<String> get _texts => [for (final i in items) i.text];

  Future<void> _pick(String l) async {
    if (l == 'en' || _shown.containsKey(l)) {
      setState(() => lang = l);
      return;
    }
    setState(() => loading = l);
    final t = await aiTranslateList(_texts, l);
    if (!mounted) return;
    setState(() {
      loading = null;
      if (t != null) {
        _shown[l] = t;
        lang = l;
      }
    });
    if (t == null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not translate to ${kAiLangs[l]} right now. Please try again.')));
  }

  Future<void> _listen() async {
    if (speaking) {
      await IlVoice.stop();
      if (mounted) setState(() => speaking = false);
      return;
    }
    final texts = lang == 'en' ? _texts : (_shown[lang] ?? _texts);
    setState(() => speaking = true);
    await IlVoice.say(texts.map(_plain).join('. '), lang: lang);
    if (mounted) setState(() => speaking = false);
  }

  @override
  void dispose() {
    IlVoice.stop();
    super.dispose();
  }

  List<InlineSpan> _spans(String s, TextStyle base, Color boldColor) {
    final spans = <InlineSpan>[];
    final parts = s.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(text: parts[i], style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w800, color: boldColor) : base));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final texts = lang == 'en' ? _texts : (_shown[lang] ?? _texts);
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: widget.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.auto_stories_rounded, color: widget.accent, size: 19)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Explanation', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)))),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: widget.accent.withOpacity(0.12), foregroundColor: widget.accent),
                onPressed: loading != null ? null : _listen,
                icon: Icon(speaking ? Icons.stop_rounded : Icons.volume_up_rounded, size: 18),
                label: Text(speaking ? 'Stop' : 'Listen', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 8),
            AiLangChips(lang: lang, loading: loading, onPick: _pick, color: widget.accent),
          ]),
        ),
        Expanded(
          child: SelectionArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 30), children: [
              for (final s in secs) _card(s, texts),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _card(_Sec s, List<String> texts) {
    final english = s.head >= 0 ? items[s.head].text : '';
    final title = s.head >= 0 ? _plain(texts[s.head]) : '';
    final isAnswer = english.toLowerCase().contains('one line');
    if (isAnswer) return _answerCard(title, s, texts);
    final look = _lookFor(english);
    final isTry = english.toLowerCase().contains('try');
    const body = TextStyle(fontSize: 14.5, height: 1.55, color: Color(0xFF1E293B));
    final steps = [for (final i in s.body) if (items[i].kind == 'n') i];
    final children = <Widget>[];
    for (final i in s.body) {
      final it = items[i];
      final text = texts[i];
      if (it.kind == 'n') {
        children.add(_step(it.num ?? '', text, steps.indexOf(i) == steps.length - 1, look.color, body));
      } else if (it.kind == 'b') {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(margin: const EdgeInsets.only(top: 3), width: 18, height: 18, decoration: BoxDecoration(color: look.color.withOpacity(0.14), shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 13, color: look.color)),
            const SizedBox(width: 10),
            Expanded(child: Text.rich(TextSpan(children: _spans(text, body, look.color)))),
          ]),
        ));
      } else {
        children.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Text.rich(TextSpan(children: _spans(text, body, look.color)))));
      }
    }
    if (english.toLowerCase().contains('real')) {
      final story = [for (final i in s.body) if (items[i].kind != 'n') _plain(items[i].text)].join(' ');
      if (story.length > 30) children.add(_RealScene(story: story, color: look.color));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: look.tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isTry ? const Color(0xFF38BDF8) : look.color.withOpacity(0.16), width: isTry ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (s.head >= 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(width: 30, height: 30, decoration: BoxDecoration(color: look.color, borderRadius: BorderRadius.circular(10)), child: Icon(look.icon, color: Colors.white, size: 17)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: look.color))),
              ]),
            ),
          ...children,
        ]),
      ),
    );
  }

  /// "In one line": the direct answer, big and on a coloured card.
  Widget _answerCard(String title, _Sec s, List<String> texts) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0369A1), Color(0xFF6D28D9)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x330369A1), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lightbulb_rounded, color: Color(0xFFFDE047), size: 20),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFFBAE6FD), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.4)),
        ]),
        const SizedBox(height: 8),
        for (final i in s.body)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(TextSpan(children: _spans(texts[i], const TextStyle(color: Colors.white, fontSize: 16.5, height: 1.45, fontWeight: FontWeight.w600), const Color(0xFFFDE047)))),
          ),
      ]),
    );
  }

  Widget _step(String n, String text, bool last, Color color, TextStyle body) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5))),
            if (!last) Expanded(child: Center(child: Container(width: 2, color: color.withOpacity(0.25)))),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(child: Padding(padding: EdgeInsets.only(bottom: last ? 6 : 14, top: 2), child: Text.rich(TextSpan(children: _spans(text, body, color))))),
      ]),
    );
  }
}
