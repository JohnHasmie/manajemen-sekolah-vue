import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// FAB widget for classroom management screen.
///
/// Displays expandable menu with options to add class and promote class.
class ClassroomManagementFab extends StatelessWidget {
  final bool isFabOpen;
  final AnimationController fabAnimationController;
  final Animation<double> fabRotateAnimation;
  final Animation<double> fabScaleAnimation;
  final GlobalKey fabKey;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final bool isReadOnly;
  final VoidCallback onToggleFab;
  final VoidCallback onAddClass;
  final VoidCallback onPromoteClass;

  const ClassroomManagementFab({
    required this.isFabOpen,
    required this.fabAnimationController,
    required this.fabRotateAnimation,
    required this.fabScaleAnimation,
    required this.fabKey,
    required this.primaryColor,
    required this.languageProvider,
    required this.isReadOnly,
    required this.onToggleFab,
    required this.onAddClass,
    required this.onPromoteClass,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isReadOnly) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isFabOpen) ...[
          ScaleTransition(
            scale: fabScaleAnimation,
            child: _buildFabButton(
              label: languageProvider.getTranslatedText({
                'en': 'Promote Class',
                'id': 'Naik Kelas / Promosi',
              }),
              icon: Icons.upgrade,
              backgroundColor: Colors.orange,
              heroTag: 'fab_promote_class',
              onPressed: onPromoteClass,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ScaleTransition(
            scale: fabScaleAnimation,
            child: _buildFabButton(
              label: languageProvider.getTranslatedText({
                'en': 'Create New Class',
                'id': 'Buat Kelas Baru',
              }),
              icon: Icons.add,
              backgroundColor: primaryColor,
              heroTag: 'fab_add_class',
              onPressed: onAddClass,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        FloatingActionButton(
          key: fabKey,
          heroTag: 'fab_main_class',
          onPressed: onToggleFab,
          backgroundColor: primaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: RotationTransition(
            turns: fabRotateAnimation,
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildFabButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required String heroTag,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(8)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FloatingActionButton(
          heroTag: heroTag,
          mini: true,
          backgroundColor: backgroundColor,
          onPressed: onPressed,
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }
}
