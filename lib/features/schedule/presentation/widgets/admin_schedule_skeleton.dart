// Loading skeleton for the admin Jadwal hub.
//
// Renders a calm shimmer-free placeholder while the initial fetch is
// in flight. Without pagination we now load every row in one request,
// which on a slow connection can take several seconds — the skeleton
// gives the admin a visual "we're working on it" cue instead of the
// previous bare spinner.
//
// Two presentations, picked by the caller:
//   * [ScheduleGridSkeleton] — mirrors the week-grid layout with
//     gray hour/day chrome + 6-8 ghost session blocks.
//   * [ScheduleListSkeleton] — mirrors the List view with a day-tab
//     strip + 4 ghost row cards.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Skeleton placeholder for the week-grid view.
class ScheduleGridSkeleton extends StatelessWidget {
  const ScheduleGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Day header row.
          Container(
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
            ),
            child: Row(
              children: [
                const _SkeletonBar(width: 32, height: 32, radius: 0),
                for (var i = 0; i < 6; i++)
                  Expanded(
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      child: const _SkeletonBar(width: 22, height: 9),
                    ),
                  ),
              ],
            ),
          ),
          // Time-aligned body grid.
          SizedBox(
            height: 420,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Time column.
                SizedBox(
                  width: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: ColorUtils.slate50,
                      border: Border(
                        right: BorderSide(color: ColorUtils.slate200),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (var i = 0; i < 7; i++)
                          const _SkeletonBar(width: 16, height: 8),
                      ],
                    ),
                  ),
                ),
                // Day columns with ghost blocks at varying positions.
                for (var i = 0; i < 6; i++)
                  Expanded(
                    child: _GhostDayColumn(seed: i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for the List view — day-tab strip + 4 ghost
/// row cards.
class ScheduleListSkeleton extends StatelessWidget {
  const ScheduleListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Day-tab strip placeholder.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                const _SkeletonBar(width: 54, height: 28, radius: 999),
                if (i < 5) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        // Day-header kicker.
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              _SkeletonBar(width: 70, height: 11),
            ],
          ),
        ),
        // Pagi/Siang section head.
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              _SkeletonBar(width: 36, height: 10),
              SizedBox(width: 8),
              _SkeletonBar(width: 50, height: 14, radius: 999),
            ],
          ),
        ),
        // 4 ghost row cards.
        for (var i = 0; i < 4; i++)
          Padding(
            padding: EdgeInsets.fromLTRB(16, i == 0 ? 6 : 8, 16, 0),
            child: _GhostRowCard(),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Building blocks
// ─────────────────────────────────────────────────────────────────────

class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBar({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A single day column with deterministically-placed ghost blocks so
/// the skeleton's silhouette feels like real schedule data instead of
/// an empty box.
class _GhostDayColumn extends StatelessWidget {
  final int seed;

  const _GhostDayColumn({required this.seed});

  @override
  Widget build(BuildContext context) {
    // Block layout patterns — picked by seed % 4 so each column has
    // a slightly different rhythm without random per-rebuild jitter.
    const patterns = [
      [(0.05, 0.10), (0.50, 0.10), (0.75, 0.10)],
      [(0.15, 0.10), (0.60, 0.10)],
      [(0.05, 0.10), (0.30, 0.10), (0.70, 0.10)],
      [(0.35, 0.10), (0.65, 0.10)],
      [(0.10, 0.10), (0.40, 0.10), (0.55, 0.10), (0.85, 0.08)],
      [(0.20, 0.10), (0.60, 0.10)],
    ];
    final pat = patterns[seed % patterns.length];
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: ColorUtils.slate100)),
      ),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final h = c.maxHeight;
          return Stack(
            children: [
              for (final (topF, hF) in pat)
                Positioned(
                  top: topF * h,
                  left: 2,
                  right: 2,
                  height: hF * h,
                  child: Container(
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(5),
                      border: Border(
                        left: BorderSide(
                          color: ColorUtils.slate200,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A single ghost row card matching the shape of [AdminScheduleRowCard].
class _GhostRowCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Time column placeholder.
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBar(width: 40, height: 14),
                SizedBox(height: 6),
                _SkeletonBar(width: 30, height: 8),
              ],
            ),
          ),
          SizedBox(width: 10),
          // Body placeholder.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBar(width: double.infinity, height: 12),
                SizedBox(height: AppSpacing.xs),
                _SkeletonBar(width: 120, height: 10),
              ],
            ),
          ),
          SizedBox(width: 6),
          // Right rail.
          _SkeletonBar(width: 28, height: 28, radius: 8),
        ],
      ),
    );
  }
}
