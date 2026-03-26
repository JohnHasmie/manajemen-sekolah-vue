// RPP generation configuration screen -- set options before AI generates.
// Like `pages/teacher/LessonPlan/Generate.vue` in a Vue app.
//
// Allows teachers to configure title, objectives, and media/tools before
// triggering AI-powered RPP generation. Shows progress during generation.
// In Laravel terms: the form before dispatching an `GenerateRppJob`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/lesson_plans/screens/lesson_plan_detail_screen.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/features/lesson_plans/services/ai_lesson_plan_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Pre-generation form for AI RPP creation.
///
/// Props (like Vue props):
/// - [teacher] -- teacher data, [selectedSubjectId] -- subject ID
/// - [subjectName] -- subject name for display
/// - [checkedChapters] / [checkedSubChapters] -- selected chapters for generation
class RPPGeneratePage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final String selectedSubjectId;
  final String subjectName;
  final List<Map<String, dynamic>> checkedChapters;
  final List<Map<String, dynamic>> checkedSubChapters;

  const RPPGeneratePage({
    super.key,
    required this.teacher,
    required this.selectedSubjectId,
    required this.subjectName,
    required this.checkedChapters,
    required this.checkedSubChapters,
  });

  @override
  RPPGeneratePageState createState() => RPPGeneratePageState();
}

/// State for [RPPGeneratePage].
///
/// Like a Vue component with `data() { return { isGenerating, progress, ... } }`.
/// Manages form fields, auto-title generation, and the RPP generation process.
class RPPGeneratePageState extends State<RPPGeneratePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _objectivesController = TextEditingController();
  final TextEditingController _toolsMediaController = TextEditingController();

  bool _isGenerating = false;
  String _statusMessage = '';
  double _progress = 0.0;

  // State for checkboxes
  bool _titleChecked = true;
  bool _objectivesChecked = true;
  bool _mediaChecked = true;

  /// Like Vue's `mounted()` -- generates an auto-title from selected chapters.
  @override
  void initState() {
    super.initState();
    _generateAutoTitle();
  }

  void _generateAutoTitle() {
    final String autoTitle = _getLessonTitleFromSelection();
    _titleController.text = autoTitle;
  }

  String _getLessonTitleFromSelection() {
    List<String> titleParts = [];

    // Prioritize checked sub-chapters
    if (widget.checkedSubChapters.isNotEmpty) {
      for (var subChapter in widget.checkedSubChapters) {
        final chapterTitle = subChapter['judul_sub_bab'] ?? '';
        if (chapterTitle.isNotEmpty) {
          titleParts.add(chapterTitle);
        }
      }
    }

    // If no sub-chapters, get from checked chapters
    if (titleParts.isEmpty && widget.checkedChapters.isNotEmpty) {
      for (var chapter in widget.checkedChapters) {
        final chapterTitle = chapter['judul_bab'] ?? '';
        if (chapterTitle.isNotEmpty) {
          titleParts.add(chapterTitle);
        }
      }
    }

    // Format title with comma separator
    String formattedTitle = titleParts.join(', ');

    // Add RPP prefix if not present and title is not empty
    if (formattedTitle.isNotEmpty &&
        !formattedTitle.toLowerCase().contains('rpp')) {
      formattedTitle = 'RPP $formattedTitle';
    }

    // If still empty, use the subject name
    if (formattedTitle.isEmpty) {
      formattedTitle = 'RPP ${widget.subjectName}';
    }

    return formattedTitle;
  }

  void _updateTitleFromSelection() {
    if (_titleChecked) {
      final newTitle = _getLessonTitleFromSelection();
      setState(() {
        _titleController.text = newTitle;
      });
    }
  }

  Future<void> _generateRPP() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Judul RPP harus diisi')));
      return;
    }

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _statusMessage = 'Mempersiapkan data...';
    });

    try {
      // Collect all material content from selected chapters and sub-chapters
      List<Map<String, dynamic>> allMaterialContent = [];

      // Get content from checked sub-chapters
      for (var subChapter in widget.checkedSubChapters) {
        setState(() {
          _statusMessage = 'Mengambil konten sub bab...';
        });

        final content = await getIt<ApiSubjectService>().getContentMateri(
          subBabId: subChapter['id'],
        );

        for (var item in content) {
          allMaterialContent.add({
            'type': 'sub_bab',
            'sub_bab': subChapter['judul_sub_bab'],
            'judul': item['judul_konten'],
            'isi': item['isi_konten'],
          });
        }
        _progress +=
            0.2 / (widget.checkedSubChapters.length + widget.checkedChapters.length);
      }

      // Get content from checked chapters (all sub-chapters within the chapter)
      for (var chapter in widget.checkedChapters) {
        setState(() {
          _statusMessage = 'Mengambil konten bab...';
        });

        final subChapters = await getIt<ApiSubjectService>().getSubBabMateri(
          babId: chapter['id'],
        );

        for (var subChapter in subChapters) {
          final content = await getIt<ApiSubjectService>().getContentMateri(
            subBabId: subChapter['id'],
          );

          for (var item in content) {
            allMaterialContent.add({
              'type': 'bab',
              'bab': chapter['judul_bab'],
              'sub_bab': subChapter['judul_sub_bab'],
              'judul': item['judul_konten'],
              'isi': item['isi_konten'],
            });
          }
        }
        _progress +=
            0.3 / (widget.checkedSubChapters.length + widget.checkedChapters.length);
      }

      setState(() {
        _statusMessage = 'Generate RPP dengan AI...';
        _progress = 0.8;
      });

      // Generate RPP using AI service
      final RPPService rppService = RPPService();
      final generatedRPP = await rppService.generateRPP(
        title: _titleController.text,
        subjectId: widget.selectedSubjectId,
        subjectName: widget.subjectName,
        materialContent: allMaterialContent,
        learningObjectives: _objectivesChecked ? _objectivesController.text : '',
        toolsMedia: _mediaChecked ? _toolsMediaController.text : '',
      );

      setState(() {
        _progress = 1.0;
        _statusMessage = 'RPP berhasil digenerate!';
      });

      // Navigate ke halaman detail RPP
      if (mounted) {
        AppNavigator.pushReplacement(context, RPPDetailPage(rppData: generatedRPP, isNew: true));
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        setState(
          () => _isGenerating = false,
        ); // Changed _isLoading to _isGenerating
                SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Generate Lesson Plan'),
        backgroundColor: ColorUtils.indigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _updateTitleFromSelection,
            tooltip: 'Refresh Title dari Selection',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Topics Section
            _buildSelectedTopics(),
            SizedBox(height: AppSpacing.xxxl),

            // Lesson Details Section
            _buildLessonDetails(),
            SizedBox(height: AppSpacing.xxxl),

            // Generate Button
            _buildGenerateButton(),
            SizedBox(height: AppSpacing.xl),

            // Progress Indicator
            if (_isGenerating) _buildProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTopics() {
    final totalSelected =
        widget.checkedChapters.length + widget.checkedSubChapters.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Topics:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorUtils.indigo600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalSelected selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.indigo600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),

          // Display selected sub topics
          if (widget.checkedSubChapters.isNotEmpty) ...[
            ...widget.checkedSubChapters.map(
              (subBab) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: ColorUtils.indigo600),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Sub ${subBab['urutan']}: ${subBab['judul_sub_bab'] ?? 'Judul Sub Bab'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Display selected chapters with their sub-chapters
          if (widget.checkedChapters.isNotEmpty) ...[
            ...widget.checkedChapters.map(
              (bab) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: widget.checkedSubChapters.isNotEmpty ? 16 : 0),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark,
                          size: 12,
                          color: ColorUtils.emerald500,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Chapter ${bab['urutan']}: ${bab['judul_bab']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Display all sub-chapters in this chapter
                  ..._getAllSubBabForBab(bab['id']).map(
                    (subBab) => Padding(
                      padding: EdgeInsets.only(left: 20, bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            '${subBab['urutan']}.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAllSubBabForBab(String babId) {
    // For real implementation, you need to fetch data from the API
    // Currently returns an empty list - needs to be implemented according to your data structure
    return [];
  }

  Widget _buildLessonDetails() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lesson Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: AppSpacing.xl),

          // Subject and Date Row
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.subject,
                  title: 'Subject',
                  content: widget.subjectName,
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.calendar_today,
                  title: 'Date',
                  content: _getFormattedDate(),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),

          // Lesson Title - Editable with auto-suggestion
          _buildEditableFieldWithCheckbox(
            controller: _titleController,
            label: 'Lesson Title',
            hintText: 'Contoh: RPP Introduction to Forces, Newton\'s First Law',
            icon: Icons.title,
            isChecked: _titleChecked,
            onCheckedChanged: (value) {
              setState(() {
                _titleChecked = value;
                if (value) {
                  _updateTitleFromSelection();
                }
              });
            },
            maxLines: 2,
          ),
          SizedBox(height: AppSpacing.lg),

          // Lesson Objectives - Editable
          _buildEditableFieldWithCheckbox(
            controller: _objectivesController,
            label: 'Lesson Objectives',
            hintText:
                'Students will identify types of forces, understand Newton\'s laws of motion, and analyze real-world applications',
            icon: Icons.flag,
            isChecked: _objectivesChecked,
            onCheckedChanged: (value) {
              setState(() {
                _objectivesChecked = value;
              });
            },
            maxLines: 3,
          ),
          SizedBox(height: AppSpacing.lg),

          // Media/Tools - Editable
          _buildEditableFieldWithCheckbox(
            controller: _toolsMediaController,
            label: 'Media/Tools',
            hintText:
                'Projector, white board, experiment kit (springs, weights, carts)',
            icon: Icons.computer,
            isChecked: _mediaChecked,
            onCheckedChanged: (value) {
              setState(() {
                _mediaChecked = value;
              });
            },
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFieldWithCheckbox({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required bool isChecked,
    required Function(bool) onCheckedChanged,
    int maxLines = 1,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isChecked,
                onChanged: (value) {
                  onCheckedChanged(value ?? false);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Icon(icon, size: 16, color: Colors.grey.shade600),
              SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            enabled: isChecked,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade500),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            onChanged: (value) {
              // User dapat mengedit manual
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateRPP,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorUtils.emerald500,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 24),
            SizedBox(width: AppSpacing.md),
            Text(
              _isGenerating ? 'Generating...' : 'Generate Lesson Plan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey.shade300,
            color: ColorUtils.emerald500,
            borderRadius: BorderRadius.circular(4),
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _statusMessage,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.emerald500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
