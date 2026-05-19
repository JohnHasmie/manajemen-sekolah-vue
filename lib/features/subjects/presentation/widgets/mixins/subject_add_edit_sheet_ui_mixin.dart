import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_add_edit_sheet.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_dialog_text_field.dart';

mixin SubjectAddEditSheetUiMixin on ConsumerState<SubjectAddEditSheet> {
  // Abstract accessors for state fields.
  TextEditingController get codeController;
  TextEditingController get nameController;
  TextEditingController get descriptionController;
  int? get selectedMasterSubjectId;
  set selectedMasterSubjectId(int? value);
  bool get isActive;
  set isActive(bool value);

  /// Build the main form body — sectioned into Data Pokok / Status.
  Widget buildFormBody(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        4,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminFormSection(
            label: lang.getTranslatedText({
              'en': 'BASIC DATA',
              'id': 'DATA POKOK',
            }),
            children: [
              _buildCodeField(lang),
              _buildMasterSubjectAutocomplete(lang),
              _buildNameField(lang),
              _buildDescriptionField(lang),
            ],
          ),
          AdminFormSection(
            label: lang.getTranslatedText({'en': 'STATUS', 'id': 'STATUS'}),
            bottomGap: 4,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdminFormFieldLabel(
                    text: lang.getTranslatedText({
                      'en': 'Active status',
                      'id': 'Status aktif',
                    }),
                  ),
                  AdminFormChoiceChips<bool>(
                    value: isActive,
                    onChanged: (v) => setState(() => isActive = v),
                    choices: [
                      AdminFormChoice(
                        value: true,
                        label: lang.getTranslatedText({
                          'en': 'Active',
                          'id': 'Aktif',
                        }),
                        icon: Icons.check_circle_rounded,
                      ),
                      AdminFormChoice(
                        value: false,
                        label: lang.getTranslatedText({
                          'en': 'Inactive',
                          'id': 'Nonaktif',
                        }),
                        icon: Icons.cancel_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (widget.subject != null) _buildDangerZone(context),
        ],
      ),
    );
  }

  /// Build the "Zona Berbahaya" block that appears in edit mode.
  ///
  /// Two affordances stacked vertically:
  ///   • Nonaktifkan (soft) — toggles `is_active = false`. Disappears
  ///     from current+future AY views; past AY records (grades,
  ///     attendance, RPP) are preserved because they reference the
  ///     subject_school_id, not the active flag.
  ///   • Hapus permanen     — calls the destructive delete endpoint.
  ///     We don't probe wired-data availability from this sheet (no
  ///     endpoint for it yet); the backend's foreign-key cascade
  ///     handles the safety check. If wired data exists the call
  ///     fails 422 and we show the message verbatim.
  Widget _buildDangerZone(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final danger = ColorUtils.error600;
    return AdminFormSection(
      label: lang.getTranslatedText({
        'en': 'DANGER ZONE',
        'id': 'ZONA BERBAHAYA',
      }),
      bottomGap: 4,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DangerRow(
              icon: Icons.visibility_off_outlined,
              title: lang.getTranslatedText({
                'en': 'Hide from current and future year',
                'id': 'Hapus dari tahun ini dan seterusnya',
              }),
              subtitle: lang.getTranslatedText({
                'en':
                    'Mark inactive — past-year records stay intact, but new lists won\'t show this subject.',
                'id':
                    'Tandai nonaktif — riwayat tahun lampau tetap tersimpan, tapi daftar baru tidak menampilkan mapel ini.',
              }),
              accent: ColorUtils.warning600,
              onTap: () => _confirmSoftDelete(context),
              enabled: isActive,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DangerRow(
              icon: Icons.delete_outline_rounded,
              title: lang.getTranslatedText({
                'en': 'Delete permanently',
                'id': 'Hapus permanen',
              }),
              subtitle: lang.getTranslatedText({
                'en':
                    'Removes the subject from the database. Blocked when wired to grades / RPP / attendance.',
                'id':
                    'Hapus mapel dari database. Akan ditolak jika sudah dipakai pada nilai / RPP / kehadiran.',
              }),
              accent: danger,
              onTap: () => _confirmHardDelete(context),
            ),
          ],
        ),
      ],
    );
  }

  /// Soft-delete: PATCH is_active=false then close. Uses the existing
  /// updateSubject endpoint so no backend change is required.
  Future<void> _confirmSoftDelete(BuildContext context) async {
    final lang = ref.read(languageRiverpod);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: lang.getTranslatedText({
          'en': 'Hide subject?',
          'id': 'Sembunyikan mapel?',
        }),
        content: lang.getTranslatedText({
          'en':
              'The subject will be hidden from this year and future years. Past-year records stay accessible.',
          'id':
              'Mapel akan disembunyikan dari tahun ini dan seterusnya. Riwayat tahun lampau tetap dapat diakses.',
        }),
        confirmColor: ColorUtils.warning600,
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await getIt<ApiSubjectService>().updateSubject(
        widget.subject!['id'].toString(),
        {...?widget.subject, 'is_active': false},
      );
      if (!context.mounted) return;
      AppNavigator.pop(context);
      widget.onSaved();
      SnackBarUtils.showSuccess(
        context,
        lang.getTranslatedText({
          'en': 'Subject hidden from current and future years',
          'id': 'Mapel disembunyikan dari tahun ini dan seterusnya',
        }),
      );
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        '${lang.getTranslatedText({'en': 'Failed: ', 'id': 'Gagal: '})}$e',
      );
    }
  }

  /// Hard-delete: calls the existing destroy endpoint. The backend
  /// returns 422 if the subject is referenced elsewhere; we surface
  /// the message verbatim so admin knows which data to clean up first.
  Future<void> _confirmHardDelete(BuildContext context) async {
    final lang = ref.read(languageRiverpod);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: lang.getTranslatedText({
          'en': 'Delete subject permanently?',
          'id': 'Hapus mapel permanen?',
        }),
        content: lang.getTranslatedText({
          'en':
              'This cannot be undone. If the subject is referenced by grades / RPP / attendance the deletion will be rejected.',
          'id':
              'Tindakan ini tidak bisa dibatalkan. Jika mapel masih dipakai pada nilai / RPP / kehadiran, penghapusan akan ditolak.',
        }),
        confirmColor: ColorUtils.error600,
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await getIt<ApiSubjectService>().deleteSubject(
        widget.subject!['id'].toString(),
      );
      if (!context.mounted) return;
      AppNavigator.pop(context);
      widget.onSaved();
      SnackBarUtils.showSuccess(
        context,
        lang.getTranslatedText({
          'en': 'Subject deleted',
          'id': 'Mapel berhasil dihapus',
        }),
      );
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        '${lang.getTranslatedText({'en': 'Cannot delete: ', 'id': 'Tidak bisa hapus: '})}$e',
      );
    }
  }

  /// Code input field
  Widget _buildCodeField(dynamic lang) {
    return SubjectDialogTextField(
      controller: codeController,
      label: lang.getTranslatedText({'en': 'Code', 'id': 'Kode'}),
      icon: Icons.code,
    );
  }

  /// Master subject autocomplete picker
  Widget _buildMasterSubjectAutocomplete(dynamic lang) {
    return Autocomplete<Map<String, dynamic>>(
      initialValue: TextEditingValue(text: _getMasterSubjectInitialValue()),
      optionsBuilder: _buildAutocompleteOptions,
      displayStringForOption: (opt) => opt['name'],
      onSelected: (selection) {
        setState(() {
          nameController.text = '${selection['name']} ${selection['grade']}';
          selectedMasterSubjectId = selection['id'];
        });
      },
      fieldViewBuilder:
          (ctx, fieldController, fieldFocusNode, onFieldSubmitted) {
            return _buildAutocompleteField(
              lang,
              fieldController,
              fieldFocusNode,
            );
          },
      optionsViewBuilder: (ctx, onSelected, options) {
        return _buildAutocompleteDropdown(onSelected, options);
      },
    );
  }

  /// Build autocomplete field with clear button
  Widget _buildAutocompleteField(
    dynamic lang,
    TextEditingController fieldController,
    FocusNode fieldFocusNode,
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
          suffixIcon: value.text.isNotEmpty ? _buildClearButton() : null,
        );
      },
    );
  }

  /// Clear button for autocomplete field
  Widget _buildClearButton() {
    return IconButton(
      icon: const Icon(Icons.clear, size: 18),
      onPressed: () {
        setState(() {
          // Assuming fieldController is accessible
          // This handles clearing the selection
          selectedMasterSubjectId = null;
        });
      },
    );
  }

  /// Build autocomplete options list
  Iterable<Map<String, dynamic>> _buildAutocompleteOptions(
    TextEditingValue tv,
  ) {
    if (tv.text.isEmpty) {
      return const Iterable<Map<String, dynamic>>.empty();
    }
    return widget.availableMasterSubjects.cast<Map<String, dynamic>>().where(
      (opt) =>
          opt['name'].toString().toLowerCase().contains(tv.text.toLowerCase()),
    );
  }

  /// Build dropdown list for autocomplete options
  Widget _buildAutocompleteDropdown(
    Function(Map<String, dynamic>) onSelected,
    Iterable<Map<String, dynamic>> options,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        child: _buildDropdownListView(onSelected, options),
      ),
    );
  }

  /// Dropdown list view
  Widget _buildDropdownListView(
    Function(Map<String, dynamic>) onSelected,
    Iterable<Map<String, dynamic>> options,
  ) {
    return SizedBox(
      height: 200.0,
      width: 300.0,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: options.length,
        itemBuilder: (ctx, index) {
          final opt = options.elementAt(index);
          return _buildDropdownItem(onSelected, opt);
        },
      ),
    );
  }

  /// Single dropdown item
  Widget _buildDropdownItem(
    Function(Map<String, dynamic>) onSelected,
    Map<String, dynamic> opt,
  ) {
    return GestureDetector(
      onTap: () => onSelected(opt),
      child: ListTile(
        title: Text(opt['name']),
        subtitle: Text('Kelas ${opt['grade']}'),
      ),
    );
  }

  /// Get initial value for master subject field
  String _getMasterSubjectInitialValue() {
    if (selectedMasterSubjectId != null) {
      final master = widget.availableMasterSubjects.firstWhere(
        (m) => m['id'] == selectedMasterSubjectId,
        orElse: () => <String, dynamic>{},
      );
      if ((master as Map).isNotEmpty) {
        return master['name'] as String;
      }
    }
    return nameController.text;
  }

  /// Subject name field
  Widget _buildNameField(dynamic lang) {
    return SubjectDialogTextField(
      controller: nameController,
      label: lang.getTranslatedText({
        'en': 'Subject Name',
        'id': 'Nama Mata Pelajaran',
      }),
      icon: Icons.menu_book,
    );
  }

  /// Description field
  Widget _buildDescriptionField(dynamic lang) {
    return SubjectDialogTextField(
      controller: descriptionController,
      label: lang.getTranslatedText({'en': 'Description', 'id': 'Deskripsi'}),
      icon: Icons.description,
      maxLines: 3,
    );
  }
}

/// One destructive-action row inside the Zona Berbahaya section.
/// Tinted card with an icon + title + subtitle and a right-trailing
/// arrow. When `enabled` is false (e.g. soft-deactivate on an already
/// inactive subject) the row dims to slate so admin doesn't think it
/// can be tapped.
class _DangerRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool enabled;

  const _DangerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? accent : ColorUtils.slate400;
    final bg = enabled
        ? accent.withValues(alpha: 0.06)
        : ColorUtils.slate100.withValues(alpha: 0.6);
    final border = enabled
        ? accent.withValues(alpha: 0.25)
        : ColorUtils.slate200;

    return Material(
      color: bg,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: enabled
                            ? ColorUtils.slate600
                            : ColorUtils.slate400,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
