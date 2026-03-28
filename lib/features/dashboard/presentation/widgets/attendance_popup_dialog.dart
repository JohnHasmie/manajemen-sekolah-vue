// Attendance popup dialog - shows detailed attendance chart data per class.
//
// Extracted from dashboard_screen.dart to keep that file focused on the main
// dashboard layout. This dialog is shown when the user taps the attendance
// overview card on the admin or parent dashboard.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mini_bar_chart.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/schedule_slider_card.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

class AttendancePopupDialog extends StatefulWidget {
  final String? semesterLabel;
  final List<Map<String, dynamic>>? initialData;
  final String? academicYearId;

  const AttendancePopupDialog({
    super.key,
    this.semesterLabel,
    this.initialData,
    this.academicYearId,
  });

  @override
  State<AttendancePopupDialog> createState() => _AttendancePopupDialogState();
}

class _AttendancePopupDialogState extends State<AttendancePopupDialog> {
  final PageController _pageController = PageController();

  bool _isWeekly = true;
  late String _selectedMonth;
  String _selectedWeek = 'Pekan 1';

  late List<String> _months;
  final List<String> _weeks = [
    'Pekan 1',
    'Pekan 2',
    'Pekan 3',
    'Pekan 4',
    'Pekan 5',
  ];

  bool _isLoading = false;
  List<Map<String, dynamic>> _classesData = [];

  @override
  void initState() {
    super.initState();
    // Default to Ganjil (Juli-Desember) if semester isn't identified
    final isGenap =
        widget.semesterLabel?.toLowerCase().contains('genap') ?? false;

    if (isGenap) {
      _months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni'];
    } else {
      _months = [
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
    }

    final now = DateTime.now();
    final allMonths = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final currentMonthName = allMonths[now.month - 1];

    // Check if the current month is applicable for the chosen semester
    if (_months.contains(currentMonthName)) {
      _selectedMonth = currentMonthName;
    } else {
      _selectedMonth = _months.first;
    }

    int currentWeek = (now.day / 7).ceil();
    if (currentWeek > 5) currentWeek = 5;
    _selectedWeek = 'Pekan $currentWeek';

    // Load initial data if available, or fetch fresh
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _classesData = List.from(widget.initialData!);
    } else {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fetchedData = await AttendanceService.getAttendanceDashboardChart(
        academicYearId: widget.academicYearId,
        month: _selectedMonth,
        week: _selectedWeek,
      );

      if (mounted) {
        setState(() {
          _classesData = List<Map<String, dynamic>>.from(fetchedData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // You could show a snackbar here
      }
    }
  }

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
            _isLoading
                ? SizedBox(
                    height: 380,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ColorUtils.warning600,
                      ),
                    ),
                  )
                : _classesData.isEmpty
                ? const SizedBox(
                    height: 380,
                    child: Center(
                      child: Text('Tidak ada data absensi untuk periode ini'),
                    ),
                  )
                : SizedBox(
                    height: 380, // Fixed height for page view
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _classesData.length,
                      itemBuilder: (context, index) {
                        final item = _classesData[index];
                        final title = item['title'] as String;
                        final List<double> chartData = _isWeekly
                            ? List<double>.from(
                                (item['weekly_data'] as List).map(
                                  (e) => (e as num).toDouble(),
                                ),
                              )
                            : List<double>.from(
                                (item['daily_data'] as List).map(
                                  (e) => (e as num).toDouble(),
                                ),
                              );

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: ColorUtils.slate800,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildTypeDropdown(),
                                    const SizedBox(height: AppSpacing.sm),
                                    _isWeekly
                                        ? _buildMonthDropdown()
                                        : _buildWeekDropdown(),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Geser ke kiri/kanan untuk berpindah kelas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorUtils.slate500,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            if (title == 'Absensi Belum Ada Data' ||
                                chartData.every((val) => val == 0.0))
                              SizedBox(
                                height:
                                    212, // match the height of 200 MiniBarChart + 12 spaces
                                child: Center(
                                  child: Text(
                                    'Belum ada data kehadiran siswa pada periode ini',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: ColorUtils.slate400,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    alignment: Alignment.center,
                                    height: 200,
                                    child: MiniBarChart(
                                      data: chartData,
                                      color: ColorUtils.warning600,
                                      height: 200,
                                      width: chartData.length * 44.0,
                                      barWidth: 22.0,
                                      barSpacing: 22.0,
                                      cornerRadius: 4.0,
                                      showLabels: true,
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: ColorUtils.slate700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      chartData.length,
                                      (idx) => Container(
                                        width:
                                            44.0, // Matching the new total width unit
                                        alignment: Alignment.center,
                                        child: Text(
                                          _isWeekly
                                              ? 'Pekan ${idx + 1}'
                                              : [
                                                  'Sen',
                                                  'Sel',
                                                  'Rab',
                                                  'Kam',
                                                  'Jum',
                                                  'Sab',
                                                ][idx],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: ColorUtils.slate600,
                                          ),
                                          maxLines: 1, // Prevent wrapping
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
            const SizedBox(height: AppSpacing.lg),
            SmoothPageIndicator(
              controller: _pageController,
              count: _classesData.length,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: () => AppNavigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.warning600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(AppLocalizations.close.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
            size: 16,
            color: ColorUtils.slate500,
          ),
          isDense: true,
          style: TextStyle(
            fontSize: 12,
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

  Widget _buildMonthDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMonth,
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
            if (newValue != null && newValue != _selectedMonth) {
              setState(() {
                _selectedMonth = newValue;
              });
              _fetchData();
            }
          },
          items: _months.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWeekDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedWeek,
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
            if (newValue != null && newValue != _selectedWeek) {
              setState(() {
                _selectedWeek = newValue;
              });
              _fetchData();
            }
          },
          items: _weeks.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }
}
