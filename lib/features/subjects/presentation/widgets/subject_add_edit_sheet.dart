// Bottom-sheet widget for creating or editing a single subject (mata pelajaran).
// Owns all form controllers, autocomplete state, active-status toggle, and
// the isSaving loading flag. Calls onSaved() on success so the screen reloads.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_dialog_text_field.dart';

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

class SubjectAddEditSheetState extends ConsumerState<SubjectAddEditSheet> {
  // Form controllers – like Vue's reactive `ref()` values
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  int? _selectedMasterSubjectId;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.subject;
    _codeController = TextEditingController(
      text: s?['code'] ?? s?['kode'],
    );
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
                'en': AppLocalizations.dataSavedSuccessfully.tr,
                'id': AppLocalizations.dataSavedSuccessfully.tr,
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
    final lang = ref.watch(languageRiverpod);
    final isEditing = widget.subject != null;

    return Padding(
      // Push sheet up when keyboard appears – like CSS safe-area-inset
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
              // ── Gradient header ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColorUtils.corporateBlue600,
                      ColorUtils.corporateBlue600.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? lang.getTranslatedText({
                                    'en': 'Edit Subject',
                                    'id': 'Edit Mata Pelajaran',
                                  })
                                : lang.getTranslatedText({
                                    'en': 'Add Subject',
                                    'id': 'Tambah Mata Pelajaran',
                                  }),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditing
                                ? lang.getTranslatedText({
                                    'en': 'Update subject information',
                                    'id': 'Perbarui informasi mata pelajaran',
                                  })
                                : lang.getTranslatedText({
                                    'en': 'Fill in subject details',
                                    'id': 'Isi detail mata pelajaran',
                                  }),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => AppNavigator.pop(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form body ────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subject code field
                      SubjectDialogTextField(
                        controller: _codeController,
                        label: lang.getTranslatedText({
                          'en': 'Code',
                          'id': 'Kode',
                        }),
                        icon: Icons.code,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Autocomplete to pick from master subject templates
                      Autocomplete<Map<String, dynamic>>(
                        initialValue: TextEditingValue(
                          text: () {
                            if (_selectedMasterSubjectId != null) {
                              final master = widget.availableMasterSubjects
                                  .firstWhere(
                                    (m) => m['id'] == _selectedMasterSubjectId,
                                    orElse: () => <String, dynamic>{},
                                  );
                              if ((master as Map).isNotEmpty) {
                                return master['name'] as String;
                              }
                            }
                            return _nameController.text;
                          }(),
                        ),
                        optionsBuilder: (TextEditingValue tv) {
                          if (tv.text.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          return widget.availableMasterSubjects
                              .cast<Map<String, dynamic>>()
                              .where(
                                (opt) => opt['name']
                                    .toString()
                                    .toLowerCase()
                                    .contains(tv.text.toLowerCase()),
                              );
                        },
                        displayStringForOption: (opt) => opt['name'],
                        onSelected: (selection) {
                          setState(() {
                            _nameController.text =
                                '${selection['name']} ${selection['grade']}';
                            _selectedMasterSubjectId = selection['id'];
                          });
                        },
                        fieldViewBuilder: (
                          ctx,
                          fieldController,
                          fieldFocusNode,
                          onFieldSubmitted,
                        ) {
                          return ValueListenableBuilder<TextEditingValue>(
                            valueListenable: fieldController,
                            builder: (ctx, value, _) {
                              return SubjectDialogTextField(
                                controller: fieldController,
                                focusNode: fieldFocusNode,
                                label: lang.getTranslatedText({
                                  'en': 'Select Subject',
                                  'id': 'Pilih Mata Pelajaran',
                                }),
                                icon: Icons.search,
                                suffixIcon: value.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            fieldController.clear();
                                            _selectedMasterSubjectId = null;
                                          });
                                        },
                                      )
                                    : null,
                              );
                            },
                          );
                        },
                        optionsViewBuilder: (ctx, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: SizedBox(
                                height: 200.0,
                                width: 300.0,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8.0),
                                  itemCount: options.length,
                                  itemBuilder: (ctx, index) {
                                    final opt = options.elementAt(index);
                                    return GestureDetector(
                                      onTap: () => onSelected(opt),
                                      child: ListTile(
                                        title: Text(opt['name']),
                                        subtitle:
                                            Text('Kelas ${opt['grade']}'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Subject name (free-text override or auto-filled above)
                      SubjectDialogTextField(
                        controller: _nameController,
                        label: lang.getTranslatedText({
                          'en': 'Subject Name',
                          'id': 'Nama Mata Pelajaran',
                        }),
                        icon: Icons.menu_book,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Description
                      SubjectDialogTextField(
                        controller: _descriptionController,
                        label: lang.getTranslatedText({
                          'en': 'Description',
                          'id': 'Deskripsi',
                        }),
                        icon: Icons.description,
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Active status toggle
                      Container(
                        decoration: BoxDecoration(
                          color: ColorUtils.slate50,
                          border: Border.all(color: ColorUtils.slate200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            lang.getTranslatedText({
                              'en': 'Active Status',
                              'id': 'Status Aktif',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: ColorUtils.slate700,
                            ),
                          ),
                          value: _isActive,
                          activeThumbColor: ColorUtils.corporateBlue600,
                          activeTrackColor: ColorUtils.corporateBlue600
                              .withValues(alpha: 0.3),
                          onChanged: (v) => setState(() => _isActive = v),
                          secondary: Icon(
                            Icons.check_circle_outline,
                            color: _isActive
                                ? ColorUtils.corporateBlue600
                                : ColorUtils.slate400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer buttons ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: ColorUtils.slate200),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.slate900.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => AppNavigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: ColorUtils.slate300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.cancel.tr,
                          style: TextStyle(
                            color: ColorUtils.slate700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () => _save(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.corporateBlue600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                AppLocalizations.save.tr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
