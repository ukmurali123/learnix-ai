import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'lx_html_view.dart';
import 'lx_support.dart';

/// Robo Car Lab: a 3D four-wheel robot car (three.js) driven by the student's Arduino code, with three missions
/// (drive a square, obstacle avoider, line follower). "Ask Zola" sends the code, mission and readings to Gemini.
class RoboCarLabScreen extends StatefulWidget {
  final String baseUrl;
  const RoboCarLabScreen({super.key, required this.baseUrl});
  @override
  State<RoboCarLabScreen> createState() => _RoboCarLabScreenState();
}

class _RoboCarLabScreenState extends State<RoboCarLabScreen> {
  final LxBridge _bridge = LxBridge();
  late final Future<String> _page = rootBundle.loadString('assets/labs/robo_car_lab.html');

  static const _system = 'You are Zola, a friendly robotics tutor for school students aged 8 to 16. '
      'Only safe, low-voltage robotics; if the student asks something not suitable for a child, gently refuse and bring them back to the mission. '
      'The student is programming a 4-wheel Arduino robot car in a simulator. Wiring: L298N driver, left motors ENA=5 IN1=8 IN2=9, '
      'right motors ENB=6 IN3=10 IN4=11; HC-SR04 ultrasonic TRIG=12 ECHO=13 (readDistance() gives cm); IR line sensors LEFT=2 RIGHT=3 '
      '(HIGH over the black line). Helpers: forward(speed), backward(speed), turnLeft(speed), turnRight(speed), stopCar(), speed 0-255; '
      'turnLeft/turnRight spin on the spot. You get a logic checklist ([done] / [MISSING]) made by the app. '
      'Answer in exactly this plain-text format, no markdown headings, no ** stars:\n'
      'Great: <one thing they did well>\n'
      'Missing logic, step by step:\n'
      '1. <first missing or wrong logic, in simple words> - Hint: <a question that makes them think>\n'
      '2. <next one> - Hint: <...>\n'
      '(only the steps that are really missing or wrong, at most 4; if nothing is missing, give tuning steps such as speeds or delay times)\n'
      'Try this: <at most 4 lines of Arduino code for step 1 only>\n'
      'Use short sentences and simple words. Under 140 words.';

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
    if (m['type'] != 'zola' || m['mode'] == 'model') return;
    final prompt = 'Mission: ${m['mission']}\nGoal: ${m['goal']}\nResult so far: ${m['status']}\n'
        '${(m['error'] ?? '').toString().isNotEmpty ? 'Code error: ${m['error']}\n' : ''}'
        'Logic checklist from the app:\n${m['checklist'] ?? ''}\nSensor readings: ${jsonEncode(m['sensors'])}\nLast serial output:\n${m['serial']}\n\nStudent code:\n${m['code']}\n\n'
        '${(m['question'] ?? '').toString().isNotEmpty ? 'Student question: ${m['question']}' : 'The student asked for help with this mission.'}';
    final r = await lxGeminiText(system: _system, prompt: prompt, temperature: 0.4, maxTokens: 700, checkText: '${m['question'] ?? ''}');
    String text = (r is Map && r['success'] == true) ? '${r['text']}'.trim() : '';
    if (text.isEmpty) text = _offlineHint('${m['mission']}', '${m['error'] ?? ''}');
    _bridge.send(jsonEncode({'type': 'zola', 'text': text}));
  }

  String _offlineHint(String mission, String error) {
    if (error.isNotEmpty) return 'I could not reach my AI brain right now, but here is a tip: your code has an error ("$error"). Check for a missing ; or } near that line.';
    if (mission.contains('square')) return 'Nice start! Tip: if the car turns too much or too little, change the delay after turnLeft(). Try 300 or 400 and watch the flags.';
    if (mission.contains('Obstacle')) return 'Good use of readDistance()! When something is close, what should the car do so it can drive away? Try: stopCar(); backward(150); delay(350); turnRight(170); delay(420);';
    return 'You are using both IR sensors, great! When the RIGHT sensor sees the line, which way should the car turn so the line goes back between the sensors?';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _page,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Could not open the Robo Car Lab: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LxHtmlView(html: lxKick(snap.data!), bridge: _bridge),
        );
      },
    );
  }
}
