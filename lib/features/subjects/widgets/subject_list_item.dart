// Subject list item component for displaying a single subject (mata pelajaran).
//
// Like a Vue component `<SubjectCard>` used inside a `v-for` loop. Shows
// subject name, code, description, associated class count, and a popup menu
// with "Manage Classes", "Edit", and "Delete" actions. Similar to a Laravel
// Nova resource list item with inline actions.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A card widget that displays a single subject's information with actions.
///
/// Like a Vue `<SubjectListItem>` component with props:
/// - [subject] - subject data map with 'nama', 'code'/'kode', 'description'
/// - [index] - position in list, used for the numbered badge color
/// - [onEdit] / [onDelete] - action callbacks (like `$emit('edit')`)
/// - [onTap] - navigate to manage classes for this subject
/// - [classCount] / [classNames] - optional class association info
///
/// Uses a `PopupMenuButton` with three options (like a Vue `<v-menu>`).
class SubjectListItem extends StatelessWidget {
  final Map<String, dynamic> subject;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final int? classCount;
  final List<String>? classNames;

  const SubjectListItem({
    super.key,
    required this.subject,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
    this.classCount,
    this.classNames,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              // Icon dan nomor
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorUtils.getColorForIndex(index).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: ColorUtils.getColorForIndex(index),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md),

              // Info mata pelajaran
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject['nama'] ?? 'Mata Pelajaran',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    if (subject['code'] != null || subject['kode'] != null)
                      Text(
                        'Kode: ${subject['code'] ?? subject['kode']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    if (classCount != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(Icons.class_, size: 12, color: Colors.green),
                              SizedBox(width: AppSpacing.xs),
                              Text(
                                '$classCount kelas',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (classNames != null && classNames!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                classNames!.take(3).join(', ') +
                                    (classNames!.length > 3 ? '...' : ''),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    if ((subject['description'] != null &&
                            subject['description'].isNotEmpty) ||
                        (subject['deskripsi'] != null &&
                            subject['deskripsi'].isNotEmpty))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            subject['description'] ?? subject['deskripsi'],
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Tombol aksi
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onSelected: (value) {
                  if (value == 'manage_classes' && onTap != null) {
                    onTap!();
                  } else if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'manage_classes',
                    child: Row(
                      children: [
                        Icon(Icons.class_, size: 20, color: Colors.blue),
                        SizedBox(width: AppSpacing.sm),
                        Text('Kelola Kelas'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: Colors.orange),
                        SizedBox(width: AppSpacing.sm),
                        Text(AppLocalizations.edit.tr),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: AppSpacing.sm),
                        Text(AppLocalizations.delete.tr),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
