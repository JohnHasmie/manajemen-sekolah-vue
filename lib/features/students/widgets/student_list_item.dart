// Student list item component for displaying a single student in a list.
//
// Like a Vue component `<StudentCard>` used inside a `v-for` loop, or a
// Blade partial `@include('students.list-item', ['student' => $student])`.
// Shows student name, class, avatar initial, and a popup menu for edit/delete.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A list tile widget that displays a single student's information.
///
/// Like a Vue `<StudentListItem>` component with props:
/// - [student] - student data map from the API (like `:student` prop)
/// - [index] - position in list, used for avatar color cycling
/// - [onEdit] - callback when "Edit" is selected from the popup menu
/// - [onDelete] - callback when "Hapus" is selected from the popup menu
///
/// Uses a `PopupMenuButton` for actions (like a Vue `<v-menu>` with items).
class StudentListItem extends StatelessWidget {
  final dynamic student;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StudentListItem({
    super.key,
    required this.student,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getColorForIndex(index);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              student['nama'] != null && student['nama'].isNotEmpty
                  ? student['nama'][0]
                  : '?',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(student['nama'] ?? AppLocalizations.nameNotAvailable.tr),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('${AppLocalizations.classString.tr}: ${student['class_name'] ?? AppLocalizations.notAssigned.tr}')],
          ),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(AppLocalizations.edit.tr)),
              PopupMenuItem(value: 'delete', child: Text(AppLocalizations.delete.tr)),
            ],
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
          ),
        ),
      ),
    );
  }
}
