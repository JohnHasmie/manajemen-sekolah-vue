// Attendance popup dialog - shows detailed attendance chart data per class.
//
// Extracted from dashboard_screen.dart to keep that file focused on the main
// dashboard layout. This dialog is shown when the user taps the attendance
// overview card on the admin or parent dashboard.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/dashboard/'
    'presentation/widgets/schedule_slider_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mixins/dropdown_builder_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mixins/chart_content_builder_mixin.dart';

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

class _AttendancePopupDialogState extends State<AttendancePopupDialog>
    with DropdownBuilderMixin, ChartContentBuilderMixin {
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

  // Mixin abstract getters and setters
  @override
  PageController get pageController => _pageController;

  @override
  bool get isWeekly => _isWeekly;

  @override
  String get selectedMonth => _selectedMonth;

  @override
  String get selectedWeek => _selectedWeek;

  @override
  List<String> get months => _months;

  @override
  List<String> get weeks => _weeks;

  @override
  bool get isLoading => _isLoading;

  @override
  List<Map<String, dynamic>> get classesData => _classesData;

  @override
  void _setIsWeekly(bool value) {
    _isWeekly = value;
  }

  @override
  void _setSelectedMonth(String value) {
    _selectedMonth = value;
  }

  @override
  void _setSelectedWeek(String value) {
    _selectedWeek = value;
  }

  @override
  void initState() {
    super.initState();
    _initializeMonths();
    _initializeSelectedValues();
    _loadInitialData();
  }

  void _initializeMonths() {
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
  }

  void _initializeSelectedValues() {
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

    if (_months.contains(currentMonthName)) {
      _selectedMonth = currentMonthName;
    } else {
      _selectedMonth = _months.first;
    }

    int currentWeek = (now.day / 7).ceil();
    if (currentWeek > 5) currentWeek = 5;
    _selectedWeek = 'Pekan $currentWeek';
  }

  void _loadInitialData() {
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _classesData = List.from(widget.initialData!);
    } else {
      fetchData();
    }
  }

  @override
  Future<void> fetchData() async {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildChartContent(),
            const SizedBox(height: AppSpacing.lg),
            SmoothPageIndicator(
              controller: _pageController,
              count: _classesData.length,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildCloseButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => AppNavigator.pop(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorUtils.warning600,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(AppLocalizations.close.tr),
    );
  }

  @override
  Widget buildDropdownBuilderSection() {
    return buildTypeDropdown();
  }
}
