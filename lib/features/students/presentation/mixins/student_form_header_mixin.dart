import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Header UI mixin for student form dialog.
///
/// Provides the gradient header with title and close button.
mixin StudentFormHeaderMixin {
  /// Primary color for header gradient.
  Color get primaryColor;

  /// Translation helper — must be implemented by consuming class.
  String t(Map<String, String> translations);

  /// Is edit mode.
  bool get isEditMode;

  /// Access to BuildContext — must be implemented by consuming class.
  BuildContext get buildContext;

  /// Build header gradient.
  LinearGradient buildHeaderGradient() => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
  );

  /// Build the gradient header widget.
  Widget buildHeaderWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        gradient: buildHeaderGradient(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(
              isEditMode ? Icons.edit_rounded : Icons.person_add_rounded,
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
                  isEditMode
                      ? t({'en': 'Edit Student', 'id': 'Edit Siswa'})
                      : t({'en': 'Add Student', 'id': 'Tambah Siswa'}),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEditMode
                      ? t({
                          'en': 'Update student information',
                          'id': 'Perbarui data siswa',
                        })
                      : t({
                          'en': 'Fill in student information',
                          'id': 'Isi data siswa baru',
                        }),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => AppNavigator.pop(buildContext),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
