import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'lx_html_view.dart';
import 'lx_support.dart';

/// 3D Working Models: five animated 3D models (the same set as the live Learnix Model Lab):
/// Smart farm, Auto street lights, Traffic signal, Factory line and Gear train. Switches drive each model,
/// and "Ask Zola to explain" sends the model and switch states to Gemini.
class ModelsLabScreen extends StatefulWidget {
  final String baseUrl;
  const ModelsLabScreen({super.key, required this.baseUrl});
  @override
  State<ModelsLabScreen> createState() => _ModelsLabScreenState();
}

class _ModelsLabScreenState extends State<ModelsLabScreen> {
  final LxBridge _bridge = LxBridge();
  late final Future<String> _page = rootBundle.loadString('assets/labs/models_lab.html');

  static const _system = 'You are Zola, a friendly electronics and coding tutor for school students aged 8 to 16. '
      'The student is running a real-component circuit in the Learnix Virtual Lab: a 3D working model controlled by their own '
      'Arduino C++ code on an Arduino Uno or ESP32 (you get the board, parts with pins, live pin states, sensor inputs, serial output and code). '
      'Answer in plain text, no markdown headings, no ** stars, under 150 words:\n'
      'Great: <one thing that works>\n'
      'What is happening: <explain the circuit and code right now, using the pin states>\n'
      'Steps:\n1. <a missing logic, bug or improvement> - Hint: <question>\n2. ...\n(at most 3 steps)\n'
      'Try this: <at most 4 lines of code>\n'
      'Mention board differences when useful (Uno 5 V and 0-1023 analog; ESP32 3.3 V, 0-4095 analog, GPIO numbers). '
      'Only safe low-voltage electronics; if the question is not suitable for a child, gently refuse and bring them back to the model.';

  @override
  void initState() {
    super.initState();
    lxApiBase = widget.baseUrl;
    _bridge.onMessage = _onMessage;
  }

  @override
  void dispose() {
    _bridge.onMessage = null;
    _bridge.toPage = null;
    super.dispose();
  }

  Future<void> _onMessage(String raw) async {
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }
    if (m['type'] != 'zola' || m['mode'] != 'model') return;
    final q = '${m['question'] ?? ''}'.trim();
    final prompt = 'Model: ${m['model']} on ${m['board']}\nWhat it does: ${m['desc']}\nParts and pins: ${m['parts']}\n'
        'Live pin states:\n${m['pins']}\nSensor inputs: ${m['inputs']}\nRunning: ${m['running']}\n'
        '${'${m['error'] ?? ''}'.isNotEmpty ? 'Code error: ${m['error']}\n' : ''}Serial output:\n${m['serial']}\n\nStudent code:\n${m['code']}\n\n'
        '${q.isNotEmpty ? 'Student question: $q' : 'Explain this circuit and code, and give the next steps.'}';
    final r = await lxGeminiText(system: _system, prompt: prompt, temperature: 0.5, maxTokens: 700, checkText: q);
    var text = (r is Map && r['success'] == true) ? '${r['text']}'.trim() : '';
    if (text.isEmpty) text = 'I could not reach my AI brain right now. Read "How it works" on the right, then flip the switches one by one and watch what changes!';
    _bridge.send(jsonEncode({'type': 'zola', 'text': text}));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _page,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Could not open the 3D models: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ClipRRect(borderRadius: BorderRadius.circular(16), child: LxHtmlView(html: lxKick(snap.data!), bridge: _bridge));
      },
    );
  }
}
