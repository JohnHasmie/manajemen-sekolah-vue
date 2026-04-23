// Widget builders for class cards and UI components
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/status_badge.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

mixin SubjectClassUiBuilderMixin {
  /// Builds individual class card
  Widget buildClassCard(
    Map<String, dynamic> classItem,
    int index,
    bool isAssigned,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: isAssigned
              ? ColorUtils.corporateBlue600.withValues(alpha: 0.3)
              : ColorUtils.slate200,
          width: isAssigned ? 1.5 : 1,
        ),
        boxShadow: ColorUtils.corporateShadow(
          elevation: isAssigned ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          onTap: () => handleClassCardTap(classItem, isAssigned),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: buildClassCardContent(classItem, isAssigned),
          ),
        ),
      ),
    );
  }

  /// Builds content inside class card
  Widget buildClassCardContent(
    Map<String, dynamic> classItem,
    bool isAssigned,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildClassIconContainer(isAssigned),
        const SizedBox(width: AppSpacing.md),
        buildClassInfo(classItem),
        const SizedBox(width: AppSpacing.sm),
        buildStatusIndicator(isAssigned),
      ],
    );
  }

  /// Builds class icon container
  Widget buildClassIconContainer(bool isAssigned) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isAssigned
            ? ColorUtils.corporateBlue600.withValues(alpha: 0.1)
            : ColorUtils.slate100,
        borderRadius: const BorderRadius.all(Radius.circular(11)),
        border: Border.all(
          color: isAssigned
              ? ColorUtils.corporateBlue600.withValues(alpha: 0.2)
              : ColorUtils.slate200,
        ),
      ),
      child: Icon(
        Icons.class_outlined,
        color: isAssigned ? ColorUtils.corporateBlue600 : ColorUtils.slate500,
        size: 22,
      ),
    );
  }

  /// Builds class information column
  Widget buildClassInfo(Map<String, dynamic> classItem) {
    final model = Classroom.fromJson(classItem);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.name.isEmpty ? 'Kelas' : model.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: ColorUtils.slate800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if ((model.gradeLevel ?? '').isNotEmpty)
                buildClassInfoTag(
                  Icons.layers_outlined,
                  'Tingkat ${model.gradeLevel}',
                ),
              if ((model.homeroomTeacherName ?? '').isNotEmpty)
                buildClassInfoTag(
                  Icons.person_outline,
                  model.homeroomTeacherName!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds status indicator badge
  Widget buildStatusIndicator(bool isAssigned) {
    return StatusBadge(
      label: isAssigned ? 'Terdaftar' : 'Tambahkan',
      color: isAssigned ? ColorUtils.success600 : ColorUtils.corporateBlue600,
      fontSize: 11,
      icon: isAssigned ? Icons.check_circle_outline : Icons.add_circle_outline,
      iconSize: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  /// Builds info tag (level, teacher)
  Widget buildClassInfoTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Builds stat item in stats container
  Widget buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  /// Handles class card tap
  void handleClassCardTap(Map<String, dynamic> classItem, bool isAssigned);
}
