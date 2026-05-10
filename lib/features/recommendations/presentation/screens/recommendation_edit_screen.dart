// Edit recommendations — Frame E of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Cobalt brand header with a check (Simpan) action button on the
// right. Body is a stack of `_SectCard`s — one per recommendation —
// each carrying Judul / Deskripsi (Quill) / Prioritas / Materi /
// Catatan blocks. The bulk-edit semantics from the previous sheet
// are kept (`saveChanges` writes every rec in one go); only the
// chrome changed to match the brand pattern.
//
// Pushes as a MaterialPageRoute (was a 92% modal bottom sheet) so
// the brand header gets its full SafeArea and the Quill toolbar
// doesn't fight a parent sheet's scroll controller.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/edit_controller_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/edit_form_card_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/edit_form_state_mixin.dart';

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

  /// Pushes the editor as a full Material page route. Returns `true`
  /// when the teacher saves so the caller can refresh the rec list.
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, String> teacher,
    required Map<String, dynamic> student,
    required List<dynamic> recommendations,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LearningRecommendationEditScreen(
          teacher: teacher,
          student: student,
          recommendations: recommendations,
        ),
      ),
    );
  }

  @override
  State<LearningRecommendationEditScreen> createState() =>
      _LearningRecommendationEditScreenState();
}

class _LearningRecommendationEditScreenState
    extends State<LearningRecommendationEditScreen>
    with EditControllerMixin, EditFormCardMixin, EditFormStateMixin {
  bool _isSaving = false;

  final Map<String, TextEditingController> _titleControllers = {};
  final Map<String, quill.QuillController> _descriptionControllers = {};
  final Map<String, Map<String, quill.QuillController>> _materialControllers =
      {};
  final Map<String, String> _priorities = {};

  @override
  void initState() {
    super.initState();
    initControllers();
  }

  @override
  void dispose() {
    disposeAllControllers();
    super.dispose();
  }

  @override
  Map<String, TextEditingController> get titleControllers => _titleControllers;

  @override
  Map<String, quill.QuillController> get descriptionControllers =>
      _descriptionControllers;

  @override
  Map<String, Map<String, quill.QuillController>> get materialControllers =>
      _materialControllers;

  @override
  Map<String, String> get priorities => _priorities;

  @override
  List<dynamic> get widgetRecommendations => widget.recommendations;

  @override
  bool get isSaving => _isSaving;

  @override
  set isSaving(bool value) => _isSaving = value;

  @override
  Map<String, String> get teacher => widget.teacher;

  String get _studentName {
    final raw =
        widget.student['name'] ?? widget.student['student_name'] ?? 'Siswa';
    return raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final count = widget.recommendations.length;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          BrandPageHeader(
            role: 'guru',
            subtitle: '$_studentName · Edit Rec',
            title: count == 1 ? 'Edit Rekomendasi' : 'Edit $count Rekomendasi',
            onBackPressed: _isSaving ? null : () => AppNavigator.pop(context),
            actionIcons: [
              BrandHeaderIconButton(
                icon: Icons.check_rounded,
                onTap: _isSaving ? () {} : saveChanges,
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: widget.recommendations.length,
              itemBuilder: (context, index) {
                final rec = widget.recommendations[index];
                return buildEditCard(rec, index);
              },
            ),
          ),
          BottomSheetFooter(
            primaryLabel: _isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
            secondaryLabel: 'Batal',
            primaryColor: cobalt,
            primaryEnabled: !_isSaving,
            onPrimary: saveChanges,
            onSecondary: _isSaving ? () {} : () => AppNavigator.pop(context),
          ),
        ],
      ),
    );
  }
}
