import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_card.dart';

class ConceptStudioScreen extends StatefulWidget {
  final String baseUrl;
  final int studentId;

  const ConceptStudioScreen({
    super.key,
    required this.baseUrl,
    required this.studentId,
  });

  @override
  State<ConceptStudioScreen> createState() => _ConceptStudioScreenState();
}

class _ConceptStudioScreenState extends State<ConceptStudioScreen> {
  final TextEditingController _topicController = TextEditingController(text: 'Resistors and Ohm\'s Law');
  final TextEditingController _doubtController = TextEditingController();
  String _selectedLang = 'English';
  bool _isGenerating = false;
  bool _isDragging = false;

  // Real File Attachment State
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String _selectedMimeType = 'image/jpeg';

  // Generated Lesson / Concepts State
  List<Map<String, dynamic>> _generatedConcepts = [];
  int _activeStepIndex = 0;
  double _sliderResistance = 220;
  String? _doubtAnswer;
  bool _isAskingDoubt = false;
  final Map<int, int> _quizSelections = {};

  final List<String> _languages = ['English', 'Tamil', 'Hindi', 'Marathi', 'Arabic'];

  void _pickFile({bool useCamera = false}) {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*,application/pdf';
    if (useCamera) {
      uploadInput.setAttribute('capture', 'environment');
    }
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((_) {
          final result = reader.result;
          Uint8List? bytes;
          if (result is Uint8List) {
            bytes = result;
          } else if (result is ByteBuffer) {
            bytes = result.asUint8List();
          } else if (result is List<int>) {
            bytes = Uint8List.fromList(result);
          }
          if (bytes != null && mounted) {
            setState(() {
              _selectedFileName = file.name;
              _selectedFileBytes = bytes;
              _selectedMimeType = file.type.isNotEmpty ? file.type : 'image/jpeg';
            });
            _generateFromUploadedFile();
          }
        });
      }
    });
  }

  Future<void> _generateFromUploadedFile() async {
    if (_selectedFileBytes == null) return;

    setState(() {
      _isGenerating = true;
      _activeStepIndex = 0;
      _quizSelections.clear();
      _doubtAnswer = null;
    });

    try {
      final uri = Uri.parse('${widget.baseUrl}/api/concept-studio/from-page');
      final request = http.MultipartRequest('POST', uri);
      request.fields['student_id'] = widget.studentId.toString();
      request.fields['language'] = _selectedLang;

      final mediaParts = _selectedMimeType.split('/');
      final contentType = mediaParts.length == 2
          ? MediaType(mediaParts[0], mediaParts[1])
          : MediaType('image', 'jpeg');

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _selectedFileBytes!,
          filename: _selectedFileName ?? 'textbook_page.jpg',
          contentType: contentType,
        ),
      );

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawConcepts = (data['concepts'] as List?) ?? [];
        if (rawConcepts.isNotEmpty) {
          setState(() {
            _generatedConcepts = rawConcepts.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          });
        } else {
          setState(() {
            _generatedConcepts = [Map<String, dynamic>.from(data as Map)];
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload error (HTTP ${res.statusCode})')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading textbook page: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not analyze file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateLesson() async {
    if (_selectedFileBytes != null) {
      await _generateFromUploadedFile();
      return;
    }

    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _activeStepIndex = 0;
      _quizSelections.clear();
      _doubtAnswer = null;
    });

    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/concept-studio'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic': topic,
          'language': _selectedLang,
          'student_id': widget.studentId,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final lesson = data['lesson'] != null
            ? Map<String, dynamic>.from(data['lesson'] as Map)
            : data;
        setState(() {
          _generatedConcepts = [lesson];
        });
      }
    } catch (e) {
      debugPrint('Error generating lesson: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _askDoubt(String conceptTitle) async {
    final q = _doubtController.text.trim();
    if (q.isEmpty) return;

    setState(() => _isAskingDoubt = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/concept-studio/doubt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.studentId,
          'concept_title': conceptTitle,
          'question': q,
          'language': _selectedLang,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _doubtAnswer = data['answer'] ?? data['explanation'] ?? 'Current flows from positive anode to negative cathode through the current-limiting resistor.';
        });
      }
    } catch (e) {
      debugPrint('Error asking doubt: $e');
    } finally {
      if (mounted) setState(() => _isAskingDoubt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final pad = isNarrow ? tokens.space16 : tokens.space32;

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                '📸 Concept Studio — Visual Learning',
                style: isNarrow ? textTheme.headlineMedium : textTheme.displayLarge,
              ),
              SizedBox(height: tokens.space8),
              Text(
                'Snap or upload a textbook page (image/PDF), or type any physics topic to build interactive diagrams and simulations.',
                style: textTheme.bodyMedium,
              ),
              SizedBox(height: isNarrow ? tokens.space20 : tokens.space32),

              // Drag and Drop + Real File Picker Upload Area
              DropTarget(
                onDragEntered: (_) => setState(() => _isDragging = true),
                onDragExited: (_) => setState(() => _isDragging = false),
                onDragDone: (detail) async {
                  setState(() => _isDragging = false);
                  if (detail.files.isNotEmpty) {
                    final xfile = detail.files.first;
                    final bytes = await xfile.readAsBytes();
                    if (mounted) {
                      setState(() {
                        _selectedFileName = xfile.name;
                        _selectedFileBytes = bytes;
                        _selectedMimeType = xfile.mimeType ?? (xfile.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg');
                      });
                      _generateFromUploadedFile();
                    }
                  }
                },
                child: InteractiveCard(
                  onTap: () => _pickFile(useCamera: false),
                  backgroundColor: _isDragging ? tokens.primaryLight : Colors.white,
                  borderColor: _isDragging
                      ? tokens.primary
                      : (_selectedFileBytes != null ? tokens.success : tokens.borderSubtle),
                  padding: EdgeInsets.all(isNarrow ? tokens.space20 : tokens.space32),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        if (_selectedFileBytes != null && _selectedMimeType.startsWith('image/')) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _selectedFileBytes!,
                              height: 160,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(LucideIcons.image, size: 48, color: tokens.primary),
                            ),
                          ),
                          SizedBox(height: tokens.space12),
                        ] else ...[
                          Container(
                            padding: EdgeInsets.all(tokens.space16),
                            decoration: BoxDecoration(
                              color: _selectedFileBytes != null ? tokens.successLight : tokens.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedFileBytes != null ? LucideIcons.fileCheck : LucideIcons.camera,
                              size: 34,
                              color: _selectedFileBytes != null ? tokens.success : tokens.primary,
                            ),
                          ),
                          SizedBox(height: tokens.space16),
                        ],
                        Text(
                          _selectedFileName != null
                              ? '✅ Attached: $_selectedFileName (${((_selectedFileBytes?.length ?? 0) / 1024).toStringAsFixed(1)} KB)'
                              : 'Snap your textbook page or drag & drop image/PDF here',
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium,
                        ),
                        SizedBox(height: tokens.space8),
                        Text(
                          'Tap to choose an image (PNG, JPG) or PDF from your device or phone camera.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium,
                        ),
                        SizedBox(height: tokens.space16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _pickFile(useCamera: false),
                              icon: const Icon(LucideIcons.upload, size: 17),
                              label: Text(_selectedFileBytes != null ? 'Change File' : 'Choose Image / PDF'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _pickFile(useCamera: true),
                              icon: const Icon(LucideIcons.camera, size: 17),
                              label: const Text('Open Camera'),
                            ),
                            if (_selectedFileBytes != null)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedFileName = null;
                                    _selectedFileBytes = null;
                                  });
                                },
                                icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                                label: const Text('Remove', style: TextStyle(color: Colors.red)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              SizedBox(height: tokens.space24),

              // Responsive Topic & Language Search Bar
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopicTextField(tokens),
                    SizedBox(height: tokens.space12),
                    Row(
                      children: [
                        _buildLanguageDropdown(tokens),
                        SizedBox(width: tokens.space12),
                        Expanded(child: _buildGenerateButton()),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _buildTopicTextField(tokens)),
                    SizedBox(width: tokens.space12),
                    _buildLanguageDropdown(tokens),
                    SizedBox(width: tokens.space12),
                    _buildGenerateButton(),
                  ],
                ),

              SizedBox(height: tokens.space24),

              // Loading Indicator
              if (_isGenerating)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(tokens.space32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: tokens.primary),
                        SizedBox(height: tokens.space16),
                        Text(
                          _selectedFileBytes != null
                              ? 'Reading textbook page & generating interactive visuals with Gemini...'
                              : 'Synthesizing interactive visual lesson in $_selectedLang...',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

              // Generated Visual Lesson Presentation
              if (!_isGenerating && _generatedConcepts.isNotEmpty)
                ..._generatedConcepts.map((lesson) => Padding(
                      padding: EdgeInsets.only(bottom: tokens.space24),
                      child: _buildLessonCard(context, lesson, tokens, textTheme, isNarrow),
                    )),

              // Suggested topics when empty
              if (!_isGenerating && _generatedConcepts.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.space16),
                    child: Column(
                      children: [
                        const Icon(LucideIcons.lightbulb, size: 44, color: Colors.amber),
                        SizedBox(height: tokens.space12),
                        const Text(
                          'Or tap a foundational robotics topic below:',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: tokens.space12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            'What is an LED',
                            'Resistors and Ohm\'s Law',
                            'Ground and Complete Circuits',
                            'Ultrasonic Distance Sensor',
                            'Variables and Logic',
                          ]
                              .map((t) => ActionChip(
                                    label: Text(t),
                                    onPressed: () {
                                      setState(() {
                                        _selectedFileBytes = null;
                                        _selectedFileName = null;
                                        _topicController.text = t;
                                      });
                                      _generateLesson();
                                    },
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopicTextField(AppTokens tokens) {
    return TextField(
      controller: _topicController,
      onSubmitted: (_) => _generateLesson(),
      decoration: InputDecoration(
        hintText: 'Type a science topic (e.g. Resistors, LEDs, Ultrasonic Sensor)...',
        prefixIcon: const Icon(LucideIcons.search, size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.all(tokens.space16),
        border: OutlineInputBorder(
          borderRadius: tokens.borderRadius16,
          borderSide: BorderSide(color: tokens.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: tokens.borderRadius16,
          borderSide: BorderSide(color: tokens.borderSubtle),
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(AppTokens tokens) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.space16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: tokens.borderRadius16,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLang,
          icon: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(LucideIcons.globe, size: 16),
          ),
          items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedLang = v);
          },
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _isGenerating ? null : _generateLesson,
      icon: _isGenerating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(LucideIcons.sparkles, size: 18),
      label: Text(_isGenerating ? 'Analyzing...' : 'Generate Visual Lesson'),
    );
  }

  Widget _buildLessonCard(
    BuildContext context,
    Map<String, dynamic> lesson,
    AppTokens tokens,
    TextTheme textTheme,
    bool isNarrow,
  ) {
    final visual = (lesson['visual'] as Map<String, dynamic>?) ?? lesson;
    final visualType = (visual['type'] ?? lesson['type'] ?? 'animated_steps').toString();
    final title = (lesson['title'] ?? 'Generated Lesson').toString();
    final summary = (lesson['summary'] ?? '').toString();
    final steps = (visual['steps'] as List?) ??
        (lesson['steps'] as List?) ??
        [
          {'caption': 'Step 1: 5V power supplies electrical energy into the circuit loop.'},
          {'caption': 'Step 2: Current passes safely through the resistor to limit electron flow.'},
          {'caption': 'Step 3: The LED glows brightly and current returns to GND (0V).'},
        ];
    final quizzes = (lesson['quiz'] as List?) ?? [];
    final safeStepIdx = _activeStepIndex.clamp(0, steps.isEmpty ? 0 : steps.length - 1);
    final currentCaption = steps.isNotEmpty
        ? (steps[safeStepIdx]['caption'] ?? steps[safeStepIdx].toString())
        : 'Explore the interactive diagram.';

    final currentMa = (5.0 / _sliderResistance * 1000).toStringAsFixed(1);
    final ledBrightness = ((1000 - _sliderResistance) / 900).clamp(0.2, 1.0);

    return InteractiveCard(
      padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: tokens.space12, vertical: tokens.space4),
                decoration: BoxDecoration(
                  color: tokens.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'VISUAL TYPE: ${visualType.toUpperCase()}',
                  style: TextStyle(color: tokens.primary, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Chip(
                avatar: const Icon(LucideIcons.globe, size: 14),
                label: Text(_selectedLang),
                backgroundColor: tokens.surfaceBg,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: tokens.space16),
          Text(
            title,
            style: textTheme.headlineMedium?.copyWith(color: tokens.primary),
          ),
          SizedBox(height: tokens.space8),
          Text(
            summary,
            style: textTheme.bodyMedium?.copyWith(fontSize: 15, color: tokens.textPrimary),
          ),
          SizedBox(height: tokens.space24),

          // Interactive Visual Simulator Canvas
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isNarrow ? tokens.space16 : tokens.space24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: tokens.borderRadius16,
              boxShadow: tokens.cardShadow,
            ),
            child: Column(
              children: [
                // Live Circuit Diagram Row
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildCircuitNode('5V Pin', LucideIcons.zap, Colors.amber, safeStepIdx >= 0),
                    const Icon(LucideIcons.arrowRight, color: Colors.white38, size: 18),
                    _buildCircuitNode(
                      '${_sliderResistance.toInt()}Ω Resistor',
                      LucideIcons.activity,
                      Colors.cyanAccent,
                      safeStepIdx >= 1,
                    ),
                    const Icon(LucideIcons.arrowRight, color: Colors.white38, size: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF3366).withOpacity(ledBrightness),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3366).withOpacity(ledBrightness * 0.8),
                            blurRadius: 24 * ledBrightness,
                            spreadRadius: 6 * ledBrightness,
                          ),
                        ],
                      ),
                      child: const Icon(LucideIcons.lightbulb, color: Colors.white, size: 28),
                    ),
                    const Icon(LucideIcons.arrowRight, color: Colors.white38, size: 18),
                    _buildCircuitNode('GND (0V)', LucideIcons.shieldCheck, Colors.greenAccent, safeStepIdx >= 2),
                  ],
                ),
                SizedBox(height: tokens.space16),
                Container(
                  padding: EdgeInsets.all(tokens.space12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Step ${safeStepIdx + 1}/${steps.length}: $currentCaption\nLive Ohm\'s Law: I = 5V / ${_sliderResistance.toInt()}Ω = $currentMa mA',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ),
                SizedBox(height: tokens.space16),
                // Live Resistance Slider
                Row(
                  children: [
                    const Text('Resistance:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _sliderResistance,
                        min: 100,
                        max: 1000,
                        divisions: 18,
                        activeColor: const Color(0xFF38BDF8),
                        label: '${_sliderResistance.toInt()} Ω',
                        onChanged: (val) => setState(() => _sliderResistance = val),
                      ),
                    ),
                    Text(
                      '${_sliderResistance.toInt()}Ω',
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _activeStepIndex = (_activeStepIndex + 1) % (steps.isEmpty ? 1 : steps.length);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black87,
                      ),
                      icon: const Icon(LucideIcons.skipForward, size: 16),
                      label: Text('Next Step (${safeStepIdx + 1}/${steps.length})'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Interactive Quiz Section (if present)
          if (quizzes.isNotEmpty) ...[
            SizedBox(height: tokens.space24),
            Text('📝 Quick Visual Check', style: textTheme.titleMedium),
            SizedBox(height: tokens.space12),
            ...quizzes.asMap().entries.map((entry) {
              final qIdx = entry.key;
              final q = entry.value as Map<String, dynamic>;
              final options = (q['options'] as List?) ?? [];
              final answerIdx = (q['answer'] is int) ? q['answer'] as int : 0;
              final selected = _quizSelections[qIdx];

              return Padding(
                padding: EdgeInsets.only(bottom: tokens.space12),
                child: Container(
                  padding: EdgeInsets.all(tokens.space16),
                  decoration: BoxDecoration(
                    color: tokens.surfaceBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${qIdx + 1}: ${q['question'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: options.asMap().entries.map((opt) {
                          final oIdx = opt.key;
                          final isSelected = selected == oIdx;
                          final isCorrect = oIdx == answerIdx;
                          Color? chipBg;
                          if (selected != null) {
                            if (isCorrect) chipBg = tokens.successLight;
                            if (isSelected && !isCorrect) chipBg = Colors.red.shade50;
                          }
                          return ChoiceChip(
                            label: Text(opt.value.toString()),
                            selected: isSelected,
                            backgroundColor: chipBg,
                            selectedColor: isCorrect ? tokens.successLight : Colors.red.shade100,
                            onSelected: (_) => setState(() => _quizSelections[qIdx] = oIdx),
                          );
                        }).toList(),
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          selected == answerIdx
                              ? '✅ Correct! ${q['why'] ?? ''}'
                              : '💡 Hint: ${q['why'] ?? 'Check the visual diagram above.'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected == answerIdx ? tokens.success : tokens.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],

          SizedBox(height: tokens.space24),

          // Ask a Doubt Box
          Container(
            padding: EdgeInsets.all(tokens.space16),
            decoration: BoxDecoration(
              color: tokens.surfaceBg,
              borderRadius: tokens.borderRadius16,
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNarrow)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _doubtController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.helpCircle, color: Colors.blueGrey),
                          hintText: 'Ask a doubt to AI Tutor Alex...',
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isAskingDoubt ? null : () => _askDoubt(title),
                        child: Text(_isAskingDoubt ? 'Thinking...' : 'Ask AI Tutor'),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      const Icon(LucideIcons.helpCircle, color: Colors.blueGrey),
                      SizedBox(width: tokens.space12),
                      Expanded(
                        child: TextField(
                          controller: _doubtController,
                          onSubmitted: (_) => _askDoubt(title),
                          decoration: const InputDecoration(
                            hintText: 'Ask a doubt to AI Tutor Alex about this visual...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isAskingDoubt ? null : () => _askDoubt(title),
                        child: Text(_isAskingDoubt ? 'Thinking...' : 'Ask AI'),
                      ),
                    ],
                  ),
                if (_doubtAnswer != null) ...[
                  const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🤖 ', style: TextStyle(fontSize: 18)),
                      Expanded(
                        child: Text(
                          _doubtAnswer!,
                          style: TextStyle(fontSize: 13, color: tokens.textPrimary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildCircuitNode(String label, IconData icon, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.18) : Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? color : Colors.white24, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? color : Colors.white54, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
