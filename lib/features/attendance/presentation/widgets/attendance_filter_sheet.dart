import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

/// Result data from the attendance filter.
class AttendanceFilterResult {
  final String? dateRange;
  final String? classId;
  final String? subjectId;

  const AttendanceFilterResult({
    this.dateRange,
    this.classId,
    this.subjectId,
  });
}

/// A premium bottom sheet for filtering attendance records.
class AttendanceFilterSheet extends ConsumerStatefulWidget {
  final Color primaryColor;
  final String? initialDateRange;
  final String? initialClassId;
  final String? initialSubjectId;
  final List<dynamic> classList;
  final List<dynamic> subjectList;
  final void Function(AttendanceFilterResult result) onApply;

  const AttendanceFilterSheet({
    super.key,
    required this.primaryColor,
    this.initialDateRange,
    this.initialClassId,
    this.initialSubjectId,
    required this.classList,
    required this.subjectList,
    required this.onApply,
  });

  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required Color primaryColor,
    String? initialDateRange,
    String? initialClassId,
    String? initialSubjectId,
    required List<dynamic> classList,
    required List<dynamic> subjectList,
    required void Function(AttendanceFilterResult result) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AttendanceFilterSheet(
        primaryColor: primaryColor,
        initialDateRange: initialDateRange,
        initialClassId: initialClassId,
        initialSubjectId: initialSubjectId,
        classList: classList,
        subjectList: subjectList,
        onApply: onApply,
      ),
    );
  }

  @override
  ConsumerState<AttendanceFilterSheet> createState() => _AttendanceFilterSheetState();
}

class _AttendanceFilterSheetState extends ConsumerState<AttendanceFilterSheet> {
  late String? _tempDateRange;
  late String? _tempClassId;
  late String? _tempSubjectId;

  @override
  void initState() {
    super.initState();
    _tempDateRange = widget.initialDateRange;
    _tempClassId = widget.initialClassId;
    _tempSubjectId = widget.initialSubjectId;
  }

  @override
  Widget build(BuildContext context) {
    final lp = ref.read(languageRiverpod);

    return AppFilterBottomSheet(
      title: lp.getTranslatedText({'en': 'Filter Attendance', 'id': 'Filter Presensi'}),
      icon: Icons.tune_rounded,
      primaryColor: widget.primaryColor,
      onApply: () {
        Navigator.pop(context);
        widget.onApply(AttendanceFilterResult(
          dateRange: _tempDateRange,
          classId: _tempClassId,
          subjectId: _tempSubjectId,
        ));
      },
      onReset: () {
        setState(() {
          _tempDateRange = null;
          _tempClassId = null;
          _tempSubjectId = null;
        });
      },
      content: TeacherFilterContent(
        sections: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
                icon: Icons.class_outlined,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String>(
                options: widget.classList.map((c) {
                  final model = Classroom.fromJson(c as Map<String, dynamic>);
                  return FilterOption(value: model.id, label: model.name);
                }).toList(),
                selectedValue: _tempClassId,
                onSelected: (val) => setState(() => _tempClassId = val),
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lp.getTranslatedText({'en': 'Subject', 'id': 'Mapel'}),
                icon: Icons.book_outlined,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String>(
                options: widget.subjectList.map((s) {
                  final model = Subject.fromJson(s as Map<String, dynamic>);
                  return FilterOption(value: model.id, label: model.name);
                }).toList(),
                selectedValue: _tempSubjectId,
                onSelected: (val) => setState(() => _tempSubjectId = val),
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lp.getTranslatedText({
                  'en': 'Time Range',
                  'id': 'Rentang Waktu',
                }),
                icon: Icons.date_range_rounded,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String>(
                options: [
                  FilterOption(
                    value: 'today',
                    label: lp
                        .getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}),
                  ),
                  FilterOption(
                    value: 'week',
                    label: lp.getTranslatedText(
                      {'en': 'This Week', 'id': 'Minggu Ini'},
                    ),
                  ),
                  FilterOption(
                    value: 'month',
                    label: lp.getTranslatedText(
                      {'en': 'This Month', 'id': 'Bulan Ini'},
                    ),
                  ),
                ],
                selectedValue: _tempDateRange,
                onSelected: (val) => setState(() => _tempDateRange = val),
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
