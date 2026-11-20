/// Concept Studio result, in the same JSON shape as the live Learnix app:
/// {kind: 'visual', title, topic, summary, blocks: [{type: 'interactive', title, html}, {type: 'explain', title, text}]}
class LxBlock {
  final String type;
  final Map<String, dynamic> d;
  const LxBlock(this.type, this.d);
  String s(String k, [String def = '']) => d[k] is String ? d[k] as String : def;
}

class LxLesson {
  final String title, topic, summary, kind;
  final List<LxBlock> blocks;
  const LxLesson(this.title, this.topic, this.summary, this.blocks, {this.kind = ''});

  static LxLesson? fromJson(Object? j) {
    if (j is! Map || j['blocks'] is! List) return null;
    final blocks = <LxBlock>[];
    for (final b in j['blocks'] as List) {
      if (b is! Map || b['type'] is! String) continue;
      final m = Map<String, dynamic>.from(b);
      if (m['type'] == 'interactive') {
        final h = m['html'];
        if (h is! String || h.length < 200 || '<script'.allMatches(h).length != '</script>'.allMatches(h).length) continue;
      }
      if (m['type'] == 'explain' && m['text'] is! String) continue;
      blocks.add(LxBlock(m['type'] as String, m));
    }
    if (!blocks.any((b) => b.type == 'interactive')) return null;
    return LxLesson('${j['title'] ?? 'Your visual'}', '${j['topic'] ?? ''}', '${j['summary'] ?? ''}', blocks, kind: '${j['kind'] ?? ''}');
  }
}
