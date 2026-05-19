// Frame E · Tambah Kelas (multi-select) sheet for the Mata Pelajaran
// detail screen. See `_design/admin_mapel_detail_redesign.html`.
//
// Replaces the legacy one-at-a-time AlertDialog. Caller passes:
//   • [subjectId]            — the subject we attach to
//   • [subjectName]          — used in the sheet subtitle
//   • [unassignedClasses]    — list of class Maps (id, name, grade_level,
//                              homeroom_teacher_name) that are eligible
//                              to be added (already filtered out
//                              currently-assigned classes)
//
// Picks up Tingkat groups from the data so admin can scope by tingkat
// without us hardcoding the curriculum. Selection summary updates live,
// and the primary button label includes the count.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

class SubjectBulkAddClassesSheet extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final List<Map<String, dynamic>> unassignedClasses;

  const SubjectBulkAddClassesSheet({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.unassignedClasses,
  });

  /// Opens the sheet wrapped in [AppBottomSheet]. Returns `true` when
  /// at least one class was attached (so the caller refreshes its
  /// list); returns `null`/`false` if dismissed.
  static Future<bool?> show({
    required BuildContext context,
    required String subjectId,
    required String subjectName,
    required List<Map<String, dynamic>> unassignedClasses,
  }) {
    return AppBottomSheet.show<bool>(
      context: context,
      title: 'Tambah Kelas',
      subtitle: 'Pilih kelas untuk $subjectName',
      icon: Icons.add_rounded,
      primaryColor: ColorUtils.getRoleColor('admin'),
      content: SubjectBulkAddClassesSheet(
        subjectId: subjectId,
        subjectName: subjectName,
        unassignedClasses: unassignedClasses,
      ),
    );
  }

  @override
  State<SubjectBulkAddClassesSheet> createState() =>
      _SubjectBulkAddClassesSheetState();
}

class _SubjectBulkAddClassesSheetState
    extends State<SubjectBulkAddClassesSheet> {
  final _service = ApiSubjectService();
  final _searchController = TextEditingController();

  /// Tingkat key the user is currently filtering by. `'all'` shows
  /// every tingkat; otherwise the trimmed `grade_level` value.
  String _selectedTingkat = 'all';

  /// Set of class IDs the user has ticked. We use a Set for O(1)
  /// lookup when rendering checkboxes.
  final Set<String> _selectedIds = <String>{};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _tingkatOptions {
    final set = <String>{};
    for (final c in widget.unassignedClasses) {
      final t = (c['grade_level'] ?? '').toString().trim();
      if (t.isNotEmpty) set.add(t);
    }
    final list = set.toList();
    // Sort numerically when possible
    list.sort((a, b) {
      final na = int.tryParse(a);
      final nb = int.tryParse(b);
      if (na != null && nb != null) return na.compareTo(nb);
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return list;
  }

  List<Map<String, dynamic>> get _filteredClasses {
    final q = _searchController.text.trim().toLowerCase();
    return widget.unassignedClasses
        .where((c) {
          final model = Classroom.fromJson(c);
          final tingkat = (model.gradeLevel ?? '').trim();
          final tingkatMatch =
              _selectedTingkat == 'all' || tingkat == _selectedTingkat;
          if (!tingkatMatch) return false;

          if (q.isEmpty) return true;
          final name = model.name.toLowerCase();
          final wali = (model.homeroomTeacherName ?? '').toLowerCase();
          return name.contains(q) ||
              tingkat.toLowerCase().contains(q) ||
              wali.contains(q);
        })
        .toList(growable: false);
  }

  void _toggle(String classId) {
    setState(() {
      if (_selectedIds.contains(classId)) {
        _selectedIds.remove(classId);
      } else {
        _selectedIds.add(classId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _saving = true);
    try {
      final ids = _selectedIds.toList(growable: false);
      final result = await _service.bulkAttachClasses(widget.subjectId, ids);
      final attached = (result['attached_count'] ?? ids.length) as int;
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        '$attached kelas berhasil ditambahkan ke ${widget.subjectName}',
      );
      AppNavigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Gagal menambah kelas: $e');
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = ColorUtils.getRoleColor('admin');
    final classes = _filteredClasses;
    final tingkatOpts = _tingkatOptions;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tingkat tabs — Semua + per-tingkat from data
        if (tingkatOpts.isNotEmpty)
          _TingkatTabs(
            options: ['all', ...tingkatOpts],
            selected: _selectedTingkat,
            primary: primary,
            onChanged: (v) => setState(() => _selectedTingkat = v),
          ),
        const SizedBox(height: AppSpacing.sm),

        // Live selection summary — shows count + clear affordance
        if (_selectedIds.isNotEmpty)
          _SelectionSummary(
            count: _selectedIds.length,
            primary: primary,
            onClear: _clearSelection,
          ),

        // Search
        _Search(controller: _searchController, primary: primary),
        const SizedBox(height: AppSpacing.sm),

        // List
        if (classes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              title: 'Tidak ada kelas',
              subtitle: 'Semua kelas pada tingkat ini sudah terdaftar',
              icon: Icons.check_circle_outline_rounded,
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: classes.length,
              itemBuilder: (context, i) {
                final c = classes[i];
                final model = Classroom.fromJson(c);
                final id = model.id;
                final selected = _selectedIds.contains(id);
                return _PickRow(
                  model: model,
                  selected: selected,
                  primary: primary,
                  onTap: () => _toggle(id),
                );
              },
            ),
          ),

        const SizedBox(height: AppSpacing.md),
        BottomSheetFooter(
          primaryLabel: _saving
              ? 'Menyimpan...'
              : _selectedIds.isEmpty
              ? 'Tambah Kelas'
              : 'Tambah ${_selectedIds.length} Kelas',
          primaryColor: primary,
          primaryEnabled: !_saving && _selectedIds.isNotEmpty,
          onPrimary: _save,
          onSecondary: _saving ? () {} : () => AppNavigator.pop(context),
        ),
      ],
    );
  }
}

class _TingkatTabs extends StatelessWidget {
  final List<String> options;
  final String selected;
  final Color primary;
  final ValueChanged<String> onChanged;

  const _TingkatTabs({
    required this.options,
    required this.selected,
    required this.primary,
    required this.onChanged,
  });

  String _label(String value) => value == 'all' ? 'Semua' : 'Tingkat $value';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          for (final opt in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(opt),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: selected == opt ? Colors.white : Colors.transparent,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    boxShadow: selected == opt
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _label(opt),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: selected == opt ? primary : ColorUtils.slate600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  final int count;
  final Color primary;
  final VoidCallback onClear;

  const _SelectionSummary({
    required this.count,
    required this.primary,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count kelas dipilih',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Text(
                'Bersihkan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Search extends StatelessWidget {
  final TextEditingController controller;
  final Color primary;

  const _Search({required this.controller, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: ColorUtils.slate400, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Cari kelas...',
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 13,
                color: ColorUtils.slate900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final Classroom model;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  const _PickRow({
    required this.model,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tingkat = (model.gradeLevel ?? '').trim();
    final wali = (model.homeroomTeacherName ?? '').trim();
    final subtitleParts = <String>[
      if (tingkat.isNotEmpty) 'Tingkat $tingkat',
      wali.isEmpty ? 'Wali: belum diset' : 'Wali: $wali',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.06) : Colors.white,
            border: Border.all(
              color: selected ? primary : ColorUtils.slate200,
              width: selected ? 1.4 : 0.75,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              _CheckBox(checked: selected, primary: primary),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.class_outlined, size: 18, color: ColorUtils.slate500),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name.isEmpty ? 'Kelas' : model.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
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

class _CheckBox extends StatelessWidget {
  final bool checked;
  final Color primary;

  const _CheckBox({required this.checked, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? primary : Colors.transparent,
        border: Border.all(
          color: checked ? primary : ColorUtils.slate300,
          width: 1.5,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      alignment: Alignment.center,
      child: checked
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}
