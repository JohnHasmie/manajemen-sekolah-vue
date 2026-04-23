// Parent view of student attendance (presence) records.
// Like `pages/parent/Attendance.vue` in a Vue app.
//
// Read-only view of a child's attendance with monthly summary stats
// (hadir/terlambat/izin/sakit/alpha), month/semester filters, and
// auto-marking records as read when scrolled into view.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/section_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_state_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_data_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_visibility_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_tour_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_filter_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_status_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_header.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_list.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_monthly_summary.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_student_info.dart';

/// Parent's read-only view of a child's attendance.
class ParentAttendanceScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> parent;
  final String studentId;
  final String? academicYearId;

  const ParentAttendanceScreen({
    super.key,
    required this.parent,
    required this.studentId,
    this.academicYearId,
  });

  @override
  ParentAttendanceScreenState createState() => ParentAttendanceScreenState();
}

/// State combining all mixins for complete functionality.
class ParentAttendanceScreenState extends ConsumerState<ParentAttendanceScreen>
    with
        ParentAttendanceStateMixin,
        ParentAttendanceDataMixin,
        ParentAttendanceVisibilityMixin,
        ParentAttendanceTourMixin,
        ParentAttendanceFilterMixin,
        ParentAttendanceStatusMixin {
  final GlobalKey _monthlySummaryKey = GlobalKey();
  final GlobalKey _attendanceListKey = GlobalKey();

  @override
  GlobalKey get monthlySummaryKey => _monthlySummaryKey;

  @override
  GlobalKey get attendanceListKey => _attendanceListKey;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(languageProvider),
          Expanded(
            child: isLoading
                ? SkeletonListLoading(
                    itemCount: 6,
                    infoTagCount: 2,
                    baseColor: getPrimaryColor().withValues(alpha: 0.15),
                    highlightColor: getPrimaryColor().withValues(alpha: 0.05),
                  )
                : _buildContent(languageProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
    return ParentAttendanceHeader(
      gradient: getCardGradient(),
      primaryColor: getPrimaryColor(),
      studentName: student?.name,
      hasActiveFilter: hasActiveFilter,
      searchController: searchController,
      filterChips: const [],
      languageProvider: languageProvider,
      onSearchChanged: () {
        checkActiveFilter();
        calculateMonthlySummary();
        setState(() {});
      },
      onFilterTap: showFilterSheet,
      onClearAllFilters: clearAllFilters,
      onRefresh: forceRefresh,
    );
  }

  Widget _buildContent(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParentAttendanceStudentInfo(
          student: student,
          primaryColor: getPrimaryColor(),
        ),
        _buildMonthlySummary(),
        _buildFilterChipsRow(),
        SectionHeader(
          title: languageProvider.getTranslatedText({
            'en': 'Attendance History',
            'id': 'Riwayat Absensi',
          }),
          titleStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ColorUtils.slate900,
          ),
        ),
        Expanded(
          child: Container(
            key: _attendanceListKey,
            child: _buildAttendanceList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChipsRow() {
    if (!hasActiveFilter) return const SizedBox.shrink();

    final filters = _getActiveFilters();
    return ActiveFilterChips(
      filters: filters,
      primaryColor: getPrimaryColor(),
      onClearAll: clearAllFilters,
      clearAllLabel: ref.read(languageRiverpod).getTranslatedText({
        'en': 'Clear all',
        'id': 'Hapus semua',
      }),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  List<ActiveFilter> _getActiveFilters() {
    final lang = ref.read(languageRiverpod);
    final filters = <ActiveFilter>[];

    if (selectedMonthFilter != null) {
      final months = getMonthsList();
      final month = months.firstWhere((m) => m['val'] == selectedMonthFilter);
      final label = lang.getTranslatedText({
        'en': month['en']!,
        'id': month['id']!,
      });
      filters.add(
        ActiveFilter(
          label:
              '${lang.getTranslatedText({'en': 'Month', 'id': 'Bulan'})}: '
              '$label',
          onRemove: () => setState(() {
            selectedMonthFilter = null;
            checkActiveFilter();
          }),
          color: getPrimaryColor(),
          icon: Icons.calendar_month_outlined,
        ),
      );
    }

    if (selectedSemesterFilter != null) {
      filters.add(
        ActiveFilter(
          label:
              '${ref.read(languageRiverpod).getTranslatedText({'en': 'Semester', 'id': 'Semester'})}: '
              '$selectedSemesterFilter',
          onRemove: () => setState(() {
            selectedSemesterFilter = null;
            checkActiveFilter();
          }),
          color: getPrimaryColor(),
          icon: Icons.school_outlined,
        ),
      );
    }

    if (searchController.text.isNotEmpty) {
      filters.add(
        ActiveFilter(
          label:
              '${ref.read(languageRiverpod).getTranslatedText({'en': 'Search', 'id': 'Cari'})}: '
              '${searchController.text}',
          onRemove: () => setState(() {
            searchController.clear();
            checkActiveFilter();
          }),
          color: getPrimaryColor(),
          icon: Icons.search_outlined,
        ),
      );
    }

    return filters;
  }

  Widget _buildMonthlySummary() {
    return ParentAttendanceMonthlySummary(
      monthlySummary: monthlySummary,
      hasActiveFilter: hasActiveFilter,
      primaryColor: getPrimaryColor(),
      languageProvider: ref.read(languageRiverpod),
      summaryKey: _monthlySummaryKey,
      getStatusColor: getStatusColor,
    );
  }

  Widget _buildAttendanceList() {
    return ParentAttendanceList(
      attendanceData: attendanceData,
      selectedMonthFilter: selectedMonthFilter,
      selectedSemesterFilter: selectedSemesterFilter,
      searchQuery: searchController.text,
      hasActiveFilter: hasActiveFilter,
      primaryColor: getPrimaryColor(),
      onItemVisible: onItemVisible,
      normalizeStatus: normalizeStatus,
      getStatusColor: getStatusColor,
      getStatusIcon: getStatusIcon,
      getTranslatedStatus: getTranslatedStatus,
    );
  }
}
