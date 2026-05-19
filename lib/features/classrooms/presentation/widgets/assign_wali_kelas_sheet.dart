// Assign Wali Kelas (homeroom teacher) sheet.
//
// Frame D in `_design/admin_mapel_detail_redesign.html`. Opens from
// either the wali-kelas chip on a Mapel-detail row (when wali is
// missing) or the kebab/long-press quick-action sheet.
//
// Teachers come from `GET /class/{id}/wali-candidates` already grouped
// into three buckets:
//   • current       — the teacher currently wali kelas for this class
//   • available     — teachers with no homeroom this academic year
//   • already_wali  — teachers wali for some other class this AY
//
// The "already_wali" bucket renders disabled with an amber warning
// pill showing their current class. Tapping a teacher selects them
// locally; the Simpan button hits PATCH /class/{id}/homeroom on save.
//
// Pass `teacherId: null` (the Lepas affordance) to clear the assignment.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';

class AssignWaliKelasSheet extends StatefulWidget {
  final String classId;
  final String className;
  final String? subjectName;

  const AssignWaliKelasSheet({
    super.key,
    required this.classId,
    required this.className,
    this.subjectName,
  });

  /// Opens the sheet wrapped in [AppBottomSheet]. Returns `true` when
  /// the wali kelas was changed (assigned or cleared) so the caller
  /// can refresh its data; `false`/`null` otherwise.
  static Future<bool?> show({
    required BuildContext context,
    required String classId,
    required String className,
    String? subjectName,
  }) {
    return AppBottomSheet.show<bool>(
      context: context,
      title: 'Tetapkan Wali Kelas',
      subtitle: subjectName != null
          ? 'Kelas $className · $subjectName'
          : 'Kelas $className',
      icon: Icons.person_outline_rounded,
      primaryColor: ColorUtils.getRoleColor('admin'),
      content: AssignWaliKelasSheet(
        classId: classId,
        className: className,
        subjectName: subjectName,
      ),
    );
  }

  @override
  State<AssignWaliKelasSheet> createState() => _AssignWaliKelasSheetState();
}

class _AssignWaliKelasSheetState extends State<AssignWaliKelasSheet> {
  final _service = ApiClassService();
  final _searchController = TextEditingController();

  Map<String, dynamic>? _currentWali;
  List<Map<String, dynamic>> _available = const [];
  List<Map<String, dynamic>> _alreadyWali = const [];

  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _selectedTeacherId;
  bool _selectionDirty = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await _service.getWaliCandidates(widget.classId);
      final current = res['current'] is Map<String, dynamic>
          ? res['current'] as Map<String, dynamic>
          : null;
      final available = (res['available'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final alreadyWali = (res['already_wali'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      setState(() {
        _currentWali = current;
        _available = available;
        _alreadyWali = alreadyWali;
        _selectedTeacherId = current?['id'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = 'Gagal memuat daftar guru: $e';
      });
    }
  }

  void _selectTeacher(String? teacherId) {
    setState(() {
      _selectedTeacherId = teacherId;
      _selectionDirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.setHomeroomTeacher(widget.classId, _selectedTeacherId);
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        _selectedTeacherId == null
            ? 'Wali kelas berhasil dihapus'
            : 'Wali kelas berhasil diperbarui',
      );
      AppNavigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Gagal menyimpan wali kelas: $e');
      setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> teachers) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return teachers;
    return teachers
        .where((t) {
          final name = (t['name'] ?? '').toString().toLowerCase();
          final nip = (t['employee_number'] ?? '').toString().toLowerCase();
          return name.contains(q) || nip.contains(q);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: EmptyState(
          title: 'Gagal memuat',
          subtitle: _loadError!,
          icon: Icons.error_outline_rounded,
          onPressed: _fetch,
          buttonText: 'Coba lagi',
        ),
      );
    }

    final primary = ColorUtils.getRoleColor('admin');
    final filteredAvailable = _filter(_available);
    final filteredAlready = _filter(_alreadyWali);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Search(controller: _searchController, primary: primary),
        const SizedBox(height: AppSpacing.md),
        if (_currentWali != null) ...[
          _SectionHeader(title: 'Saat ini', accent: primary),
          _TeacherRow(
            teacher: _currentWali!,
            isSelected: _selectedTeacherId == _currentWali!['id'],
            primary: primary,
            onTap: () => _selectTeacher(_currentWali!['id'] as String?),
          ),
          // Inline "Lepas wali" affordance — clears the selection so
          // Simpan submits null.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 4,
            ),
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      _selectTeacher(null);
                    },
              icon: Icon(
                Icons.person_remove_outlined,
                size: 18,
                color: ColorUtils.error600,
              ),
              label: Text(
                'Lepas wali kelas',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.error600,
                ),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (filteredAvailable.isNotEmpty) ...[
          _SectionHeader(title: 'Tersedia', accent: primary),
          for (final t in filteredAvailable)
            _TeacherRow(
              teacher: t,
              isSelected: _selectedTeacherId == t['id'],
              primary: primary,
              onTap: () => _selectTeacher(t['id'] as String?),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (filteredAlready.isNotEmpty) ...[
          _SectionHeader(
            title: 'Sudah jadi wali',
            accent: primary,
            warning: true,
          ),
          for (final t in filteredAlready)
            _TeacherRow(
              teacher: t,
              isSelected: _selectedTeacherId == t['id'],
              primary: primary,
              warning: true,
              onTap: () => _selectTeacher(t['id'] as String?),
            ),
        ],
        if (filteredAvailable.isEmpty &&
            filteredAlready.isEmpty &&
            _currentWali == null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              title: 'Tidak ada guru',
              subtitle: 'Tidak ada guru yang cocok dengan pencarian',
              icon: Icons.search_off_rounded,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        BottomSheetFooter(
          primaryLabel: _saving ? 'Menyimpan...' : 'Simpan',
          primaryColor: primary,
          primaryEnabled: !_saving && _selectionDirty,
          onPrimary: _save,
          onSecondary: _saving ? () {} : () => AppNavigator.pop(context),
        ),
      ],
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
                hintText: 'Cari nama / NIP guru...',
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color accent;
  final bool warning;

  const _SectionHeader({
    required this.title,
    required this.accent,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: warning ? ColorUtils.warning600 : accent,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _TeacherRow extends StatelessWidget {
  final Map<String, dynamic> teacher;
  final bool isSelected;
  final bool warning;
  final Color primary;
  final VoidCallback onTap;

  const _TeacherRow({
    required this.teacher,
    required this.isSelected,
    required this.primary,
    required this.onTap,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = (teacher['name'] ?? '').toString();
    final nip = (teacher['employee_number'] ?? '').toString();
    final currentClassName = (teacher['current_class_name'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? primary.withValues(alpha: 0.06) : Colors.white,
            border: Border.all(
              color: isSelected ? primary : ColorUtils.slate200,
              width: isSelected ? 1.4 : 0.75,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              InitialsAvatar(
                name: name.isEmpty ? '?' : name,
                size: 40,
                color: primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '—' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    if (nip.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'NIP $nip',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                    if (warning && currentClassName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ColorUtils.warning600.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Wali $currentClassName',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.warning600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? primary : ColorUtils.slate300,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
