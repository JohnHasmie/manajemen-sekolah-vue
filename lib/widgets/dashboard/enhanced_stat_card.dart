// Enhanced statistics card for the dashboard with trend indicators and sparklines.
//
// Like a Vue `<StatCard>` dashboard widget you would build with Chart.js or
// ApexCharts for a Laravel admin panel. Displays a key metric with an icon,
// optional trend badge (+12%, -5%), a progress bar, or a sparkline chart.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/dashboard_typography.dart';
import 'package:manajemensekolah/widgets/dashboard/mini_sparkline.dart';

/// Enhanced statistics card for professional dashboard display.
///
/// Like a Vue `<EnhancedStatCard>` with props:
/// - [title] / [value] / [subtitle] - text content
/// - [icon] - can be `IconData` or emoji `String` (like a Vue dynamic component)
/// - [accentColor] - theme color for the card accent
/// - [trend] - optional trend badge text (e.g., "+12%", "-5%")
/// - [progress] - optional progress bar value (0.0 to 1.0)
/// - [sparklineData] - optional data points for a mini sparkline chart
/// - [onTap] - navigation callback
/// - [isLoading] - shows placeholder skeleton when true
///
/// Supports progress indicators, trends, and sparklines in a compact card.
class EnhancedStatCard extends StatelessWidget {
  /// Main title of the statistic
  final String title;

  /// Primary value to display
  final String value;

  /// Subtitle or description
  final String subtitle;

  /// Icon to display (can be IconData or emoji string)
  final dynamic icon;

  /// Accent color for the card
  final Color accentColor;

  /// Optional trend indicator (e.g., "+12%", "-5%")
  final String? trend;

  /// Optional progress value (0.0 - 1.0)
  final double? progress;

  /// Optional sparkline data points
  final List<double>? sparklineData;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  /// Whether card is currently loading
  final bool isLoading;

  const EnhancedStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.trend,
    this.progress,
    this.sparklineData,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 160,
          height: 130,
          padding: EdgeInsets.all(16),
          decoration: ColorUtils.statCardDecoration(accentColor: accentColor),
          child: isLoading ? _buildLoadingState() : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ColorUtils.slate200,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        SizedBox(height: 12),
        Container(
          width: 60,
          height: 20,
          decoration: BoxDecoration(
            color: ColorUtils.slate200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(height: 4),
        Container(
          width: 100,
          height: 14,
          decoration: BoxDecoration(
            color: ColorUtils.slate200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon and trend row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildIcon(),
            if (trend != null) _buildTrendBadge(),
          ],
        ),
        SizedBox(height: 12),

        // Value and title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: DashboardTypography.statValue(
                  color: ColorUtils.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Text(
                title,
                style: DashboardTypography.statTitle(
                  color: ColorUtils.slate600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                SizedBox(height: 1),
                Text(
                  subtitle,
                  style: DashboardTypography.statSubtitle(
                    color: ColorUtils.slate500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Visual indicator at bottom
        if (progress != null || sparklineData != null)
          _buildVisualIndicator(),
      ],
    );
  }

  Widget _buildIcon() {
    if (icon is IconData) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon as IconData,
          size: 20,
          color: accentColor,
        ),
      );
    } else if (icon is String) {
      // Handle emoji icons
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            icon as String,
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildTrendBadge() {
    final isPositive = trend!.startsWith('+');
    final isNegative = trend!.startsWith('-');

    Color trendColor;
    IconData trendIcon;

    if (isPositive) {
      trendColor = ColorUtils.success600;
      trendIcon = Icons.trending_up;
    } else if (isNegative) {
      trendColor = ColorUtils.error600;
      trendIcon = Icons.trending_down;
    } else {
      trendColor = ColorUtils.slate500;
      trendIcon = Icons.trending_flat;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 12, color: trendColor),
          SizedBox(width: 2),
          Text(
            trend!,
            style: DashboardTypography.trendText(color: trendColor),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualIndicator() {
    if (sparklineData != null && sparklineData!.isNotEmpty) {
      return MiniSparkline(
        data: sparklineData!,
        color: accentColor,
        height: 24,
        strokeWidth: 1.5,
        fillArea: true,
      );
    }

    if (progress != null) {
      return Column(
        children: [
          SizedBox(height: 4),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth * progress!.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return SizedBox.shrink();
  }
}
