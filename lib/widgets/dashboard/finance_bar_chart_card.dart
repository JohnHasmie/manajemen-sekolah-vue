// Finance bar chart card for the dashboard, with swipeable semester pages.
//
// Like a Vue `<FinanceChartCard>` dashboard widget using Chart.js to display
// monthly payment data per semester. Supports swiping between semesters
// (PageView). Similar to a Laravel admin dashboard finance chart panel.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/dashboard_typography.dart';
import 'package:manajemensekolah/widgets/dashboard/mini_bar_chart.dart';
import 'package:manajemensekolah/widgets/dashboard/schedule_slider_card.dart'; // For SmoothPageIndicator

/// A swipeable finance bar chart card showing monthly payment data per semester.
///
/// Like a Vue `<FinanceBarChartCard>` with props:
/// - [title] / [icon] / [accentColor] - card header styling
/// - [semestersData] - list of semester data maps, each with 'subtitle' and 'data' array
/// - [onTap] - navigate to full finance screen
///
/// Uses a `PageView` for swiping between semesters and [MiniBarChart] for rendering.
/// X-axis labels show month abbreviations, adjusted based on semester (ganjil/genap).
class FinanceBarChartCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Map<String, dynamic>> semestersData;
  final VoidCallback? onTap;

  const FinanceBarChartCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.semestersData,
    this.onTap,
  });

  @override
  State<FinanceBarChartCard> createState() => _FinanceBarChartCardState();
}

class _FinanceBarChartCardState extends State<FinanceBarChartCard> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.semestersData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: ColorUtils.statCardDecoration(
        accentColor: widget.accentColor,
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.semestersData.length,
            itemBuilder: (context, index) {
              final semester = widget.semestersData[index];
              final subtitle = semester['subtitle'] as String;
              final chartData = List<double>.from(
                (semester['data'] as List).map((e) => (e as num).toDouble()),
              );

              return InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 16,
                              color: widget.accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: DashboardTypography.statTitle(
                                    color: ColorUtils.slate600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    style: DashboardTypography.statSubtitle(
                                      color: ColorUtils.slate500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Main Visual: Bar Chart (Not Scrollable, fit to block)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 40,
                            child: MiniBarChart(
                              data: chartData,
                              color: widget.accentColor,
                              height: 40,
                              width:
                                  chartData.length *
                                  24.0, // Calculate width based on items (barWidth 14 + barSpacing 10)
                              barWidth: 14.0,
                              barSpacing: 10.0,
                              cornerRadius: 2.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // X-axis labels
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              chartData.length,
                              (idx) => Container(
                                width:
                                    24.0, // Exact barWidth(14) + barSpacing(10)
                                alignment: Alignment.center,
                                child: Text(
                                  [
                                    'Jan',
                                    'Feb',
                                    'Mar',
                                    'Apr',
                                    'Mei',
                                    'Jun',
                                    'Jul',
                                    'Ags',
                                    'Sep',
                                    'Okt',
                                    'Nov',
                                    'Des',
                                  ][subtitle.toLowerCase().contains('genap')
                                      ? idx
                                      : (idx + 6)],
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: ColorUtils.slate400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8), // Padding for page indicator
                    ],
                  ),
                ),
              );
            },
          ),
          // Page Indicator (dots)
          if (widget.semestersData.length > 1)
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: widget.semestersData.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
