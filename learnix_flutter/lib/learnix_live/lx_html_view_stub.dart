import 'package:flutter/material.dart';
import 'lx_html_view.dart' show LxBridge;

class LxHtmlViewImpl extends StatelessWidget {
  final String html;
  final LxBridge? bridge;
  const LxHtmlViewImpl({super.key, required this.html, this.bridge});
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black, child: Center(child: Text('Interactive view unavailable', style: TextStyle(color: Colors.white70))));
}
