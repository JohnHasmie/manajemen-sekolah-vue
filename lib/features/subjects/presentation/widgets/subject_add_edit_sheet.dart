// Bottom-sheet widget for creating or editing a single subject (mata pelajaran).
// Owns all form controllers, autocomplete state, active-status toggle, and
// the isSaving loading flag. Calls onSaved() on success so the screen reloads.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/mixins/subject_add_edit_sheet_ui_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/mixins/subject_add_edit_sheet_header_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/mixins/subject_add_edit_sheet_buttons_mixin.dart';

/// A modal bottom-sheet for creating or editing a subject.
///
/// Analogous to a Vue modal component:
/// - [subject] is null when adding (like a "new" prop), or populated for edit.
/// - [availableMasterSubjects] is a preloaded list (like a Vuex store getter).
/// - [onSaved] is the "$emit('saved')" callback the screen uses to trigger reload.
class SubjectAddEditSheet extends ConsumerStatefulWidget {
  /// If null, the sheet creates a new subject; if set, it edits the given one.
  final Map<String, dynamic>? subject;

  /// Predefined subject templates for the autocomplete field.
  final List<dynamic> availableMasterSubjects;

  /// Called after a successful create or update so the parent can reload data.
  final VoidCallback onSaved;

  const SubjectAddEditSheet({
    super.key,
    this.subject,
    required this.availableMasterSubjects,
    required this.onSaved,
  });

  @override
  SubjectAddEditSheetState createState() => SubjectAddEditSheetState();
}

class SubjectAddEditSheetState extends ConsumerState<SubjectAddEditSheet>
    with
        SubjectAddEditSheetUiMixin,
        SubjectAddEditSheetHeaderMixin,
        SubjectAddEditSheetButtonsMixin {
  // Form controllers – like Vue's reactive `ref()` values
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  int? _selectedMasterSubjectId;
  late bool _isActive;
  bool _isSaving = false;

  // Public getters/setters for mixin access (file-scope privacy workaround)
  @override
  TextEditingController get codeController => _codeController;
  @override
  TextEditingController get nameController => _nameController;
  @override
  TextEditingController get descriptionController => _descriptionController;

  @override
  int? get selectedMasterSubjectId => _selectedMasterSubjectId;
  @override
  set selectedMasterSubjectId(int? value) => _selectedMasterSubjectId = value;

  @override
  bool get isActive => _isActive;
  @override
  set isActive(bool value) => _isActive = value;

  @override
  bool get isSaving => _isSaving;

  /// Validate, call API create/update, then close and notify parent.
  /// This method is exposed publicly for mixin access.
  @override
  Future<void> save(BuildContext ctx) => _save(ctx);

  @override
  void initState() {
    super.initState();
    final s = widget.subject;
    _codeController = TextEditingController(text: s?['code'] ?? s?['kode']);
    _nameController = TextEditingController(text: s?['name']);
    _descriptionController = TextEditingController(
      text: s?['description'] ?? s?['deskripsi'],
    );
    _isActive = s?['is_active'] ?? true;
    if (s != null && s['subject_id'] != null) {
      _selectedMasterSubjectId = int.tryParse(s['subject_id'].toString());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Validate, call API create/update, then close and notify parent.
  Future<void> _save(BuildContext ctx) async {
    final lang = ref.read(languageRiverpod);

    if (_codeController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            lang.getTranslatedText({
              'en': 'Code and name must be filled',
              'id': 'Kode dan nama harus diisi',
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'name': _nameController.text,
        'code': _codeController.text,
        'description': _descriptionController.text,
        'subject_id': _selectedMasterSubjectId,
        'is_active': _isActive,
      };

      if (widget.subject == null) {
        await getIt<ApiSubjectService>().addSubject(payload);
      } else {
        await getIt<ApiSubjectService>().updateSubject(
          widget.subject!['id'],
          payload,
        );
      }

      if (!ctx.mounted) return;

      setState(() => _isSaving = false);
      AppNavigator.pop(ctx);
      widget.onSaved(); // Tell the screen to reload – like $emit('saved')

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              lang.getTranslatedText({
                'en': 'Data saved successfully',
                'id': 'Data berhasil disimpan',
              }),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      AppLogger.error('subject', 'Save/Update subject error: $error');
      if (!mounted) return;
      setState(() => _isSaving = false);
      final lang2 = ref.read(languageRiverpod);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              '${lang2.getTranslatedText({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}'
              '${ErrorUtils.getFriendlyMessage(error)}',
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subject != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              buildHeader(
                context,
                isEditing ? 'edit' : 'add',
                isEditing ? 'edit' : 'add',
                isEditing,
              ),
              buildFormBody(context),
              buildFooterButtons(context),
            ],
          ),
        ),
      ),
    );
  }
}
