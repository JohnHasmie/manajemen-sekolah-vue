// Filter sheet for the admin Kegiatan Kelas hub (Frame C).
//
// Five sections wired into `AppFilterBottomSheet` chrome:
//   * Periode    — FilterChipGrid (Hari Ini / 7 / 30 / Semester / Tahun)
//   * Kelas      — FilterChipGrid
//   * Mapel      — FilterChipGrid
//   * Guru       — autocomplete field (lists can be hundreds long)
//   * Tipe       — FilterChipGrid (Tugas / PR / Ulangan / Lainnya)
//
// Returns the selected values to the host screen via the [onApply]
// callback. Reset clears every section back to the defaults
// (Periode → 7 hari, others → null).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/features/class_activity/domain/models/admin_activity_summary.dart';

typedef AdminActivityFilterApply =
    void Function({
      required String? classId,
      required String? className,
      required String? subjectId,
      required String? subjectName,
      required String? teacherId,
      required String? teacherName,
      required AdminActivityType? type,
      required AdminActivityPeriod period,
    });

class AdminActivityFilterSheet extends StatefulWidget {
  const AdminActivityFilterSheet({
    super.key,
    required this.availableClasses,
    required this.availableSubjects,
    required this.availableTeachers,
    required this.onApply,
    this.initialClassId,
    this.initialSubjectId,
    this.initialTeacherId,
    this.initialType,
    this.initialPeriod = AdminActivityPeriod.sevenDays,
    this.previewCount = 0,
  });

  final List<Map<String, dynamic>> availableClasses;
  final List<Map<String, dynamic>> availableSubjects;
  final List<Map<String, dynamic>> availableTeachers;
  final String? initialClassId;
  final String? initialSubjectId;
  final String? initialTeacherId;
  final AdminActivityType? initialType;
  final AdminActivityPeriod initialPeriod;
  final int previewCount;
  final AdminActivityFilterApply onApply;

  static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> availableClasses,
    required List<Map<String, dynamic>> availableSubjects,
    required List<Map<String, dynamic>> availableTeachers,
    required AdminActivityFilterApply onApply,
    String? initialClassId,
    String? initialSubjectId,
    String? initialTeacherId,
    AdminActivityType? initialType,
    AdminActivityPeriod initialPeriod = AdminActivityPeriod.sevenDays,
    int previewCount = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminActivityFilterSheet(
        availableClasses: availableClasses,
        availableSubjects: availableSubjects,
        availableTeachers: availableTeachers,
        onApply: onApply,
        initialClassId: initialClassId,
        initialSubjectId: initialSubjectId,
        initialTeacherId: initialTeacherId,
        initialType: initialType,
        initialPeriod: initialPeriod,
        previewCount: previewCount,
      ),
    );
  }

  @override
  State<AdminActivityFilterSheet> createState() =>
      _AdminActivityFilterSheetState();
}

class _AdminActivityFilterSheetState extends State<AdminActivityFilterSheet> {
  late String? _classId = widget.initialClassId;
  late String? _subjectId = widget.initialSubjectId;
  late String? _teacherId = widget.initialTeacherId;
  late AdminActivityType? _type = widget.initialType;
  late AdminActivityPeriod _period = widget.initialPeriod;

  late final TextEditingController _teacherSearchController =
      TextEditingController(text: _teacherName(_teacherId));

  String? _teacherName(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final t in widget.availableTeachers) {
      if (t['id']?.toString() == id) {
        return (t['name'] ?? t['nama'])?.toString();
      }
    }
    return null;
  }

  String? _classNameFromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in widget.availableClasses) {
      if (c['id']?.toString() == id) {
        return (c['name'] ?? c['nama'])?.toString();
      }
    }
    return null;
  }

  String? _subjectNameFromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final s in widget.availableSubjects) {
      if (s['id']?.toString() == id) {
        return (s['name'] ?? s['nama'])?.toString();
      }
    }
    return null;
  }

  @override
  void dispose() {
    _teacherSearchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var n = 0;
    if (_classId != null) n++;
    if (_subjectId != null) n++;
    if (_teacherId != null) n++;
    if (_type != null) n++;
    if (_period != AdminActivityPeriod.sevenDays) n++;
    return n;
  }

  void _reset() {
    setState(() {
      _classId = null;
      _subjectId = null;
      _teacherId = null;
      _type = null;
      _period = AdminActivityPeriod.sevenDays;
      _teacherSearchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = ColorUtils.getRoleColor('admin');
    final count = _activeFilterCount;
    return AppFilterBottomSheet(
      title: 'Filter Kegiatan',
      icon: Icons.event_note_rounded,
      headerSubtitle:
          'Periode ${_period.labelId} · ${widget.previewCount} kegiatan',
      primaryColor: primary,
      applyLabel: count > 0 ? 'Terapkan ($count)' : 'Terapkan Filter',
      onApply: () {
        AppNavigator.pop(context);
        widget.onApply(
          classId: _classId,
          className: _classNameFromId(_classId),
          subjectId: _subjectId,
          subjectName: _subjectNameFromId(_subjectId),
          teacherId: _teacherId,
          teacherName: _teacherName(_teacherId),
          type: _type,
          period: _period,
        );
      },
      onReset: _reset,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterSectionHeader(
            title: 'Periode',
            icon: Icons.calendar_month_rounded,
            primaryColor: primary,
          ),
          FilterChipGrid<AdminActivityPeriod>(
            options: AdminActivityPeriod.values
                .map(
                  (p) => FilterOption<AdminActivityPeriod>(
                    value: p,
                    label: p.labelId,
                  ),
                )
                .toList(),
            selectedValue: _period,
            onSelected: (v) {
              if (v == null) return;
              setState(() => _period = v);
            },
            selectedColor: primary,
          ),
          const SizedBox(height: 16),
          FilterSectionHeader(
            title: 'Kelas',
            icon: Icons.class_outlined,
            primaryColor: primary,
          ),
          FilterChipGrid<String>(
            options: widget.availableClasses
                .map<FilterOption<String>>(
                  (c) => FilterOption(
                    value: c['id'].toString(),
                    label: (c['name'] ?? c['nama'] ?? '').toString(),
                  ),
                )
                .toList(),
            selectedValue: _classId,
            onSelected: (v) => setState(() => _classId = v),
            selectedColor: primary,
          ),
          const SizedBox(height: 16),
          FilterSectionHeader(
            title: 'Mata Pelajaran',
            icon: Icons.menu_book_outlined,
            primaryColor: primary,
          ),
          FilterChipGrid<String>(
            options: widget.availableSubjects
                .map<FilterOption<String>>(
                  (s) => FilterOption(
                    value: s['id'].toString(),
                    label: (s['name'] ?? s['nama'] ?? '').toString(),
                  ),
                )
                .toList(),
            selectedValue: _subjectId,
            onSelected: (v) => setState(() => _subjectId = v),
            selectedColor: primary,
          ),
          const SizedBox(height: 16),
          FilterSectionHeader(
            title: 'Guru',
            icon: Icons.person_outline_rounded,
            primaryColor: primary,
          ),
          _TeacherAutocomplete(
            teachers: widget.availableTeachers,
            controller: _teacherSearchController,
            selectedId: _teacherId,
            onSelected: (id) => setState(() => _teacherId = id),
          ),
          const SizedBox(height: 16),
          FilterSectionHeader(
            title: 'Tipe Kegiatan',
            icon: Icons.label_outline_rounded,
            primaryColor: primary,
          ),
          FilterChipGrid<AdminActivityType>(
            options: AdminActivityType.values
                .map(
                  (t) => FilterOption<AdminActivityType>(
                    value: t,
                    label: t.labelId,
                  ),
                )
                .toList(),
            selectedValue: _type,
            onSelected: (v) => setState(() => _type = v),
            selectedColor: primary,
          ),
        ],
      ),
    );
  }
}

/// Autocomplete field for the Guru section. Mirrors the pattern used
/// by the Jadwal Fix-1a guru/mapel autocomplete — lists can be
/// hundreds long, so a chip grid is impractical.
class _TeacherAutocomplete extends StatelessWidget {
  const _TeacherAutocomplete({
    required this.teachers,
    required this.controller,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> teachers;
  final TextEditingController controller;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, String>>(
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) {
          return const Iterable<Map<String, String>>.empty();
        }
        return teachers
            .map(
              (t) => {
                'id': t['id'].toString(),
                'name': (t['name'] ?? t['nama'] ?? '').toString(),
              },
            )
            .where(
              (m) =>
                  m['name']!.toLowerCase().contains(value.text.toLowerCase()),
            );
      },
      displayStringForOption: (m) => m['name']!,
      onSelected: (m) => onSelected(m['id']),
      fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
        if (selectedId != null && ctrl.text.isEmpty) {
          final match = teachers.firstWhere(
            (t) => t['id']?.toString() == selectedId,
            orElse: () => const {},
          );
          if (match.isNotEmpty) {
            ctrl.text = (match['name'] ?? match['nama'] ?? '').toString();
          }
        }
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Cari guru…',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: ColorUtils.slate50,
            prefixIcon: Icon(Icons.search_rounded, color: ColorUtils.slate400),
            suffixIcon: selectedId != null
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      ctrl.clear();
                      onSelected(null);
                      focusNode.unfocus();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: ColorUtils.getRoleColor('admin'),
                width: 2,
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 220,
                maxWidth: MediaQuery.of(context).size.width - 40,
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final option = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(option['name']!),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
