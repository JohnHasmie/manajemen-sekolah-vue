import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_form_ui_mixin.dart';

/// Builds individual form field widgets for teacher form
mixin TeacherFormBuildersMixin on TeacherFormUiMixin {
  // These fields are declared and initialized in TeacherFormInitMixin.
  // Using `abstract` avoids creating a new storage slot that would shadow
  // the initialized values and cause LateInitializationError.
  abstract TextEditingController nameController;
  abstract TextEditingController emailController;
  abstract TextEditingController nipController;
  abstract String? selectedGender;
  abstract String? selectedWaliKelasId;
  abstract String? selectedStatus;
  abstract List<String> selectedSubjectIds;
  abstract List<String> selectedClassIds;
  abstract bool isChangeUserMode;

  Widget buildNameField(LanguageProvider languageProvider) {
    return buildDialogTextField(
      controller: nameController,
      label: languageProvider.getTranslatedText({
        'en': 'Teacher Name',
        'id': 'Nama Guru',
      }),
      icon: Icons.person,
    );
  }

  Widget buildChangeUserSwitch(LanguageProvider languageProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ColorUtils.warning600.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.warning600.withValues(alpha: 0.2)),
      ),
      child: SwitchListTile(
        title: _buildChangeUserTitle(languageProvider),
        subtitle: _buildChangeUserSubtitle(languageProvider),
        value: isChangeUserMode,
        activeThumbColor: ColorUtils.warning600,
        onChanged: (val) {
          setState(() {
            isChangeUserMode = val;
          });
        },
      ),
    );
  }

  Widget _buildChangeUserTitle(LanguageProvider languageProvider) {
    return Text(
      languageProvider.getTranslatedText({
        'en': 'Use Another User / Change Account',
        'id': 'Ganti Akun / Gunakan User Lain',
      }),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: ColorUtils.warning600,
      ),
    );
  }

  Widget _buildChangeUserSubtitle(LanguageProvider languageProvider) {
    return Text(
      languageProvider.getTranslatedText({
        'en':
            'Link this teacher to a different user account based on the '
            'email below (does not edit the current linked user).',
        'id':
            'Pindahkan guru ini ke akun user lain berdasarkan email di '
            'bawah (tidak merubah data user saat ini).',
      }),
      style: TextStyle(fontSize: 11, color: ColorUtils.slate600),
    );
  }

  Widget buildEmailField(LanguageProvider languageProvider) {
    return buildDialogTextField(
      controller: emailController,
      label: languageProvider.getTranslatedText({'en': 'Email', 'id': 'Email'}),
      icon: Icons.email,
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget buildNipField() {
    return buildDialogTextField(
      controller: nipController,
      label: 'NIP',
      icon: Icons.badge,
    );
  }

  Widget buildGenderDropdown(LanguageProvider languageProvider) {
    return buildDialogDropdown(
      value: selectedGender,
      label: languageProvider.getTranslatedText({
        'en': 'Gender*',
        'id': 'Jenis Kelamin*',
      }),
      icon: Icons.person_outline,
      items: _buildGenderMenuItems(languageProvider),
      onChanged: (value) {
        setState(() => selectedGender = value);
      },
    );
  }

  List<DropdownMenuItem<String>> _buildGenderMenuItems(
    LanguageProvider languageProvider,
  ) {
    return [
      DropdownMenuItem(
        value: 'L',
        child: Text(
          languageProvider.getTranslatedText({'en': 'Male', 'id': 'Laki-laki'}),
        ),
      ),
      DropdownMenuItem(
        value: 'P',
        child: Text(
          languageProvider.getTranslatedText({
            'en': 'Female',
            'id': 'Perempuan',
          }),
        ),
      ),
    ];
  }

  Widget buildSubjectsSection(LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(languageProvider),
          const SizedBox(height: AppSpacing.sm),
          ..._buildSubjectCheckboxes(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(LanguageProvider languageProvider) {
    return Text(
      languageProvider.getTranslatedText({
        'en': 'Subjects:',
        'id': 'Mata Pelajaran:',
      }),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  List<Widget> _buildSubjectCheckboxes() {
    return widget.subjects
        .map((subject) => Subject.fromJson(subject as Map<String, dynamic>))
        .where((model) => model.id.isNotEmpty && model.name.isNotEmpty)
        .map(
          (model) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(model.name, style: const TextStyle(fontSize: 14)),
            value: selectedSubjectIds.contains(model.id),
            onChanged: (value) => _toggleSubject(model, value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        )
        .toList();
  }

  void _toggleSubject(Subject subject, bool? value) {
    final subjectId = subject.id;
    if (subjectId.isEmpty) return;

    setState(() {
      if (value == true) {
        selectedSubjectIds.add(subjectId);
      } else {
        selectedSubjectIds.remove(subjectId);
      }
    });
  }

  Widget buildHomeroomClassDropdown(LanguageProvider languageProvider) {
    return buildDialogDropdown(
      value: selectedWaliKelasId,
      label: languageProvider.getTranslatedText({
        'en': 'Homeroom Class (Optional)',
        'id': 'Wali Kelas (Opsional)',
      }),
      icon: Icons.class_,
      items: _buildClassItems(languageProvider),
      onChanged: (value) {
        setState(() => selectedWaliKelasId = value);
      },
    );
  }

  List<DropdownMenuItem<String>> _buildClassItems(
    LanguageProvider languageProvider,
  ) {
    final noneItem = DropdownMenuItem<String>(
      value: '',
      child: Text(
        languageProvider.getTranslatedText({'en': 'None', 'id': 'Tidak ada'}),
      ),
    );
    return [noneItem, ..._getClassMenuItems()];
  }

  List<DropdownMenuItem<String>> _getClassMenuItems() {
    return widget.classes
        .where((c) => c['id'] != null && c['name'] != null)
        .fold<Map<String, Map<String, dynamic>>>({}, (map, item) {
          map[item['id'].toString()] = item;
          return map;
        })
        .values
        .map(
          (item) => DropdownMenuItem<String>(
            value: item['id'].toString(),
            child: Text(item['name']?.toString() ?? 'Unknown Class'),
          ),
        )
        .toList();
  }

  Widget buildEmploymentStatusDropdown(LanguageProvider languageProvider) {
    return buildDialogDropdown(
      value: selectedStatus,
      label: languageProvider.getTranslatedText({
        'en': 'Employment Status (Optional)',
        'id': 'Status Kepegawaian (Opsional)',
      }),
      icon: Icons.work_outline,
      items: _buildStatusItems(languageProvider),
      onChanged: (value) {
        setState(() => selectedStatus = value);
      },
    );
  }

  List<DropdownMenuItem<String>> _buildStatusItems(
    LanguageProvider languageProvider,
  ) {
    return [
      _buildStatusMenuItem(null, 'None', 'Tidak ada', languageProvider),
      _buildStatusMenuItem('permanent', 'Permanent', 'Tetap', languageProvider),
      _buildStatusMenuItem('contract', 'Contract', 'Kontrak', languageProvider),
      _buildStatusMenuItem(
        'temporary',
        'Temporary/Honorary',
        'Honor',
        languageProvider,
      ),
    ];
  }

  DropdownMenuItem<String> _buildStatusMenuItem(
    String? value,
    String enText,
    String idText,
    LanguageProvider languageProvider,
  ) {
    return DropdownMenuItem(
      value: value,
      child: Text(
        languageProvider.getTranslatedText({'en': enText, 'id': idText}),
      ),
    );
  }
}
