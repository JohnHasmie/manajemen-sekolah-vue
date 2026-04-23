// Form for editing AI-generated learning recommendations.
//
// Presented as a draggable bottom sheet (flat-flow pattern) on top of the
// result sheet. Call [LearningRecommendationEditScreen.show] — do not push
// this widget directly. Pops with `true` when the teacher saves changes.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/edit_controller_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/edit_form_card_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/edit_form_state_mixin.dart';

/// Form view for editing AI-generated learning recommendations.
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

  /// Opens this form as a modal bottom sheet. Returns `true` when the
  /// teacher saves so the caller can refresh the recommendation list.
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, String> teacher,
    required Map<String, dynamic> student,
    required List<dynamic> recommendations,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => LearningRecommendationEditScreen(
        teacher: teacher,
        student: student,
        recommendations: recommendations,
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = getPrimaryColor();
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomSheetHeader(
                title: 'Edit Rekomendasi',
                subtitle:
                    '${widget.recommendations.length} rekomendasi untuk diedit',
                icon: Icons.edit_note_rounded,
                primaryColor: primaryColor,
                onClose:
                    _isSaving ? null : () => AppNavigator.pop(context),
              ),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: widget.recommendations.length,
                  itemBuilder: (context, index) {
                    final rec = widget.recommendations[index];
                    return buildEditCard(rec, index);
                  },
                ),
              ),
              BottomSheetFooter(
                primaryLabel: _isSaving
                    ? 'Menyimpan...'
                    : 'Simpan Perubahan',
                secondaryLabel: 'Batal',
                primaryColor: primaryColor,
                primaryEnabled: !_isSaving,
                onPrimary: saveChanges,
                onSecondary:
                    _isSaving ? () {} : () => AppNavigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
