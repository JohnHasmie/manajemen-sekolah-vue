// Empty state placeholder for the parent grade screen.
// Shown when no student is selected or no grades are available.
// Like an empty-state component in Vue (e.g., `<EmptyState :message="..." />`).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Displays a centred icon + message when there is nothing to show.
///
/// In Laravel terms this is the "no records" view that Blade renders when a
/// collection is empty.  Pass [message] as you would a `$message` view variable.
class ParentGradeEmptyState extends StatelessWidget {
  /// The human-readable message displayed below the icon.
  final String message;

  const ParentGradeEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: const BorderRadius.all(Radius.circular(20)),
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 36,
              color: ColorUtils.slate400,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            style: TextStyle(
              color: ColorUtils.slate500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
