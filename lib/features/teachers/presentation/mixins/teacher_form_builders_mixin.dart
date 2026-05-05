import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';
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

  /// "Ganti akun wali" toggle — uses the shared [AdminFormToggle] in
  /// warning tone since toggling on flips the save behaviour from "update
  /// current user" to "link to a different user".
  Widget buildChangeUserSwitch(LanguageProvider languageProvider) {
    return AdminFormToggle(
      tone: AdminToggleTone.warning,
      title: languageProvider.getTranslatedText({
        'en': 'Change linked account',
        'id': 'Ganti akun terkait',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en':
            'Link this teacher to a different user account based on the '
            'email below.',
        'id':
            'Pindahkan guru ini ke akun lain berdasarkan email di bawah.',
      }),
      value: isChangeUserMode,
      onChanged: (val) => setState(() => isChangeUserMode = val),
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

  /// Multi-select chip pills for the teacher's subjects (Mata Pelajaran).
  /// Replaces the old checkbox list — selected chips fill admin navy /
  /// white text, unselected stay white / slate border. Wrap layout flows
  /// across rows so the form stays compact even with many subjects.
  Widget buildSubjectsSection(LanguageProvider languageProvider) {
    final adminNavy = ColorUtils.getRoleColor('admin');
    final models = widget.subjects
        .map((subject) => Subject.fromJson(subject as Map<String, dynamic>))
        .where((model) => model.id.isNotEmpty && model.name.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Subjects',
                  'id': 'Mata Pelajaran',
                }),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
              const SizedBox(width: 6),
              if (selectedSubjectIds.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: adminNavy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${selectedSubjectIds.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: adminNavy,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: models
              .map((m) => _SubjectChip(
                    label: m.name,
                    selected: selectedSubjectIds.contains(m.id),
                    accent: adminNavy,
                    onTap: () => _toggleSubject(m, !selectedSubjectIds.contains(m.id)),
                  ))
              .toList(),
        ),
      ],
    );
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

  /// Homeroom class — wrap of selectable chips. Single-select; tapping
  /// the active chip again clears it (same affordance as Employment
  /// Status). The label includes a small "(Opsional)" hint and a count
  /// badge once a class is picked.
  Widget buildHomeroomClassDropdown(LanguageProvider languageProvider) {
    final adminNavy = ColorUtils.getRoleColor('admin');
    final classes = widget.classes
        .where((c) => c['id'] != null && c['name'] != null)
        .fold<Map<String, Map<String, dynamic>>>({}, (map, item) {
          map[item['id'].toString()] = item;
          return map;
        })
        .values
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Homeroom Class',
                  'id': 'Wali Kelas',
                }),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                languageProvider.getTranslatedText({
                  'en': '(Optional)',
                  'id': '(Opsional)',
                }),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate500,
                ),
              ),
            ],
          ),
        ),
        if (classes.isEmpty)
          Text(
            languageProvider.getTranslatedText({
              'en': 'No classes available',
              'id': 'Belum ada kelas',
            }),
            style: TextStyle(
              fontSize: 11.5,
              color: ColorUtils.slate500,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: classes.map((c) {
              final id = c['id'].toString();
              final name = (c['name'] ?? '').toString();
              final isSelected =
                  selectedWaliKelasId != null && selectedWaliKelasId == id;
              return _SubjectChip(
                label: name,
                selected: isSelected,
                accent: adminNavy,
                onTap: () => setState(
                  () => selectedWaliKelasId = isSelected ? '' : id,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ignore: unused_element
  List<DropdownMenuItem<String>> _legacyClassItems(
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

  /// Employment-status chip selector. Three values + an implicit "none"
  /// state when nothing is selected (chip can be tapped again to clear).
  Widget buildEmploymentStatusDropdown(LanguageProvider languageProvider) {
    String t(Map<String, String> m) => languageProvider.getTranslatedText(m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFormFieldLabel(
          text: t(const {
            'en': 'Employment Status',
            'id': 'Status Kepegawaian',
          }),
        ),
        AdminFormChoiceChips<String?>(
          value: selectedStatus,
          onChanged: (v) =>
              setState(() => selectedStatus = (selectedStatus == v) ? null : v),
          choices: [
            AdminFormChoice(
              value: 'permanent',
              label: t(const {'en': 'Permanent', 'id': 'Tetap'}),
              icon: Icons.workspace_premium_rounded,
            ),
            AdminFormChoice(
              value: 'contract',
              label: t(const {'en': 'Contract', 'id': 'Kontrak'}),
              icon: Icons.assignment_rounded,
            ),
            AdminFormChoice(
              value: 'temporary',
              label: t(const {'en': 'Honorary', 'id': 'Honor'}),
              icon: Icons.schedule_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

/// Single subject pill — used by [buildSubjectsSection]. Solid-fill
/// admin navy when selected, bordered slate when not.
class _SubjectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : ColorUtils.slate700;
    final bg = selected ? accent : Colors.white;
    final border = selected ? accent : ColorUtils.slate200;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: selected ? 1.4 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
