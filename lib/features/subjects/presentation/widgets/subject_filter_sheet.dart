import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

/// A modal bottom-sheet for filtering the subject list.
class SubjectFilterSheet extends ConsumerStatefulWidget {
  /// Current filter values passed in as initial state (like Vue props).
  final String? initialStatus;
  final String? initialClassStatus;
  final String? initialGradeLevel;
  final String? initialClassName;

  /// Dynamic lists populated from loaded subject data.
  final List<String> availableGradeLevels;
  final List<String> availableClassNames;

  /// Called with the four filter values when the user taps
  /// "Apply Filter". Pass null for a field to clear it.
  final void Function(
    String? status,
    String? classStatus,
    String? gradeLevel,
    String? className,
  )
  onApply;

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

  void _resetFilters() {
    setState(() {
      _tempStatus = null;
      _tempClassStatus = null;
      _tempGradeLevel = null;
      _tempClassName = null;
    });
  }

  void _applyFilters() {
    widget.onApply(
      _tempStatus,
      _tempClassStatus,
      _tempGradeLevel,
      _tempClassName,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final primaryColor = ColorUtils.getRoleColor('admin');

    return AppFilterBottomSheet(
      title: lang.getTranslatedText({
        'en': 'Filter Subjects',
        'id': 'Filter Mata Pelajaran',
      }),
      icon: Icons.tune_rounded,
      primaryColor: primaryColor,
      maxHeightFactor: 0.75,
      content: TeacherFilterContent(
        sections: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lang.getTranslatedText({'en': 'Status', 'id': 'Status'}),
                icon: Icons.check_circle_outline_rounded,
                primaryColor: primaryColor,
              ),
              FilterChipGrid<String?>(
                options: [
                  FilterOption(
                    value: 'Aktif',
                    label: lang.getTranslatedText({
                      'en': 'Active',
                      'id': 'Aktif',
                    }),
                  ),
                  FilterOption(
                    value: 'Non-Aktif',
                    label: lang.getTranslatedText({
                      'en': 'Inactive',
                      'id': 'Non-Aktif',
                    }),
                  ),
                ],
                selectedValue: _tempStatus,
                onSelected: (val) => setState(() => _tempStatus = val),
                selectedColor: primaryColor,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lang.getTranslatedText({
                  'en': 'Class Status',
                  'id': 'Status Kelas',
                }),
                icon: Icons.assignment_outlined,
                primaryColor: primaryColor,
              ),
              FilterChipGrid<String?>(
                options: [
                  FilterOption(
                    value: 'Mandatory',
                    label: lang.getTranslatedText({
                      'en': 'Mandatory',
                      'id': 'Wajib',
                    }),
                  ),
                  FilterOption(
                    value: 'Optional',
                    label: lang.getTranslatedText({
                      'en': 'Optional',
                      'id': 'Pilihan',
                    }),
                  ),
                ],
                selectedValue: _tempClassStatus,
                onSelected: (val) => setState(() => _tempClassStatus = val),
                selectedColor: primaryColor,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lang.getTranslatedText({
                  'en': 'Grade Level',
                  'id': 'Tingkat',
                }),
                icon: Icons.layers_outlined,
                primaryColor: primaryColor,
              ),
              FilterChipGrid<String?>(
                options: widget.availableGradeLevels
                    .map((g) => FilterOption(value: g, label: g))
                    .toList(),
                selectedValue: _tempGradeLevel,
                onSelected: (val) => setState(() => _tempGradeLevel = val),
                selectedColor: primaryColor,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lang.getTranslatedText({
                  'en': 'Class Name',
                  'id': 'Nama Kelas',
                }),
                icon: Icons.class_outlined,
                primaryColor: primaryColor,
              ),
              FilterChipGrid<String?>(
                options: widget.availableClassNames
                    .map((c) => FilterOption(value: c, label: c))
                    .toList(),
                selectedValue: _tempClassName,
                onSelected: (val) => setState(() => _tempClassName = val),
                selectedColor: primaryColor,
              ),
            ],
          ),
        ],
      ),
      onApply: _applyFilters,
      onReset: _resetFilters,
    );
  }
}
