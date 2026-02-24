import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/dashboard_typography.dart';
import 'package:manajemensekolah/widgets/dashboard/mini_bar_chart.dart';
import 'package:manajemensekolah/widgets/dashboard/schedule_slider_card.dart'; // For SmoothPageIndicator

class AttendanceBarChartCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Map<String, dynamic>> classesData;
  final VoidCallback? onTap;

  const AttendanceBarChartCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.classesData,
    this.onTap,
  });

  @override
  State<AttendanceBarChartCard> createState() => _AttendanceBarChartCardState();
}

class _AttendanceBarChartCardState extends State<AttendanceBarChartCard> {
  final PageController _pageController = PageController();
  bool _isWeekly = true;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.classesData.isEmpty) {
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
            physics: const BouncingScrollPhysics(),
            itemCount: widget.classesData.length,
            itemBuilder: (context, index) {
              final classItem = widget.classesData[index];
              final subtitle = classItem['subtitle'] as String;
              final weeklyData = List<double>.from(
                (classItem['weekly_data'] as List).map(
                  (e) => (e as num).toDouble(),
                ),
              );
              final dailyData = List<double>.from(
                (classItem['daily_data'] as List).map(
                  (e) => (e as num).toDouble(),
                ),
              );
              final chartData = _isWeekly ? weeklyData : dailyData;

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
                          // Dropdowns and Toggle
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [_buildTypeDropdown()],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Main Visual: Bar Chart or Empty State
                      if (classItem['title'] == 'Absensi Belum Ada Data' ||
                          chartData.every((val) => val == 0.0))
                        SizedBox(
                          height: 60,
                          child: Center(
                            child: Text(
                              'Belum ada data kehadiran siswa',
                              style: TextStyle(
                                fontSize: 11,
                                color: ColorUtils.slate400,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      else
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
                                width: chartData.length * 31.0,
                                barWidth: 16.0,
                                barSpacing: 15.0,
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
                                  width: 31.0,
                                  alignment: Alignment.center,
                                  child: Text(
                                    _isWeekly
                                        ? 'P${idx + 1}'
                                        : [
                                            'Sen',
                                            'Sel',
                                            'Rab',
                                            'Kam',
                                            'Jum',
                                            'Sab',
                                          ][idx],
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
          if (widget.classesData.length > 1)
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: min(
                    widget.classesData.length,
                    5,
                  ), // Show max 5 dots to not overload UI
                ),
              ),
            ),
        ],
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;

  Widget _buildTypeDropdown() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _isWeekly ? 'Pekanan' : 'Harian',
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: ColorUtils.slate500,
          ),
          isDense: true,
          style: TextStyle(
            fontSize: 10,
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _isWeekly = newValue == 'Pekanan';
              });
            }
          },
          items: ['Harian', 'Pekanan'].map<DropdownMenuItem<String>>((
            String value,
          ) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }
}
