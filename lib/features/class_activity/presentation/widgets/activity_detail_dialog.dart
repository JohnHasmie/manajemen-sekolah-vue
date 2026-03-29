// ActivityDetailDialog — the read-only detail sheet shown when a teacher taps
// an activity card.
//
// Extracted from `ClassActivityScreenState._showActivityDetail`.
// Think of this like a Vue `<ActivityDetailModal :activity="item" />`.
//
// The dialog is shown via a static helper [ActivityDetailDialog.show] so
// callers don't have to construct it manually — same pattern as the existing
// `AddActivityDialog`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A modal dialog that shows the full details of one class activity.
///
/// Props (constructor params — like Vue props):
/// - [activity]            — raw API map for the entry
/// - [primaryColor]        — theme colour (passed in so the widget is stateless)
/// - [languageProvider]    — translation helper
/// - [canEdit]             — whether the edit button is shown
/// - [selectedClassName]   — fallback when [activity]['class_name'] is null
/// - [selectedSubjectName] — fallback when [activity]['subject_name'] is null
/// - [onEditPressed]       — called after the dialog closes and Edit is tapped
class ActivityDetailDialog extends StatelessWidget {
  final dynamic activity;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final bool canEdit;
  final String? selectedClassName;
  final String? selectedSubjectName;
  final VoidCallback? onEditPressed;

  const ActivityDetailDialog({
    super.key,
    required this.activity,
    required this.primaryColor,
    required this.languageProvider,
    required this.canEdit,
    this.selectedClassName,
    this.selectedSubjectName,
    this.onEditPressed,
  });

  // ---------------------------------------------------------------------------
  // Static helper — call this instead of showDialog(...) manually.
  // Mirrors how `showDialog` was called inside `_showActivityDetail`.
  // ---------------------------------------------------------------------------
  static Future<void> show({
    required BuildContext context,
    required dynamic activity,
    required Color primaryColor,
    required LanguageProvider languageProvider,
    required bool canEdit,
    String? selectedClassName,
    String? selectedSubjectName,
    VoidCallback? onEditPressed,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ActivityDetailDialog(
        activity: activity,
        primaryColor: primaryColor,
        languageProvider: languageProvider,
        canEdit: canEdit,
        selectedClassName: selectedClassName,
        selectedSubjectName: selectedSubjectName,
        onEditPressed: onEditPressed,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Format a date value to dd/mm/yyyy. Mirrors `_formatDate` in the screen.
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
  // One labelled row in the detail body (icon + label + value).
  // Like a Vue `<DetailRow :icon="..." :label="..." :value="..." />`.
  // Note: the `color` param is accepted for API compatibility but the icon
  // always uses [primaryColor] — matching original behaviour.
  // ---------------------------------------------------------------------------
  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAssignment =
        activity['jenis'] == 'tugas' ||
        activity['jenis'] == 'assignment' ||
        activity['type'] == 'assignment';

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ──────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.75)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isAssignment
                        ? Icons.assignment_rounded
                        : Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAssignment
                            ? languageProvider.getTranslatedText({
                                'en': 'Assignment',
                                'id': 'Tugas',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'Material',
                                'id': 'Materi',
                              }),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        activity['title'] ?? '-',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable detail rows ────────────────────────────────────────
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    Icons.class_rounded,
                    languageProvider.getTranslatedText({
                      'en': 'Class',
                      'id': 'Kelas',
                    }),
                    activity['class_name'] ?? selectedClassName ?? '-',
                    primaryColor,
                  ),
                  _buildDetailRow(
                    Icons.menu_book_rounded,
                    languageProvider.getTranslatedText({
                      'en': 'Subject',
                      'id': 'Mata Pelajaran',
                    }),
                    activity['subject_name'] ?? selectedSubjectName ?? '-',
                    primaryColor,
                  ),
                  _buildDetailRow(
                    Icons.calendar_today_rounded,
                    languageProvider.getTranslatedText({
                      'en': 'Date',
                      'id': 'Tanggal',
                    }),
                    '${activity['day']} • ${_formatDate(activity['date'])}',
                    primaryColor,
                  ),
                  if (isAssignment && activity['batas_waktu'] != null)
                    _buildDetailRow(
                      Icons.access_time_rounded,
                      languageProvider.getTranslatedText({
                        'en': 'Deadline',
                        'id': 'Batas Waktu',
                      }),
                      _formatDate(activity['batas_waktu']),
                      ColorUtils.error600,
                    ),
                  if (activity['deskripsi'] != null &&
                      activity['deskripsi'].toString().isNotEmpty)
                    _buildDetailRow(
                      Icons.description_rounded,
                      languageProvider.getTranslatedText({
                        'en': 'Description',
                        'id': 'Deskripsi',
                      }),
                      activity['deskripsi'].toString(),
                      primaryColor,
                    ),
                  if (activity['bab_judul'] != null)
                    _buildDetailRow(
                      Icons.auto_stories_rounded,
                      languageProvider.getTranslatedText({
                        'en': 'Chapter',
                        'id': 'Materi',
                      }),
                      '${activity['bab_judul']}${activity['sub_bab_judul'] != null ? '\n• ${activity['sub_bab_judul']}' : ''}',
                      primaryColor,
                    ),
                ],
              ),
            ),
          ),

          // ── Footer buttons ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ColorUtils.slate100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppNavigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: ColorUtils.slate300),
                      foregroundColor: ColorUtils.slate700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Close',
                        'id': 'Tutup',
                      }),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (canEdit && onEditPressed != null) ...[
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        AppNavigator.pop(context);
                        onEditPressed!();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Edit',
                          'id': 'Edit',
                        }),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
