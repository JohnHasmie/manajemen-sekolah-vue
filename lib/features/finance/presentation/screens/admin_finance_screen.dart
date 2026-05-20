import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/admin_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/class_finance_list_screen.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_navigation_bar.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_header.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_kpi_block.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_tab_content.dart';
import 'package:manajemensekolah/features/finance/domain/models/bill_group.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_fab.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/jenis_filter_pickers.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/month_filter_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/status_filter_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/tagih_reminder_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/tagihan_filter_sheet.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/finance_filter_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/finance_data_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/finance_action_mixin.dart';

/// Admin finance/billing management screen.
/// Main finance hub for payment types, bills, and pending payments.
/// Tab-based layout with CRUD, pagination, search, filtering, and verification.

/// Admin finance management screen.
class FinanceScreen extends ConsumerStatefulWidget {
  /// Optional deep-link entry point. Valid values: 0 Tagihan,
  /// 1 Pembayaran, 2 Jenis. Defaults to 0.
  ///
  /// Used by admin dashboard PendingInboxCard to route
  /// "Verifikasi pembayaran" straight into tab 1 (Pembayaran) without
  /// the user tapping through the hub first.
  final int initialTabIndex;

  const FinanceScreen({super.key, this.initialTabIndex = 0});

  @override
  FinanceScreenState createState() => FinanceScreenState();
}

/// State for FinanceScreen with mixins.
class FinanceScreenState extends ConsumerState<FinanceScreen>
    with
        FinanceFilterMixin,
        FinanceDataMixin,
        FinanceActionMixin,
        AdminAcademicYearReloadMixin<FinanceScreen> {
  /// Reload bills + pending payments + payment types when the
  /// dashboard AY picker flips. The current tab is preserved (admin
  /// stays where they were); pagination state is reset on each list
  /// so we don't accumulate pages across years. `useCache: false`
  /// avoids serving stale per-year data on the first paint.
  @override
  void onAcademicYearChanged() {
    if (!mounted) return;
    setState(() {
      _currentPage = 1;
      _hasMoreData = true;
      _pendingPage = 1;
      _hasMorePending = true;
    });
    loadData(useCache: false);
  }

  AdminFinanceController get _ctrl => ref.read(adminFinanceControllerProvider);

  // Core state
  List<dynamic> _paymentTypeList = [];
  List<dynamic> _billList = [];
  /// Aggregated Tagihan rows from `/finance/bill-groups`. The hub no
  /// longer downloads every individual bill just to group on-device
  /// — this list is what feeds the Tagihan tab. The detail screen
  /// fetches its own per-student bills on tap.
  List<BillGroup> _billGroups = [];
  List<dynamic> _pendingPaymentList = [];
  int _totalPendingPayments = 0;
  List<dynamic> _classList = [];
  List<dynamic> _studentList = [];
  Map<String, List<dynamic>> _studentsByClass = {};
  Map<String, List<dynamic>> _billsByStudent = {};
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  String _errorMessage = '';
  late int _currentTabIndex = widget.initialTabIndex.clamp(0, 2);

  /// Active sub-filter chip on the Tagihan tab — `'all'` (default),
  /// `'unpaid'`, or `'overdue'`. Drives [TagihanTab.activeFilterKey].
  String _tagihanFilterKey = 'all';

  /// Set of payment-type IDs to keep in the Tagihan list. Empty = no
  /// jenis filter applied. Driven by [TagihanFilterSheet].
  Set<String> _tagihanSelectedJenisIds = {};

  /// Single `YYYY-MM` to keep in the Tagihan list, or null = all months.
  String? _tagihanSelectedMonth;

  final ScrollController _billScrollController = ScrollController();
  final ScrollController _pendingScrollController = ScrollController();

  /// Used to measure the sticky FinanceHeader so the scrollable below
  /// it can reserve the right amount of top spacing — matters because
  /// the header height varies with status-bar inset and chip count.
  final GlobalKey _headerKey = GlobalKey();
  // Compact v2 estimate — admin Keuangan: status bar (~44) + toolbar
  // (~52) + filter strip (~32) + padding (~24) ≈ 152. Refined to the

  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  int _pendingPage = 1;
  final int _pendingPerPage = 10;
  bool _hasMorePending = true;
  bool _isLoadingMorePending = false;

  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter;
  String? _selectedPeriodFilter;
  bool _hasActiveFilter = false;

  @override
  void initState() {
    super.initState();
    _setupScrollListeners();
    loadData();
    _loadBillGroups();
  }

  /// Pull-to-refresh handler for the Tagihan tab — refreshes the
  /// legacy bill list (still feeds the bill update path + KPI overdue
  /// badge) and the new aggregated /finance/bill-groups response in
  /// parallel. The two requests are independent on the server side
  /// so running them concurrently doesn't add wall-clock latency.
  Future<void> _refreshAll() async {
    await Future.wait([loadData(), _loadBillGroups()]);
  }

  /// Fetch the aggregated Tagihan rows for the hub. Independent of the
  /// existing bill-list pipeline (which still feeds the bill update
  /// path + KPI overdue badge) so a slow groups fetch doesn't block
  /// the rest of the screen from rendering. Re-run on pull-to-refresh
  /// alongside `loadData`, and any time the academic-year / jenis /
  /// bulan filters change so the response is already narrowed by the
  /// time it reaches TagihanTab.
  Future<void> _loadBillGroups() async {
    try {
      // Deliberately NOT scoping by academic_year_id here. The global
      // AY picker drives the rest of the hub (KPI strip, Pembayaran
      // tab, Jenis tab) but admin feedback showed the Tagihan tab was
      // routinely empty because the AY picker's selected year rarely
      // matched the year stamped on the bills (esp. when the school
      // hasn't promoted classes yet for the new AY). The bulan filter
      // — which carries the year inside its `YYYY-MM` value — is the
      // explicit scope on this tab; without a bulan pick we surface
      // every (jenis × kelas × tahun) bucket the school has so the
      // admin can drill into whichever one needs attention.
      //
      // The detail screen still scopes its own per-student fetch by
      // AY when the user taps a group — that AY comes from the group
      // row itself (resolved server-side by the LATERAL join), so
      // crossings between hub-list and detail stay consistent.
      final groups = await FinanceService.getBillGroups(
        paymentTypeId: _tagihanSelectedJenisIds.length == 1
            ? _tagihanSelectedJenisIds.first
            : null,
        month: _tagihanSelectedMonth,
      );
      if (!mounted) return;
      setState(() => _billGroups = groups);
    } catch (_) {
      // Swallowed — TagihanTab renders an empty-state when the list
      // is empty, which is correct behaviour while the fetch fails
      // or returns no rows.
    }
  }

  void _setupScrollListeners() {
    _billScrollController.addListener(() {
      if (_billScrollController.position.pixels >=
          _billScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMoreData && !_isLoading) {
          loadMoreBills();
        }
      }
    });

    _pendingScrollController.addListener(() {
      if (_pendingScrollController.position.pixels >=
          _pendingScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMorePending && _hasMorePending && !_isLoading) {
          loadMorePendingPayments();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _billScrollController.dispose();
    _pendingScrollController.dispose();
    super.dispose();
  }

  // FinanceFilterMixin overrides
  @override
  TextEditingController get searchController => _searchController;
  @override
  String? get selectedStatusFilter => _selectedStatusFilter;
  @override
  String? get selectedPeriodFilter => _selectedPeriodFilter;
  @override
  bool get hasActiveFilter => _hasActiveFilter;
  @override
  Color getPrimaryColor() => _ctrl.getPrimaryColor();

  @override
  void updateStatusFilter(String? s) =>
      setState(() => _selectedStatusFilter = s);
  @override
  void updatePeriodFilter(String? p) =>
      setState(() => _selectedPeriodFilter = p);
  @override
  void updateHasActiveFilter(bool v) => setState(() => _hasActiveFilter = v);
  @override
  Future<void> loadDataAfterFilter() => loadData();

  // FinanceDataMixin overrides
  @override
  AdminFinanceController get controller => _ctrl;
  @override
  ScrollController get billScrollController => _billScrollController;
  @override
  ScrollController get pendingScrollController => _pendingScrollController;
  @override
  int get currentPage => _currentPage;
  @override
  int get perPage => _perPage;
  @override
  int get pendingPage => _pendingPage;
  @override
  int get pendingPerPage => _pendingPerPage;
  @override
  bool get hasMoreData => _hasMoreData;
  @override
  bool get hasMorePending => _hasMorePending;
  @override
  bool get isLoadingMore => _isLoadingMore;
  @override
  bool get isLoadingMorePending => _isLoadingMorePending;
  @override
  List<dynamic> get billList => _billList;
  @override
  List<dynamic> get pendingPaymentList => _pendingPaymentList;

  @override
  void updateBillPage(int v) => _currentPage = v;
  @override
  void updatePendingPage(int v) => _pendingPage = v;

  @override
  void updateBillList(List<dynamic> bills, {bool append = false}) {
    setState(() => append ? _billList.addAll(bills) : _billList = bills);
  }

  @override
  void updatePendingPaymentList(List<dynamic> p, {bool append = false}) {
    setState(
      () => append ? _pendingPaymentList.addAll(p) : _pendingPaymentList = p,
    );
  }

  @override
  void updateHasMoreData(bool v) => setState(() => _hasMoreData = v);
  @override
  void updateHasMorePending(bool v) => setState(() => _hasMorePending = v);
  @override
  void updateIsLoadingMore(bool v) => setState(() => _isLoadingMore = v);
  @override
  void updateIsLoadingMorePending(bool v) =>
      setState(() => _isLoadingMorePending = v);
  @override
  void updateIsLoading(bool v) => setState(() => _isLoading = v);

  @override
  void applyLoadedData(Map<String, dynamic> cached) {
    setState(() {
      _paymentTypeList = (cached['paymentTypes'] as List<dynamic>?) ?? [];
      _billList = (cached['bills'] as List<dynamic>?) ?? [];
      _pendingPaymentList = (cached['pendingPayments'] as List<dynamic>?) ?? [];
      _totalPendingPayments = (cached['totalPending'] as int?) ?? 0;
      _dashboardData = Map<String, dynamic>.from(cached['dashboard'] ?? {});
      _classList = (cached['classes'] as List<dynamic>?) ?? [];
      _studentList = (cached['students'] as List<dynamic>?) ?? [];
      _studentsByClass =
          (cached['studentsByClass'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<dynamic>.from(v)),
          ) ??
          {};
      _billsByStudent =
          (cached['billsByStudent'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<dynamic>.from(v)),
          ) ??
          {};
      _isLoading = false;
      _errorMessage = '';
    });
  }

  @override
  void applyResults(
    LoadPaymentTypesResult ptResult,
    LoadBillsResult billResult,
    LoadPendingPaymentsResult pendingResult,
    LoadDashboardResult dashResult,
    LoadClassDataResult classResult,
  ) {
    setState(() {
      _paymentTypeList = ptResult.paymentTypeList;
      _billList = billResult.bills;
      _hasMoreData = billResult.hasMoreData;
      _currentPage = 1;
      _pendingPaymentList = pendingResult.pendingPaymentList;
      _totalPendingPayments = pendingResult.totalPendingPayments;
      _hasMorePending = pendingResult.hasMorePending;
      _pendingPage = 1;
      _dashboardData = dashResult.dashboardData;
      _classList = classResult.classList;
      _studentList = classResult.studentList;
      _studentsByClass = classResult.studentsByClass;
      _billsByStudent = classResult.billsByStudent;
      _isLoading = false;
    });
  }

  @override
  Map<String, dynamic> buildCacheData() {
    return {
      'paymentTypes': _paymentTypeList,
      'bills': _billList,
      'pendingPayments': _pendingPaymentList,
      'totalPending': _totalPendingPayments,
      'dashboard': _dashboardData,
      'classes': _classList,
      'students': _studentList,
      'studentsByClass': _studentsByClass,
      'billsByStudent': _billsByStudent,
    };
  }

  @override
  void handleLoadError(dynamic error) {
    if (!hasMoreData) {
      _errorMessage = ErrorUtils.getFriendlyMessage(error);
    }
  }

  // FinanceActionMixin overrides
  @override
  List<dynamic> get classList => _classList;
  @override
  Map<String, List<dynamic>> get studentsByClass => _studentsByClass;
  @override
  String formatCurrency(dynamic a) => _ctrl.formatCurrency(a);
  @override
  String formatMonth(String? m) => _ctrl.formatMonth(m);
  @override
  String getGoalDescription(dynamic g) => _ctrl.getGoalDescription(g);
  @override
  String getTranslatedPeriod(String? p) => _ctrl.getTranslatedPeriod(p);
  @override
  LinearGradient getCardGradient() => _ctrl.getCardGradient();
  @override
  Future<void> loadDataAfterAction() => loadData(useCache: false);
  @override
  void updateIsLoadingForDelete(bool v) => setState(() => _isLoading = v);

  List<dynamic> _getFilteredPaymentTypes() => _ctrl.getFilteredPaymentTypes(
    paymentTypeList: _paymentTypeList,
    searchTerm: _searchController.text,
    statusFilter: _selectedStatusFilter,
    periodFilter: _selectedPeriodFilter,
  );

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: const SkeletonListLoading(itemCount: 6, infoTagCount: 1),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return ErrorScreen(errorMessage: _errorMessage, onRetry: loadData);
    }

    final filteredPaymentTypes = _getFilteredPaymentTypes();
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    final overdueCount = _computeOverdueCount();

    // Resolve all chip values + active counts up front so the header
    // gets a clean, tab-specific chip list.
    final monthLabel = _tagihanSelectedMonth == null
        ? null
        : monthFilterLabelFor(_tagihanSelectedMonth);
    final jenisLabel = _tagihanSelectedJenisIds.isEmpty
        ? null
        : '${_tagihanSelectedJenisIds.length} jenis';
    final tagihanStatus = tagihanStatusFromKey(_tagihanFilterKey);
    final tagihanStatusLabel = tagihanStatus.chipValueOrNull;

    final jenisStatusLabel = jenisStatusChipLabel(_selectedStatusFilter);
    final jenisPeriodLabel = jenisPeriodChipLabel(_selectedPeriodFilter);

    // Active count drives the tune badge on the header. Each tab has
    // its own filter universe so we count only what's relevant.
    final int activeFilterCount;
    final List<BrandFilterChip> headerChips;
    if (_currentTabIndex == 2) {
      // Jenis tab — Status + Periode
      activeFilterCount =
          (jenisStatusLabel == null ? 0 : 1) +
          (jenisPeriodLabel == null ? 0 : 1);
      headerChips = [
        BrandFilterChip(
          label: 'Status',
          value: jenisStatusLabel,
          onTap: _pickJenisStatus,
        ),
        BrandFilterChip(
          label: 'Periode',
          value: jenisPeriodLabel,
          onTap: _pickJenisPeriod,
        ),
      ];
    } else {
      // Tagihan / Pembayaran tabs — Status (bill) + Bulan + Jenis
      activeFilterCount =
          (tagihanStatus == TagihanStatusFilter.all ? 0 : 1) +
          (_tagihanSelectedMonth == null ? 0 : 1) +
          (_tagihanSelectedJenisIds.isEmpty ? 0 : 1);
      headerChips = [
        BrandFilterChip(
          label: 'Status',
          value: tagihanStatusLabel,
          onTap: _pickHeaderStatus,
        ),
        BrandFilterChip(
          label: 'Bulan',
          value: monthLabel,
          onTap: _pickHeaderMonth,
          width: 168,
        ),
        BrandFilterChip(
          label: 'Jenis',
          value: jenisLabel,
          onTap: _openTagihanFilterSheet,
        ),
      ];
    }

    // Tune-icon target: open the most-relevant filter for the active
    // tab. On Jenis we open the Status picker (Periode is one tap away
    // via its chip), on other tabs we open the Tagihan filter sheet.
    final VoidCallback onTuneTap = _currentTabIndex == 2
        ? _pickJenisStatus
        : _openTagihanFilterSheet;

    final ayId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          FinanceHeader(
            key: _headerKey,
            languageProvider: languageProvider,
            primaryColor: getPrimaryColor(),
            onTuneTap: onTuneTap,
            activeFilterCount: activeFilterCount,
            chips: headerChips,
          ),
          // KPI cards (Masuk / Terutang / Jatuh tempo + Aliran bar)
          FinanceKpiBlock(
            academicYearId: ayId,
            onOverdueTap: () => setState(() {
              _currentTabIndex = 0;
              _tagihanFilterKey = 'overdue';
            }),
          ),
          const SizedBox(height: 4),
          FinanceNavigationBar(
            currentIndex: _currentTabIndex,
            pendingCount: _totalPendingPayments,
            overdueCount: overdueCount,
            primaryColor: getPrimaryColor(),
            onTabSelected: (index) => setState(() => _currentTabIndex = index),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: FinanceTabContent(
                currentTabIndex: _currentTabIndex,
                pendingPaymentList: _pendingPaymentList,
                billGroups: _billGroups,
                academicYearId: ayId,
                languageProvider: languageProvider,
                // Pull-to-refresh on the Tagihan tab now refreshes
                // both the legacy bill list (still feeds the bill
                // update path + KPI overdue badge) and the new
                // aggregated groups in parallel.

                primaryColor: getPrimaryColor(),
                isReadOnly: isReadOnly,
                formatCurrency: formatCurrency,
                onRefresh: _refreshAll,
                filteredPaymentTypes: filteredPaymentTypes,
                searchController: _searchController,
                hasActiveFilter: _hasActiveFilter,
                onShowFilterSheet: showFilterSheet,
                onClearAllFilters: clearAllFilters,
                buildFilterChips: () => buildFilterChips(languageProvider),
                getGoalDescription: getGoalDescription,
                getTranslatedPeriod: getTranslatedPeriod,
                onEdit: (index) =>
                    showPaymentTypeDetail(filteredPaymentTypes[index]),
                onDelete: (index) =>
                    deletePaymentType(filteredPaymentTypes[index]),
                pendingScrollController: _pendingScrollController,
                hasMorePending: _hasMorePending,
                onVerify: (index) =>
                    showVerificationDialog(_pendingPaymentList[index]),
                onShowProof: (index) =>
                    showPaymentProof(_pendingPaymentList[index]),
                tagihanFilterKey: _tagihanFilterKey,
                onTagihBill: _onTagihBill,
                onClassReportTap: _openClassFinanceReport,
                tagihanSelectedJenisIds: _tagihanSelectedJenisIds,
                tagihanSelectedMonth: _tagihanSelectedMonth,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FinanceFab(
        isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
        currentTabIndex: _currentTabIndex,
        primaryColor: getPrimaryColor(),
        onPressed: showAddEditPaymentType,
      ),
    );
  }

  /// Counts unpaid bills whose due_date has already passed. Drives both
  /// the FinanceNavigationBar Tagihan badge and the Tagihan tab's
  /// "Jatuh tempo" sub-filter chip badge.
  int _computeOverdueCount() {
    final now = DateTime.now();
    var count = 0;
    for (final raw in _billList) {
      if (raw is! Map) continue;
      final b = Map<String, dynamic>.from(raw);
      final status = (b['status'] ?? '').toString().toLowerCase();
      final isUnpaid = status == 'pending' || status == 'unpaid';
      if (!isUnpaid) continue;
      final due = b['due_date'] ?? b['jatuh_tempo'] ?? b['tanggal_jatuh_tempo'];
      if (due == null) continue;
      final parsed = DateTime.tryParse(due.toString());
      if (parsed != null && parsed.isBefore(now)) count++;
    }
    return count;
  }

  void _openClassFinanceReport() {
    // ClassFinanceReportScreen requires a (classId, className) pair
    // — push the class-list screen instead so the admin can pick
    // which kelas to drill into. This is the same pattern the legacy
    // 4th tab used to render inline.
    AppNavigator.push(context, const ClassFinanceListScreen());
  }

  /// Header Jenis-tab Status chip — opens the Aktif/Nonaktif picker
  /// and writes through to the FinanceFilterMixin's
  /// `_selectedStatusFilter`, which `_getFilteredPaymentTypes()`
  /// already consumes.
  Future<void> _pickJenisStatus() async {
    final picked = await showJenisStatusPickerSheet(
      context,
      primaryColor: getPrimaryColor(),
      initial: _selectedStatusFilter,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedStatusFilter = picked.value;
      _hasActiveFilter =
          _selectedStatusFilter != null || _selectedPeriodFilter != null;
    });
  }

  /// Header Jenis-tab Periode chip — opens the
  /// Sekali/Bulanan/Semester/Tahunan picker. Same wire-through as
  /// status above.
  Future<void> _pickJenisPeriod() async {
    final picked = await showJenisPeriodPickerSheet(
      context,
      primaryColor: getPrimaryColor(),
      initial: _selectedPeriodFilter,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedPeriodFilter = picked.value;
      _hasActiveFilter =
          _selectedStatusFilter != null || _selectedPeriodFilter != null;
    });
  }

  /// Opens the Status picker sheet from the header chip. Result writes
  /// to `_tagihanFilterKey` — the same slot the (now-removed) in-body
  /// sub-filter strip used to drive — so the existing TagihanTab
  /// filter logic keeps working unchanged.
  Future<void> _pickHeaderStatus() async {
    final overdueCount = _computeOverdueCount();
    final picked = await showTagihanStatusFilterSheet(
      context,
      primaryColor: getPrimaryColor(),
      initial: tagihanStatusFromKey(_tagihanFilterKey),
      overdueCount: overdueCount,
    );
    if (!mounted || picked == null) return;
    setState(() => _tagihanFilterKey = picked.key);
  }

  /// Opens the month picker sheet from the header period pill. The
  /// chosen value is stored in the same `_tagihanSelectedMonth` slot
  /// the Tagihan filter sheet writes to — so picking "Mei 2026" from
  /// the pill scopes the Tagihan list to that month, the pill label
  /// updates, and the dedicated Tagihan filter toolbar reflects the
  /// same selection. Picking "Semua bulan" resets the override and
  /// the pill falls back to the API's `periodLabel`.
  Future<void> _pickHeaderMonth() async {
    final result = await showMonthFilterSheet(
      context,
      primaryColor: getPrimaryColor(),
      initialMonth: _tagihanSelectedMonth,
    );
    if (!mounted || result == null) return;
    setState(() => _tagihanSelectedMonth = result.month);
    _loadBillGroups();
  }

  /// Opens the Tagihan filter sheet with the current jenis + month
  /// selections pre-applied. Stores the result back into screen state
  /// so the next rebuild filters the bill list.
  Future<void> _openTagihanFilterSheet() async {
    final jenisOptions = _paymentTypeList
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .map(
          (m) => {
            'id': (m['id'] ?? '').toString(),
            'name': (m['name'] ?? '-').toString(),
          },
        )
        .where((opt) => opt['id']!.isNotEmpty)
        .toList(growable: false);

    final result = await showTagihanFilterSheet(
      context,
      primaryColor: getPrimaryColor(),
      jenisOptions: jenisOptions,
      initialJenisIds: _tagihanSelectedJenisIds,
      initialMonth: _tagihanSelectedMonth,
    );
    if (!mounted || result == null) return;
    setState(() {
      _tagihanSelectedJenisIds = result.selectedJenisIds;
      _tagihanSelectedMonth = result.selectedMonth;
    });
    // Re-fetch groups so the server-side filter narrows the new list.
    _loadBillGroups();
  }

  /// Tagih button handler — opens [showTagihReminderSheet] for the
  /// chosen bill. On confirm, calls
  /// `POST /finance/bills/{id}/remind`, then syncs the local row's
  /// `reminder_count` + `last_reminded_at` from the response. Errors
  /// surface as a snackbar without bumping the counter so the row
  /// truthfully reflects backend state.
  Future<void> _onTagihBill(Map<String, dynamic> bill) async {
    final sheetResult = await showTagihReminderSheet(context, bill: bill);
    if (sheetResult == null || !mounted) return;

    final id = bill['id']?.toString();
    if (id == null || id.isEmpty) return;

    final channelLabel = sheetResult.channel == TagihReminderChannel.whatsapp
        ? 'WhatsApp'
        : 'Email';
    final channelKey = sheetResult.channel == TagihReminderChannel.whatsapp
        ? 'whatsapp'
        : 'email';

    try {
      final response = await FinanceService.remindBill(
        billId: id,
        channel: channelKey,
      );
      if (!mounted) return;

      final data = response['data'];
      final newCount = (data is Map && data['reminder_count'] is num)
          ? (data['reminder_count'] as num).toInt()
          : ((bill['reminder_count'] as num?)?.toInt() ?? 0) + 1;
      final lastRemindedAt = (data is Map && data['last_reminded_at'] != null)
          ? data['last_reminded_at'].toString()
          : DateTime.now().toIso8601String();

      setState(() {
        for (var i = 0; i < _billList.length; i++) {
          final raw = _billList[i];
          if (raw is! Map) continue;
          if (raw['id']?.toString() != id) continue;
          final updated = Map<String, dynamic>.from(raw);
          updated['reminder_count'] = newCount;
          updated['last_reminded_at'] = lastRemindedAt;
          _billList[i] = updated;
          break;
        }
      });

      SnackBarUtils.showSuccess(
        context,
        'Pengingat tagihan terkirim via $channelLabel.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal mencatat pengingat: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }
}

// =====================================================================
// SliverPersistentHeader delegate that pins the navigation bar below
