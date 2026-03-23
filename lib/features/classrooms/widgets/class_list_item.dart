// Class list item component for displaying a single class (kelas) card.
//
// Like a Vue component `<ClassCard>` used inside a `v-for` loop, or a
// Blade partial `@include('classes.card-item', ['class' => $class])`.
// Renders class info (name, grade, teacher, student count) with edit/delete actions.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A gradient card widget that displays a single class's information.
///
/// Like a Vue component `<ClassCard>` with props:
/// - [classData] - the class data map (like a `:class-data` prop from API response)
/// - [index] - position in list (for alternating styles)
/// - [onTap] - navigate to detail (like `@click` / `$router.push`)
/// - [onEdit] / [onDelete] - action callbacks (like `$emit('edit')`)
///
/// Used in the class management list screen.
class ClassListItem extends StatelessWidget {
  final Map<String, dynamic> classData;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ClassListItem({
    super.key,
    required this.classData,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getPrimaryColor() {
    return Color(0xFF4361EE); // Blue untuk admin
  }

  /// Builds the gradient class card with name, grade, teacher info, student count,
  /// and edit/delete action buttons. Like the `<template>` of a Vue SFC.
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPrimaryColor(),
                        _getPrimaryColor().withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _getPrimaryColor().withOpacity(0.2),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Background pattern
                      Positioned(
                        right: -10,
                        top: -10,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header dengan nama dan grade
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        classData['nama'] ?? 'No Name',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Grade ${classData['grade_level'] ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 12),

                            // Informasi wali kelas
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.person, 
                                    color: Colors.white, 
                                    size: 16
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        languageProvider.getTranslatedText({
                                          'en': 'Homeroom Teacher',
                                          'id': 'Wali Kelas',
                                        }),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        classData['wali_kelas_nama'] ?? languageProvider.getTranslatedText({
                                          'en': 'Not assigned',
                                          'id': 'Belum ditugaskan',
                                        }),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 8),

                            // Informasi jumlah siswa
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.people, 
                                    color: Colors.white, 
                                    size: 16
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        languageProvider.getTranslatedText({
                                          'en': 'Students',
                                          'id': 'Siswa',
                                        }),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        '${classData['jumlah_siswa'] ?? 0} ${languageProvider.getTranslatedText({
                                          'en': 'students',
                                          'id': 'siswa',
                                        })}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 12),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildActionButton(
                                  icon: Icons.edit,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Edit',
                                    'id': 'Edit',
                                  }),
                                  color: Colors.white,
                                  onPressed: onEdit,
                                ),
                                SizedBox(width: 8),
                                _buildActionButton(
                                  icon: Icons.delete,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Delete',
                                    'id': 'Hapus',
                                  }),
                                  color: Colors.white,
                                  onPressed: onDelete,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds a small action button (edit/delete) with icon and label.
  /// Like a reusable `<ActionBtn>` Vue component used in the card footer.
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: color,
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}