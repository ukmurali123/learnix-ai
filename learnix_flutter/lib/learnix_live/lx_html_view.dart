import 'lx_html_view_stub.dart' if (dart.library.html) 'lx_html_view_web.dart' as impl;

/// Shows an AI-written interactive page (HTML, CSS, JS, often three.js) in a locked-down sandbox:
/// an `<iframe sandbox="allow-scripts">` on the web (no access to the app's storage or cookies) and a WebView on phones.
/// The server wraps the page in a Content-Security-Policy that blocks all network calls except the three.js CDN.
class LxHtmlView extends impl.LxHtmlViewImpl {
  const LxHtmlView({super.key, required super.html, super.bridge});
}

/// Optional two-way text channel between the app and a page shown in [LxHtmlView].
/// The page calls `parent.postMessage(str, '*')` (web) or `LxBridge.postMessage(str)` (phones); the app calls [send].
class LxBridge {
  void Function(String message)? onMessage;
  void Function(String message)? toPage;
  void send(String message) => toPage?.call(message);
}

/// Fires a few `resize` events after the page loads, so canvases that measure themselves at start-up
/// redraw once the frame has its real size.
String lxKick(String html) {
  const kick = "<script>(function(){var n=0;function k(){try{window.dispatchEvent(new Event('resize'))}catch(e){}if(++n<14)setTimeout(k,n<5?120:500)}window.addEventListener('load',k);setTimeout(k,40)})()</script>";
  final i = html.lastIndexOf('</body>');
  return i < 0 ? html + kick : html.substring(0, i) + kick + html.substring(i);
}
