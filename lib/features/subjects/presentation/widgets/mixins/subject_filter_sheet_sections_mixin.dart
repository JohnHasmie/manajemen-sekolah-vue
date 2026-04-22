import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_filter_section_header.dart';

/// Mixin providing filter sections building.
mixin SubjectFilterSheetSectionsMixin {
  /// Provides access to BuildContext.
  BuildContext get context;

  /// Provides access to ref for language translation.
  WidgetRef get ref;

  /// Provides access to setState.
  void setState(VoidCallback fn);

  /// Available grade levels list.
  List<String> getAvailableGradeLevels();

  /// Available class names list.
  List<String> getAvailableClassNames();

  /// Gets current temp status.
  String? getTempStatus();

  /// Sets temp status.
  void setTempStatus(String? value);

  /// Gets current temp class status.
  String? getTempClassStatus();

  /// Sets temp class status.
  void setTempClassStatus(String? value);

  /// Gets current temp grade level.
  String? getTempGradeLevel();

  /// Sets temp grade level.
  void setTempGradeLevel(String? value);

  /// Gets current temp class name.
  String? getTempClassName();

  /// Sets temp class name.
  void setTempClassName(String? value);

  /// Builds a single FilterChip row for a list of options.
  Widget _buildChipGroup({
    required List<Map<String, String>> options,
    required String? selected,
    required void Function(String? value) onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((item) {
        final isSelected = selected == item['value'];
        return FilterChip(
          label: Text(item['label']!),
          selected: isSelected,
          onSelected: (sel) =>
              setState(() => onChanged(sel ? item['value'] : null)),
          backgroundColor: Colors.white,
          selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
          checkmarkColor: ColorUtils.corporateBlue600,
          side: BorderSide(
            color: isSelected
                ? ColorUtils.corporateBlue600
                : ColorUtils.slate300,
            width: 1,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          labelStyle: TextStyle(
            color: isSelected
                ? ColorUtils.corporateBlue600
                : ColorUtils.slate700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }

  /// Builds a single grade level chip.
  FilterChip _buildGradeLevelChip(String gradeLevel, bool isSelected) {
    return FilterChip(
      label: Text('Kelas $gradeLevel'),
      selected: isSelected,
      onSelected: (sel) =>
          setState(() => setTempGradeLevel(sel ? gradeLevel : null)),
      backgroundColor: Colors.white,
      selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
      checkmarkColor: ColorUtils.corporateBlue600,
      side: BorderSide(
        color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
        width: 1,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: TextStyle(
        color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }

  /// Builds grade level filter chips.
  Widget _buildGradeLevelChips() {
    final gradeLevels = getAvailableGradeLevels().isEmpty
        ? List.generate(12, (i) => (i + 1).toString())
        : getAvailableGradeLevels();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: gradeLevels.map((gradeLevel) {
        final isSelected = getTempGradeLevel() == gradeLevel;
        return _buildGradeLevelChip(gradeLevel, isSelected);
      }).toList(),
    );
  }

  /// Builds a single class name chip.
  FilterChip _buildClassNameChip(String className, bool isSelected) {
    return FilterChip(
      label: Text(className),
      selected: isSelected,
      onSelected: (sel) =>
          setState(() => setTempClassName(sel ? className : null)),
      backgroundColor: Colors.white,
      selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
      checkmarkColor: ColorUtils.corporateBlue600,
      side: BorderSide(
        color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
        width: 1,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: TextStyle(
        color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }

  /// Builds class name filter chips.
  Widget _buildClassNameChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: getAvailableClassNames().map((className) {
        final isSelected = getTempClassName() == className;
        return _buildClassNameChip(className, isSelected);
      }).toList(),
    );
  }

  /// Builds status filter section.
  List<Widget> _buildStatusSection() {
    final lang = ref.watch(languageRiverpod);
    return [
      SubjectFilterSectionHeader(
        title: lang.getTranslatedText({'en': 'Status', 'id': 'Status'}),
        icon: Icons.circle_outlined,
      ),
      _buildChipGroup(
        options: [
          {
            'value': 'active',
            'label': lang.getTranslatedText({'en': 'Active', 'id': 'Aktif'}),
          },
          {
            'value': 'inactive',
            'label': lang.getTranslatedText({
              'en': 'Inactive',
              'id': 'Tidak Aktif',
            }),
          },
          {
            'value': 'all',
            'label': lang.getTranslatedText({'en': 'All', 'id': 'Semua'}),
          },
        ],
        selected: getTempStatus(),
        onChanged: setTempStatus,
      ),
    ];
  }

  /// Builds classes status filter section.
  List<Widget> _buildClassesStatusSection() {
    final lang = ref.watch(languageRiverpod);
    return [
      SubjectFilterSectionHeader(
        title: lang.getTranslatedText({
          'en': 'Classes Status',
          'id': 'Status Kelas',
        }),
        icon: Icons.class_outlined,
      ),
      _buildChipGroup(
        options: [
          {
            'value': 'ada',
            'label': lang.getTranslatedText({
              'en': 'Has Classes',
              'id': 'Ada Kelas',
            }),
          },
          {
            'value': 'tidak_ada',
            'label': lang.getTranslatedText({
              'en': 'No Classes',
              'id': 'Tidak Ada Kelas',
            }),
          },
        ],
        selected: getTempClassStatus(),
        onChanged: setTempClassStatus,
      ),
    ];
  }

  /// Builds grade level filter section.
  List<Widget> _buildGradeLevelSection() {
    final lang = ref.watch(languageRiverpod);
    return [
      SubjectFilterSectionHeader(
        title: lang.getTranslatedText({
          'en': 'Grade Level',
          'id': 'Tingkat Kelas',
        }),
        icon: Icons.layers_outlined,
      ),
      _buildGradeLevelChips(),
    ];
  }

  /// Builds class name filter section if available.
  List<Widget> _buildClassNameSection() {
    final lang = ref.watch(languageRiverpod);
    if (getAvailableClassNames().isEmpty) return [];
    return [
      SubjectFilterSectionHeader(
        title: lang.getTranslatedText({'en': 'Class Name', 'id': 'Nama Kelas'}),
        icon: Icons.school_outlined,
      ),
      _buildClassNameChips(),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  /// Builds the entire filter sections widget.
  Widget buildFilterSections() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._buildStatusSection(),
            ..._buildClassesStatusSection(),
            ..._buildGradeLevelSection(),
            ..._buildClassNameSection(),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
