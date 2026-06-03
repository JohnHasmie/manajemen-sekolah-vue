// ActivityCard — displays one teaching-journal entry in the activity list.
// Refined single-row layout: type indicator + title/meta + overflow menu.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

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

  /// When rendered inside the Wali Kelas tab we show who authored the
  /// activity, since the homeroom teacher is viewing entries from across
  /// every teacher who works with the class.
  final bool isHomeroomView;

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
    this.isHomeroomView = false,
  });

  String? _authorName() {
    final raw =
        activity['guru_nama'] ??
        activity['teacher_name'] ??
        activity['teacher']?['name'];
    final str = raw?.toString().trim();
    if (str == null || str.isEmpty) return null;
    return str;
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

  @override
  Widget build(BuildContext context) {
    final deadlineWord = languageProvider.getTranslatedText({
      'en': 'Deadline',
      'id': 'Batas waktu',
    });
    final isAssignment =
        activity['jenis'] == 'tugas' ||
        activity['jenis'] == 'assignment' ||
        activity['type'] == 'assignment';
    final isSpecificTarget = activity['target_role'] == 'khusus';
    final accentColor = isAssignment
        ? ColorUtils.warning600
        : ColorUtils.success600;
    final typeLabel = isAssignment
        ? languageProvider.getTranslatedText({'en': 'Task', 'id': 'Tugas'})
        : languageProvider.getTranslatedText({
            'en': 'Material',
            'id': 'Materi',
          });

    final description = (activity['deskripsi'] ?? activity['description'])
        ?.toString();
    final hasDescription = description != null && description.isNotEmpty;
    final dateStr =
        '${activity['day'] ?? '-'}, ${_formatDate(activity['date'])}';
    final authorName = isHomeroomView ? _authorName() : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Type badge + Title + overflow menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type indicator (thin left accent)
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['title'] ?? 'Judul Kegiatan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Meta row: date + type + target
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: ColorUtils.slate400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ColorUtils.slate500,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              if (isSpecificTarget) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.violet700.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Specific',
                                      'id': 'Khusus',
                                    }),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: ColorUtils.violet700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Overflow menu (edit/delete) or chevron
                    if (canEdit)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') onDelete();
                        },
                        icon: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: ColorUtils.slate400,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Edit',
                                    'id': 'Edit',
                                  }),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: ColorUtils.error600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Delete',
                                    'id': 'Hapus',
                                  }),
                                  style: TextStyle(color: ColorUtils.error600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: ColorUtils.slate400,
                        ),
                      ),
                  ],
                ),

                // Author row (wali kelas tab only) — shows which teacher
                // recorded the journal entry, since the homeroom view
                // aggregates across every teacher in the class.
                if (authorName != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 13,
                          color: ColorUtils.slate400,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            authorName,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: ColorUtils.slate500,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Description preview (if any)
                if (hasDescription) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // Deadline row (assignments only)
                if (isAssignment && activity['batas_waktu'] != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: ColorUtils.error600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$deadlineWord: '
                          '${_formatDate(activity['batas_waktu'])}',
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.error600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
