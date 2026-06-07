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
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/edit_controller_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/edit_form_card_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/edit_form_state_mixin.dart';

class LearningRecommendationEditScreen extends StatefulWidget {
  final Map<String, String> teacher;
  final Map<String, dynamic> student;

  /// The single recommendation being edited. The teacher edits one
  /// recommendation per session — bulk edit was removed because it
  /// led to long Quill stacks the wali couldn't see in one screen.
  final Map<String, dynamic> recommendation;

  const LearningRecommendationEditScreen({
    super.key,
    required this.teacher,
    required this.student,
    required this.recommendation,
  });

  /// Pushes the editor as a full Material page route. Returns `true`
  /// when the teacher saves so the caller can refresh the rec list.
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, String> teacher,
    required Map<String, dynamic> student,
    required Map<String, dynamic> recommendation,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LearningRecommendationEditScreen(
          teacher: teacher,
          student: student,
          recommendation: recommendation,
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

  /// Teacher-facing notes ("Catatan Wali Kelas"). Optional. Single
  /// controller now that the screen edits one rec at a time.
  late final TextEditingController _notesController;

  /// Live list of selected materials — drives the chip strip in
  /// "Materi Terkait". Mutable so the wali can remove a chip.
  late final List<Map<String, dynamic>> _materialChips;

  @override
  void initState() {
    super.initState();
    initControllers();
    _notesController = TextEditingController(
      text: widget.recommendation['teacher_notes']?.toString() ?? '',
    );
    final raw = widget.recommendation['materials'];
    _materialChips = raw is List
        ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
  }

  @override
  void dispose() {
    disposeAllControllers();
    _notesController.dispose();
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

  /// Bridge for the existing list-based mixin contract — wraps the
  /// single recommendation in a one-element list so `initControllers`
  /// + `saveChanges` keep working without a deeper refactor.
  @override
  List<dynamic> get widgetRecommendations => [widget.recommendation];

  @override
  bool get isSaving => _isSaving;

  @override
  set isSaving(bool value) => _isSaving = value;

  @override
  Map<String, String> get teacher => widget.teacher;

  // ── Per-rec extras (notes + materi chips) ──
  // EditFormCardMixin reads these to render the Catatan textarea
  // and the Materi Terkait chip strip. Mutation flows through
  // onRemoveMaterialChip / onAddMaterialChip with setState so the
  // strip rebuilds in place.
  @override
  TextEditingController get notesController => _notesController;
  @override
  List<Map<String, dynamic>> get materialChips => _materialChips;
  @override
  void onRemoveMaterialChip(int index) {
    setState(() => _materialChips.removeAt(index));
  }

  @override
  void onAddMaterialChip(Map<String, dynamic> mat) {
    setState(() => _materialChips.add(mat));
  }

  /// Subject the rec is scoped to — drives the curriculum picker in
  /// `_AddMaterialSheet`. We accept a few snake/camel variants because
  /// the rec map comes from both the result-screen ListView and the
  /// edit-rec mixin which serializes slightly differently.
  @override
  String? get materialPickerSubjectId {
    final raw =
        widget.recommendation['subject_id'] ??
        widget.recommendation['subjectId'] ??
        widget.recommendation['subject']?.toString();
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  String get _studentName {
    final raw =
        widget.student['name'] ?? widget.student['student_name'] ?? 'Siswa';
    return raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          BrandPageHeader(
            role: 'guru',
            subtitle: '$_studentName · Edit Rec',
            title: kRecEditRecommendation.tr,
            onBackPressed: _isSaving ? null : () => AppNavigator.pop(context),
            actionIcons: [
              BrandHeaderIconButton(
                icon: Icons.check_rounded,
                onTap: _isSaving ? () {} : saveChanges,
              ),
            ],
          ),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [buildEditCard(widget.recommendation, 0)],
            ),
          ),
          BottomSheetFooter(
            primaryLabel: _isSaving ? kRecSavingEllipsis.tr : kRecSaveChanges.tr,
            secondaryLabel: kRecCancel.tr,
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
