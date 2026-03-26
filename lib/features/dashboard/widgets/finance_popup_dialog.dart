// Finance popup dialog - shows detailed finance chart data per semester.
//
// Extracted from dashboard_screen.dart to keep that file focused on the main
// dashboard layout. This dialog is shown when the user taps the finance
// overview card on the admin dashboard.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/dashboard/widgets/mini_bar_chart.dart';
import 'package:manajemensekolah/features/dashboard/widgets/schedule_slider_card.dart';

class FinancePopupDialog extends StatefulWidget {
  final List<Map<String, dynamic>> semestersData;

  const FinancePopupDialog({super.key, required this.semestersData});

  @override
  State<FinancePopupDialog> createState() => _FinancePopupDialogState();
}

class _FinancePopupDialogState extends State<FinancePopupDialog> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 380, // Fixed height for page view
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.semestersData.length,
                itemBuilder: (context, index) {
                  final item = widget.semestersData[index];
                  final subtitle = item['subtitle'] as String;
                  final title = 'Detail $subtitle';
                  final chartData = List<double>.from(
                    (item['data'] as List).map((e) => (e as num).toDouble()),
                  );
                  final isGenap = subtitle.toLowerCase().contains('genap');

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Geser ke kiri/kanan untuk melihat riwayat',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Use an explicit container without ScrollView so PageView catches horizontal swipe gestures
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            alignment: Alignment.center,
                            height: 200,
                            child: MiniBarChart(
                              data: chartData,
                              color: ColorUtils.success600,
                              height: 200,
                              width:
                                  chartData.length *
                                  44.0, // Reduced from 50 to 44 to better fit small screens without scrolling
                              barWidth: 28.0,
                              barSpacing: 16.0,
                              cornerRadius: 4.0,
                              showLabels: true,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ColorUtils.slate700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              chartData.length,
                              (idx) => Container(
                                width:
                                    44.0, // Matching the new total width unit
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
                                  ][isGenap ? idx : (idx + 6)],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ColorUtils.slate600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SmoothPageIndicator(
              controller: _pageController,
              count: widget.semestersData.length,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => AppNavigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.success600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }
}
