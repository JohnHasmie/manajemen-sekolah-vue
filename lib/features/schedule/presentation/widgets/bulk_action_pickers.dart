// Bulk-select picker sheets for the admin Jadwal hub (TR.F).
//
// Two surfaces:
//   * [showBulkDayPickerSheet] — admin chooses a target weekday (Senin–Sabtu)
//     for [ApiScheduleService.bulkMoveSessions]. Each session moves to the
//     equivalent lesson_hour on the target day, preserving its hour_number.
//   * [showBulkTeacherPickerSheet] — admin picks a teacher from the
//     available pool for [ApiScheduleService.bulkChangeTeacher]. The body
//     keeps a live search filter so long teacher lists stay scannable.
//
// Both sheets are thin wrappers around [AppBottomSheet] + a tile grid /
// list. They return the picked `id` via the modal's pop result, or null
// if the admin dismisses without choosing.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';

/// Opens the "Pindah Hari" picker. Returns the selected day_id, or null
/// when the admin dismisses without picking.
///
/// [days] is the visible weekday list (Senin–Sabtu) — typically the
/// screen's `_availableDays` filtered through `_visibleListDays` or any
/// equivalent helper that strips Minggu.
Future<String?> showBulkDayPickerSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> days,
  required int selectedCount,
}) {
  return AppBottomSheet.show<String>(
    context: context,
    title: 'Pindah Hari',
    subtitle: 'Pindahkan $selectedCount sesi ke hari berikut '
        '(jam ke- dipertahankan)',
    icon: Icons.swap_horiz_rounded,
    primaryColor: ColorUtils.brandDarkBlue,
    scrollable: false,
    contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    content: _DayGrid(days: days),
  );
}

/// Opens the "Ganti Guru" picker. Returns the selected teacher_id, or
/// null when the admin dismisses.
///
/// [teachers] is the available teacher list (usually the screen's
/// `_availableTeachers`). The sheet shows a search field for filtering
/// when the list is long.
Future<String?> showBulkTeacherPickerSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> teachers,
  required int selectedCount,
}) {
  return AppBottomSheet.show<String>(
    context: context,
    title: 'Ganti Guru',
    subtitle: 'Tugaskan $selectedCount sesi ke guru berikut',
    icon: Icons.person_rounded,
    primaryColor: ColorUtils.brandDarkBlue,
    scrollable: false,
    contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    content: _TeacherSearchList(teachers: teachers),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Day grid — 3-column chip grid, taller-than-wide tap targets
// ─────────────────────────────────────────────────────────────────────

class _DayGrid extends StatelessWidget {
  final List<Map<String, dynamic>> days;

  const _DayGrid({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Tidak ada data hari.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      children: [
        for (final d in days)
          _DayTile(
            label: (d['name'] ?? '').toString(),
            onTap: () => AppNavigator.pop(context, d['id']?.toString()),
          ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DayTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: ColorUtils.brandDarkBlue,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Teacher search list — search field + scrollable filtered list
// ─────────────────────────────────────────────────────────────────────

class _TeacherSearchList extends StatefulWidget {
  final List<Map<String, dynamic>> teachers;

  const _TeacherSearchList({required this.teachers});

  @override
  State<_TeacherSearchList> createState() => _TeacherSearchListState();
}

class _TeacherSearchListState extends State<_TeacherSearchList> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.teachers;
    return widget.teachers.where((t) {
      final name = (t['name'] ?? t['nama'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        children: [
          // Search field — only show when the pool is large enough to need it.
          if (widget.teachers.length > 6)
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                hintText: 'Cari guru...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: ColorUtils.slate400,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: ColorUtils.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: ColorUtils.slate200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: ColorUtils.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: ColorUtils.brandCobalt),
                ),
              ),
            ),
          if (widget.teachers.length > 6) const SizedBox(height: AppSpacing.sm),
          // Result list.
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.text.isEmpty
                          ? 'Tidak ada guru tersedia.'
                          : 'Tidak ada hasil untuk "${_query.text}".',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (_, i) {
                      final t = filtered[i];
                      final name = (t['name'] ?? t['nama'] ?? '—').toString();
                      final id = t['id']?.toString();
                      return _TeacherTile(
                        name: name,
                        onTap: id == null
                            ? null
                            : () => AppNavigator.pop(context, id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TeacherTile extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;

  const _TeacherTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Two-letter avatar from the name's initials — same pattern used by
    // the row card so the bulk picker visually matches the surface the
    // admin came from.
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = (parts.isEmpty
            ? '?'
            : parts.length == 1
                ? parts.first.substring(0, parts.first.length.clamp(0, 2))
                : '${parts.first[0]}${parts.last[0]}')
        .toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ColorUtils.brandCobalt.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.brandCobalt,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: ColorUtils.slate400,
            ),
          ],
        ),
      ),
    );
  }
}
