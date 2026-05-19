// Slot cluster expansion sheet — Frame B of the density layout (TR.I.4).
//
// Surfaces every session at a single (day · lesson_hour) slot when the
// admin taps the aggregator card in the week grid. With 21 classes
// stacked into one cell the grid can only show a count + preview;
// this sheet is the actual list — searchable, filter-tabbed, with
// inline edit / move actions per row.
//
// Composition
// -----------
//   Navy-gradient header (day + time, count + bentrok pill)
//     ↓
//   Search field
//     ↓
//   Filter tabs (Semua · Bentrok · per-mapel)
//     ↓
//   Scrollable row list — compact variant of AdminScheduleRowCard
//   without the time column (time is in the header)
//     ↓
//   Footer: Tutup (secondary) · + Tambah di slot ini (primary)
//
// Callbacks
//   * [onOpenDetail] — tap a row → opens the existing detail sheet.
//   * [onMoveSession] — ⇄ icon → opens the day picker for that row.
//   * [onAddInSlot]   — Tambah CTA → opens the add form pre-filled with
//                       the slot's day + lesson_hour.
//
// The sheet pops with `true` when anything changed (edit / move / add)
// so the caller can refresh; `false` or `null` on plain dismiss.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule_kpi_summary.dart';

/// Opens the cluster expansion sheet for [sessions] (every session
/// sharing one day + lesson_hour slot).
///
/// Returns `true` if anything inside the sheet changed the underlying
/// data (so the caller can refresh the list); `false` / `null` if the
/// admin just dismissed without acting.
Future<bool?> showSlotClusterSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> sessions,
  required String dayName,
  required String startTime,
  required String endTime,
  required void Function(Map<String, dynamic> session) onOpenDetail,
  required void Function(Map<String, dynamic> session) onMoveSession,
  required VoidCallback onAddInSlot,
}) {
  return AppBottomSheet.show<bool>(
    context: context,
    title: '$dayName · $startTime${endTime.isNotEmpty ? ' – $endTime' : ''}',
    subtitle: _composeSubtitle(sessions),
    icon: Icons.calendar_today_rounded,
    primaryColor: ColorUtils.getRoleColor('admin'),
    scrollable: false,
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
    content: _SlotClusterContent(
      sessions: sessions,
      onOpenDetail: onOpenDetail,
      onMoveSession: onMoveSession,
    ),
    footer: BottomSheetFooter(
      primaryLabel: '+ Tambah di slot ini',
      secondaryLabel: 'Tutup',
      primaryColor: ColorUtils.brandCobalt,
      onPrimary: () {
        AppNavigator.pop(context, true);
        onAddInSlot();
      },
      onSecondary: () => AppNavigator.pop(context),
    ),
  );
}

/// Builds the "N sesi di slot ini · M bentrok" header subtitle. Falls
/// back to just the session count when nothing is bentrok.
String _composeSubtitle(List<Map<String, dynamic>> sessions) {
  final total = sessions.length;
  final conflicts = sessions.where((s) => s.hasScheduleConflict).length;
  if (conflicts == 0) return '$total sesi di slot ini';
  return '$total sesi di slot ini · $conflicts bentrok';
}

// ─────────────────────────────────────────────────────────────────────
// Body — search + tabs + list
// ─────────────────────────────────────────────────────────────────────

class _SlotClusterContent extends StatefulWidget {
  final List<Map<String, dynamic>> sessions;
  final void Function(Map<String, dynamic> session) onOpenDetail;
  final void Function(Map<String, dynamic> session) onMoveSession;

  const _SlotClusterContent({
    required this.sessions,
    required this.onOpenDetail,
    required this.onMoveSession,
  });

  @override
  State<_SlotClusterContent> createState() => _SlotClusterContentState();
}

class _SlotClusterContentState extends State<_SlotClusterContent> {
  final TextEditingController _query = TextEditingController();

  /// Active filter — either a subject name or one of the special
  /// constants `_kAll` / `_kConflict`. Backed by a String so the
  /// FilterChipGrid-style equality just works.
  String _activeFilter = _kAll;

  static const _kAll = '__all__';
  static const _kConflict = '__conflict__';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// All distinct subjects present in this slot's sessions, sorted by
  /// occurrence count desc (so the most common appears first).
  List<String> get _subjects {
    final counts = <String, int>{};
    for (final s in widget.sessions) {
      final name = (s['subject_name'] ?? s['mata_pelajaran_nama'] ?? '')
          .toString();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final entries = counts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList(growable: false);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.text.trim().toLowerCase();
    return widget.sessions
        .where((s) {
          // Subject / conflict filter.
          if (_activeFilter == _kConflict && !s.hasScheduleConflict) {
            return false;
          } else if (_activeFilter != _kAll && _activeFilter != _kConflict) {
            final subj = (s['subject_name'] ?? s['mata_pelajaran_nama'] ?? '')
                .toString();
            if (subj != _activeFilter) return false;
          }
          // Free-text search across class / subject / teacher.
          if (q.isEmpty) return true;
          final fields = [
            s['class_name'],
            s['kelas_nama'],
            s['subject_name'],
            s['mata_pelajaran_nama'],
            s['teacher_name'],
            s['guru_nama'],
            s['room'],
            s['ruangan'],
          ].whereType<String>().map((e) => e.toLowerCase()).toList();
          return fields.any((f) => f.contains(q));
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final conflictCount = widget.sessions
        .where((s) => s.hasScheduleConflict)
        .length;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          // Search field.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                hintText: 'Cari mapel / kelas / guru...',
                hintStyle: TextStyle(fontSize: 13, color: ColorUtils.slate400),
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
          ),
          // Filter tabs.
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterTab(
                  label: 'Semua · ${widget.sessions.length}',
                  active: _activeFilter == _kAll,
                  onTap: () => setState(() => _activeFilter = _kAll),
                ),
                if (conflictCount > 0) ...[
                  const SizedBox(width: 6),
                  _FilterTab(
                    label: 'Bentrok · $conflictCount',
                    active: _activeFilter == _kConflict,
                    destructive: true,
                    onTap: () => setState(() => _activeFilter = _kConflict),
                  ),
                ],
                for (final subj in _subjects) ...[
                  const SizedBox(width: 6),
                  _FilterTab(
                    label: subj,
                    active: _activeFilter == subj,
                    onTap: () => setState(() => _activeFilter = subj),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Result list.
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.text.isNotEmpty
                          ? 'Tidak ada hasil untuk "${_query.text}".'
                          : 'Tidak ada sesi pada filter ini.',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return _ClusterRow(
                        schedule: s,
                        onTap: () {
                          AppNavigator.pop(context, true);
                          widget.onOpenDetail(s);
                        },
                        onMove: () {
                          AppNavigator.pop(context, true);
                          widget.onMoveSession(s);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Filter tab + row tile
// ─────────────────────────────────────────────────────────────────────

class _FilterTab extends StatelessWidget {
  final String label;
  final bool active;
  final bool destructive;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = destructive
        ? ColorUtils.error600
        : ColorUtils.getRoleColor('admin');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          border: Border.all(
            color: active
                ? activeColor
                : (destructive
                      ? ColorUtils.error600.withValues(alpha: 0.35)
                      : ColorUtils.slate200),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: active
                ? Colors.white
                : (destructive ? ColorUtils.error600 : ColorUtils.slate700),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _ClusterRow extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final VoidCallback onTap;
  final VoidCallback onMove;

  const _ClusterRow({
    required this.schedule,
    required this.onTap,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final subject =
        (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'] ?? '—')
            .toString();
    final className = (schedule['class_name'] ?? schedule['kelas_nama'] ?? '')
        .toString();
    final teacher = (schedule['teacher_name'] ?? schedule['guru_nama'] ?? '')
        .toString();
    final room = (schedule['room'] ?? schedule['ruangan'] ?? '').toString();
    final isConflict = schedule.hasScheduleConflict;

    final avatarText = className.isEmpty
        ? '?'
        : (className.length <= 2
              ? className.toUpperCase()
              : className.substring(0, 2).toUpperCase());

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: isConflict
              ? ColorUtils.error600.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isConflict
                ? ColorUtils.error600.withValues(alpha: 0.35)
                : ColorUtils.slate200,
          ),
        ),
        child: Row(
          children: [
            // 2-letter class avatar.
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isConflict
                    ? ColorUtils.error600
                    : ColorUtils.brandCobalt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                avatarText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Body.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isConflict) ...[
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: ColorUtils.error600,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isConflict
                                ? ColorUtils.error600
                                : ColorUtils.slate900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (teacher.isNotEmpty || room.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          teacher,
                          if (room.isNotEmpty) room,
                        ].where((e) => e.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Move-slot icon (cobalt). Tap → close sheet → open day picker.
            _IconBtn(
              icon: Icons.swap_horiz_rounded,
              tooltip: 'Pindah Slot',
              onTap: onMove,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ColorUtils.slate100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: ColorUtils.brandCobalt),
        ),
      ),
    );
  }
}
