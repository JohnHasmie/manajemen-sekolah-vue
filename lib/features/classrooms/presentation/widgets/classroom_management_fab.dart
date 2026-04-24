// Speed-dial FAB for the classroom admin screen.
//
// Owns its own [AnimationController] and open/closed state — the screen
// only wires in the two tap handlers (add class, promote class). Moved
// to a self-contained widget in Phase 1 (#186) so the screen no longer
// needs [SingleTickerProviderStateMixin] or a pile of animation fields.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Two-action speed-dial FAB for classroom management (Add + Promote).
///
/// Usage:
/// ```dart
/// AdminCrudScaffold(
///   ...,
///   customFab: ClassroomManagementFab(
///     primaryColor: primary,
///     languageProvider: lang,
///     isReadOnly: year.isReadOnly,
///     onAddClass: _openAddEditSheet,
///     onPromoteClass: _showPromotionWizard,
///     triggerKey: _fabKey,
///   ),
/// )
/// ```
class ClassroomManagementFab extends StatefulWidget {
  /// Accent color for the main FAB and "Create New Class" action. Usually
  /// the admin role color.
  final Color primaryColor;

  /// Provides Bahasa Indonesia / English copy for the action labels.
  final LanguageProvider languageProvider;

  /// When true, the FAB disappears entirely — e.g., viewing an archived
  /// academic year.
  final bool isReadOnly;

  /// Called when the "Create New Class" action is tapped. The speed-dial
  /// collapses automatically before invoking.
  final VoidCallback onAddClass;

  /// Called when the "Promote Class" action is tapped. The speed-dial
  /// collapses automatically before invoking.
  final VoidCallback onPromoteClass;

  /// Optional key on the main FAB — used by the onboarding tour target.
  final Key? triggerKey;

  const ClassroomManagementFab({
    super.key,
    required this.primaryColor,
    required this.languageProvider,
    required this.isReadOnly,
    required this.onAddClass,
    required this.onPromoteClass,
    this.triggerKey,
  });

  @override
  State<ClassroomManagementFab> createState() => _ClassroomManagementFabState();
}

class _ClassroomManagementFabState extends State<ClassroomManagementFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotate;
  late final Animation<double> _scale;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotate = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    setState(() {
      _open = false;
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isReadOnly) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          ScaleTransition(
            scale: _scale,
            child: _SpeedDialAction(
              label: widget.languageProvider.getTranslatedText(const {
                'en': 'Promote Class',
                'id': 'Naik Kelas / Promosi',
              }),
              icon: Icons.upgrade,
              backgroundColor: Colors.orange,
              heroTag: 'fab_promote_class',
              onPressed: () {
                _close();
                widget.onPromoteClass();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ScaleTransition(
            scale: _scale,
            child: _SpeedDialAction(
              label: widget.languageProvider.getTranslatedText(const {
                'en': 'Create New Class',
                'id': 'Buat Kelas Baru',
              }),
              icon: Icons.add,
              backgroundColor: widget.primaryColor,
              heroTag: 'fab_add_class',
              onPressed: () {
                _close();
                widget.onAddClass();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        FloatingActionButton(
          key: widget.triggerKey,
          heroTag: 'fab_main_class',
          onPressed: _toggle,
          backgroundColor: widget.primaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: RotationTransition(
            turns: _rotate,
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }
}

/// Individual action row in the speed-dial stack — label tag + mini FAB.
class _SpeedDialAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final String heroTag;
  final VoidCallback onPressed;

  const _SpeedDialAction({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.heroTag,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
