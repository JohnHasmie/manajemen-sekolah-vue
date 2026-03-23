// Subject list item component for displaying a single subject (mata pelajaran).
//
// Like a Vue component `<SubjectCard>` used inside a `v-for` loop. Shows
// subject name, code, description, associated class count, and a popup menu
// with "Manage Classes", "Edit", and "Delete" actions. Similar to a Laravel
// Nova resource list item with inline actions.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A card widget that displays a single subject's information with actions.
///
/// Like a Vue `<SubjectListItem>` component with props:
/// - [subject] - subject data map with 'nama', 'code'/'kode', 'description'
/// - [index] - position in list, used for the numbered badge color
/// - [onEdit] / [onDelete] - action callbacks (like `$emit('edit')`)
/// - [onTap] - navigate to manage classes for this subject
/// - [kelasCount] / [kelasNames] - optional class association info
///
/// Uses a `PopupMenuButton` with three options (like a Vue `<v-menu>`).
class SubjectListItem extends StatelessWidget {
  final Map<String, dynamic> subject;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final int? kelasCount;
  final List<String>? kelasNames;

  const SubjectListItem({
    super.key,
    required this.subject,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
    this.kelasCount,
    this.kelasNames,
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
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon dan nomor
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorUtils.getColorForIndex(index).withOpacity(0.1),
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
              SizedBox(width: 12),

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
                    SizedBox(height: 4),
                    if (subject['code'] != null || subject['kode'] != null)
                      Text(
                        'Kode: ${subject['code'] ?? subject['kode']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    if (kelasCount != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.class_, size: 12, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                '$kelasCount kelas',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (kelasNames != null && kelasNames!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                kelasNames!.take(3).join(', ') +
                                    (kelasNames!.length > 3 ? '...' : ''),
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
                          SizedBox(height: 4),
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
                        SizedBox(width: 8),
                        Text('Kelola Kelas'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus'),
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
