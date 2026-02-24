import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/dashboard_typography.dart';
import 'package:manajemensekolah/widgets/dashboard/mini_bar_chart.dart';

class FinanceBarChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<double> chartData;
  final VoidCallback? onTap;

  const FinanceBarChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.chartData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: ColorUtils.statCardDecoration(accentColor: accentColor),
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
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
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
              // Main Visual: Bar Chart
              SizedBox(
                height: 45,
                child: MiniBarChart(
                  data: chartData,
                  color: accentColor,
                  height: 45,
                  width: double.infinity, // Take up full width internally
                  barWidth: 8.0,
                  barSpacing: 4.0,
                  cornerRadius: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              // Dummy X-axis labels for months context (last 6 months assuming 6 data points)
              if (chartData.length == 6)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (index) => Text(
                      ['Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'][index],
                      style: TextStyle(
                        fontSize: 9,
                        color: ColorUtils.slate400,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
