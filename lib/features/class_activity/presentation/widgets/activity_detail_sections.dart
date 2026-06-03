// Body section building blocks for the teacher activity-detail screen.
//
// Extracted verbatim from `_TeacherActivityDetailScreenState`:
//   • [ActivityDetailSection]  — the white labelled card wrapper
//     (Tipe / Deskripsi / Materi terkait).
//   • [ActivityDetailTypePill] — the type icon-chip + label (was `_typePill`).
//   • [ActivityDetailArchiveBanner] — the read-only "tahun ajaran lalu" banner.
//
// Pure presentation: each takes its data/children as constructor props,
// like small Vue components with `props` and a `<slot>`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_specs.dart';

/// White labelled card wrapping a single body section. The [label] renders
/// as a small uppercase caption above [child].
class ActivityDetailSection extends StatelessWidget {
  final String label;
  final Widget child;

  const ActivityDetailSection({
    super.key,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// The Tipe section's content: a tinted icon chip + the type label.
class ActivityDetailTypePill extends StatelessWidget {
  /// Raw activity type string (any casing); lower-cased internally.
  final String type;

  const ActivityDetailTypePill({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final spec = activityTypeSpec(type.toLowerCase());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: spec.tint,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(spec.icon, size: 16, color: spec.fg),
        ),
        const SizedBox(width: 10),
        Text(
          spec.label,
          style: TextStyle(
            fontSize: 13,
            color: ColorUtils.slate900,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Read-only ARSIP banner shown at the top of the body when `canEdit=false`.
class ActivityDetailArchiveBanner extends StatelessWidget {
  final LanguageProvider lp;

  const ActivityDetailArchiveBanner({super.key, required this.lp});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.info600.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.info600.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: ColorUtils.info600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lp.getTranslatedText({
                'en':
                    'Past academic year — activity is locked. '
                    'Export PDF to archive.',
                'id':
                    'Tahun ajaran lalu — tidak bisa diubah. '
                    'Ekspor PDF untuk arsip.',
              }),
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.info600,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
