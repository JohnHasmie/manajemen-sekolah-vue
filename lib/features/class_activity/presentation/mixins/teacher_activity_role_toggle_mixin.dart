import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityRoleToggleMixin
    on ConsumerState<TeacherClassActivityScreen> {
  Widget buildRoleToggle(LanguageProvider lp) {
    if (homeroomClassesList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lp.getTranslatedText({'en': 'View as', 'id': 'Lihat sebagai'}),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildRoleButton(
                  lp.getTranslatedText({'en': 'Teaching', 'id': 'Mengajar'}),
                  !isHomeroomView,
                  () {
                    updateHomeroomView(false);
                    refreshGroupedActivities();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildRoleButton(
                  lp.getTranslatedText({'en': 'Homeroom', 'id': 'Perwalian'}),
                  isHomeroomView,
                  () {
                    updateHomeroomView(true);
                    refreshGroupedActivities();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? primaryColor : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  bool get isHomeroomView;
  List<dynamic> get homeroomClassesList;
  Color get primaryColor;

  void updateHomeroomView(bool value);
  Future<void> refreshGroupedActivities();
}
