import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

mixin TeacherActivityFilterDialogMixin {
  void setState(VoidCallback fn);
  BuildContext get context;

  void showFilterDialog(LanguageProvider lp) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityFilterSheet(
        classList: classList,
        initialClassId: filterClassId,
        initialSubjectId: filterSubjectId,
        initialDateOption: filterDateOption,
        initialSubjectList: filterSubjectList,
        primaryColor: primaryColor,
        languageProvider: lp,
        onFetchSubjects: _fetchSubjectsForClass,
        onApply:
            ({
              String? classId,
              String? subjectId,
              String? dateOption,
              List<dynamic>? subjectList,
            }) {
              updateFilters(
                classId: classId,
                subjectId: subjectId,
                dateOption: dateOption,
                subjectList: subjectList,
              );
              forceRefresh();
            },
      ),
    );
  }

  Future<List<dynamic>> _fetchSubjectsForClass(String classId) async {
    try {
      // Fetch only subjects THIS teacher teaches for the selected class.
      // `/teacher/:id/subjects?class_id=` returns `{success, data: [...]}`.
      final r = await getIt<Dio>().get(
        '/teacher/$teacherId/subjects',
        queryParameters: {'class_id': classId},
      );
      final raw = r.data;
      if (raw is List) return raw;
      if (raw is Map && raw['data'] is List) return raw['data'] as List;
      return [];
    } catch (_) {
      return [];
    }
  }

  List<dynamic> get classList;
  String get teacherId;
  String? get filterClassId;
  String? get filterSubjectId;
  String? get filterDateOption;
  List<dynamic> get filterSubjectList;
  Color get primaryColor;

  void updateFilters({
    String? classId,
    String? subjectId,
    String? dateOption,
    List<dynamic>? subjectList,
  });

  Future<void> forceRefresh();
}

/// Stateful bottom sheet widget for the class activity filter.
class _ActivityFilterSheet extends StatefulWidget {
  final List<dynamic> classList;
  final String? initialClassId;
  final String? initialSubjectId;
  final String? initialDateOption;
  final List<dynamic> initialSubjectList;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final Future<List<dynamic>> Function(String classId) onFetchSubjects;
  final void Function({
    String? classId,
    String? subjectId,
    String? dateOption,
    List<dynamic>? subjectList,
  })
  onApply;

  const _ActivityFilterSheet({
    required this.classList,
    required this.initialClassId,
    required this.initialSubjectId,
    required this.initialDateOption,
    required this.initialSubjectList,
    required this.primaryColor,
    required this.languageProvider,
    required this.onFetchSubjects,
    required this.onApply,
  });

  @override
  State<_ActivityFilterSheet> createState() => _ActivityFilterSheetState();
}

class _ActivityFilterSheetState extends State<_ActivityFilterSheet> {
  late String? _classId;
  late String? _subjectId;
  late String? _dateOption;
  late List<dynamic> _subjectList;

  @override
  void initState() {
    super.initState();
    _classId = widget.initialClassId;
    _subjectId = widget.initialSubjectId;
    _dateOption = widget.initialDateOption;
    _subjectList = List.from(widget.initialSubjectList);
  }

  LanguageProvider get _lp => widget.languageProvider;

  @override
  Widget build(BuildContext context) {
    return AppFilterBottomSheet(
      title: _lp.getTranslatedText({
        'en': 'Filter Activity',
        'id': 'Filter Kegiatan',
      }),
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.75,
      onApply: () {
        Navigator.pop(context);
        widget.onApply(
          classId: _classId,
          subjectId: _subjectId,
          dateOption: _dateOption,
          subjectList: _subjectList,
        );
      },
      onReset: () => setState(() {
        _classId = null;
        _subjectId = null;
        _dateOption = null;
        _subjectList = [];
      }),
      content: TeacherFilterContent(
        sections: [
          // Class section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: _lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
                icon: Icons.class_outlined,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String>(
                options: widget.classList.map((c) {
                  final id = c['id']?.toString() ?? '';
                  final name = (c['name'] ?? c['nama'] ?? '-').toString();
                  return FilterOption(value: id, label: name);
                }).toList(),
                selectedValue: _classId,
                onSelected: (val) async {
                  final newId = val == _classId ? null : val;
                  setState(() {
                    _classId = newId;
                    _subjectId = null;
                    _subjectList = [];
                  });
                  if (newId != null) {
                    final subjects = await widget.onFetchSubjects(newId);
                    if (mounted) {
                      setState(() => _subjectList = subjects);
                    }
                  }
                },
                selectedColor: widget.primaryColor,
              ),
            ],
          ),

          // Subject section (only when class is selected)
          if (_classId != null && _subjectList.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilterSectionHeader(
                  title: _lp.getTranslatedText({
                    'en': 'Subject',
                    'id': 'Mata Pelajaran',
                  }),
                  icon: Icons.book_outlined,
                  primaryColor: widget.primaryColor,
                ),
                FilterChipGrid<String>(
                  options: _subjectList.map((s) {
                    final id =
                        (s['id'] ?? s['mata_pelajaran_id'])?.toString() ?? '';
                    final name = (s['nama'] ?? s['name'] ?? '-').toString();
                    return FilterOption(value: id, label: name);
                  }).toList(),
                  selectedValue: _subjectId,
                  onSelected: (val) => setState(() => _subjectId = val),
                  selectedColor: widget.primaryColor,
                ),
              ],
            ),

          // Date range section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: _lp.getTranslatedText({
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
                    label: _lp.getTranslatedText({
                      'en': 'Today',
                      'id': 'Hari Ini',
                    }),
                  ),
                  FilterOption(
                    value: 'week',
                    label: _lp.getTranslatedText({
                      'en': 'This Week',
                      'id': 'Minggu Ini',
                    }),
                  ),
                  FilterOption(
                    value: 'month',
                    label: _lp.getTranslatedText({
                      'en': 'This Month',
                      'id': 'Bulan Ini',
                    }),
                  ),
                ],
                selectedValue: _dateOption,
                onSelected: (val) => setState(() => _dateOption = val),
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
