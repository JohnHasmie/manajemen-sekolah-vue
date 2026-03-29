// DashboardQuickActionsSection — horizontal scrollable row of role-specific quick-action buttons.
// Receives a pre-built list of QuickActionButton widgets from the screen so it stays stateless.
// Like a Vue "shortcut bar" presentational component that renders whatever actions are passed in.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/quick_action_skeleton.dart';

/// A section widget that shows a labelled horizontal list of quick-action buttons.
///
/// The parent (dashboard screen) builds the actual [QuickActionButton] list via
/// `_getQuickActions(state)` and passes it in as [actions]. This widget only handles
/// the layout, skeleton placeholder, and section header — not the navigation logic.
class DashboardQuickActionsSection extends StatelessWidget {
  /// Pre-built list of [QuickActionButton] widgets for the current role.
  /// Pass an empty list while [isLoaded] is false — skeletons are shown instead.
  final List<Widget> actions;

  /// Whether the dashboard stats have finished loading.
  /// False → shows skeleton shimmer placeholders.
  final bool isLoaded;

  /// Optional GlobalKey placed on the outer Padding (used by the onboarding tour).
  final GlobalKey? quickActionsKey;

  const DashboardQuickActionsSection({
    super.key,
    required this.actions,
    required this.isLoaded,
    this.quickActionsKey,
  });

  @override
  Widget build(BuildContext context) {
    // Hide the section entirely once loaded if there are no actions for this role
    if (actions.isEmpty && isLoaded) {
      return SizedBox.shrink();
    }

    return Padding(
      key: quickActionsKey,
      padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.quickAccess.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),

          // Horizontal scroll list — real buttons or skeleton placeholders
          SizedBox(
            height: 85,
            child: isLoaded
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: BouncingScrollPhysics(),
                    itemCount: actions.length,
                    separatorBuilder: (context, index) => SizedBox(width: 10),
                    itemBuilder: (context, index) => actions[index],
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    separatorBuilder: (context, index) => SizedBox(width: 10),
                    itemBuilder: (context, index) =>
                        const QuickActionSkeleton(),
                  ),
          ),
        ],
      ),
    );
  }
}
