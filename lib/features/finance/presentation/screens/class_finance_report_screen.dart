// Class-level finance report screen - shows billing/payment status
// per student. Supports filtering by student name, payment type,
// month, and payment status.
//
// Used both as a stand-alone route AND as an embedded drill-down inside
// the admin finance hub's Class Report tab. When [embedded] is true,
// the outer [Scaffold] is dropped and [onBack] replaces route-pop so the
// hub keeps its header + tab-bar visible during the drill-down.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/class_finance_data_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/class_finance_payment_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/class_finance_ui_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/class_finance_utils_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_table.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';

/// Class finance report screen showing billing and payment details
/// for a specific class. Displays students and their bills with
/// filtering and payment management capabilities.
class ClassFinanceReportScreen extends StatefulWidget {
  final String classId;
  final String className;
  final String? academicYearId;

  /// Whether this widget is embedded inside the admin finance hub.
  ///
  /// When `true`, the outer [Scaffold] + gradient hero are dropped in favour
  /// of a compact back-bar so the hub's header and tab-bar stay visible.
  final bool embedded;

  /// Called when the user taps the back chevron. Only used when [embedded] is
  /// true — outside the hub the screen falls back to [AppNavigator.pop].
  final VoidCallback? onBack;

  const ClassFinanceReportScreen({
    super.key,
    required this.classId,
    required this.className,
    this.academicYearId,
    this.embedded = false,
    this.onBack,
  });

  @override
  State<ClassFinanceReportScreen> createState() =>
      _ClassFinanceReportScreenState();
}

/// State for [ClassFinanceReportScreen] with data loading, payment
/// handling, and UI management.
///
/// Loading / data / error state lives on [ClassFinanceDataMixin]'s
/// `late` fields (`isLoadingData`, `errorMessage`, `students`,
/// `billsByStudent`, `monthGroups`). They are seeded in [initState]
/// before [loadData] runs — without that, the mixin's `setState`
/// would trip a `LateInitializationError` on the very first read.
///
/// Earlier versions kept private final shadows here (`_isLoading =
/// true`, `_students = []`, …) which never got mutated, so `build()`
/// rendered a perpetual loading screen even after the mixin's fetch
/// returned successfully — the loaded data lived on different
/// fields. Don't reintroduce those shadows.
class _ClassFinanceReportScreenState extends State<ClassFinanceReportScreen>
    with
        ClassFinanceDataMixin,
        ClassFinancePaymentMixin,
        ClassFinanceUtilsMixin,
        ClassFinanceUIMixin {
  @override
  File? selectedFile;

  String _searchQuery = '';
  String? _selectedPaymentTypeId;
  String? _selectedMonthKey;
  String _selectedStatus = 'Semua';

  @override
  void initState() {
    super.initState();
    // Seed the mixin's late fields so the first `setState` inside
    // loadData() doesn't trip LateInitializationError. The screen
    // owns no shadow state — mixin fields are the single source.
    apiService = ApiService();
    students = const [];
    billsByStudent = const {};
    monthGroups = const [];
    isLoadingData = true;
    errorMessage = null;
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return _buildLoadingScreen();
    }
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      final errorChild = ErrorScreen(
        errorMessage: errorMessage!,
        onRetry: loadData,
      );
      return widget.embedded ? errorChild : errorChild;
    }
    return _buildMainContent();
  }

  Widget _buildLoadingScreen() {
    final column = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: const SkeletonListLoading(itemCount: 6, infoTagCount: 1),
          ),
        ),
      ],
    );

    if (widget.embedded) return column;
    return Scaffold(backgroundColor: ColorUtils.slate50, body: column);
  }

  Widget _buildMainContent() {
    final column = Column(
      children: [
        _buildHeader(),
        if (_hasActiveFilters()) _buildActiveFiltersRow(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: students.isEmpty
                ? const EmptyState(
                    title: 'Tidak ada siswa',
                    subtitle: 'Kelas ini belum memiliki siswa',
                    icon: Icons.people_outline,
                  )
                : _buildTableContent(),
          ),
        ),
      ],
    );

    if (widget.embedded) return column;
    return Scaffold(backgroundColor: ColorUtils.slate50, body: column);
  }

  Widget _buildTableContent() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: ClassFinanceTable(
        students: students,
        billsByStudent: billsByStudent,
        monthGroups: monthGroups,
        searchQuery: _searchQuery,
        selectedPaymentTypeId: _selectedPaymentTypeId,
        selectedMonthKey: _selectedMonthKey,
        selectedStatus: _selectedStatus,
        onBillTap: showPaymentOptions,
      ),
    );
  }

  Widget _buildHeader() {
    if (widget.embedded) return _buildEmbeddedHeader();

    final c = getPrimaryColor();
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, c.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderTop(),
          const SizedBox(height: AppSpacing.lg),
          _buildSearchAndFilterRow(),
        ],
      ),
    );
  }

  /// Compact back-bar used when rendered inside the admin finance hub.
  ///
  /// Keeps the hub's own gradient header + tab-bar visible above and falls
  /// back to a white tile with a back chevron, class name, and the shared
  /// search + filter row.
  Widget _buildEmbeddedHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _onBackPressed,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: ColorUtils.slate700,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.className,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Laporan Keuangan',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildEmbeddedSearchRow(),
        ],
      ),
    );
  }

  Widget _buildEmbeddedSearchRow() {
    final active = _hasActiveFilters();
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari siswa...',
                hintStyle: TextStyle(color: ColorUtils.slate400),
                prefixIcon: Icon(Icons.search, color: ColorUtils.slate400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: () => showFilterSheet(
            monthGroups,
            _selectedStatus,
            _selectedMonthKey,
            _selectedPaymentTypeId,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: active ? getPrimaryColor() : ColorUtils.slate50,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: active ? getPrimaryColor() : ColorUtils.slate200,
              ),
            ),
            child: Icon(
              Icons.tune,
              color: active ? Colors.white : ColorUtils.slate700,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  void _onBackPressed() {
    if (widget.embedded && widget.onBack != null) {
      widget.onBack!.call();
    } else {
      AppNavigator.pop(context);
    }
  }

  Widget _buildHeaderTop() => Row(
    children: [
      GestureDetector(
        onTap: _onBackPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.className,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            AppSpacing.v2,
            Text(
              'Laporan Keuangan',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildSearchAndFilterRow() {
    return Row(
      children: [
        Expanded(child: _buildSearchField()),
        const SizedBox(width: AppSpacing.sm),
        _buildFilterButton(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Cari siswa...',
          hintStyle: TextStyle(color: ColorUtils.slate400),
          prefixIcon: Icon(Icons.search, color: ColorUtils.slate400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildFilterButton() {
    return GestureDetector(
      onTap: () => showFilterSheet(
        monthGroups,
        _selectedStatus,
        _selectedMonthKey,
        _selectedPaymentTypeId,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _hasActiveFilters()
              ? Colors.white
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Icon(
          Icons.filter_list,
          color: _hasActiveFilters() ? getPrimaryColor() : Colors.white,
        ),
      ),
    );
  }

  Widget _buildActiveFiltersRow() {
    final filters = <ActiveFilter>[];
    if (_selectedStatus != 'Semua') {
      filters.add(
        ActiveFilter(
          label: 'Status: $_selectedStatus',
          onRemove: () => setState(() => _selectedStatus = 'Semua'),
        ),
      );
    }
    if (_selectedMonthKey != null) {
      filters.add(
        ActiveFilter(
          label: 'Bulan: ${_getSelectedMonthName()}',
          onRemove: () => setState(() => _selectedMonthKey = null),
        ),
      );
    }
    if (_selectedPaymentTypeId != null) {
      filters.add(
        ActiveFilter(
          label: 'Jenis: Pembayaran Terpilih',
          onRemove: () => setState(() => _selectedPaymentTypeId = null),
        ),
      );
    }
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ActiveFilterChips(
        filters: filters,
        primaryColor: getPrimaryColor(),
        onClearAll: () => setState(() {
          _selectedStatus = 'Semua';
          _selectedMonthKey = null;
          _selectedPaymentTypeId = null;
        }),
        padding: EdgeInsets.zero,
      ),
    );
  }

  String _getSelectedMonthName() {
    return monthGroups
        .firstWhere(
          (m) => m.monthKey == _selectedMonthKey,
          orElse: () => MonthGroup(
            monthKey: '',
            monthName: _selectedMonthKey!,
            paymentTypes: [],
          ),
        )
        .monthName;
  }

  bool _hasActiveFilters() {
    return _selectedStatus != 'Semua' ||
        _selectedMonthKey != null ||
        _selectedPaymentTypeId != null;
  }

  // === Mixin implementations ===
  @override
  String getClassId() => widget.classId;
  @override
  void onImagePicked(File file) => selectedFile = file;
  @override
  void onFilePicked(File file) => selectedFile = file;
  @override
  void onPaymentSuccess() => loadData();
  @override
  void onStatusFilterChanged(String s) => setState(() => _selectedStatus = s);
  @override
  void onMonthFilterChanged(String? m) => setState(() => _selectedMonthKey = m);
  @override
  void onPaymentTypeFilterChanged(String? t) =>
      setState(() => _selectedPaymentTypeId = t);
}
