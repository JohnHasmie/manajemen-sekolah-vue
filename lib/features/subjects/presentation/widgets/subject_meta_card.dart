// Subject metadata card shown at the top of the Mata Pelajaran detail
// body. Displays the subject identity (icon + name + code/kategori) and
// an explicit "Edit" button so admin doesn't have to hunt for a pencil
// icon in the header.
//
// Status pill on the right shows is_active / nonaktif so admin always
// knows whether the mapel is currently in use.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

class SubjectMetaCard extends StatelessWidget {
  final Subject subject;
  final int totalClasses;
  final VoidCallback onEdit;

  /// When true the user is browsing a past / archived academic year.
  /// In that mode the inline Edit CTA renders as a slate "Hanya baca"
  /// pill instead of an active button, matching the rest of the admin
  /// surface that locks writes on inactive AYs.
  final bool isReadOnly;

  const SubjectMetaCard({
    super.key,
    required this.subject,
    required this.totalClasses,
    required this.onEdit,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.getRoleColor('admin');

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeadingIcon(accent: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name.isEmpty ? kSubject.tr : subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusPill(active: subject.isActive),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Single explicit Edit CTA inside the card — replaces the
          // pencil icon that used to live in BrandPageHeader actions.
          // On past AYs the CTA flips to a slate "Hanya baca" pill so
          // admin can't enter edit mode for archived data.
          if (isReadOnly)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: ColorUtils.slate500,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    kSubPastAcademicYear.tr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate600,
                    ),
                  ),
                ],
              ),
            )
          else
            Material(
              color: accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: InkWell(
                onTap: onEdit,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm + 2,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_rounded, color: accent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        kSubEditSubject.tr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Subtitle composes whatever subject metadata is non-empty.
  /// Today the API gives us Kode + class_count; KKM/JP/Kategori are
  /// not yet on the subjects table.
  String _subtitle() {
    final parts = <String>[];
    final code = (subject.code ?? '').trim();
    if (code.isNotEmpty) parts.add('${kSubCodeLabel.tr}$code');
    parts.add(
      totalClasses == 0
          ? kSubNoClasses.tr
          : '$totalClasses${kSubClassesAvailable.tr}',
    );
    return parts.join(' · ');
  }
}

class _LeadingIcon extends StatelessWidget {
  final Color accent;

  const _LeadingIcon({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Icon(Icons.menu_book_rounded, color: accent, size: 22),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;

  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? ColorUtils.success600 : ColorUtils.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            active ? kSubActive.tr : kSubInactive.tr,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
