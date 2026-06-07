// Bottom sheet modal for selecting payment target (classes and students) — v3.
//
// Two changes from the previous version:
//
//   1. **Bug fix.** The previous implementation split rendering across
//      `UiBuilderMixin` and `StudentUiBuilderMixin`, with `_buildStudentList`
//      declared as a private abstract in one mixin and concretely
//      implemented in the other. In Dart, private members are
//      library-scoped — `_buildStudentList` from library A and
//      `_buildStudentList` from library B are TWO DIFFERENT symbols, so
//      the abstract was never satisfied and tapping into the modal
//      threw `NoSuchMethodError: _TargetSelectionModalState has no
//      instance method '_buildStudentList'`. We collapse all rendering
//      back into the State class so there's no cross-library override.
//
//   2. **Visual refresh.** Brings the modal in line with the rest of
//      v3 admin chrome: AppBottomSheet scaffold, slate-bordered search
//      field, compact pill quick-actions, navy-edged class cards with
//      checkbox + chevron, student rows with initial avatar + NIS, and
//      a `BottomSheetFooter` for Batal / Simpan.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/selection_logic_mixin.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// A bottom sheet that lets the admin select target classes and students
/// for a payment type.
///
/// Receives class/student data from the parent, and calls [onSave] with
/// the built goal data when the user confirms.
class TargetSelectionModal extends StatefulWidget {
  final Map<String, dynamic>? paymentType;
  final Function(Map<String, dynamic>) onSave;
  final Color primaryColor;
  final List<dynamic> classList;
  final Map<String, List<dynamic>> studentsByClass;

  const TargetSelectionModal({
    super.key,
    this.paymentType,
    required this.onSave,
    required this.primaryColor,
    required this.classList,
    required this.studentsByClass,
  });

  @override
  State<TargetSelectionModal> createState() => _TargetSelectionModalState();
}

class _TargetSelectionModalState extends State<TargetSelectionModal>
    with SelectionLogicMixin {
  final List<dynamic> _selectedClasses = [];
  final Map<String, List<dynamic>> _selectedStudentsByClass = {};
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedClasses = {};

  @override
  List<dynamic> get selectedClasses => _selectedClasses;

  @override
  Map<String, List<dynamic>> get selectedStudentsByClass =>
      _selectedStudentsByClass;

  @override
  void initState() {
    super.initState();
    if (widget.paymentType?['goal'] != null) {
      loadExistingGoal(widget.paymentType!['goal']);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -- Selection helpers ------------------------------------------------------

  void _selectAllClasses() {
    setState(() {
      _selectedClasses
        ..clear()
        ..addAll(widget.classList);
      for (final classItem in widget.classList) {
        final classId = classItem['id'].toString();
        _selectedStudentsByClass[classId] = List.from(
          widget.studentsByClass[classId] ?? [],
        );
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selectedClasses.clear();
      _selectedStudentsByClass.clear();
    });
  }

  void _toggleClass(
    Map<String, dynamic> classItem,
    String classId,
    List<dynamic> studentList,
    bool selected,
  ) {
    setState(() {
      if (selected) {
        if (!_selectedClasses.any((k) => k['id'].toString() == classId)) {
          _selectedClasses.add(classItem);
        }
        _selectedStudentsByClass[classId] = List.from(studentList);
      } else {
        _selectedClasses.removeWhere((k) => k['id'].toString() == classId);
        _selectedStudentsByClass.remove(classId);
      }
    });
  }

  void _toggleStudent(
    Map<String, dynamic> student,
    Map<String, dynamic> classItem,
    String classId,
    bool selected,
  ) {
    setState(() {
      final list = List<dynamic>.from(_selectedStudentsByClass[classId] ?? []);
      if (selected) {
        if (!list.any((s) => s['id'].toString() == student['id'].toString())) {
          list.add(student);
        }
      } else {
        list.removeWhere((s) => s['id'].toString() == student['id'].toString());
      }
      if (list.isEmpty) {
        _selectedStudentsByClass.remove(classId);
        _selectedClasses.removeWhere((k) => k['id'].toString() == classId);
      } else {
        _selectedStudentsByClass[classId] = list;
        if (!_selectedClasses.any((k) => k['id'].toString() == classId)) {
          _selectedClasses.add(classItem);
        }
      }
    });
  }

  bool _isStudentSelected(Map<String, dynamic> student, String classId) {
    final list = _selectedStudentsByClass[classId];
    if (list == null) return false;
    return list.any((s) => s['id'].toString() == student['id'].toString());
  }

  void _toggleExpand(String classId) {
    setState(() {
      if (_expandedClasses.contains(classId)) {
        _expandedClasses.remove(classId);
      } else {
        _expandedClasses.add(classId);
      }
    });
  }

  // -- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final navy = widget.primaryColor;
    final search = _searchController.text.trim().toLowerCase();
    final totalClasses = _selectedClasses.length;
    final totalSelectedStudents = _selectedStudentsByClass.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    final totalAllStudents = getTotalStudents();
    final isAllSelected =
        totalClasses == widget.classList.length &&
        totalSelectedStudents == totalAllStudents &&
        widget.classList.isNotEmpty;

    return AppBottomSheet(
      title: kFinSelectPaymentTarget.tr,
      subtitle: kFinSelectClassesStudents.tr,
      icon: Icons.groups_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.92,
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SearchField(
            controller: _searchController,
            primaryColor: navy,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 10),
          _QuickActionsRow(
            primaryColor: navy,
            onSelectAll: _selectAllClasses,
            onClearAll: _clearAll,
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            label: kFinClasses.tr,
            icon: Icons.class_rounded,
            trailing: '${widget.classList.length} TOTAL',
          ),
          const SizedBox(height: 8),
          if (widget.classList.isEmpty)
            _EmptyState(navy: navy)
          else
            ...widget.classList.map((classItem) {
              final classMap = Map<String, dynamic>.from(classItem as Map);
              final classId = classMap['id'].toString();
              final studentList = widget.studentsByClass[classId] ?? const [];
              final filtered = search.isEmpty
                  ? studentList
                  : studentList.where((s) {
                      final m = Student.fromJson(s as Map<String, dynamic>);
                      return m.name.toLowerCase().contains(search) ||
                          m.studentNumber.toLowerCase().contains(search);
                    }).toList();
              final isClassSelected = _selectedClasses.any(
                (k) => k['id'].toString() == classId,
              );
              final selectedStudentCount =
                  _selectedStudentsByClass[classId]?.length ?? 0;
              final isExpanded =
                  _expandedClasses.contains(classId) || search.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ClassCard(
                  classItem: classMap,
                  classId: classId,
                  studentList: studentList,
                  filteredStudents: filtered,
                  isClassSelected: isClassSelected,
                  selectedStudentCount: selectedStudentCount,
                  primaryColor: navy,
                  isExpanded: isExpanded,
                  onToggleExpand: () => _toggleExpand(classId),
                  onToggleClass: (val) =>
                      _toggleClass(classMap, classId, studentList, val),
                  isStudentSelected: (s) => _isStudentSelected(s, classId),
                  onToggleStudent: (s, val) =>
                      _toggleStudent(s, classMap, classId, val),
                ),
              );
            }),
          const SizedBox(height: 4),
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _SummaryStrip(
              totalClasses: totalClasses,
              totalStudents: totalSelectedStudents,
              isAllSelected: isAllSelected,
              primaryColor: navy,
            ),
          ),
          BottomSheetFooter(
            primaryLabel: kFinSaveTarget.tr,
            primaryColor: navy,
            secondaryLabel: 'Batal',
            onPrimary: () {
              final goal = buildGoalData();
              widget.onSave(goal);
              AppNavigator.pop(context);
            },
            onSecondary: () => AppNavigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// --- Search ------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final Color primaryColor;
  final VoidCallback onChanged;

  const _SearchField({
    required this.controller,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      cursorColor: primaryColor,
      decoration: InputDecoration(
        hintText: kFinSearchStudentsByNameNumber.tr,
        hintStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ColorUtils.slate400,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            Icons.search_rounded,
            size: 18,
            color: ColorUtils.slate400,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 0),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ColorUtils.slate400,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
          borderSide: BorderSide(color: primaryColor, width: 1.4),
        ),
      ),
    );
  }
}

// --- Quick actions -----------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  const _QuickActionsRow({
    required this.primaryColor,
    required this.onSelectAll,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionPill(
            icon: Icons.done_all_rounded,
            label: kFinSelectAll.tr,
            color: primaryColor,
            onTap: onSelectAll,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionPill(
            icon: Icons.cleaning_services_rounded,
            label: kFinClearAll.tr,
            color: const Color(0xFFDC2626),
            onTap: onClearAll,
          ),
        ),
      ],
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Section header ----------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? trailing;
  const _SectionHeader({
    required this.label,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: ColorUtils.slate500),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: ColorUtils.slate500,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(
              '· $trailing',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: ColorUtils.slate300,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: ColorUtils.slate100)),
        ],
      ),
    );
  }
}

// --- Empty state -------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final Color navy;
  const _EmptyState({required this.navy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 40, color: ColorUtils.slate300),
          const SizedBox(height: 8),
          Text(
            'Belum ada kelas tersedia',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan kelas terlebih dahulu di menu Manajemen Kelas.',
            style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// --- Class card --------------------------------------------------------------

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> classItem;
  final String classId;
  final List<dynamic> studentList;
  final List<dynamic> filteredStudents;
  final bool isClassSelected;
  final int selectedStudentCount;
  final Color primaryColor;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onToggleClass;
  final bool Function(Map<String, dynamic>) isStudentSelected;
  final void Function(Map<String, dynamic>, bool) onToggleStudent;

  const _ClassCard({
    required this.classItem,
    required this.classId,
    required this.studentList,
    required this.filteredStudents,
    required this.isClassSelected,
    required this.selectedStudentCount,
    required this.primaryColor,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onToggleClass,
    required this.isStudentSelected,
    required this.onToggleStudent,
  });

  @override
  Widget build(BuildContext context) {
    final className = Classroom.fromJson(classItem).name;
    final hasSelection = selectedStudentCount > 0;
    final edgeColor = hasSelection ? primaryColor : ColorUtils.slate200;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasSelection
              ? primaryColor.withValues(alpha: 0.4)
              : ColorUtils.slate200,
          width: hasSelection ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: edgeColor),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onToggleExpand,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          child: Row(
                            children: [
                              _ClassCheckbox(
                                value: isClassSelected,
                                primaryColor: primaryColor,
                                onChanged: onToggleClass,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      className,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      hasSelection
                                          ? '$selectedStudentCount dari '
                                                '${studentList.length} siswa '
                                                'dipilih'
                                          : '${studentList.length} siswa',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: hasSelection
                                            ? primaryColor
                                            : ColorUtils.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (hasSelection)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '$selectedStudentCount/${studentList.length}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              AnimatedRotation(
                                duration: const Duration(milliseconds: 160),
                                turns: isExpanded ? 0.5 : 0,
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  size: 20,
                                  color: ColorUtils.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Container(
                        decoration: BoxDecoration(
                          color: ColorUtils.slate50,
                          border: Border(
                            top: BorderSide(color: ColorUtils.slate100),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (filteredStudents.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  'Tidak ada siswa yang cocok',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                    color: ColorUtils.slate400,
                                  ),
                                ),
                              )
                            else
                              ...filteredStudents.map((s) {
                                final student = Map<String, dynamic>.from(
                                  s as Map,
                                );
                                return _StudentRow(
                                  student: student,
                                  selected: isStudentSelected(student),
                                  primaryColor: primaryColor,
                                  onToggle: (val) =>
                                      onToggleStudent(student, val),
                                );
                              }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCheckbox extends StatelessWidget {
  final bool value;
  final Color primaryColor;
  final ValueChanged<bool> onChanged;

  const _ClassCheckbox({
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: value ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value ? primaryColor : ColorUtils.slate300,
            width: 1.4,
          ),
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

// --- Student row -------------------------------------------------------------

class _StudentRow extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool selected;
  final Color primaryColor;
  final ValueChanged<bool> onToggle;

  const _StudentRow({
    required this.student,
    required this.selected,
    required this.primaryColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final m = Student.fromJson(student);
    final name = m.name.isNotEmpty ? m.name : 'Siswa';
    final nis = m.studentNumber.isNotEmpty ? m.studentNumber : '-';
    final initial = name[0].toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onToggle(!selected),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? primaryColor.withValues(alpha: 0.4)
                  : ColorUtils.slate200,
            ),
          ),
          child: Row(
            children: [
              _ClassCheckbox(
                value: selected,
                primaryColor: primaryColor,
                onChanged: onToggle,
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'NIS · $nis',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Footer summary strip ----------------------------------------------------

class _SummaryStrip extends StatelessWidget {
  final int totalClasses;
  final int totalStudents;
  final bool isAllSelected;
  final Color primaryColor;

  const _SummaryStrip({
    required this.totalClasses,
    required this.totalStudents,
    required this.isAllSelected,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          Icon(Icons.checklist_rounded, size: 14, color: ColorUtils.slate500),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                children: [
                  const TextSpan(text: 'Terpilih · '),
                  TextSpan(
                    text: '$totalClasses kelas',
                    style: TextStyle(color: primaryColor),
                  ),
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: '$totalStudents siswa',
                    style: TextStyle(color: primaryColor),
                  ),
                ],
              ),
            ),
          ),
          if (isAllSelected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'SEMUA',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
