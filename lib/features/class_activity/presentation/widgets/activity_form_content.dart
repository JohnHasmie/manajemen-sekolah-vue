import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_form_builder.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_material_selector.dart';

/// Widget for building the activity form content section
class ActivityFormContent extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final Color accentColor;
  final bool isAssignment;
  final bool useMaterialTitle;
  final String? selectedSubjectId;
  final String? selectedChapterId;
  final bool isLoadingChapters;
  final List<dynamic> chapters;
  final List<dynamic> subChapters;
  final List<String> selectedSubChapterIds;
  final DateTime? selectedDate;
  final DateTime? deadline;
  final String? selectedClassId;
  final String initialTarget;
  final List<dynamic> studentList;
  final List<String> selectedStudents;
  final bool isLoadingStudents;
  final LanguageProvider languageProvider;
  final String Function(dynamic) getChapterName;
  final String Function(dynamic) getSubChapterName;
  final Function(bool) onMaterialModeChanged;
  final Function(String) onChapterSelected;
  final Function(String, bool) onSubChapterToggled;
  final VoidCallback onShowDatePicker;
  final VoidCallback onShowDateTimePicker;
  final VoidCallback onClearDeadline;
  final VoidCallback onViewAllSubChapters;
  final VoidCallback onRefreshStudents;
  final Function(String, bool) onToggleStudent;

  const ActivityFormContent({
    super.key,
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.accentColor,
    required this.isAssignment,
    required this.useMaterialTitle,
    required this.selectedSubjectId,
    required this.selectedChapterId,
    required this.isLoadingChapters,
    required this.chapters,
    required this.subChapters,
    required this.selectedSubChapterIds,
    required this.selectedDate,
    required this.deadline,
    required this.selectedClassId,
    required this.initialTarget,
    required this.studentList,
    required this.selectedStudents,
    required this.isLoadingStudents,
    required this.languageProvider,
    required this.getChapterName,
    required this.getSubChapterName,
    required this.onMaterialModeChanged,
    required this.onChapterSelected,
    required this.onSubChapterToggled,
    required this.onShowDatePicker,
    required this.onShowDateTimePicker,
    required this.onClearDeadline,
    required this.onViewAllSubChapters,
    required this.onRefreshStudents,
    required this.onToggleStudent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              ActivityFormBuilder.buildSectionLabel(
                icon: Icons.auto_stories_rounded,
                label: 'Sumber Judul',
                color: accentColor,
              ),
              const SizedBox(height: 8),
              ActivityMaterialSelector(
                useMaterialTitle: useMaterialTitle,
                selectedSubjectId: selectedSubjectId,
                onMaterialModeToggle: () {},
                onMaterialModeChanged: onMaterialModeChanged,
              ),
              ActivityFormBuilder.buildMaterialSelectionSection(
                accentColor: accentColor,
                useMaterialTitle: useMaterialTitle,
                chapters: chapters,
                isLoadingChapters: isLoadingChapters,
                selectedChapterId: selectedChapterId,
                subChapters: subChapters,
                selectedSubChapterIds: selectedSubChapterIds,
                getChapterName: getChapterName,
                getSubChapterName: getSubChapterName,
                onChapterSelected: onChapterSelected,
                onSubChapterToggled: onSubChapterToggled,
                languageProvider: languageProvider,
                onViewAllPressed: onViewAllSubChapters,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: ColorUtils.slate100, height: 1),
              ),
              ActivityFormBuilder.buildTitleField(
                controller: titleController,
                accentColor: accentColor,
                isAssignment: isAssignment,
                useMaterialTitle: useMaterialTitle,
                selectedChapterId: selectedChapterId,
              ),
              const SizedBox(height: 10),
              ActivityFormBuilder.buildDescriptionField(
                controller: descriptionController,
                accentColor: accentColor,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: ColorUtils.slate100, height: 1),
              ),
              ActivityFormBuilder.buildDateCard(
                icon: Icons.calendar_today_rounded,
                iconColor: accentColor,
                label: 'Tanggal Kegiatan',
                value: selectedDate != null
                    ? ActivityFormBuilder.formatDate(selectedDate!)
                    : null,
                placeholder: 'Pilih tanggal',
                onTap: onShowDatePicker,
              ),
              if (isAssignment) ...[
                const SizedBox(height: 10),
                ActivityFormBuilder.buildDateCard(
                  icon: Icons.access_time_rounded,
                  iconColor: ColorUtils.warning600,
                  label: 'Batas Waktu',
                  value: deadline != null
                      ? ActivityFormBuilder.formatDateTime(deadline!)
                      : null,
                  placeholder: 'Belum ditentukan (opsional)',
                  onTap: onShowDateTimePicker,
                  onClear: deadline != null ? onClearDeadline : null,
                ),
              ],
              ActivityFormBuilder.buildStudentSelectorSection(
                studentList: studentList,
                selectedStudents: selectedStudents,
                isLoading: isLoadingStudents,
                initialTarget: initialTarget,
                selectedClassId: selectedClassId,
                languageProvider: languageProvider,
                onRefresh: onRefreshStudents,
                onToggleStudent: onToggleStudent,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
