// Edit screen for AI-generated learning recommendations.
// Like `pages/teacher/LearningRecommendation/Edit.vue` in a Vue app.
//
// Allows teachers to modify AI-generated recommendation titles, descriptions,
// priorities, and materials using rich text editors (Quill). In Laravel terms,
// this is like `RecommendationController@edit` + `@update`.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Form screen for editing AI-generated learning recommendations.
///
/// Uses Flutter Quill for rich text editing (like Vue Quill Editor / TinyMCE).
/// Each recommendation has a title, priority, description, and materials --
/// all editable via dedicated controllers.
///
/// Props (like Vue props):
/// - [teacher] -- current teacher info
/// - [student] -- the student whose recommendations are being edited
/// - [recommendations] -- list of recommendation objects to edit
class LearningRecommendationEditScreen extends StatefulWidget {
  final Map<String, String> teacher;
  final Map<String, dynamic> student;
  final List<dynamic> recommendations;

  const LearningRecommendationEditScreen({
    super.key,
    required this.teacher,
    required this.student,
    required this.recommendations,
  });

  @override
  State<LearningRecommendationEditScreen> createState() =>
      _LearningRecommendationEditScreenState();
}

/// State for [LearningRecommendationEditScreen].
///
/// Like a Vue page component with `data() { return {...} }`. Manages
/// multiple Quill controllers (one per editable field) and text controllers
/// for titles. `setState()` triggers re-render like Vue reactivity.
class _LearningRecommendationEditScreenState
    extends State<LearningRecommendationEditScreen> {
  bool _isSaving = false;

  // Controllers for Titles
  final Map<String, TextEditingController> _titleControllers = {};

  // Controllers for Quill editors
  final Map<String, quill.QuillController> _descriptionControllers = {};
  final Map<String, Map<String, quill.QuillController>> _materialControllers =
      {};

  // State for Priorities
  final Map<String, String> _priorities = {};

  /// Like Vue's `mounted()` -- initializes all form controllers from the
  /// recommendation data passed via props.
  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  /// Like Vue's `beforeUnmount()` -- disposes all Quill and text controllers.
  @override
  void dispose() {
    for (var controller in _titleControllers.values) {
      controller.dispose();
    }
    for (var controller in _descriptionControllers.values) {
      controller.dispose();
    }
    for (var materialGroup in _materialControllers.values) {
      for (var controller in materialGroup.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  quill.Document _convertHtmlToQuill(String html) {
    if (html.isEmpty) return quill.Document();

    // Basic HTML to text conversion for Quill
    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
    int counter = 1;
    while (text.contains('<li>')) {
      if (text.contains('<ol>')) {
        text = text.replaceFirst('<li>', '$counter. ');
        counter++;
      } else {
        text = text.replaceFirst('<li>', '• ');
      }
    }
    text = text.replaceAll('</li>', '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<h3>'), '\n');
    text = text.replaceAll(RegExp(r'</h3>|<p>|</p>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.trim();

    return quill.Document()..insert(0, text);
  }

  /// Creates text/Quill controllers for each recommendation and its materials.
  /// Like Vue `mounted()` setting up `this.$refs` for each editor instance.
  void _initControllers() {
    for (var rec in widget.recommendations) {
      final recId = rec['id']?.toString() ?? UniqueKey().toString();

      // Title
      _titleControllers[recId] = TextEditingController(
        text: rec['title'] ?? '',
      );

      // Priority
      _priorities[recId] = rec['priority']?.toString().toLowerCase() ?? 'low';

      // Description
      _descriptionControllers[recId] = quill.QuillController(
        document: _convertHtmlToQuill(rec['description'] ?? ''),
        selection: const TextSelection.collapsed(offset: 0),
      );

      if (rec['materials'] != null) {
        _materialControllers[recId] = {};
        for (var mat in rec['materials']) {
          final matId = mat['id']?.toString() ?? UniqueKey().toString();
          _materialControllers[recId]?[matId] = quill.QuillController(
            document: _convertHtmlToQuill(mat['content'] ?? ''),
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      }
    }
  }

  /// Saves edited recommendations and navigates back.
  /// Like a Vue `methods.save()` calling `axios.put()` then `this.$router.back()`.
  /// Returns `true` via `Navigator.pop()` to signal the parent that data changed
  /// (like Vue `$emit('saved')`).
  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    // Simulation: Prepare data to send back
    // for (var rec in widget.recommendations) {
    //   final recId = rec['id'].toString();
    //   rec['title'] = _titleControllers[recId]!.text;
    //   rec['priority'] = _priorities[recId];
    //   ...
    // }

    await Future.delayed(
      const Duration(seconds: 1),
    ); // Simulate network latency

    if (mounted) {
      setState(() => _isSaving = false);
            SnackBarUtils.showInfo(context, 'Perubahan berhasil disimpan!');
      AppNavigator.pop(context, true); // Return true to indicate data changed
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getPrimaryColor(),
                  _getPrimaryColor().withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Rekomendasi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Penyuntingan Konten AI',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isSaving)
                  GestureDetector(
                    onTap: _saveChanges,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: widget.recommendations.length,
              itemBuilder: (context, index) {
                final rec = widget.recommendations[index];
                return _buildEditCard(rec);
              },
            ),
          ),

          // Bottom Save Section
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Perubahan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditCard(Map<String, dynamic> rec) {
    final recId = rec['id']?.toString() ?? UniqueKey().toString();
    final currentPriority = _priorities[recId] ?? 'low';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ColorUtils.corporateShadow(),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note, color: ColorUtils.slate400, size: 20),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Penyuntingan Rekomendasi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Field
                Text(
                  'JUDUL REKOMENDASI:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate400,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _titleControllers[recId],
                  decoration: InputDecoration(
                    hintText: 'Masukkan judul...',
                    filled: true,
                    fillColor: ColorUtils.slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Priority Field
                Text(
                  'PRIORITAS:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate400,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: ['low', 'medium', 'high'].map((p) {
                    final bool isSelected = currentPriority == p;
                    Color pColor = Colors.blue;
                    if (p == 'high') pColor = Colors.red;
                    if (p == 'medium') pColor = Colors.orange;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _priorities[recId] = p),
                        child: Container(
                          margin: EdgeInsets.only(right: p == 'high' ? 0 : 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? pColor : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? pColor : ColorUtils.slate200,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p.toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : ColorUtils.slate500,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Description Field
                Text(
                  'DESKRIPSI REKOMENDASI:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate400,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_descriptionControllers[recId] != null)
                  _buildQuillSection(_descriptionControllers[recId]!),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (rec['materials'] != null &&
              (rec['materials'] as List).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'MATERI & AKTIVITAS:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: ColorUtils.slate400,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...(rec['materials'] as List).map((mat) {
              final matId = mat['id']?.toString() ?? UniqueKey().toString();
              return Container(
                margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.label_important_outline,
                          color: ColorUtils.slate400,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          mat['title'] ?? 'Materi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_materialControllers[recId]?[matId] != null)
                      _buildQuillSection(_materialControllers[recId]![matId]!),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildQuillSection(quill.QuillController controller) {
    return Column(
      children: [
        quill.QuillSimpleToolbar(
          controller: controller,
          config: const quill.QuillSimpleToolbarConfig(
            showFontFamily: false,
            showFontSize: false,
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true,
            showStrikeThrough: false,
            showColorButton: false,
            showBackgroundColorButton: false,
            showClearFormat: false,
            showLeftAlignment: false,
            showCenterAlignment: false,
            showRightAlignment: false,
            showJustifyAlignment: false,
            showListNumbers: true,
            showListBullets: true,
            showListCheck: false,
            showCodeBlock: false,
            showQuote: false,
            showIndent: false,
            showLink: false,
            showUndo: true,
            showRedo: true,
            multiRowsDisplay: false,
          ),
        ),
        Container(
          height: 180,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: quill.QuillEditor.basic(
            controller: controller,
            config: const quill.QuillEditorConfig(
              placeholder: 'Tulis sesuatu...',
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
