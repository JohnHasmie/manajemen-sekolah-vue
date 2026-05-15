// Bottom sheet shown when an admin taps a schedule row or grid block —
// Frame C of the admin Jadwal redesign.
//
// Layout
// ------
// Navy admin gradient header (mapel icon + title + day/time subtitle)
//   ↓
// 2-column meta-tile grid: Mata Pelajaran · Kelas · Guru · Ruangan ·
//   Jam Ke- · Durasi (+ full-width Catatan when present)
//   ↓
// "Aksi Cepat" kicker
//   ↓
// 2×2 action tiles: Edit Lengkap · Pindah Slot · Duplikat · Hapus
//   ↓
// Footer: Tutup (secondary) · Edit (cobalt primary)
//
// Migrated from the legacy `showAdminEntityDetailSheet` (BrandListRow-
// style sections) so the surface matches the redesign's brand chrome
// and exposes the four quick actions called out in the mockup.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';

/// Shows the Frame C detail / quick-edit sheet for a single schedule.
///
/// Callers:
/// * [onEdit] — open the full add/edit form sheet pre-filled with the
///   current row's values.
/// * [onDelete] — open the destructive confirm (existing screen handler).
/// * [onDuplicate] — open the add/edit form in "duplicate" mode (no id,
///   same teacher/class/subject, but fresh slot pick).
/// * [onMoveSlot] — launches Frame E drag-to-reschedule pre-selecting
///   this session. The screen wires this to a no-op + snack until TR.E
///   ships the drag implementation.
void showAdminScheduleDetailSheet({
  required BuildContext context,
  required Map<String, dynamic> schedule,
  required AdminScheduleController controller,
  required LanguageProvider lang,
  required List<dynamic> dayList,
  required bool isReadOnly,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onDuplicate,
  required VoidCallback onMoveSlot,
  required VoidCallback onChangeTeacher,
}) {
  AppBottomSheet.show<void>(
    context: context,
    title: lang.getTranslatedText(const {
      'en': 'Session Detail',
      'id': 'Detail Sesi Kelas',
    }),
    subtitle: _composeHeaderSubtitle(schedule, controller, lang, dayList),
    icon: Icons.menu_book_rounded,
    primaryColor: ColorUtils.brandDarkBlue,
    content: _DetailContent(
      schedule: schedule,
      lang: lang,
      isReadOnly: isReadOnly,
      onEdit: onEdit,
      onDelete: onDelete,
      onDuplicate: onDuplicate,
      onMoveSlot: onMoveSlot,
      onChangeTeacher: onChangeTeacher,
    ),
    footer: BottomSheetFooter(
      primaryLabel: isReadOnly
          ? lang.getTranslatedText(const {'en': 'Close', 'id': 'Tutup'})
          : lang.getTranslatedText(const {'en': 'Edit', 'id': 'Edit'}),
      secondaryLabel: lang.getTranslatedText(const {
        'en': 'Close',
        'id': 'Tutup',
      }),
      primaryColor: ColorUtils.brandCobalt,
      onPrimary: () {
        AppNavigator.pop(context);
        if (!isReadOnly) onEdit();
      },
      onSecondary: () => AppNavigator.pop(context),
    ),
  );
}

/// Builds the subtitle line under the sheet's title — "Senin · 14 Mei
/// 2026 · 07:00 — 08:30" style. Falls back gracefully when fields are
/// missing so the sheet never renders a half-empty subtitle.
String _composeHeaderSubtitle(
  Map<String, dynamic> schedule,
  AdminScheduleController controller,
  LanguageProvider lang,
  List<dynamic> dayList,
) {
  final dayLabel = controller.formatScheduleDays(
    schedule,
    dayList,
    lang.currentLanguage,
  );
  final timeLabel = controller.formatTime(schedule);
  final pieces = <String>[
    if (dayLabel.isNotEmpty) dayLabel,
    if (timeLabel.isNotEmpty) timeLabel,
  ];
  return pieces.join(' · ');
}

// ─────────────────────────────────────────────────────────────────────
// Body — meta-tile grid + Aksi Cepat
// ─────────────────────────────────────────────────────────────────────

class _DetailContent extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final LanguageProvider lang;
  final bool isReadOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onMoveSlot;
  final VoidCallback onChangeTeacher;

  const _DetailContent({
    required this.schedule,
    required this.lang,
    required this.isReadOnly,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onMoveSlot,
    required this.onChangeTeacher,
  });

  @override
  Widget build(BuildContext context) {
    final subject =
        (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'] ?? '—')
            .toString();
    final className =
        (schedule['class_name'] ?? schedule['kelas_nama'] ?? '—').toString();
    final teacher =
        (schedule['teacher_name'] ?? schedule['guru_nama'] ?? '—').toString();
    final room =
        (schedule['room'] ?? schedule['ruangan'] ?? '—').toString();
    final lessonHour = _readLessonHour(schedule);
    final duration = _formatDuration(schedule);
    final notes =
        (schedule['description'] ?? schedule['catatan'] ?? '').toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Meta-tile grid ────────────────────────────────────────
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2.5,
          children: [
            _MetaTile(
              label: lang.getTranslatedText(const {
                'en': 'Subject',
                'id': 'Mata Pelajaran',
              }),
              value: subject,
            ),
            _MetaTile(
              label: lang.getTranslatedText(const {
                'en': 'Class',
                'id': 'Kelas',
              }),
              value: className,
              accent: true,
            ),
            _MetaTile(
              label: lang.getTranslatedText(const {
                'en': 'Teacher',
                'id': 'Guru Pengampu',
              }),
              value: teacher,
            ),
            _MetaTile(
              label: lang.getTranslatedText(const {
                'en': 'Room',
                'id': 'Ruangan',
              }),
              value: room,
            ),
            _MetaTile(
              label: lang.getTranslatedText(const {
                'en': 'Hour',
                'id': 'Jam Ke-',
              }),
              value: lessonHour,
            ),
            _MetaTile(
              label: lang.getTranslatedText(const {
                'en': 'Duration',
                'id': 'Durasi',
              }),
              value: duration ?? '—',
            ),
          ],
        ),

        if (notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _MetaTile(
            label: lang.getTranslatedText(const {
              'en': 'Notes',
              'id': 'Catatan',
            }),
            value: notes,
            fullWidth: true,
            valueStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate700,
              height: 1.4,
            ),
          ),
        ],

        // ── Aksi Cepat ────────────────────────────────────────────
        if (!isReadOnly) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionHead(
            label: lang.getTranslatedText(const {
              'en': 'Quick Actions',
              'id': 'Aksi Cepat',
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.1,
            children: [
              _ActionTile(
                icon: Icons.edit_outlined,
                label: lang.getTranslatedText(const {
                  'en': 'Edit Full',
                  'id': 'Edit Lengkap',
                }),
                onTap: () {
                  AppNavigator.pop(context);
                  onEdit();
                },
              ),
              _ActionTile(
                icon: Icons.swap_horiz_rounded,
                label: lang.getTranslatedText(const {
                  'en': 'Move Slot',
                  'id': 'Pindah Slot',
                }),
                onTap: () {
                  AppNavigator.pop(context);
                  onMoveSlot();
                },
              ),
              _ActionTile(
                icon: Icons.person_search_rounded,
                label: lang.getTranslatedText(const {
                  'en': 'Change Teacher',
                  'id': 'Ganti Guru',
                }),
                onTap: () {
                  AppNavigator.pop(context);
                  onChangeTeacher();
                },
              ),
              _ActionTile(
                icon: Icons.content_copy_rounded,
                label: lang.getTranslatedText(const {
                  'en': 'Duplicate',
                  'id': 'Duplikat',
                }),
                onTap: () {
                  AppNavigator.pop(context);
                  onDuplicate();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Hapus sits below the grid as a full-width destructive
          // affordance so it can't be confused with the safe actions.
          SizedBox(
            width: double.infinity,
            child: _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: lang.getTranslatedText(const {
                'en': 'Delete',
                'id': 'Hapus',
              }),
              destructive: true,
              onTap: () {
                AppNavigator.pop(context);
                onDelete();
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Returns a "90 mnt" style label by diffing start_time and end_time.
  String? _formatDuration(Map<String, dynamic> s) {
    int? toMinutes(dynamic raw) {
      if (raw == null) return null;
      final parts = raw.toString().replaceAll('.', ':').split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return h * 60 + m;
    }

    // Read start/end from the flat fields first, then fall back to the
    // nested `lesson_hour` Map for un-normalized payloads (e.g. a row
    // opened from the cache before _normalizeScheduleRows ran).
    dynamic start = s['start_time'];
    dynamic end = s['end_time'];
    if (start == null || end == null) {
      final lh = s['lesson_hour'];
      if (lh is Map) {
        start ??= lh['start_time'] ?? lh['jam_mulai'];
        end ??= lh['end_time'] ?? lh['jam_selesai'];
      }
    }
    final startMin = toMinutes(start);
    final endMin = toMinutes(end);
    if (startMin == null || endMin == null || endMin <= startMin) {
      return null;
    }
    return '${endMin - startMin} mnt';
  }

  /// Resolves the "Jam Ke-" label from a schedule row.
  ///
  /// Handles three payload shapes:
  ///   * Already normalized: `row['lesson_hour']` is an int → render as
  ///     "1", "2", etc.
  ///   * Raw API: `row['lesson_hour']` is the eager-loaded Map
  ///     `{id, hour_number, start_time, ...}` → reach into `hour_number`.
  ///   * Indonesian alias: `row['jam_ke']` flat number.
  ///
  /// Previously this site called `(row['lesson_hour'] ?? '...').toString()`
  /// which rendered the entire Map ("{id: 019d7e0f-..., ...}") into the
  /// detail tile when the row hadn't been normalized yet.
  String _readLessonHour(Map<String, dynamic> s) {
    final lh = s['lesson_hour'];
    if (lh is num) return lh.toInt().toString();
    if (lh is String && lh.isNotEmpty) return lh;
    if (lh is Map) {
      final hn = lh['hour_number'] ?? lh['jam_ke'];
      if (hn != null) return hn.toString();
    }
    final jamKe = s['jam_ke'] ?? s['hour_number'];
    if (jamKe != null) return jamKe.toString();
    return '—';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Meta tile — small slate-50 card with label kicker + value
// ─────────────────────────────────────────────────────────────────────

class _MetaTile extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  final bool fullWidth;
  final TextStyle? valueStyle;

  const _MetaTile({
    required this.label,
    required this.value,
    this.accent = false,
    this.fullWidth = false,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: fullWidth ? 4 : 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle ??
                TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: accent ? ColorUtils.brandCobalt : ColorUtils.slate900,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );

    if (fullWidth) return SizedBox(width: double.infinity, child: tile);
    return tile;
  }
}

// ─────────────────────────────────────────────────────────────────────
// Section head — kicker bar + uppercase label
// ─────────────────────────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  final String label;
  const _SectionHead({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 11,
          decoration: BoxDecoration(
            color: ColorUtils.brandCobalt,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate500,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Action tile — Aksi Cepat 2×2 grid
// ─────────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? ColorUtils.error600 : ColorUtils.brandCobalt;
    final border = destructive
        ? ColorUtils.error600.withValues(alpha: 0.4)
        : ColorUtils.slate200;
    return Material(
      color: destructive
          ? ColorUtils.error600.withValues(alpha: 0.04)
          : ColorUtils.slate50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
