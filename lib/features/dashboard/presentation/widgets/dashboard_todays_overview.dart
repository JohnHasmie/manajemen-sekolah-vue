// DashboardTodaysOverview — the "Today's Overview" 2-column card grid section.
// Receives pre-built overview card widgets from the screen; only handles the layout.
// Like a Vue grid-section component that renders whatever card slots are passed as children.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/overview_card_skeleton.dart';

/// A section widget that renders a 2-column `GridView` of overview cards.
///
/// The parent (dashboard screen) builds the role-specific [cards] list via
/// `_getTodaysOverviewCards(state)` (FinanceBarChartCard, AttendanceOverviewCard,
/// ScheduleSliderCard, OverviewCard, etc.) and passes them in. This widget only
/// handles the section title, grid layout, and skeleton placeholder rows.
class DashboardTodaysOverview extends StatelessWidget {
  /// Pre-built list of overview card widgets for the current role.
  /// Pass an empty list while [isLoaded] is false — skeletons are shown instead.
  final List<Widget> cards;

  /// Whether the dashboard stats have finished loading.
  /// False → shows 4 skeleton placeholder cards.
  final bool isLoaded;

  /// Optional GlobalKey placed on the outer Padding (used by the onboarding tour).
  final GlobalKey? statsSectionKey;

  const DashboardTodaysOverview({
    super.key,
    required this.cards,
    required this.isLoaded,
    this.statsSectionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: statsSectionKey,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.todaysOverview.tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          GridView.count(
            padding: const EdgeInsets.only(top: 12),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            // Tuned down progressively to absorb tiny overflow incidents
            // on different screen sizes:
            //   1.4 → 1.3: fixed S24 5dp overflow on slider cards.
            //   1.3 → 1.2: fixed a recurring 2.6px overflow on iPhone 13/14
            //     (390dp logical width) where the slider cards' header row +
            //     subject + class + dot indicator reserved space added up to
            //     just barely past the grid cell height.
            // OverviewCard variants use mainAxisSize.min so they stay snug
            // to their content even when the grid grants extra height.
            childAspectRatio: 1.2,
            children: isLoaded
                ? cards
                : List.generate(4, (_) => const OverviewCardSkeleton()),
          ),
        ],
      ),
    );
  }
}
