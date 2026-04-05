// ActivityDetailDialog — the read-only detail sheet shown when a teacher taps
// an activity card.
//
// Shown as a draggable bottom sheet that can be pulled to full screen.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => ActivityDetailDialog(
          activity: activity,
          primaryColor: primaryColor,
          languageProvider: languageProvider,
          canEdit: canEdit,
          selectedClassName: selectedClassName,
          selectedSubjectName: selectedSubjectName,
          onEditPressed: () {
            Navigator.pop(context);
            onEditPressed?.call();
          },
        ),
      ),
    );
  }

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

  bool get _isAssignment =>
      activity['type'] == 'assignment' ||
      activity['type'] == 'tugas' ||
      activity['jenis'] == 'tugas' ||
      activity['jenis'] == 'assignment';

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: ColorUtils.slate400, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, color: ColorUtils.slate800, fontWeight: FontWeight.w600, height: 1.4),
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
    final isAssignment = _isAssignment;
    final className = activity['class_name'] ?? selectedClassName ?? '-';
    final subjectName = activity['subject_name'] ?? selectedSubjectName ?? '-';
    final typeLabel = isAssignment
        ? languageProvider.getTranslatedText({'en': 'Assignment', 'id': 'Tugas'})
        : languageProvider.getTranslatedText({'en': 'Material', 'id': 'Materi'});
    final description = (activity['deskripsi'] ?? activity['description'])?.toString();
    final hasDescription = description != null && description.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Gradient header ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 18),
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
                          isAssignment ? Icons.assignment_rounded : Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeLabel,
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activity['title'] ?? '-',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Detail body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoTile(
                    Icons.class_rounded,
                    languageProvider.getTranslatedText({'en': 'Class — Subject', 'id': 'Kelas — Mata Pelajaran'}),
                    'Kelas: $className — $subjectName',
                  ),
                  _buildInfoTile(
                    Icons.calendar_today_rounded,
                    languageProvider.getTranslatedText({'en': 'Date', 'id': 'Tanggal'}),
                    '${activity['day'] ?? '-'} • ${_formatDate(activity['date'])}',
                  ),
                  if (isAssignment && activity['batas_waktu'] != null)
                    _buildInfoTile(
                      Icons.access_time_rounded,
                      languageProvider.getTranslatedText({'en': 'Deadline', 'id': 'Batas Waktu'}),
                      _formatDate(activity['batas_waktu']),
                    ),
                  if (hasDescription)
                    _buildInfoTile(
                      Icons.description_rounded,
                      languageProvider.getTranslatedText({'en': 'Description', 'id': 'Deskripsi'}),
                      description,
                    ),
                  if (activity['bab_judul'] != null)
                    _buildInfoTile(
                      Icons.auto_stories_rounded,
                      languageProvider.getTranslatedText({'en': 'Chapter', 'id': 'Materi'}),
                      '${activity['bab_judul']}${activity['sub_bab_judul'] != null ? '\n• ${activity['sub_bab_judul']}' : ''}',
                    ),
                ],
              ),
            ),
          ),

          // ── Footer buttons ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate100)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                        foregroundColor: ColorUtils.slate700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({'en': 'Close', 'id': 'Tutup'}),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (canEdit && onEditPressed != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onEditPressed,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(
                          languageProvider.getTranslatedText({'en': 'Edit', 'id': 'Edit'}),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
