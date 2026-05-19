import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';
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
        ],
      ),
    );
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
