import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/drag_handle.dart';

/// Gradient header for the lesson plan detail **bottom sheet**.
///
/// Matches the shared [BottomSheetHeader] scaffolding used by the other
/// teacher flat-flow sheets (recommendations, grade editor, filter sheets)
/// — drag handle + icon-in-rounded-box + title/subtitle column + trailing
/// action buttons — but keeps the RPP-specific edit/save/export/copy affordances
/// instead of a generic close button, because the detail sheet drives an
/// inline edit toggle plus a per-field regen/export menu that the shared
/// header doesn't model.
class LessonPlanDetailHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isEditing;
  final bool isSaving;
  final Color primaryColor;
  final VoidCallback onEditTap;
  final VoidCallback onSaveTap;
  final VoidCallback? onExportTap;
  final VoidCallback? onCopyTap;

  const LessonPlanDetailHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isEditing,
    required this.isSaving,
    required this.primaryColor,
    required this.onEditTap,
    required this.onSaveTap,
    this.onExportTap,
    this.onCopyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DragHandle.onGradient(),
          Row(
            children: [
              GestureDetector(
                onTap: () => AppNavigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit RPP' : title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ..._buildActionButtons(context),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    if (isEditing) {
      return [
        _HeaderButton(icon: Icons.save_rounded, onTap: onSaveTap),
        const SizedBox(width: AppSpacing.sm),
        _HeaderButton(icon: Icons.close_rounded, onTap: onEditTap),
      ];
    }

    return [
      _HeaderButton(icon: Icons.edit_outlined, onTap: onEditTap),
      const SizedBox(width: AppSpacing.sm),
      if (onExportTap != null)
        _MoreActionsButton(
          onExport: onExportTap!,
          onCopy: onCopyTap ?? () {},
        ),
    ];
  }
}

/// Simple header button widget.
class _HeaderButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _HeaderButton({this.icon, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// More actions popup menu button.
class _MoreActionsButton extends StatelessWidget {
  final VoidCallback onExport;
  final VoidCallback onCopy;

  const _MoreActionsButton({required this.onExport, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final primaryColor = ColorUtils.getRoleColor('guru');

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'export') onExport();
        if (value == 'copy') onCopy();
      },
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
              SizedBox(width: 10),
              Text('Export ke PDF'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.content_copy, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              const Text('Copy ke Clipboard'),
            ],
          ),
        ),
      ],
    );
  }
}
