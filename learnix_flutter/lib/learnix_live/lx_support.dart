// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Backend address for the Concept Studio calls (set by the screen from the app's base URL).
String lxApiBase = '';

/// Languages the explanation can be switched to (same as the live Learnix app).
const kAiLangs = <String, String>{'en': 'English', 'ta': 'தமிழ்', 'hi': 'हिन्दी'};

final _memory = <String, List<String>>{};

/// Translates the explanation items with Gemini on this project's backend. Returns null on failure.
Future<List<String>?> aiTranslateList(List<String> texts, String lang) async {
  if (lang == 'en' || texts.isEmpty) return texts;
  final key = '${texts.join('\u0001').hashCode}|$lang';
  if (_memory[key] != null) return _memory[key];
  try {
    final r = await http
        .post(Uri.parse('$lxApiBase/api/concept-studio/translate'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'texts': texts, 'lang': lang}))
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) return null;
    final list = [for (final t in (jsonDecode(r.body)['texts'] as List)) '$t'];
    if (list.length != texts.length) return null;
    return _memory[key] = list;
  } catch (_) {
    return null;
  }
}

/// Short Gemini text call (used for the small real-life scene in the explanation).
Future<Object?> lxGeminiText({required String system, required String prompt, double temperature = 0.3, int maxTokens = 400, String checkText = ''}) async {
  try {
    final r = await http
        .post(Uri.parse('$lxApiBase/api/concept-studio/text'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'system': system, 'prompt': prompt, 'temperature': temperature, 'maxTokens': maxTokens, 'check_text': checkText}))
        .timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  } catch (_) {
    return null;
  }
}

/// Read-aloud with the browser's own voice (this project runs on the web).
class IlVoice {
  static const _codes = {'en': 'en-IN', 'ta': 'ta-IN', 'hi': 'hi-IN'};
  static Future<void> say(String text, {String lang = 'en'}) async {
    final s = html.window.speechSynthesis;
    if (s == null) return;
    s.cancel();
    final u = html.SpeechSynthesisUtterance(text)..lang = _codes[lang] ?? 'en-IN';
    final done = u.onEnd.first;
    s.speak(u);
    try {
      await done.timeout(const Duration(minutes: 5));
    } catch (_) {}
  }

  static Future<void> stop() async => html.window.speechSynthesis?.cancel();
}

/// Language switch chips (copied from the live Learnix app).
class AiLangChips extends StatelessWidget {
  final String lang;
  final String? loading;
  final ValueChanged<String> onPick;
  final Color color;
  const AiLangChips({super.key, required this.lang, required this.onPick, this.loading, this.color = const Color(0xFF0077B6)});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.translate_rounded, size: 16, color: color),
      const SizedBox(width: 6),
      for (final e in kAiLangs.entries)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: loading != null || e.key == lang ? null : () => onPick(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: e.key == lang ? color : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (loading == e.key) ...[
                  SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
                  const SizedBox(width: 6),
                ],
                Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: e.key == lang ? Colors.white : color)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

