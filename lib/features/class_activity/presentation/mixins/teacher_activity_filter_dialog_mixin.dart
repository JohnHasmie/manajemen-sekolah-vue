import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/filter_sheet_reset.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

mixin TeacherActivityFilterDialogMixin {
  void setState(VoidCallback fn);
  BuildContext get context;

  /// The host's Riverpod ref. Satisfied automatically when the host
  /// is a ConsumerState.
  WidgetRef get ref;

  /// Wali kelas vs mengajar — picks the right roster partition.
  bool get isHomeroomView;

  void showFilterDialog(LanguageProvider lp) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityFilterSheet(
        ref: ref,
        hideClassSection: isHomeroomView,
        isHomeroomView: isHomeroomView,
        initialClassId: filterClassId,
        initialSubjectId: filterSubjectId,
        initialDateOption: filterDateOption,
        primaryColor: primaryColor,
        languageProvider: lp,
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
///
/// Brand filter rule: sources chips from `filterRosterRiverpod`
/// (provider hydrated at dashboard init). No per-tap network calls.
/// Cross-axis narrowing + auto-select-on-single is wired into the
/// chip `onSelected` handlers.
class _ActivityFilterSheet extends StatefulWidget {
  final WidgetRef ref;
  final bool hideClassSection;
  final bool isHomeroomView;
  final String? initialClassId;
  final String? initialSubjectId;
  final String? initialDateOption;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final void Function({
    String? classId,
    String? subjectId,
    String? dateOption,
    List<dynamic>? subjectList,
  })
  onApply;

  const _ActivityFilterSheet({
    required this.ref,
    required this.hideClassSection,
    required this.isHomeroomView,
    required this.initialClassId,
    required this.initialSubjectId,
    required this.initialDateOption,
    required this.primaryColor,
    required this.languageProvider,
    required this.onApply,
  });

  @override
  State<_ActivityFilterSheet> createState() => _ActivityFilterSheetState();
}

class _ActivityFilterSheetState extends State<_ActivityFilterSheet> {
  late String? _classId;
  late String? _subjectId;
  late String? _dateOption;

  @override
  void initState() {
    super.initState();
    _classId = widget.initialClassId;
    _subjectId = widget.initialSubjectId;
    _dateOption = widget.initialDateOption;
  }

  LanguageProvider get _lp => widget.languageProvider;

  @override
  Widget build(BuildContext context) {
    final roster = widget.ref.watch(filterRosterRiverpod);
    final rosterClasses = roster.classesForSubject(
      _subjectId,
      isHomeroomView: widget.isHomeroomView,
    );
    final rosterSubjects = roster.subjectsForClass(
      _classId,
      isHomeroomView: widget.isHomeroomView,
    );

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
          subjectList: rosterSubjects,
        );
      },
      onReset: () => FilterSheetHelpers.reset(
        context,
        () => widget.onApply(
          classId: null,
          subjectId: null,
          dateOption: null,
          subjectList: const [],
        ),
      ),
      content: TeacherFilterContent(
        sections: [
          // Kelas section hides in wali kelas mode — the role toggle
          // in the page header has already locked the class.
          if (!widget.hideClassSection)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilterSectionHeader(
                  title: _lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
                  icon: Icons.class_outlined,
                  primaryColor: widget.primaryColor,
                ),
                FilterChipGrid<String>(
                  options: rosterClasses.map((c) {
                    final id = c['id']?.toString() ?? '';
                    final name = (c['name'] ?? c['nama'] ?? '-').toString();
                    return FilterOption(value: id, label: name);
                  }).toList(),
                  selectedValue: _classId,
                  onSelected: (val) {
                    final newId = val == _classId ? null : val;
                    setState(() {
                      _classId = newId;
                      // Cross-axis: drop subject if the new class
                      // doesn't teach it.
                      if (_subjectId != null && newId != null) {
                        final allowed = roster
                            .subjectsForClass(
                              newId,
                              isHomeroomView: widget.isHomeroomView,
                            )
                            .map((s) => (s as Map)['id']?.toString());
                        if (!allowed.contains(_subjectId)) {
                           _subjectId = null;
                        }
                      }
                      // Auto-select-on-single.
                      if (newId != null && _subjectId == null) {
                        final only = roster.subjectsForClass(
                          newId,
                          isHomeroomView: widget.isHomeroomView,
                        );
                        if (only.length == 1 && only.first is Map) {
                          _subjectId = (only.first as Map)['id']?.toString();
                        }
                      }
                    });
                  },
                  selectedColor: widget.primaryColor,
                ),
              ],
            ),

          // Subject section
          if (rosterSubjects.isNotEmpty)
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
                  options: rosterSubjects.map((s) {
                    final id =
                        (s['id'] ?? s['mata_pelajaran_id'])?.toString() ?? '';
                    final name = (s['nama'] ?? s['name'] ?? '-').toString();
                    return FilterOption(value: id, label: name);
                  }).toList(),
                  selectedValue: _subjectId,
                  onSelected: (val) {
                    setState(() {
                      _subjectId = val;
                      // Cross-axis inverse: auto-select sole class.
                      if (val != null && _classId == null) {
                        final only = roster.classesForSubject(
                          val,
                          isHomeroomView: widget.isHomeroomView,
                        );
                        if (only.length == 1 && only.first is Map) {
                          _classId = (only.first as Map)['id']?.toString();
                        }
                      }
                    });
                  },
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
                // Tapping the already-selected chip deselects it so
                // the user can drop a "this week" filter without
                // having to hit Reset.
                onSelected: (val) => setState(
                  () => _dateOption = val == _dateOption ? null : val,
                ),
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
