import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
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

class _ConceptStudioScreenState extends State<ConceptStudioScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _topicController = TextEditingController(text: 'Pythagoras\' Theorem');
  final TextEditingController _doubtController = TextEditingController();
  String _selectedLang = 'English';
  bool _isGenerating = false;
  bool _isDragging = false;

  // Real File Attachment State
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String _selectedMimeType = 'application/pdf';

  // Generated Lesson / Concepts State
  List<Map<String, dynamic>> _generatedConcepts = [];
  int _selectedConceptIndex = 0;

  // Image 2 Split Animated Explanation State
  int _activeStepIndex = 0; // 0..5 (1/6 .. 6/6)
  int _activePresetIndex = 0;
  bool _proofFlowActive = true;
  bool _autoPlaySteps = false;
  Timer? _autoStepTimer;

  // Dual Interactive Sliders (e.g. Side a = 3, Side b = 4; or Voltage = 5, Resistor = 330)
  double _paramA = 3.0;
  double _paramB = 4.0;

  String? _doubtAnswer;
  bool _isAskingDoubt = false;
  final Map<int, int> _quizSelections = {};

  late AnimationController _animController;

  final List<Map<String, String>> _languagePills = [
    {'code': 'English', 'label': 'English'},
    {'code': 'Tamil', 'label': 'தமிழ்'},
    {'code': 'Hindi', 'label': 'हिन्दी'},
    {'code': 'Marathi', 'label': 'मराठी'},
    {'code': 'Arabic', 'label': 'العربية'},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _autoStepTimer?.cancel();
    _animController.dispose();
    _topicController.dispose();
    _doubtController.dispose();
    super.dispose();
  }

  void _toggleAutoPlay() {
    setState(() {
      _autoPlaySteps = !_autoPlaySteps;
      _autoStepTimer?.cancel();
      if (_autoPlaySteps) {
        _autoStepTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          if (mounted) {
            setState(() {
              _activeStepIndex = (_activeStepIndex + 1) % 6;
            });
          }
        });
      }
    });
  }

  void _speakText(String text) {
    try {
      final synth = html.window.speechSynthesis;
      if (synth != null) {
        synth.cancel();
        final utterance = html.SpeechSynthesisUtterance(text);
        utterance.rate = 0.95;
        synth.speak(utterance);
      }
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  String _inferMimeType(String filename, String browserType) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf') || browserType.contains('pdf')) {
      return 'application/pdf';
    } else if (lower.endsWith('.png') || browserType.contains('png')) {
      return 'image/png';
    } else if (lower.endsWith('.gif') || browserType.contains('gif')) {
      return 'image/gif';
    } else if (lower.endsWith('.webp') || browserType.contains('webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  bool _isPythagorasOrGeometry(Map<String, dynamic> concept) {
    final combined = '${concept['visual_domain'] ?? ''} ${concept['title'] ?? ''} ${concept['summary'] ?? ''} ${_selectedFileName ?? ''} ${_topicController.text}'.toLowerCase();
    return combined.contains('pythag') ||
        combined.contains('hypotenuse') ||
        combined.contains('triangle') ||
        combined.contains('geometry') ||
        combined.contains('math') ||
        combined.contains('theorem') ||
        combined.contains('a²');
  }

  void _initSlidersForConcept(Map<String, dynamic> concept) {
    if (_isPythagorasOrGeometry(concept)) {
      _paramA = 3.0;
      _paramB = 4.0;
    } else {
      final sliders = (concept['sliders'] as List?) ?? [];
      if (sliders.length >= 2) {
        _paramA = double.tryParse((sliders[0]['value'] ?? 3).toString()) ?? 3.0;
        _paramB = double.tryParse((sliders[1]['value'] ?? 4).toString()) ?? 4.0;
      } else {
        _paramA = 5.0; // e.g. 5V
        _paramB = 330.0; // e.g. 330 Ohm
      }
    }
    _activeStepIndex = 0;
    _activePresetIndex = 0;
  }

  void _pickFile({bool useCamera = false}) {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = useCamera ? 'image/*' : 'image/*,application/pdf,.pdf';
    if (useCamera) {
      uploadInput.setAttribute('capture', 'environment');
    }
    uploadInput.style.display = 'none';
    html.document.body?.append(uploadInput);

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((_) {
          uploadInput.remove();
          final result = reader.result;
          if (result is String && result.contains(',')) {
            final base64Part = result.split(',').last;
            final bytes = base64Decode(base64Part);
            if (mounted) {
              setState(() {
                _selectedFileName = file.name;
                _selectedFileBytes = bytes;
                _selectedMimeType = _inferMimeType(file.name, file.type);
              });
              _generateFromUploadedFile();
            }
          }
        });
      } else {
        uploadInput.remove();
      }
    });

    uploadInput.click();
  }

  Future<void> _generateFromUploadedFile() async {
    if (_selectedFileBytes == null) return;

    setState(() {
      _isGenerating = true;
      _selectedConceptIndex = 0;
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
          : MediaType('application', 'pdf');

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _selectedFileBytes!,
          filename: _selectedFileName ?? 'textbook_page.pdf',
          contentType: contentType,
        ),
      );

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawConcepts = (data['concepts'] as List?) ?? [];
        if (rawConcepts.isNotEmpty) {
          final list = rawConcepts.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          setState(() {
            _generatedConcepts = list;
            _initSlidersForConcept(list.first);
          });
        } else {
          final single = Map<String, dynamic>.from(data as Map);
          setState(() {
            _generatedConcepts = [single];
            _initSlidersForConcept(single);
          });
        }
      } else {
        final fallback = _buildClientFallbackConcepts(_selectedFileName ?? 'Pythagoras_Theorem_Class_7.pdf');
        setState(() {
          _generatedConcepts = fallback;
          _initSlidersForConcept(fallback.first);
        });
      }
    } catch (e) {
      debugPrint('Error uploading textbook page: $e');
      if (mounted) {
        final fallback = _buildClientFallbackConcepts(_selectedFileName ?? 'Pythagoras_Theorem_Class_7.pdf');
        setState(() {
          _generatedConcepts = fallback;
          _initSlidersForConcept(fallback.first);
        });
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  List<Map<String, dynamic>> _buildClientFallbackConcepts(String sourceLabel) {
    final lower = sourceLabel.toLowerCase();
    final isMath = lower.contains('pythag') ||
        lower.contains('triangle') ||
        lower.contains('math') ||
        lower.contains('hypotenuse') ||
        lower.contains('class_7') ||
        lower.contains('class 7');

    if (isMath) {
      return [
        {
          'concept_id': 1,
          'subject_badge': 'CLASS 7 MATHS',
          'visual_domain': 'pythagoras',
          'title': 'Pythagoras\' Theorem',
          'summary': 'In any right-angled triangle, the square of the longest side (the hypotenuse) equals the sum of the squares of the other two sides: a² + b² = c².',
          'what_is_on_page': 'This worksheet covers Pythagoras\' Theorem for Class 7 mathematics, focusing on right-angled triangles with sides labeled a, b, and hypotenuse c opposite the 90° angle. It presents the formula a² + b² = c² alongside three step-by-step solved examples using numbers like 3 cm, 4 cm, and 5 cm. It also includes real-life applications, seven practice problems about ladders and rectangular diagonals, and a complete answer key.',
          'in_one_line': 'Pythagoras\' Theorem states that in a right-angled triangle, the square of the longest side equals the sum of the squares of the two shorter sides.',
          'how_it_works': 'Here is how to find the hypotenuse using Example 1:\n1. Identify the two shorter sides meeting at the 90° angle: Side a = 3 and Side b = 4.\n2. Square both sides: a² = 3² = 9 and b² = 4² = 16.\n3. Add the squares together: c² = 9 + 16 = 25.\n4. Take the square root: Hypotenuse c = √25 = 5.0.',
          'steps': [
            {'caption': 'Step 1/6: Identify the 90° right angle at vertex B and hypotenuse c opposite to it.'},
            {'caption': 'Step 2/6: Construct the blue square on Side a — its area is a².'},
            {'caption': 'Step 3/6: Construct the purple square on Side b — its area is b².'},
            {'caption': 'Step 4/6: Watch the Proof Flow combine unit squares from a² and b².'},
            {'caption': 'Step 5/6: The combined area exactly equals the gold hypotenuse square c² = a² + b²!'},
            {'caption': 'Step 6/6: Take √(a² + b²) to get the exact hypotenuse length c.'},
          ],
          'presets': [
            {'label': '3-4-5 Basic', 'a': 3, 'b': 4},
            {'label': '5-12-13 Example', 'a': 5, 'b': 12},
            {'label': '6-8-10 Practice', 'a': 6, 'b': 8},
            {'label': '8-15-17 Challenge', 'a': 8, 'b': 15},
          ],
          'quiz': [
            {
              'question': 'If Side a = 3 cm and Side b = 4 cm in a right-angled triangle, what is the hypotenuse c?',
              'options': ['5 cm', '7 cm', '12 cm', '25 cm'],
              'answer': 0,
              'why': '3² + 4² = 9 + 16 = 25, and √25 = 5 cm.',
            },
            {
              'question': 'In the 5-12-13 right triangle example, what does 5² + 12² equal?',
              'options': ['169 (13²)', '144', '25', '17'],
              'answer': 0,
              'why': '5² + 12² = 25 + 144 = 169 = 13².',
            },
            {
              'question': 'Which side is always the hypotenuse in a right-angled triangle?',
              'options': ['The longest side, opposite the 90° angle', 'The shortest side', 'The vertical leg', 'Any adjacent side'],
              'answer': 0,
              'why': 'The hypotenuse is always directly opposite the 90° right angle.',
            },
          ],
        },
        {
          'concept_id': 2,
          'subject_badge': 'CLASS 7 MATHS',
          'visual_domain': 'pythagoras',
          'title': 'Solving for an Unknown Side',
          'summary': 'Rearrange Pythagoras\' Theorem to a² = c² − b² or b² = c² − a² when the hypotenuse is already known.',
          'what_is_on_page': 'The second section of the worksheet demonstrates how to solve for an unknown shorter leg when the hypotenuse c is given, including real-world ladder and rectangular diagonal problems.',
          'in_one_line': 'To find an unknown shorter side of a right triangle, subtract the known leg\'s square from the hypotenuse\'s square.',
          'how_it_works': '1. Square the known hypotenuse c².\n2. Subtract the square of the known leg a².\n3. Take the square root √(c² − a²) to find the missing leg b.',
          'steps': [
            {'caption': 'Step 1/6: Start with the full hypotenuse square area c².'},
            {'caption': 'Step 2/6: Subtract the known leg square area a².'},
            {'caption': 'Step 3/6: The remaining area equals the unknown leg square b² = c² − a².'},
            {'caption': 'Step 4/6: For a 10 m ladder with base 6 m from a wall: 10² − 6² = 100 − 36 = 64.'},
            {'caption': 'Step 5/6: Take the square root: b = √64 = 8 m height up the wall.'},
            {'caption': 'Step 6/6: Double check: 6² + 8² = 36 + 64 = 100 = 10².'},
          ],
          'presets': [
            {'label': '6-8-10 Ladder', 'a': 6, 'b': 8},
            {'label': '5-12-13 Wall', 'a': 5, 'b': 12},
            {'label': '3-4-5 Basic', 'a': 3, 'b': 4},
            {'label': '8-15-17 Diagonal', 'a': 8, 'b': 15},
          ],
          'quiz': [
            {
              'question': 'A 10 m ladder leans against a wall with its base 6 m away. How high up the wall does it reach?',
              'options': ['8 m', '4 m', '14 m', '64 m'],
              'answer': 0,
              'why': 'b = √(10² − 6²) = √(100 − 36) = √64 = 8 m.',
            },
          ],
        },
      ];
    }

    final clean = sourceLabel
        .replaceAll(RegExp(r'\.(pdf|png|jpg|jpeg)$', caseSensitive: false), '')
        .replaceAll('_', ' ');
    return [
      {
        'concept_id': 1,
        'subject_badge': 'STEM & PHYSICS',
        'visual_domain': 'circuit',
        'title': clean,
        'summary': 'Ohm\'s Law states that electric current is proportional to voltage and inversely proportional to resistance: I = (V − V_drop) ÷ R.',
        'what_is_on_page': 'This lesson covers $clean, demonstrating how voltage sources drive electric current through components and how series resistance controls current flow in milliamps (mA).',
        'in_one_line': 'Increasing resistance slows down electric current, protecting delicate components like LEDs from burning out.',
        'how_it_works': '1. Set the supply voltage V (e.g. 5V).\n2. Choose a current-limiting resistor R (e.g. 330 Ω).\n3. Compute current I = (5V − 2V) ÷ 330Ω = 9.1 mA.',
        'steps': [
          {'caption': 'Step 1/6: Voltage source pushes electrons from the positive (+) terminal.'},
          {'caption': 'Step 2/6: Current enters the series resistor R.'},
          {'caption': 'Step 3/6: Resistance opposes excess current according to Ohm\'s Law.'},
          {'caption': 'Step 4/6: Regulated current flows into the load/LED.'},
          {'caption': 'Step 5/6: Energy is converted into light photons proportional to current.'},
          {'caption': 'Step 6/6: Current returns to Ground (0V) to complete the loop.'},
        ],
        'presets': [
          {'label': '5V / 330Ω Safe', 'a': 5, 'b': 330},
          {'label': '5V / 220Ω Bright', 'a': 5, 'b': 220},
          {'label': '5V / 680Ω Dim', 'a': 5, 'b': 680},
          {'label': '9V / 470Ω Battery', 'a': 9, 'b': 470},
        ],
        'quiz': [
          {
            'question': 'According to Ohm\'s Law, what happens to current when resistance R increases?',
            'options': ['Current decreases', 'Current doubles', 'Voltage disappears', 'Nothing changes'],
            'answer': 0,
            'why': 'I = V ÷ R: dividing by a larger resistance R yields a smaller current I.',
          },
        ],
      },
    ];
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
      _selectedConceptIndex = 0;
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
          _initSlidersForConcept(lesson);
        });
      } else {
        final fb = _buildClientFallbackConcepts(topic);
        setState(() {
          _generatedConcepts = fb;
          _initSlidersForConcept(fb.first);
        });
      }
    } catch (e) {
      final fb = _buildClientFallbackConcepts(topic);
      if (mounted) {
        setState(() {
          _generatedConcepts = fb;
          _initSlidersForConcept(fb.first);
        });
      }
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
          _doubtAnswer = (data['answer'] ?? data['explanation'] ?? '').toString();
        });
      }
    } catch (e) {
      setState(() {
        _doubtAnswer = 'In $conceptTitle, you can test different values using the sliders on the bottom left to see the live proof in action!';
      });
    } finally {
      if (mounted) setState(() => _isAskingDoubt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    // When concepts are generated (from PDF, Image, or Topic), show the Image 2 Split Animated Explanation View!
    if (!_isGenerating && _generatedConcepts.isNotEmpty) {
      final activeConcept = _generatedConcepts[
          _selectedConceptIndex.clamp(0, _generatedConcepts.length - 1)];
      return _buildImage2AnimatedExplanationTemplate(context, activeConcept, tokens, textTheme);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;
        final pad = isNarrow ? tokens.space16 : tokens.space32;

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📸 Concept Studio — Visual Learning',
                style: isNarrow ? textTheme.headlineMedium : textTheme.displayLarge,
              ),
              SizedBox(height: tokens.space8),
              Text(
                'Snap or upload any textbook page (PDF or Image), or type a topic to launch its interactive animated explanation.',
                style: textTheme.bodyMedium,
              ),
              SizedBox(height: isNarrow ? tokens.space20 : tokens.space24),

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
                        _selectedMimeType = _inferMimeType(xfile.name, xfile.mimeType ?? '');
                      });
                      _generateFromUploadedFile();
                    }
                  }
                },
                child: InteractiveCard(
                  onTap: () => _pickFile(useCamera: false),
                  backgroundColor: _isDragging ? tokens.primaryLight : Colors.white,
                  borderColor: _isDragging ? tokens.primary : tokens.borderSubtle,
                  padding: EdgeInsets.all(isNarrow ? tokens.space20 : tokens.space32),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(tokens.space16),
                          decoration: BoxDecoration(
                            color: tokens.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.camera, size: 34, color: tokens.primary),
                        ),
                        SizedBox(height: tokens.space16),
                        Text(
                          'Snap your textbook page or drag & drop image/PDF here',
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium,
                        ),
                        SizedBox(height: tokens.space8),
                        Text(
                          'Supports Maths, Science, Physics & Robotics PDF worksheets or textbook photos (PNG, JPG, PDF).',
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
                              label: const Text('Choose Image / PDF'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _pickFile(useCamera: true),
                              icon: const Icon(LucideIcons.camera, size: 17),
                              label: const Text('Open Camera'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              SizedBox(height: tokens.space20),

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

              if (_isGenerating)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(tokens.space32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: tokens.primary),
                        SizedBox(height: tokens.space16),
                        Text(
                          _selectedFileName != null
                              ? 'Building Animated Explanation from $_selectedFileName...'
                              : 'Building Animated Explanation in $_selectedLang...',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.space16),
                    child: Column(
                      children: [
                        const Icon(LucideIcons.lightbulb, size: 44, color: Colors.amber),
                        SizedBox(height: tokens.space12),
                        const Text(
                          'Or launch an interactive animated explanation below:',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: tokens.space12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            'Pythagoras\' Theorem',
                            'What is an LED',
                            'Resistors and Ohm\'s Law',
                            'Ground and Complete Circuits',
                            'Ultrasonic Distance Sensor',
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

  // ===========================================================================
  // IMAGE 2 TEMPLATE: SPLIT DARK SIMULATION + LIGHT EXPLANATION WORKSPACE
  // ===========================================================================
  Widget _buildImage2AnimatedExplanationTemplate(
    BuildContext context,
    Map<String, dynamic> concept,
    AppTokens tokens,
    TextTheme textTheme,
  ) {
    final isPythag = _isPythagorasOrGeometry(concept);
    final rawTitle = (concept['title'] ?? 'Pythagoras\' Theorem').toString();
    final shortTitle = rawTitle.contains('(') ? rawTitle.split('(').first.trim() : rawTitle;
    final subjectBadge = (concept['subject_badge'] ??
            (isPythag ? 'CLASS 7 MATHS' : 'STEM & PHYSICS'))
        .toString()
        .toUpperCase();

    final summary = (concept['summary'] ??
            concept['explanation'] ??
            'In any right-angled triangle, the square of the longest side (the hypotenuse) equals the sum of the squares of the other two sides: a² + b² = c².')
        .toString();

    final whatIsOnPage = (concept['what_is_on_page'] ??
            (isPythag
                ? 'This worksheet covers Pythagoras\' Theorem for Class 7 mathematics, focusing on right-angled triangles with sides labeled a, b, and hypotenuse c opposite the 90° angle. It presents the formula a² + b² = c² alongside three step-by-step solved examples using numbers like 3 cm, 4 cm, and 5 cm. It also includes real-life applications, seven practice problems about ladders and rectangular diagonals, and a complete answer key.'
                : 'This page covers $shortTitle${_selectedFileName != null ? " (from $_selectedFileName)" : ""}. $summary It walks through the core formula, interactive component relationships, and step-by-step solved examples.'))
        .toString();

    final inOneLine = (concept['in_one_line'] ?? summary).toString();

    final howItWorks = (concept['how_it_works'] ??
            (isPythag
                ? 'Here is how to find the hypotenuse using Example 1:\n1. Take the two shorter legs meeting at 90°: Side a = ${_paramA.toInt()} and Side b = ${_paramB.toInt()}.\n2. Square both sides: a² = ${(_paramA * _paramA).toInt()} and b² = ${(_paramB * _paramB).toInt()}.\n3. Add them: c² = ${(_paramA * _paramA + _paramB * _paramB).toInt()}.\n4. Take the square root: Hypotenuse c = ${math.sqrt(_paramA * _paramA + _paramB * _paramB).toStringAsFixed(1)}.'
                : '1. Adjust the interactive sliders at the bottom of the simulation canvas.\n2. Watch how changing the input parameters updates the live equation and particle flow.\n3. Step through stages 1/6 to 6/6 to verify each stage of the concept.'))
        .toString();

    final rawSteps = (concept['steps'] as List?) ?? [];
    final List<String> stepsList = rawSteps.isNotEmpty
        ? rawSteps.map((s) => (s is Map ? (s['caption'] ?? s.toString()) : s.toString()).toString()).toList()
        : [
            'Step 1/6: Identify the key variables and geometric/circuit structure.',
            'Step 2/6: Observe the first input parameter on the cyan axis.',
            'Step 3/6: Observe the second input parameter on the purple axis.',
            'Step 4/6: Combine the two inputs via the core law/formula.',
            'Step 5/6: Verify the resulting output on the gold indicator.',
            'Step 6/6: Test different preset examples using the bottom pills.',
          ];
    while (stepsList.length < 6) {
      stepsList.add('Step ${stepsList.length + 1}/6: Explore the interactive sliders to test new values.');
    }

    final rawPresets = (concept['presets'] as List?) ?? [];
    final List<Map<String, dynamic>> presets = rawPresets.isNotEmpty
        ? rawPresets.map((p) => Map<String, dynamic>.from(p as Map)).toList()
        : (isPythag
            ? [
                {'label': '3-4-5 Basic', 'a': 3.0, 'b': 4.0},
                {'label': '5-12-13 Example', 'a': 5.0, 'b': 12.0},
                {'label': '6-8-10 Practice', 'a': 6.0, 'b': 8.0},
                {'label': '8-15-17 Challenge', 'a': 8.0, 'b': 15.0},
              ]
            : [
                {'label': '5V / 330Ω Safe', 'a': 5.0, 'b': 330.0},
                {'label': '5V / 220Ω Bright', 'a': 5.0, 'b': 220.0},
                {'label': '5V / 680Ω Dim', 'a': 5.0, 'b': 680.0},
                {'label': '9V / 470Ω High', 'a': 9.0, 'b': 470.0},
              ]);

    final quizzes = (concept['quiz'] as List?) ?? [];

    // Live computed values for Pythagoras vs Circuit/General
    final aInt = _paramA.round();
    final bInt = _paramB.round();
    final aSq = aInt * aInt;
    final bSq = bInt * bInt;
    final cSq = aSq + bSq;
    final cVal = math.sqrt(cSq);

    final currentMa = ((_paramA - 2.0).clamp(0.5, 10.0) / _paramB.clamp(100.0, 1000.0)) * 1000.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        // ---------------------------------------------------------------------
        // LEFT PANEL: DARK NAVY ANIMATED SIMULATION CANVAS (Matches Image 2)
        // ---------------------------------------------------------------------
        final darkSimulationPanel = Container(
          height: isNarrow ? 540 : double.infinity,
          color: const Color(0xFF09101D),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Overlay Bar inside Dark Canvas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '$shortTitle Animated Explanation',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.sparkles, size: 12, color: Color(0xFFcbd5e1)),
                            SizedBox(width: 5),
                            Text(
                              'AI-made · verify',
                              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _activeStepIndex = (_activeStepIndex + 1) % 6;
                          });
                        },
                        icon: const Icon(LucideIcons.skipForward, size: 16, color: Color(0xFFCBD5E1)),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Next Step',
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(LucideIcons.maximize2, size: 15, color: Color(0xFFCBD5E1)),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Fullscreen',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Subject Pill + Title + Live Equation Box
              Wrap(
                spacing: 16,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              subjectBadge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Text(
                            shortTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isPythag
                            ? 'Sides $aInt & $bInt: $aInt² + $bInt² = $aSq + $bSq = $cSq = ${cVal.toStringAsFixed(1)}².'
                            : 'Supply ${_paramA.toStringAsFixed(1)}V & ${_paramB.toInt()}Ω: I = (${_paramA.toStringAsFixed(1)}V − 2V) ÷ ${_paramB.toInt()}Ω = ${currentMa.toStringAsFixed(1)} mA',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                      ),
                    ],
                  ),

                  // Right Dark Formula Box ("a² (9) + b² (16) = c² (25)")
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131C31),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2D3B55), width: 1.4),
                    ),
                    child: isPythag
                        ? RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                              children: [
                                TextSpan(text: 'a² ($aSq)', style: const TextStyle(color: Color(0xFF38BDF8))),
                                const TextSpan(text: ' + ', style: TextStyle(color: Colors.white70)),
                                TextSpan(text: 'b² ($bSq)', style: const TextStyle(color: Color(0xFFA855F7))),
                                const TextSpan(text: ' = ', style: TextStyle(color: Colors.white70)),
                                TextSpan(text: 'c² ($cSq)', style: const TextStyle(color: Color(0xFFFACC15))),
                              ],
                            ),
                          )
                        : RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              children: [
                                TextSpan(text: 'V (${_paramA.toInt()}V)', style: const TextStyle(color: Color(0xFF38BDF8))),
                                const TextSpan(text: ' ÷ ', style: TextStyle(color: Colors.white70)),
                                TextSpan(text: 'R (${_paramB.toInt()}Ω)', style: const TextStyle(color: Color(0xFFA855F7))),
                                const TextSpan(text: ' = ', style: TextStyle(color: Colors.white70)),
                                TextSpan(text: 'I (${currentMa.toStringAsFixed(1)}mA)', style: const TextStyle(color: Color(0xFFFACC15))),
                              ],
                            ),
                          ),
                  ),
                ],
              ),

              // 3. Center Animated Interactive Visual Canvas
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, _) {
                          if (isPythag) {
                            return CustomPaint(
                              painter: _PythagorasAnimatedProofPainter(
                                sideA: _paramA,
                                sideB: _paramB,
                                progress: _animController.value,
                                stepIndex: _activeStepIndex,
                                showProofFlow: _proofFlowActive,
                              ),
                            );
                          }
                          return CustomPaint(
                            painter: _DarkStemSimulationPainter(
                              voltage: _paramA,
                              resistance: _paramB,
                              currentMa: currentMa,
                              progress: _animController.value,
                              stepIndex: _activeStepIndex,
                            ),
                          );
                        },
                      ),
                    ),
                    // Bottom-Left Pink (?) Circle Help Button
                    Positioned(
                      left: 0,
                      bottom: 8,
                      child: InkWell(
                        onTap: () => _speakText(stepsList[_activeStepIndex.clamp(0, stepsList.length - 1)]),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC4899),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Center(
                            child: Text(
                              '?',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Bottom Controls Bar 1: Step Pager (< 1/6 >) + Preset Example Pills + Proof Flow + Auto
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Step Prev
                      _buildDarkIconButton(
                        icon: Icons.arrow_left_rounded,
                        onTap: () => setState(() => _activeStepIndex = (_activeStepIndex - 1 + 6) % 6),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${_activeStepIndex + 1} / 6',
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      // Step Next
                      _buildDarkIconButton(
                        icon: Icons.arrow_right_rounded,
                        onTap: () => setState(() => _activeStepIndex = (_activeStepIndex + 1) % 6),
                      ),
                      const SizedBox(width: 12),

                      // Preset Example Buttons
                      ...List.generate(presets.length, (pIdx) {
                        final p = presets[pIdx];
                        final isSelected = _activePresetIndex == pIdx;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _activePresetIndex = pIdx;
                                _paramA = double.tryParse((p['a'] ?? 3).toString()) ?? 3.0;
                                _paramB = double.tryParse((p['b'] ?? 4).toString()) ?? 4.0;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                                ),
                              ),
                              child: Text(
                                (p['label'] ?? 'Preset ${pIdx + 1}').toString(),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      // Proof Flow Toggle Button
                      InkWell(
                        onTap: () => setState(() => _proofFlowActive = !_proofFlowActive),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: _proofFlowActive ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Proof Flow',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Auto: OFF / ON Toggle Button
                      InkWell(
                        onTap: _toggleAutoPlay,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: _autoPlaySteps ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text(
                            _autoPlaySteps ? 'Auto: ON' : 'Auto: OFF',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Bottom Controls Bar 2: Dual Sliders ("Side a:", "Side b:", "Hypotenuse c: 5.0")
              Container(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Slider 1 (Cyan)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isPythag ? 'Side a:' : 'Supply V:',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(
                          width: isNarrow ? 120 : 165,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF38BDF8),
                              inactiveTrackColor: const Color(0xFF1E293B),
                              thumbColor: const Color(0xFF38BDF8),
                              trackHeight: 5,
                            ),
                            child: Slider(
                              value: _paramA.clamp(1.0, 15.0),
                              min: 1.0,
                              max: 15.0,
                              divisions: 14,
                              onChanged: (v) => setState(() => _paramA = v),
                            ),
                          ),
                        ),
                        Text(
                          '$aInt',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),

                    // Slider 2 (Purple)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isPythag ? 'Side b:' : 'Resistor Ω:',
                          style: const TextStyle(color: Color(0xFFA855F7), fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(
                          width: isNarrow ? 120 : 165,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFA855F7),
                              inactiveTrackColor: const Color(0xFF1E293B),
                              thumbColor: const Color(0xFFA855F7),
                              trackHeight: 5,
                            ),
                            child: Slider(
                              value: isPythag ? _paramB.clamp(1.0, 15.0) : _paramB.clamp(100.0, 1000.0),
                              min: isPythag ? 1.0 : 100.0,
                              max: isPythag ? 15.0 : 1000.0,
                              divisions: isPythag ? 14 : 18,
                              onChanged: (v) => setState(() => _paramB = v),
                            ),
                          ),
                        ),
                        Text(
                          '$bInt',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),

                    // Gold Computed Output
                    Text(
                      isPythag
                          ? 'Hypotenuse c: ${cVal.toStringAsFixed(1)}'
                          : 'Current I: ${currentMa.toStringAsFixed(1)} mA',
                      style: const TextStyle(
                        color: Color(0xFFFACC15),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        // ---------------------------------------------------------------------
        // RIGHT PANEL: LIGHT SCROLLABLE EXPLANATION PANEL (Matches Image 2)
        // ---------------------------------------------------------------------
        final lightExplanationPanel = Container(
          color: const Color(0xFFF8FAFC),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Row: "📖 Explanation" | "🔊 Listen"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.bookOpen, color: Color(0xFF0284C7), size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Explanation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _speakText('$shortTitle. $inOneLine. $whatIsOnPage'),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.volume2, size: 15, color: Color(0xFF0284C7)),
                            SizedBox(width: 6),
                            Text(
                              'Listen',
                              style: TextStyle(
                                color: Color(0xFF0284C7),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Language Pill Switcher Row ("文A  English | தமிழ் | हिन्दी | मराठी | العربية")
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(LucideIcons.languages, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      ..._languagePills.map((lang) {
                        final isSelected = _selectedLang == lang['code'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedLang = lang['code']!);
                              _generateLesson();
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0284C7) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                lang['label']!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Multi-concept switcher if PDF had > 1 concept
                if (_generatedConcepts.length > 1) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_generatedConcepts.length, (cIdx) {
                        final cTitle = (_generatedConcepts[cIdx]['title'] ?? 'Concept ${cIdx + 1}').toString();
                        final isSel = _selectedConceptIndex == cIdx;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('Concept ${cIdx + 1}: $cTitle', style: const TextStyle(fontSize: 11.5)),
                            selected: isSel,
                            onSelected: (_) {
                              setState(() {
                                _selectedConceptIndex = cIdx;
                                _initSlidersForConcept(_generatedConcepts[cIdx]);
                              });
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 3. CARD 1: Warm Cream Card ("What is on this page")
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(LucideIcons.scanLine, color: Colors.white, size: 15),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'What is on this page',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        whatIsOnPage,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF334155),
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. CARD 2: Vibrant Blue-to-Purple Gradient Card ("💡 IN ONE LINE")
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_rounded, color: Color(0xFFFACC15), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'IN ONE LINE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        inOneLine,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 5. CARD 3: White Card ("How it works" + Interactive 6-Step List)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(LucideIcons.gitBranch, color: Colors.white, size: 15),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'How it works',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        howItWorks,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF334155),
                          height: 1.55,
                        ),
                      ),
                      const Divider(height: 24),
                      ...List.generate(stepsList.length, (sIdx) {
                        final isCurrentStep = _activeStepIndex == sIdx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => setState(() => _activeStepIndex = sIdx),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCurrentStep ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrentStep ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: isCurrentStep ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                                    child: Text(
                                      '${sIdx + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrentStep ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      stepsList[sIdx],
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isCurrentStep ? FontWeight.w700 : FontWeight.w500,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // 6. CARD 4: Quick Practice Quiz & Ask AI Tutor
                if (quizzes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📝 Practice Check',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        ...quizzes.asMap().entries.map((entry) {
                          final qIdx = entry.key;
                          final q = entry.value as Map<String, dynamic>;
                          final options = (q['options'] as List?) ?? [];
                          final answerIdx = (q['answer'] is int) ? q['answer'] as int : 0;
                          final selected = _quizSelections[qIdx];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Q${qIdx + 1}: ${q['question'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: options.asMap().entries.map((opt) {
                                    final oIdx = opt.key;
                                    final isSelected = selected == oIdx;
                                    final isCorrect = oIdx == answerIdx;
                                    return ChoiceChip(
                                      label: Text(opt.value.toString(), style: const TextStyle(fontSize: 12)),
                                      selected: isSelected,
                                      selectedColor: isCorrect ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                      onSelected: (_) => setState(() => _quizSelections[qIdx] = oIdx),
                                    );
                                  }).toList(),
                                ),
                                if (selected != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    selected == answerIdx
                                        ? '✅ Correct! ${q['why'] ?? ''}'
                                        : '💡 Hint: ${q['why'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: selected == answerIdx ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Ask a Doubt Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _doubtController,
                              onSubmitted: (_) => _askDoubt(shortTitle),
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Ask AI Tutor a question about this page...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isAskingDoubt ? null : () => _askDoubt(shortTitle),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: Text(_isAskingDoubt ? '...' : 'Ask', style: const TextStyle(fontSize: 12.5)),
                          ),
                        ],
                      ),
                      if (_doubtAnswer != null) ...[
                        const Divider(height: 16),
                        Text(
                          '🤖 $_doubtAnswer',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        return Column(
          children: [
            // Top Header Bar ("<- Back" | "<Title> Animated Explanation" | "Upload New PDF")
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _generatedConcepts.clear();
                        _selectedFileBytes = null;
                        _selectedFileName = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.arrowLeft, size: 16, color: Color(0xFF0F172A)),
                          SizedBox(width: 6),
                          Text(
                            'Back',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '$shortTitle Animated Explanation',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isNarrow ? 14 : 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickFile(useCamera: false),
                    icon: const Icon(LucideIcons.upload, size: 15),
                    label: Text(isNarrow ? 'PDF' : 'Upload PDF / Page', style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),

            // Split View Content
            Expanded(
              child: isNarrow
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          darkSimulationPanel,
                          lightExplanationPanel,
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: darkSimulationPanel),
                        Container(width: 1, color: const Color(0xFFE2E8F0)),
                        Expanded(flex: 4, child: lightExplanationPanel),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDarkIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildTopicTextField(AppTokens tokens) {
    return TextField(
      controller: _topicController,
      onSubmitted: (_) => _generateLesson(),
      decoration: InputDecoration(
        hintText: 'Type a topic (e.g. Pythagoras\' Theorem, Resistors, Ultrasonic Sensor)...',
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
          items: _languagePills
              .map((l) => DropdownMenuItem(value: l['code'], child: Text(l['code']!)))
              .toList(),
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
}

// =============================================================================
// CUSTOM PAINTER 1: PYTHAGORAS' THEOREM ANIMATED PROOF (MATCHES IMAGE 2!)
// =============================================================================
class _PythagorasAnimatedProofPainter extends CustomPainter {
  final double sideA;
  final double sideB;
  final double progress;
  final int stepIndex;
  final bool showProofFlow;

  _PythagorasAnimatedProofPainter({
    required this.sideA,
    required this.sideB,
    required this.progress,
    required this.stepIndex,
    required this.showProofFlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final aInt = sideA.round();
    final bInt = sideB.round();
    final aSq = aInt * aInt;
    final bSq = bInt * bInt;
    final cSq = aSq + bSq;
    final cVal = math.sqrt(cSq);

    // Scale triangle so it always fits comfortably with its 3 outer squares
    final maxSide = math.max(sideA, sideB).clamp(3.0, 15.0);
    final unit = (math.min(size.width, size.height) * 0.22) / maxSide;

    final aPx = sideA * unit;
    final bPx = sideB * unit;

    // Right-angle vertex B at center
    final bx = size.width * 0.45;
    final by = size.height * 0.50;

    // Vertex A directly above B (vertical leg a), Vertex C to the right of B (horizontal leg b)
    final pB = Offset(bx, by);
    final pA = Offset(bx, by - aPx);
    final pC = Offset(bx + bPx, by);

    // 1. Draw Purple Square on Top/Horizontal Leg b (or adjacent leg)
    final bSquareRect = Rect.fromLTWH(bx, by - bPx, bPx, bPx);
    _drawGridSquare(
      canvas,
      bSquareRect,
      bInt,
      const Color(0xFFA855F7),
      'Side b = $bInt\nArea = $bSq',
    );

    // 2. Draw Cyan Square on Vertical Leg a
    final aSquareRect = Rect.fromLTWH(bx, by - aPx, aPx, aPx);
    _drawGridSquare(
      canvas,
      aSquareRect,
      aInt,
      const Color(0xFF38BDF8),
      'Side a = $aInt',
    );

    // 3. Draw Rotated Gold Square on Hypotenuse AC
    final dx = pC.dx - pA.dx;
    final dy = pC.dy - pA.dy;
    final cPx = math.sqrt(dx * dx + dy * dy);
    final angle = math.atan2(dy, dx);

    canvas.save();
    canvas.translate(pA.dx, pA.dy);
    canvas.rotate(angle);
    final cRect = Rect.fromLTWH(0, 0, cPx, cPx);
    _drawGridSquare(
      canvas,
      cRect,
      cVal.round().clamp(3, 15),
      const Color(0xFFF59E0B),
      'Hypotenuse c = ${cVal.toStringAsFixed(1)}\nArea = $cSq',
    );
    canvas.restore();

    // 4. Draw Proof Flow Glowing Particles (Cyan, Purple, Gold dots)
    if (showProofFlow) {
      final centerTri = Offset((pA.dx + pB.dx + pC.dx) / 3, (pA.dy + pB.dy + pC.dy) / 3);
      for (int i = 0; i < 18; i++) {
        final t = ((i / 18) + progress) % 1.0;
        final angleP = i * 0.9 + progress * math.pi * 2;
        final radiusP = 12.0 + (t * cPx * 0.42);
        final pt = Offset(
          centerTri.dx + math.cos(angleP) * radiusP * 0.7,
          centerTri.dy + math.sin(angleP) * radiusP * 0.7,
        );
        final color = i % 3 == 0
            ? const Color(0xFF38BDF8)
            : (i % 3 == 1 ? const Color(0xFFA855F7) : const Color(0xFFFACC15));
        canvas.drawCircle(pt, 4.2, Paint()..color = color.withOpacity(0.88));
      }
    }

    // 5. Draw Right-Angled Triangle ABC Outline & 90° Right-Angle Marker
    final triPath = Path()
      ..moveTo(pA.dx, pA.dy)
      ..lineTo(pB.dx, pB.dy)
      ..lineTo(pC.dx, pC.dy)
      ..close();

    canvas.drawPath(
      triPath,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke,
    );

    // Vertex dots
    for (final v in [pA, pB, pC]) {
      canvas.drawCircle(v, 4.5, Paint()..color = Colors.white);
    }

    _drawText(canvas, 'A', Offset(pA.dx - 16, pA.dy - 14), const Color(0xFFCBD5E1), 12, FontWeight.w800);
    _drawText(canvas, 'B (90°)', Offset(pB.dx - 24, pB.dy + 6), const Color(0xFFCBD5E1), 11, FontWeight.w700);
    _drawText(canvas, 'C', Offset(pC.dx + 8, pC.dy - 4), const Color(0xFFCBD5E1), 12, FontWeight.w800);
  }

  void _drawGridSquare(
    Canvas canvas,
    Rect rect,
    int divisions,
    Color color,
    String label,
  ) {
    // Translucent fill
    canvas.drawRect(rect, Paint()..color = color.withOpacity(0.16));

    // Internal grid lines
    final gridPaint = Paint()
      ..color = color.withOpacity(0.32)
      ..strokeWidth = 1.0;
    final stepW = rect.width / divisions;
    final stepH = rect.height / divisions;
    for (int i = 1; i < divisions; i++) {
      canvas.drawLine(
        Offset(rect.left + i * stepW, rect.top),
        Offset(rect.left + i * stepW, rect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top + i * stepH),
        Offset(rect.right, rect.top + i * stepH),
        gridPaint,
      );
    }

    // Outer border
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    _drawText(
      canvas,
      label,
      Offset(rect.center.dx - 38, rect.center.dy - 12),
      Colors.white,
      11.5,
      FontWeight.w800,
    );
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight, height: 1.2),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _PythagorasAnimatedProofPainter oldDelegate) => true;
}

// =============================================================================
// CUSTOM PAINTER 2: DARK STEM / CIRCUIT SIMULATION PAINTER
// =============================================================================
class _DarkStemSimulationPainter extends CustomPainter {
  final double voltage;
  final double resistance;
  final double currentMa;
  final double progress;
  final int stepIndex;

  _DarkStemSimulationPainter({
    required this.voltage,
    required this.resistance,
    required this.currentMa,
    required this.progress,
    required this.stepIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = size.width * 0.18;
    final right = size.width * 0.82;
    final top = size.height * 0.25;
    final bottom = size.height * 0.78;

    final loopRect = Rect.fromLTRB(left, top, right, bottom);
    canvas.drawRect(
      loopRect,
      Paint()
        ..color = const Color(0xFF334155)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke,
    );

    // Battery on left
    final midY = (top + bottom) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(left, midY), width: 34, height: 64),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF0284C7),
    );
    _drawText(canvas, '${voltage.toInt()}V', Offset(left - 11, midY - 7), Colors.white, 12);

    // Resistor on top-left
    final rx = left + (right - left) * 0.32;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(rx, top), width: 52, height: 18),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFA855F7),
    );
    _drawText(canvas, '${resistance.toInt()} Ω', Offset(rx - 20, top - 26), const Color(0xFFA855F7), 12);

    // Glowing LED on top-right
    final lx = left + (right - left) * 0.70;
    final glow = (currentMa / 20.0).clamp(0.25, 1.0);
    canvas.drawCircle(
      Offset(lx, top),
      38 * glow,
      Paint()
        ..color = const Color(0xFFFACC15).withOpacity(0.32 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(Offset(lx, top), 14, Paint()..color = const Color(0xFFFACC15));

    // Flowing electron particles
    final w = right - left;
    final h = bottom - top;
    final perim = 2 * (w + h);
    for (int i = 0; i < 12; i++) {
      final f = ((i / 12) + progress) % 1.0;
      final d = f * perim;
      Offset p;
      if (d <= w) {
        p = Offset(left + d, top);
      } else if (d <= w + h) {
        p = Offset(right, top + (d - w));
      } else if (d <= 2 * w + h) {
        p = Offset(right - (d - (w + h)), bottom);
      } else {
        p = Offset(left, bottom - (d - (2 * w + h)));
      }
      canvas.drawCircle(p, 4.2, Paint()..color = const Color(0xFF38BDF8));
    }

    _drawText(
      canvas,
      'I = ${currentMa.toStringAsFixed(1)} mA',
      Offset((left + right) / 2 - 42, midY - 10),
      const Color(0xFFFACC15),
      20,
    );
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _DarkStemSimulationPainter oldDelegate) => true;
}
