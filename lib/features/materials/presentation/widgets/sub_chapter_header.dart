// Header for the sub-chapter detail page — Frame C of the Materi
// redesign.
//
// Replaces the legacy bespoke gradient banner with a `BrandPageHeader`
// (cobalt) plus a hero card overlapping the gradient bottom edge —
// same shape as the Jadwal session detail (Frame E).
//
// Layout:
//
//   • BrandPageHeader: kicker `Sub-Bab · Bab <n>`, title `<sub-bab
//     name>`, back-button auto-resolves.
//   • Hero card: cobalt breadcrumb (`<class> · <subject> · Bab <n>
//     <chapter title>`), bold sub-bab title, meta-pill row (Tercatat
//     green / AI Siap violet / 45 menit cobalt).
//
// Both pieces share the same horizontal margin so the hero card
// visually anchors to the cobalt gradient's bottom edge via 20dp
// negative margin.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';

/// Brand header + hero card combined. The page mounts this directly
/// above the tabbed content area in a Column.
class SubChapterHeader extends StatelessWidget {
  final Map<String, dynamic> chapter;
  final Map<String, dynamic> subChapter;
  final Color primaryColor;
  final LinearGradient cardGradient;
  final LanguageProvider languageProvider;

  /// True when this sub-bab has been marked-as-taught by the teacher.
  final bool isChecked;

  /// True when this sub-bab has AI-generated content available.
  final bool hasAi;

  /// Optional class context — surfaces in the hero breadcrumb.
  final String? className;

  /// Optional subject context — surfaces in the hero breadcrumb.
  final String? subjectName;

  const SubChapterHeader({
    super.key,
    required this.chapter,
    required this.subChapter,
    required this.primaryColor,
    required this.cardGradient,
    required this.languageProvider,
    this.isChecked = false,
    this.hasAi = false,
    this.className,
    this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    final chapterTitle = chapter['judul_bab']?.toString() ?? 'Bab';
    final subTitle = subChapter['judul_sub_bab']?.toString() ?? 'Sub-Bab';
    final urutan = chapter['urutan']?.toString() ?? '-';
    final cobalt = ColorUtils.brandCobalt;

    return Column(
      children: [
        BrandPageHeader(
          role: 'guru',
          subtitle: 'Sub-Bab · Bab $urutan',
          title: subTitle,
          // 28dp overlap so the hero card can lift up into the gradient
          // bottom edge without breaking the rounded corner.
          kpiOverlayHeight: 28,
        ),
        Transform.translate(
          offset: const Offset(0, -20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HeroCard(
              chapterTitle: chapterTitle,
              subTitle: subTitle,
              urutan: urutan,
              className: className,
              subjectName: subjectName,
              isChecked: isChecked,
              hasAi: hasAi,
              cobalt: cobalt,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String chapterTitle;
  final String subTitle;
  final String urutan;
  final String? className;
  final String? subjectName;
  final bool isChecked;
  final bool hasAi;
  final Color cobalt;

  const _HeroCard({
    required this.chapterTitle,
    required this.subTitle,
    required this.urutan,
    required this.className,
    required this.subjectName,
    required this.isChecked,
    required this.hasAi,
    required this.cobalt,
  });

  @override
  Widget build(BuildContext context) {
    final crumbBits = <String>[
      if ((className ?? '').isNotEmpty) className!,
      if ((subjectName ?? '').isNotEmpty) subjectName!,
      'Bab $urutan $chapterTitle',
    ];

    return Container(
      width: double.infinity,
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
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_right_rounded, size: 12, color: cobalt),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  crumbBits.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: cobalt,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: ColorUtils.slate900,
              letterSpacing: -0.3,
              height: 1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (isChecked)
                _MetaPill(
                  icon: Icons.check_rounded,
                  label: 'Tercatat',
                  color: ColorUtils.success600,
                ),
              if (hasAi)
                _MetaPill(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Siap',
                  color: const Color(0xFF7C3AED),
                ),
              _MetaPill(
                icon: Icons.access_time_rounded,
                label: 'Bab $urutan',
                color: cobalt,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
