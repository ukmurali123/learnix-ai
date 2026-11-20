import 'dart:html' as dhtml;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'lx_html_view.dart' show LxBridge;

class LxHtmlViewImpl extends StatelessWidget {
  final String html;
  final LxBridge? bridge;
  const LxHtmlViewImpl({super.key, required this.html, this.bridge});

  @override
  Widget build(BuildContext context) {
    final b = bridge;
    final viewType = 'lx-html-${this.html.hashCode}-${this.html.length}${b == null ? '' : '-${identityHashCode(b)}'}';
    try {
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final f = dhtml.IFrameElement()
          ..setAttribute('sandbox', 'allow-scripts') // no same-origin: the page cannot touch the app's storage or cookies
          ..srcdoc = this.html
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        if (b != null) {
          b.toPage = (String m) => f.contentWindow?.postMessage(m, '*');
          // Note: comparing e.source with f.contentWindow is unreliable on the web (each read gives a new
          // wrapper object), so messages are accepted by content instead: only pages that use a bridge send them.
          dhtml.window.onMessage.listen((e) {
            if (e.data is String && (e.data as String).startsWith('{')) b.onMessage?.call(e.data as String);
          });
        }
        return f;
      });
    } catch (_) {
      // already registered for this content
    }
    return HtmlElementView(viewType: viewType);
  }
}
