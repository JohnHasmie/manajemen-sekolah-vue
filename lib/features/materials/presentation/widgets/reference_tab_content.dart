// Scrollable list of reference cards shown in the Referensi tab.
// Each card carries a type badge (concept deep-dive, real-world example,
// misconception, teaching tip) plus title and stripped-HTML content.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Tab content listing AI-generated reference materials.
///
/// Analogous to a Vue `<ReferenceList>` component: [references] is the
/// data prop, [stripHtml] is a utility function passed in so this widget
/// stays free of HTML-parsing logic, and [onEmptyGenerateTap] handles
/// the empty-state CTA without coupling to navigation internals.
class ReferenceTabContent extends StatelessWidget {
  final List<Map<String, dynamic>> references;
  final Color primaryColor;

  /// Converts HTML strings to plain text — injected from the parent.
  final String Function(String) stripHtml;

  /// Called when the empty-state "Generate AI" button is tapped.
  final VoidCallback onEmptyGenerateTap;

  const ReferenceTabContent({
    super.key,
    required this.references,
    required this.primaryColor,
    required this.stripHtml,
    required this.onEmptyGenerateTap,
  });

  ({Color color, String label, IconData icon}) _referenceTypeConfig(
    String type,
  ) {
    switch (type) {
      case 'concept_deep_dive':
        return (
          color: ColorUtils.corporateBlue500,
          label: 'Pendalaman Konsep',
          icon: Icons.psychology_rounded,
        );
      case 'real_world_example':
        return (
          color: ColorUtils.emerald500,
          label: 'Contoh Nyata',
          icon: Icons.public_rounded,
        );
      case 'common_misconception':
        return (
          color: ColorUtils.amber500,
          label: 'Miskonsepsi Umum',
          icon: Icons.warning_amber_rounded,
        );
      case 'teaching_tip':
        return (
          color: ColorUtils.violet500,
          label: 'Tips Mengajar',
          icon: Icons.tips_and_updates_rounded,
        );
      default:
        return (
          color: ColorUtils.indigo500,
          label: type.replaceAll('_', ' ').toUpperCase(),
          icon: Icons.bookmark_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (references.isEmpty) {
      return _EmptyReferenceState(
        primaryColor: primaryColor,
        onGenerateTap: onEmptyGenerateTap,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: references.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final ref = references[index];
        final refType = ref['type']?.toString() ?? '';
        final typeConfig = _referenceTypeConfig(refType);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type badge
              Container(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  color: typeConfig.color.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: typeConfig.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        typeConfig.icon,
                        size: 15,
                        color: typeConfig.color,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: typeConfig.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeConfig.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: typeConfig.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Title
              Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
                child: Text(
                  ref['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                    fontSize: 15,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  stripHtml(ref['content'] ?? ''),
                  style: TextStyle(
                    color: ColorUtils.slate600,
                    height: 1.6,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Private empty-state sub-widget (file-local)
// ---------------------------------------------------------------------------

class _EmptyReferenceState extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onGenerateTap;

  const _EmptyReferenceState({
    required this.primaryColor,
    required this.onGenerateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 28,
                color: ColorUtils.slate400,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Belum Ada Referensi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate700,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Generate materi AI untuk mendapatkan referensi otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
            ),
            SizedBox(height: AppSpacing.xl),
            GestureDetector(
              onTap: onGenerateTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Generate AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
