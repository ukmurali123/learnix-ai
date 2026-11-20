// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'lx_lesson_lite.dart';
import 'lx_support.dart';
import 'lx_visual_view.dart';

/// Concept Studio, as in the live Learnix app: type anything and/or add a page (photo or PDF) and get ONE
/// interactive visual made for it, with a written explanation beside it.
class ConceptStudioLiveScreen extends StatefulWidget {
  final String baseUrl;
  final int studentId;
  const ConceptStudioLiveScreen({super.key, required this.baseUrl, required this.studentId});
  @override
  State<ConceptStudioLiveScreen> createState() => _ConceptStudioLiveScreenState();
}

class _ConceptStudioLiveScreenState extends State<ConceptStudioLiveScreen> {
  final _q = TextEditingController();
  final _files = <Map<String, String>>[]; // {kind, data (dataUrl), name}
  String dim = 'auto';
  bool busy = false;
  String busyText = '';
  Timer? _busyTimer;
  final _history = <LxLesson>[];

  static const _suggestions = [
    'How does an LED work?',
    'Resistors and Ohm\'s law',
    'How does an ultrasonic sensor measure distance?',
    'Pythagoras\' theorem',
    'Phases of the Moon',
    'How do volcanoes erupt?',
  ];
  static const _steps = ['Reading your request...', 'Designing the visual...', 'Drawing and animating...', 'Writing the explanation...', 'Almost ready...'];

  @override
  void initState() {
    super.initState();
    lxApiBase = widget.baseUrl;
  }

  @override
  void dispose() {
    _busyTimer?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _pick({bool camera = false}) {
    if (_files.length >= 3 || (_files.isNotEmpty && _files.first['kind'] == 'pdf')) {
      _snack('You can add up to 3 photos or one PDF.');
      return;
    }
    final input = html.FileUploadInputElement()..accept = camera ? 'image/*' : 'image/jpeg,image/png,application/pdf,.pdf';
    if (camera) input.setAttribute('capture', 'environment');
    input.onChange.listen((_) {
      final f = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (f == null) return;
      final isPdf = f.type == 'application/pdf' || f.name.toLowerCase().endsWith('.pdf');
      if (isPdf && _files.isNotEmpty) return _snack('A PDF must be sent on its own.');
      if (!isPdf && !(f.type == 'image/jpeg' || f.type == 'image/png')) return _snack('Use a JPEG or PNG photo, or a PDF.');
      if (f.size > (isPdf ? 8 : 4) * 1024 * 1024) return _snack(isPdf ? 'PDFs up to 8 MB, please.' : 'Photos up to 4 MB each, please.');
      final r = html.FileReader()..readAsDataUrl(f);
      r.onLoadEnd.first.then((_) {
        final data = r.result;
        if (data is String && mounted) setState(() => _files.add({'kind': isPdf ? 'pdf' : 'image', 'data': data, 'name': f.name}));
      });
    });
    input.click();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _ask([String? preset]) async {
    if (preset != null) _q.text = preset;
    final q = _q.text.trim();
    if (q.length < 3 && _files.isEmpty) return _snack('Type what you want to learn, or add a page.');
    setState(() {
      busy = true;
      busyText = _steps.first;
    });
    var i = 0;
    _busyTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (mounted && i < _steps.length - 1) setState(() => busyText = _steps[++i]);
    });
    try {
      final r = await http
          .post(Uri.parse('${widget.baseUrl}/api/concept-studio/visual'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'question': q,
                'files': [for (final f in _files) {'kind': f['kind'], 'data': f['data']}],
                'dim': dim == 'auto' ? '' : dim,
                'student_id': widget.studentId,
              }))
          .timeout(const Duration(seconds: 200));
      final body = jsonDecode(r.body);
      if (r.statusCode != 200) {
        _snack('${body is Map ? (body['detail'] ?? 'Something went wrong.') : 'Something went wrong.'} Please try again.');
      } else if (body is Map && body['rejected'] == true) {
        _snack('${body['reason']}');
      } else {
        final lesson = LxLesson.fromJson(body is Map ? body['lesson'] : null);
        if (lesson == null) {
          _snack('The visual could not be built this time. Please try again.');
        } else {
          setState(() {
            _history.insert(0, lesson);
            _files.clear();
          });
          _open(lesson);
        }
      }
    } on TimeoutException {
      _snack('This is taking too long. Please try again.');
    } catch (e) {
      _snack('Could not reach the server: $e');
    } finally {
      _busyTimer?.cancel();
      if (mounted) setState(() => busy = false);
    }
  }

  void _open(LxLesson lesson) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Concept Studio', style: TextStyle(fontSize: 18)),
        ),
        body: SafeArea(child: LxVisualView(lesson: lesson)),
      ),
    ));
  }

  Widget _tile(IconData icon, String label, String sub, VoidCallback? onTap) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: const Color(0xFF0077B6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(sub, style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              const Text('What do you want to learn today?', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Type anything and get an interactive visual made for it. Add a photo or PDF if you want it built from your page.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFCBD5E1)), boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 14, offset: Offset(0, 5))]),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: TextField(
                      controller: _q,
                      enabled: !busy,
                      minLines: 1,
                      maxLines: 6,
                      maxLength: 300,
                      onSubmitted: (_) => _ask(),
                      style: const TextStyle(fontSize: 16, height: 1.4),
                      decoration: const InputDecoration(border: InputBorder.none, counterText: '', hintText: 'Ask anything, like "How do volcanoes erupt?"'),
                    ),
                  ),
                  IconButton.filled(onPressed: busy ? null : () => _ask(), icon: const Icon(Icons.arrow_upward)),
                ]),
              ),
              if (_files.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < _files.length; i++)
                    InputChip(
                      avatar: Icon(_files[i]['kind'] == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined, size: 18),
                      label: Text(_files[i]['name'] ?? 'Page ${i + 1}', overflow: TextOverflow.ellipsis),
                      onDeleted: busy ? null : () => setState(() => _files.removeAt(i)),
                    ),
                ]),
              ],
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                for (final s in _suggestions) ActionChip(label: Text(s, style: const TextStyle(fontSize: 12.5)), onPressed: busy ? null : () => _ask(s)),
              ]),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _tile(Icons.photo_camera_outlined, 'Capture', 'Photograph a page', busy ? null : () => _pick(camera: true)),
                const SizedBox(width: 10),
                _tile(Icons.upload_file, 'Upload', 'Add a photo or PDF to your request', busy ? null : () => _pick()),
              ]),
              const SizedBox(height: 12),
              Center(
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [ButtonSegment(value: 'auto', label: Text('AI chooses')), ButtonSegment(value: '2d', label: Text('2D')), ButtonSegment(value: '3d', label: Text('3D'))],
                  selected: {dim},
                  onSelectionChanged: busy ? null : (s) => setState(() => dim = s.first),
                ),
              ),
              if (dim == '3d') const Padding(padding: EdgeInsets.only(top: 6), child: Text('3D needs internet and a little more time to build.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontSize: 12))),
              const SizedBox(height: 8),
              const Text('Scan textbook pages only, not people or personal papers. AI-made lessons can have mistakes, so please verify.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 11.5)),
              if (busy)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Flexible(child: Text(busyText, style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text('Made today', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                for (final l in _history)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome, color: Color(0xFF0077B6)),
                      title: Text(l.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: l.topic.isEmpty ? null : Text(l.topic),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(l),
                    ),
                  ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
