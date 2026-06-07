// Class card on the rekomendasi hub — Frame A of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Layout, top to bottom:
//   • Header row — 44dp cobalt subject icon, kicker (`VII A · WALI` /
//     `VIII B · MENGAJAR`), bold class name, slate meta line, chevron.
//   • 4-cell stats grid (PENDING amber / PROSES cobalt / SELESAI green /
//     DITOLAK slate) sourced from the rec summary's by_status map.
//   • Gradient progress bar — cobalt→azure when 40-79%, success ≥80,
//     amber 1-39%, slate when no recs yet.
//   • Dual CTA row:
//       – Lihat Siswa (cobalt-tonal) — opens the student list.
//       – Buat Baru (violet AI) — generates fresh recs. Switches to
//         the dashed variant when the class has zero recs yet.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class RecommendationClassCard extends StatelessWidget {
  final String className;
  final String classId;
  final Map<String, dynamic> classData;
  final Map<String, dynamic>? summary;
  final Color primaryColor;
  final bool isLoading;
  final bool isGenerating;
  final bool schedulesLoaded;
  final List<Map<String, dynamic>> history;
  final bool isLoadingHistory;
  final VoidCallback onGenerate;
  final VoidCallback onViewStudents;
  final void Function(Map<String, dynamic> entry) onHistoryItemTap;

  /// Whether this card is being rendered inside the wali-kelas scope
  /// — drives the "VII A · WALI" vs "VIII B · MENGAJAR" kicker.
  final bool isHomeroom;

  const RecommendationClassCard({
    super.key,
    required this.className,
    required this.classId,
    required this.classData,
    required this.primaryColor,
    required this.onGenerate,
    required this.onViewStudents,
    required this.onHistoryItemTap,
    this.summary,
    this.isLoading = false,
    this.isGenerating = false,
    this.schedulesLoaded = false,
    this.history = const [],
    this.isLoadingHistory = false,
    this.isHomeroom = false,
  });

  // ── Helpers ─────────────────────────────────────────────────────

  Map<String, int> _toCountMap(dynamic data) {
    if (data is Map) {
      return data.map(
        (k, v) => MapEntry(
          k.toString(),
          v is int ? v : int.tryParse(v.toString()) ?? 0,
        ),
      );
    }
    return {};
  }

  int _readStudentCount() {
    final raw =
        classData['students_count'] ??
        classData['student_count'] ??
        classData['jumlah_siswa'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String? _subjectName() {
    final raw =
        classData['subject_name'] ??
        classData['mapel_name'] ??
        classData['subject']?.toString();
    final s = raw?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  ({int pending, int proses, int selesai, int dismissed, int total})
  _statsBundle() {
    final byStatus = _toCountMap(summary?['by_status']);
    final pending = byStatus['pending'] ?? 0;
    final proses = byStatus['in_progress'] ?? 0;
    final selesai = byStatus['completed'] ?? 0;
    final dismissed = byStatus['dismissed'] ?? 0;
    final total = pending + proses + selesai + dismissed;
    return (
      pending: pending,
      proses: proses,
      selesai: selesai,
      dismissed: dismissed,
      total: total,
    );
  }

  double _completionPct() {
    final s = _statsBundle();
    if (s.total == 0) return 0;
    return (s.selesai / s.total) * 100;
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final s = _statsBundle();
    final pct = _completionPct();
    final hasActivity = s.total > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onViewStudents,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(cobalt),
                const SizedBox(height: 12),
                if (isLoading) _buildSkeletonStats() else _buildStatsRow(s),
                const SizedBox(height: 10),
                _buildProgressBar(pct),
                const SizedBox(height: 12),
                _buildCtaRow(hasActivity),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(Color cobalt) {
    final studentCount = _readStudentCount();
    final s = _statsBundle();
    final studentText = studentCount > 0
        ? '$studentCount siswa'
        : 'Belum ada siswa';
    final subject = _subjectName();
    final kicker = isHomeroom
        ? '${className.toUpperCase()} · WALI'
        : (subject != null
              ? '${className.toUpperCase()} · MENGAJAR'
              : '${className.toUpperCase()} · KELAS');
    final metaSubject = subject != null && !isHomeroom ? ' · $subject' : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cobalt.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            isHomeroom ? Icons.menu_book_rounded : Icons.auto_stories_rounded,
            size: 18,
            color: cobalt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kicker,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: cobalt,
                  letterSpacing: 0.4,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Kelas $className$metaSubject',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$studentText · ${s.total} rekomendasi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate500,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: 18, color: ColorUtils.slate400),
      ],
    );
  }

  Widget _buildStatsRow(
    ({int pending, int proses, int selesai, int dismissed, int total}) s,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            value: '${s.pending}',
            label: kRecPendingUpper.tr,
            color: ColorUtils.warning600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatCell(
            value: '${s.proses}',
            label: kRecInProgressUpper.tr,
            color: ColorUtils.brandCobalt,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatCell(
            value: '${s.selesai}',
            label: kRecCompletedUpper.tr,
            color: ColorUtils.success600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatCell(
            value: '${s.dismissed}',
            label: kRecRejectedUpper.tr,
            color: s.dismissed > 0 ? ColorUtils.error600 : ColorUtils.slate500,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonStats() {
    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
            height: 50,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProgressBar(double pct) {
    final color = _completionColor(pct);
    return SizedBox(
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(color: ColorUtils.slate100),
            FractionallySizedBox(
              widthFactor: (pct / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: pct >= 40 && pct < 80
                      ? LinearGradient(
                          colors: [
                            ColorUtils.brandCobalt,
                            ColorUtils.brandAzure,
                          ],
                        )
                      : null,
                  color: pct >= 40 && pct < 80 ? null : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _completionColor(double pct) {
    if (pct >= 80) return ColorUtils.success600;
    if (pct >= 40) return ColorUtils.brandCobalt;
    if (pct >= 1) return ColorUtils.warning600;
    return ColorUtils.slate400;
  }

  Widget _buildCtaRow(bool hasActivity) {
    final cobalt = ColorUtils.brandCobalt;
    final violet = ColorUtils.violet700;
    return Row(
      children: [
        Expanded(
          child: _CardCta(
            icon: Icons.people_alt_rounded,
            label: kRecViewStudents.tr,
            color: cobalt,
            variant: _CtaVariant.tonal,
            onTap: onViewStudents,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CardCta(
            icon: Icons.auto_awesome_rounded,
            label: isGenerating ? kRecProcessingEllipsisShort.tr : kRecCreateNew.tr,
            color: violet,
            // Filled when there's already activity (this is a refresh
            // action), dashed-outline when the class is empty so the
            // "first generate" feels distinct.
            variant: hasActivity ? _CtaVariant.filled : _CtaVariant.dashed,
            onTap: isGenerating ? null : onGenerate,
            busy: isGenerating,
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

enum _CtaVariant { tonal, filled, dashed }

class _CardCta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final _CtaVariant variant;
  final VoidCallback? onTap;
  final bool busy;

  const _CardCta({
    required this.icon,
    required this.label,
    required this.color,
    required this.variant,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final filled = variant == _CtaVariant.filled;
    final dashed = variant == _CtaVariant.dashed;

    final bg = filled ? color : color.withValues(alpha: dashed ? 0.06 : 0.08);
    final fg = filled ? Colors.white : color;
    final borderColor = dashed
        ? color.withValues(alpha: 0.30)
        : Colors.transparent;

    final body = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: dashed ? Border.all(color: borderColor, width: 1.2) : null,
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(icon, size: 12, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return body;
  }
}
