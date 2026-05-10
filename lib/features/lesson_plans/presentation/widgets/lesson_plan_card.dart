// RPP (lesson plan) list card — matches the brand mockup:
// subject letter avatar (color-coded by subject), title row with
// optional AI sparkle badge, chip strip (format · class · subject),
// time/date metadata row, and a status pill at the bottom.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';

class LessonPlanCard extends StatelessWidget {
  final Map<String, dynamic> lessonPlan;
  final Color primaryColor;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const LessonPlanCard({
    super.key,
    required this.lessonPlan,
    required this.primaryColor,
    required this.statusColor,
    required this.statusLabel,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  // ── Subject avatar ───────────────────────────────────────────
  // The avatar uses the teacher role color (cobalt) — same approach
  // as Presensi / Kegiatan Kelas / Rekap Nilai so the list reads as
  // a teacher tool. The rainbow per-subject palette was retired
  // together with the legacy summary view: it made every page feel
  // multi-colored instead of cobalt-themed.
  static Color _subjectColor(String subject) {
    if (subject.trim().isEmpty) return ColorUtils.slate400;
    return ColorUtils.getRoleColor('guru');
  }

  static String _initial(String s) {
    final t = s.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  // ── Format styling ───────────────────────────────────────────
  // Pulled from LessonPlanFormat's authoritative brand palette so
  // the badge stays in sync with the chooser tile, detail header,
  // and KPI cell. K13 is INDIGO (#4338CA) — not violet — so it
  // reads distinct from Modul Ajar's violet on the list.
  ({Color bg, Color fg, String label}) _formatStyle(LessonPlanFormat f) {
    return (bg: f.tintColor, fg: f.brandColor, label: f.shortLabel);
  }

  // ── Status styling ───────────────────────────────────────────
  ({IconData icon, Color bg, Color fg, String label}) _statusStyle() {
    final s = statusLabel.toLowerCase();
    if (s.contains('setuj') || s.contains('approv')) {
      return (
        icon: Icons.check_rounded,
        bg: const Color(0xFFD1FAE5),
        fg: const Color(0xFF047857),
        label: 'Disetujui',
      );
    }
    if (s.contains('tolak') || s.contains('reject') || s.contains('revisi')) {
      return (
        icon: Icons.close_rounded,
        bg: const Color(0xFFFEE2E2),
        fg: const Color(0xFFB91C1C),
        label: s.contains('revisi') ? 'Perlu revisi' : 'Ditolak',
      );
    }
    if (s.contains('draft') || s.contains('draf')) {
      return (
        icon: Icons.edit_note_rounded,
        bg: ColorUtils.slate100,
        fg: ColorUtils.slate600,
        label: 'Draf',
      );
    }
    // pending / menunggu / etc.
    return (
      icon: Icons.schedule_rounded,
      bg: const Color(0xFFFEF3C7),
      fg: const Color(0xFFB45309),
      label: 'Menunggu review',
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = LessonPlan.fromJson(lessonPlan);
    final subjectName = (model.subjectName ?? '').trim();
    final className = (model.className ?? '').trim();
    final format = LessonPlanFormat.fromMap(lessonPlan);
    final isAi = model.aiGenerated == true;
    final subColor = _subjectColor(subjectName);
    final fmt = _formatStyle(format);
    final stat = _statusStyle();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 6, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject-letter avatar — cobalt-tinted (the format
                // axis is already communicated by the format chip
                // below, no need to double-encode it on the avatar).
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: subColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _initial(subjectName),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: subColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Right column — title row + chip strip + meta row
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + AI badge + 3-dot menu (one row)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              model.title.isNotEmpty
                                  ? model.title
                                  : 'Tanpa Judul',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: ColorUtils.slate900,
                                height: 1.2,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAi) ...[
                            const SizedBox(width: 6),
                            const _AiSparklePill(),
                          ],
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') onEdit();
                                if (v == 'delete') onDelete();
                              },
                              icon: Icon(
                                Icons.more_vert_rounded,
                                size: 17,
                                color: ColorUtils.slate400,
                              ),
                              padding: EdgeInsets.zero,
                              splashRadius: 16,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  height: 40,
                                  child: Row(children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: ColorUtils.slate600,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Edit'),
                                  ]),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  height: 40,
                                  child: Row(children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: ColorUtils.error600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hapus',
                                      style: TextStyle(
                                        color: ColorUtils.error600,
                                      ),
                                    ),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Chip strip: format · class · subject. Wrap
                      // gracefully when the subject is long so the
                      // card doesn't overflow horizontally.
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _chip(
                            fmt.label,
                            fmt.bg,
                            fmt.fg,
                            icon: format == LessonPlanFormat.file
                                ? Icons.insert_drive_file_outlined
                                : null,
                          ),
                          if (className.isNotEmpty)
                            _chip(
                              className,
                              const Color(0xFFDBEAFE),
                              const Color(0xFF1D4ED8),
                            ),
                          if (subjectName.isNotEmpty)
                            _chip(
                              subjectName,
                              subColor.withValues(alpha: 0.10),
                              subColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Meta row — date on the left, status pill on
                      // the right. Combining them onto one row is the
                      // single biggest height saving vs the legacy
                      // stacked-rows card.
                      Row(
                        children: [
                          Icon(
                            format == LessonPlanFormat.file
                                ? Icons.insert_drive_file_outlined
                                : Icons.calendar_today_rounded,
                            size: 11,
                            color: ColorUtils.slate400,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatDate(model.createdAtDate),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: ColorUtils.slate500,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: stat.bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(stat.icon, size: 10, color: stat.fg),
                                const SizedBox(width: 3),
                                Text(
                                  stat.label,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: stat.fg,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 6 : 7,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Convert YYYY-MM-DD to a friendlier `DD MMM · DayName` form.
  /// Returns the raw input if parsing fails.
  String _formatDate(String raw) {
    if (raw.isEmpty || raw == '-') return '-';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final dn = days[d.weekday - 1];
    final mn = months[d.month - 1];
    return '${d.day} $mn · $dn';
  }
}

/// Small "✦ AI" pill rendered next to the title on AI-generated rows.
/// Violet is the app-wide AI signature color — same hue as the AI
/// Generate button on the setup sheet and the AI KPI cell.
class _AiSparklePill extends StatelessWidget {
  const _AiSparklePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 9, color: Color(0xFF7C3AED)),
          SizedBox(width: 3),
          Text(
            'AI',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7C3AED),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
