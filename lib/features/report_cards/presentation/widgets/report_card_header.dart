// Header widget for the report card detail screen — hero pattern
// from `_design/teacher_raport_isi_redesign.html`.
//
// Combines:
//   • [BrandPageHeader] (cobalt gradient, kicker `Kelas <class> · ISI
//     RAPORT`, title `<student name>`, back button, optional print
//     icon when `status == 'final'`).
//   • Hero card overlapping the gradient bottom by ~36dp — large
//     2-letter avatar + bold name + meta line (`NIS · Kelas`)
//     + Rerata pill on the right (green ≥80, amber ≥60, slate empty)
//     + status row (DRAFT/FINAL/TERBIT + RANK + KKM ✓).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_print_screen.dart';

class ReportCardHeader extends StatelessWidget {
  final String studentName;
  final String className;
  final String? status;
  final Map<String, dynamic>? existingRaport;
  final VoidCallback onBack;

  const ReportCardHeader({
    super.key,
    required this.studentName,
    required this.className,
    required this.status,
    required this.existingRaport,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final s = (status ?? '').toLowerCase();
    final isFinal = s == 'final' || s == 'published' || s == 'terbit';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        BrandPageHeader(
          role: 'guru',
          subtitle: className.isNotEmpty
              ? 'Kelas $className · ISI RAPORT'
              : 'ISI RAPORT',
          title: studentName,
          onBackPressed: onBack,
          // SS2 fix — bumped from 38 to 96 so the title row clears the
          // overlapping hero card below. The card is ~120dp tall and
          // overlaps 96dp into the gradient (card height minus the
          // 24dp translate); the previous 38dp overlay reserve was
          // smaller than the card's intrusion, so the title got covered
          // by the white card. 96dp matches the actual overlap and
          // leaves the gradient title clear.
          kpiOverlayHeight: 96,
          actionIcons: [
            if (isFinal)
              BrandHeaderIconButton(
                icon: Icons.print_rounded,
                onTap: () => _openPrint(context),
              ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: Transform.translate(
            offset: const Offset(0, 24),
            child: _HeroCard(
              studentName: studentName,
              className: className,
              status: s,
              existingRaport: existingRaport,
              cobalt: cobalt,
            ),
          ),
        ),
      ],
    );
  }

  void _openPrint(BuildContext context) {
    if (existingRaport == null) return;
    AppNavigator.push<void>(
      context,
      ReportCardPrintScreen(
        studentName: studentName,
        className: className,
        reportCardData: existingRaport!,
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String studentName;
  final String className;
  final String status;
  final Map<String, dynamic>? existingRaport;
  final Color cobalt;

  const _HeroCard({
    required this.studentName,
    required this.className,
    required this.status,
    required this.existingRaport,
    required this.cobalt,
  });

  String get _initials {
    final parts = studentName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Pull the summary block. Prefer the saved raport's own `summary`
  /// field; fall back to the cached initial-data summary so a synthetic
  /// raport map (no row yet) still renders sensible numbers.
  Map<String, dynamic> get _summary {
    final r = existingRaport;
    if (r == null) return const {};
    final live = r['summary'];
    if (live is Map) return Map<String, dynamic>.from(live);
    final fallback = r['_initial_summary'];
    if (fallback is Map) return Map<String, dynamic>.from(fallback);
    return const {};
  }

  String? get _nis {
    final r = existingRaport;
    if (r == null) return null;
    final sc = r['student_class'] ?? r['studentClass'];
    if (sc is Map) {
      final st = sc['student'];
      if (st is Map) {
        final n = (st['student_number'] ?? st['nis'])?.toString();
        if (n != null && n.isNotEmpty) return n;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final rerata = s['rerata'];
    final hasRerata = rerata is num && rerata > 0;
    final kkmPass = s['kkm_pass_count'];
    final totalSubj = s['total_subjects'];
    final classRank = s['class_rank'];
    final classTotal = s['class_total'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cobalt.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cobalt,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      studentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ColorUtils.slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _MetaLine(nis: _nis, className: className, cobalt: cobalt),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RerataPill(
                value: hasRerata ? rerata.toDouble() : 0.0,
                hasValue: hasRerata,
              ),
            ],
          ),
          if (status.isNotEmpty ||
              _hasPills(classRank, kkmPass, totalSubj)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (status.isNotEmpty) _StatusPill(status: status),
                if (classRank is num &&
                    classTotal is num &&
                    classRank > 0 &&
                    classTotal > 0)
                  _InfoPill(
                    label: 'RANK ${classRank.toInt()} / ${classTotal.toInt()}',
                    color: cobalt,
                  ),
                if (kkmPass is num && totalSubj is num && totalSubj > 0)
                  _InfoPill(
                    label: kkmPass >= totalSubj
                        ? '${totalSubj.toInt()} KKM ✓'
                        : '${kkmPass.toInt()}/${totalSubj.toInt()} KKM',
                    color: kkmPass >= totalSubj
                        ? ColorUtils.success600
                        : ColorUtils.warning600,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _hasPills(dynamic rank, dynamic pass, dynamic total) {
    final r = (rank is num) && rank > 0;
    final p = (pass is num) && (total is num) && total > 0;
    return r || p;
  }
}

class _MetaLine extends StatelessWidget {
  final String? nis;
  final String className;
  final Color cobalt;

  const _MetaLine({
    required this.nis,
    required this.className,
    required this.cobalt,
  });

  @override
  Widget build(BuildContext context) {
    final bits = <InlineSpan>[];
    if (nis != null && nis!.isNotEmpty) {
      bits.add(
        TextSpan(
          text: 'NIS $nis',
          style: TextStyle(
            color: cobalt,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      );
    }
    if (className.isNotEmpty) {
      if (bits.isNotEmpty) {
        bits.add(const TextSpan(text: ' · ', style: TextStyle(fontSize: 11)));
      }
      bits.add(
        TextSpan(
          text: 'Kelas $className',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (bits.isEmpty) {
      bits.add(
        const TextSpan(
          text: 'Smt aktif',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: ColorUtils.slate500,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        children: bits,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'published' || 'terbit' => (
        ColorUtils.success600.withValues(alpha: 0.10),
        ColorUtils.success600,
        'TERBIT',
      ),
      'final' => (
        ColorUtils.info600.withValues(alpha: 0.10),
        ColorUtils.info600,
        'FINAL',
      ),
      'draft' => (
        ColorUtils.warning600.withValues(alpha: 0.10),
        ColorUtils.warning600,
        'DRAFT',
      ),
      _ => (ColorUtils.slate100, ColorUtils.slate500, status.toUpperCase()),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _RerataPill extends StatelessWidget {
  final double value;
  final bool hasValue;

  const _RerataPill({required this.value, required this.hasValue});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tint();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasValue ? _formatRerata(value) : '—',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: fg,
              height: 1.0,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'RERATA',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRerata(double v) {
    final s = v.toStringAsFixed(1);
    return s.replaceAll('.', ',');
  }

  (Color, Color) _tint() {
    if (!hasValue) {
      return (ColorUtils.slate50, ColorUtils.slate500);
    }
    if (value >= 80) {
      return (
        ColorUtils.success600.withValues(alpha: 0.08),
        ColorUtils.success600,
      );
    }
    if (value >= 60) {
      return (
        ColorUtils.warning600.withValues(alpha: 0.08),
        ColorUtils.warning600,
      );
    }
    return (ColorUtils.error600.withValues(alpha: 0.08), ColorUtils.error600);
  }
}
