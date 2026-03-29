// ActivityCard — displays one teaching-journal entry in the activity list.
//
// Extracted from `ClassActivityScreenState._buildActivityCard`.
// Think of this like a Vue `<ActivityCard :activity="item" />` component.
// It is a pure presentational widget: all business logic (delete, edit,
// detail dialog) is delegated back to the parent via callbacks.
//
// StatelessWidget is sufficient because the card holds no mutable state of
// its own — it's just a "view" of a data map.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A single row card showing one class activity (material or task).
///
/// Parameters are the equivalent of Vue props:
/// - [activity]           — the raw API map for this entry
/// - [primaryColor]       — theme colour passed from the screen
/// - [languageProvider]   — translation helper (read-only; no need for ref)
/// - [canEdit]            — whether the current user can edit/delete
/// - [onTap]              — called when the whole card is tapped (opens detail)
/// - [onEdit]             — called when the edit button is pressed
/// - [onDelete]           — called when the delete button is pressed
/// - [selectedSubjectName] / [selectedClassName] — fallback labels when the
///   activity map doesn't carry its own subject/class names
class ActivityCard extends StatelessWidget {
  final dynamic activity;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String? selectedSubjectName;
  final String? selectedClassName;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.primaryColor,
    required this.languageProvider,
    required this.canEdit,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.selectedSubjectName,
    this.selectedClassName,
  });

  // ---------------------------------------------------------------------------
  // Helper: format a date value to dd/mm/yyyy.
  // Mirrors `ClassActivityScreenState._formatDate`.
  // ---------------------------------------------------------------------------
  String _formatDate(dynamic date) {
    if (date == null) return '-';
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      dt = DateTime.tryParse(date);
    }
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  // ---------------------------------------------------------------------------
  // Small coloured tag used in the Wrap below the title.
  // Like a Vue `<InfoTag :icon="..." :label="..." />` sub-component.
  // ---------------------------------------------------------------------------
  Widget _buildInfoTag(IconData icon, String label, {Color? tagColor}) {
    final c = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tagColor != null
              ? tagColor.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Small circular icon button (edit / delete).
  // Like a Vue `<CircleActionButton :icon="..." :color="..." />`.
  // ---------------------------------------------------------------------------
  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAssignment =
        activity['jenis'] == 'tugas' ||
        activity['jenis'] == 'assignment' ||
        activity['type'] == 'assignment';
    final isSpecificTarget = activity['target_role'] == 'khusus';
    final accentColor =
        isAssignment ? ColorUtils.warning600 : ColorUtils.success600;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    isAssignment
                        ? Icons.assignment_outlined
                        : Icons.menu_book_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                // Body: title, subject/class, info tags, description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['title'] ?? 'Judul Kegiatan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${activity['subject_name'] ?? selectedSubjectName ?? ''} • ${activity['class_name'] ?? selectedClassName ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _buildInfoTag(
                            Icons.calendar_today_outlined,
                            '${activity['day'] ?? '-'} • ${_formatDate(activity['date'])}',
                          ),
                          _buildInfoTag(
                            isAssignment
                                ? Icons.assignment_outlined
                                : Icons.menu_book_outlined,
                            isAssignment
                                ? languageProvider.getTranslatedText({
                                    'en': 'Task',
                                    'id': 'Tugas',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Material',
                                    'id': 'Materi',
                                  }),
                            tagColor: accentColor,
                          ),
                          _buildInfoTag(
                            isSpecificTarget
                                ? Icons.person_outline
                                : Icons.group_outlined,
                            isSpecificTarget
                                ? languageProvider.getTranslatedText({
                                    'en': 'Specific',
                                    'id': 'Khusus',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'All',
                                    'id': 'Semua',
                                  }),
                            tagColor: isSpecificTarget
                                ? ColorUtils.violet700
                                : ColorUtils.success600,
                          ),
                          if (isAssignment &&
                              activity['batas_waktu'] != null)
                            _buildInfoTag(
                              Icons.access_time_outlined,
                              _formatDate(activity['batas_waktu']),
                              tagColor: ColorUtils.error600,
                            ),
                        ],
                      ),
                      if (activity['deskripsi'] != null &&
                          activity['deskripsi'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          activity['deskripsi'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.slate500,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                // Right side: edit/delete buttons or chevron
                if (canEdit)
                  Column(
                    children: [
                      _buildCircleActionButton(
                        icon: Icons.edit_outlined,
                        color: primaryColor,
                        onPressed: onEdit,
                      ),
                      const SizedBox(height: 6),
                      _buildCircleActionButton(
                        icon: Icons.delete_outline,
                        color: ColorUtils.error600,
                        onPressed: onDelete,
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: ColorUtils.slate500,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
