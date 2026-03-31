// Bottom-sheet widget for filtering subjects by status, class status,
// grade level, and class name. Owns all temporary selection state internally
// and calls onApply(status, classStatus, gradeLevel, className) on confirm.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_filter_section_header.dart';

/// A modal bottom-sheet for filtering the subject list.
///
/// Like a Vue component with its own reactive data:
/// temp* variables mirror the current filter state while the user is editing.
/// Only committed to the parent when the user taps "Apply Filter".
class SubjectFilterSheet extends ConsumerStatefulWidget {
  /// Current filter values passed in as initial state (like Vue props).
  final String? initialStatus;
  final String? initialClassStatus;
  final String? initialGradeLevel;
  final String? initialClassName;

  /// Dynamic lists populated from loaded subject data.
  final List<String> availableGradeLevels;
  final List<String> availableClassNames;

  /// Called with the four filter values when the user taps "Apply Filter".
  /// Pass null for a field to clear it.
  final void Function(
    String? status,
    String? classStatus,
    String? gradeLevel,
    String? className,
  ) onApply;

  const SubjectFilterSheet({
    super.key,
    this.initialStatus,
    this.initialClassStatus,
    this.initialGradeLevel,
    this.initialClassName,
    required this.availableGradeLevels,
    required this.availableClassNames,
    required this.onApply,
  });

  @override
  SubjectFilterSheetState createState() => SubjectFilterSheetState();
}

class SubjectFilterSheetState extends ConsumerState<SubjectFilterSheet> {
  // Temp state – like Vue data() holding working copies of the filter props
  late String? _tempStatus;
  late String? _tempClassStatus;
  late String? _tempGradeLevel;
  late String? _tempClassName;

  @override
  void initState() {
    super.initState();
    _tempStatus = widget.initialStatus;
    _tempClassStatus = widget.initialClassStatus;
    _tempGradeLevel = widget.initialGradeLevel;
    _tempClassName = widget.initialClassName;
  }

  /// Helper that builds a single FilterChip row for a list of options.
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
          onSelected: (sel) => setState(
            () => onChanged(sel ? item['value'] : null),
          ),
          backgroundColor: Colors.white,
          selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
          checkmarkColor: ColorUtils.corporateBlue600,
          side: BorderSide(
            color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          labelStyle: TextStyle(
            color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Gradient header ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.corporateBlue600,
                    ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Icon(
                      Icons.filter_list,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      lang.getTranslatedText({
                        'en': 'Filter Subjects',
                        'id': 'Filter Mata Pelajaran',
                      }),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _tempStatus = null;
                      _tempClassStatus = null;
                      _tempGradeLevel = null;
                      _tempClassName = null;
                    }),
                    child: Text(
                      lang.getTranslatedText({'en': 'Reset', 'id': 'Reset'}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable filter sections ─────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status filter
                    SubjectFilterSectionHeader(
                      title: lang.getTranslatedText({
                        'en': 'Status',
                        'id': 'Status',
                      }),
                      icon: Icons.circle_outlined,
                    ),
                    _buildChipGroup(
                      options: [
                        {
                          'value': 'active',
                          'label': lang.getTranslatedText({
                            'en': 'Active',
                            'id': 'Aktif',
                          }),
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
                          'label': lang.getTranslatedText({
                            'en': 'All',
                            'id': 'Semua',
                          }),
                        },
                      ],
                      selected: _tempStatus,
                      onChanged: (v) => _tempStatus = v,
                    ),

                    // Classes status filter
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
                      selected: _tempClassStatus,
                      onChanged: (v) => _tempClassStatus = v,
                    ),

                    // Grade level filter
                    SubjectFilterSectionHeader(
                      title: lang.getTranslatedText({
                        'en': 'Grade Level',
                        'id': 'Tingkat Kelas',
                      }),
                      icon: Icons.layers_outlined,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (widget.availableGradeLevels.isEmpty
                              ? List.generate(12, (i) => (i + 1).toString())
                              : widget.availableGradeLevels)
                          .map((gradeLevel) {
                        final isSelected = _tempGradeLevel == gradeLevel;
                        return FilterChip(
                          label: Text('Kelas $gradeLevel'),
                          selected: isSelected,
                          onSelected: (sel) => setState(
                            () => _tempGradeLevel = sel ? gradeLevel : null,
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: ColorUtils.corporateBlue600
                              .withValues(alpha: 0.12),
                          checkmarkColor: ColorUtils.corporateBlue600,
                          side: BorderSide(
                            color: isSelected
                                ? ColorUtils.corporateBlue600
                                : ColorUtils.slate300,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? ColorUtils.corporateBlue600
                                : ColorUtils.slate700,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        );
                      }).toList(),
                    ),

                    // Class name filter (only shown when data is available)
                    if (widget.availableClassNames.isNotEmpty) ...[
                      SubjectFilterSectionHeader(
                        title: lang.getTranslatedText({
                          'en': 'Class Name',
                          'id': 'Nama Kelas',
                        }),
                        icon: Icons.school_outlined,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.availableClassNames.map((className) {
                          final isSelected = _tempClassName == className;
                          return FilterChip(
                            label: Text(className),
                            selected: isSelected,
                            onSelected: (sel) => setState(
                              () => _tempClassName = sel ? className : null,
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: ColorUtils.corporateBlue600
                                .withValues(alpha: 0.12),
                            checkmarkColor: ColorUtils.corporateBlue600,
                            side: BorderSide(
                              color: isSelected
                                  ? ColorUtils.corporateBlue600
                                  : ColorUtils.slate300,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(10)),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? ColorUtils.corporateBlue600
                                  : ColorUtils.slate700,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),

            // ── Footer buttons ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: ColorUtils.slate100)),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.slate900.withValues(alpha: 0.06),
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
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      child: Text(
                        lang.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(
                          color: ColorUtils.slate600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Commit values to parent then close – like emitting a Vue event
                        widget.onApply(
                          _tempStatus,
                          _tempClassStatus,
                          _tempGradeLevel,
                          _tempClassName,
                        );
                        AppNavigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: ColorUtils.corporateBlue600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        lang.getTranslatedText({
                          'en': 'Apply Filter',
                          'id': 'Terapkan Filter',
                        }),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
