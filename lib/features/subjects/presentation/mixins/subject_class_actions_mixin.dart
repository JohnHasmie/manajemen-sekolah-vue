// Dialog actions and quick add functionality
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

mixin SubjectClassActionsMixin {
  /// Shows quick add class dialog
  void showQuickAddClassDialog(
    List<dynamic> availableClasses,
    List<dynamic> assignedClasses0,
    dynamic subjectName,
  );

  /// Gets color for UI elements (admin role)
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Builds dialog header with gradient
  Widget buildDialogHeader(Color primaryColor, VoidCallback onClose) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah Kelas',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pilih kelas untuk ditambahkan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds list item for unassigned class
  Widget buildClassListItem(
    Map<String, dynamic> classItem,
    Color primaryColor,
    VoidCallback onAddPressed,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Icon(Icons.class_, color: primaryColor, size: 18),
        ),
        title: Text(
          (() {
            final model = Classroom.fromJson(classItem);
            return model.name.isEmpty ? 'Kelas' : model.name;
          })(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Builder(
          builder: (context) {
            final model = Classroom.fromJson(classItem);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((model.gradeLevel ?? '').isNotEmpty)
                  Text(
                    'Tingkat: ${model.gradeLevel}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if ((model.homeroomTeacherName ?? '').isNotEmpty)
                  Text(
                    'Wali: ${model.homeroomTeacherName}',
                    style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
                  ),
              ],
            );
          },
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          padding: const EdgeInsets.all(6),
          child: const Icon(Icons.add, color: Colors.white, size: 16),
        ),
        onTap: onAddPressed,
      ),
    );
  }

  /// Builds dialog footer with action buttons
  Widget buildDialogFooter(VoidCallback onCancel, VoidCallback onViewAll) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: ColorUtils.slate300),
              ),
              child: Text(
                AppLocalizations.cancel.tr,
                style: TextStyle(
                  color: ColorUtils.slate600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: onViewAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.corporateBlue600,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
              child: const Text(
                'Lihat Semua',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
