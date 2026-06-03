// Daftar Siswa preview card for the teacher activity-detail screen.
//
// Extracted verbatim from `_TeacherActivityDetailScreenState`:
//   • [ActivityStudentListSection] — was `_studentListSection`.
//   • `_statusBreakdownPill` / `_studentRow` are now private helpers here.
//
// Focused on the actionable Belum bucket:
//   • a status breakdown strip at the top (Belum N · Sudah N · …)
//   • only the Belum rows inline (max 5), since those are the ones a
//     teacher actually scans the list for
//   • a "+N belum lainnya" tail line ONLY when the bucket overflows
//   • a "Semua siswa sudah dicatat ✓" empty-state when Belum is cleared
//
// Rendered only for tugas/ujian/kuis with non-empty submissions; the
// screen guards that before building this.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_specs.dart';

/// Daftar Siswa preview card driven by the [submissions] rows.
class ActivityStudentListSection extends StatelessWidget {
  final LanguageProvider lp;

  /// Sorted submission rows (pending first) — the screen's `_submissions`.
  final List<Map<String, dynamic>> submissions;

  const ActivityStudentListSection({
    super.key,
    required this.lp,
    required this.submissions,
  });

  @override
  Widget build(BuildContext context) {
    int belum = 0, sudah = 0, telat = 0, izin = 0;
    final pendingRows = <Map<String, dynamic>>[];
    for (final r in submissions) {
      switch ((r['status'] ?? 'pending').toString()) {
        case 'submitted':
          sudah++;
          break;
        case 'late':
          telat++;
          break;
        case 'excused':
          izin++;
          break;
        default:
          belum++;
          pendingRows.add(r);
      }
    }
    final preview = pendingRows.take(5).toList();
    final extraBelum = pendingRows.length - preview.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lp.getTranslatedText({
                      'en': 'Student list',
                      'id': 'Daftar Siswa',
                    }).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Text(
                  '${submissions.length} siswa',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Status breakdown strip — replaces the redundant "Lihat semua"
          // tail with at-a-glance counts. Only renders the buckets that
          // have rows so it stays compact for fresh activities.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (belum > 0)
                  _statusBreakdownPill(
                    count: belum,
                    label: 'Belum',
                    spec: activityStatusSpec('pending'),
                  ),
                if (sudah > 0)
                  _statusBreakdownPill(
                    count: sudah,
                    label: 'Sudah',
                    spec: activityStatusSpec('submitted'),
                  ),
                if (telat > 0)
                  _statusBreakdownPill(
                    count: telat,
                    label: 'Telat',
                    spec: activityStatusSpec('late'),
                  ),
                if (izin > 0)
                  _statusBreakdownPill(
                    count: izin,
                    label: 'Izin',
                    spec: activityStatusSpec('excused'),
                  ),
              ],
            ),
          ),
          // Belum bucket — the actionable section. Empty state when the
          // bucket is cleared signals "all caught up".
          if (preview.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: ColorUtils.success600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lp.getTranslatedText({
                        'en': 'All students recorded',
                        'id': 'Semua siswa sudah dicatat',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.success600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              height: 1,
              color: ColorUtils.slate100,
            ),
            for (int i = 0; i < preview.length; i++) ...[
              if (i > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  height: 1,
                  color: ColorUtils.slate100,
                ),
              _studentRow(preview[i]),
            ],
            if (extraBelum > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Text(
                  '+ $extraBelum siswa lainnya belum submit',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// One pill in the breakdown strip. Tinted background, colored count
  /// + tiny status word inside. Used as a glanceable summary at the
  /// top of the Daftar Siswa card.
  Widget _statusBreakdownPill({
    required int count,
    required String label,
    required ActivityStatusSpec spec,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: spec.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: spec.fg,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: spec.fg,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentRow(Map<String, dynamic> r) {
    final name = (r['student_name'] ?? '-').toString();
    final status = (r['status'] ?? 'pending').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final spec = activityStatusSpec(status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: ColorUtils.slate700,
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
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: spec.tint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              spec.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: spec.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
