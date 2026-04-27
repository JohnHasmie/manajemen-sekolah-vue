import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/admin_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_navigation_bar.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_header.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_tab_content.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_fab.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/finance_filter_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/finance_data_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/finance_action_mixin.dart';

/// Admin finance/billing management screen.
/// Main finance hub for payment types, bills, and pending payments.
/// Tab-based layout with CRUD, pagination, search, filtering, and verification.

/// Admin finance management screen.
class FinanceScreen extends ConsumerStatefulWidget {
  /// Optional deep-link entry point. Valid values: 0 Dashboard, 1 Payment
  /// Types, 2 Verification, 3 Class Report. Defaults to 0.
  ///
  /// Used by admin dashboard PendingInboxCard to route "Verifikasi pembayaran"
  /// straight into tab 2 and "Tagihan menunggak" into tab 3 without the user
  /// tapping through the hub first.
  final int initialTabIndex;

  const FinanceScreen({super.key, this.initialTabIndex = 0});

  @override
  FinanceScreenState createState() => FinanceScreenState();
}

/// State for FinanceScreen with mixins.
class FinanceScreenState extends ConsumerState<FinanceScreen>
    with FinanceFilterMixin, FinanceDataMixin, FinanceActionMixin {
  AdminFinanceController get _ctrl => ref.read(adminFinanceControllerProvider);

  // Core state
  List<dynamic> _paymentTypeList = [];
  List<dynamic> _billList = [];
  List<dynamic> _pendingPaymentList = [];
  int _totalPendingPayments = 0;
  List<dynamic> _classList = [];
  List<dynamic> _studentList = [];
  Map<String, List<dynamic>> _studentsByClass = {};
  Map<String, List<dynamic>> _billsByStudent = {};
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  String _errorMessage = '';
  late int _currentTabIndex = widget.initialTabIndex.clamp(0, 3);

  final ScrollController _billScrollController = ScrollController();
  final ScrollController _pendingScrollController = ScrollController();

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

  List<dynamic> _calculateBatchesFromBills(List<dynamic> bills) =>
      _ctrl.calculateBatchesFromBills(bills);

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

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          FinanceHeader(
            languageProvider: languageProvider,
            primaryColor: getPrimaryColor(),
            onRefresh: forceRefresh,
          ),
          FinanceNavigationBar(
            currentIndex: _currentTabIndex,
            pendingCount: _totalPendingPayments,
            primaryColor: getPrimaryColor(),
            onTabSelected: (index) => setState(() => _currentTabIndex = index),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: FinanceTabContent(
                currentTabIndex: _currentTabIndex,
                dashboardData: _dashboardData,
                pendingPaymentList: _pendingPaymentList,
                billList: _billList,
                languageProvider: languageProvider,
                primaryColor: getPrimaryColor(),
                isReadOnly: isReadOnly,
                onVerifyNow: () => setState(() => _currentTabIndex = 2),
                calculateBatchesFromBills: () =>
                    _calculateBatchesFromBills(_billList),
                formatMonth: formatMonth,
                formatCurrency: formatCurrency,
                onDeleteBatch: deleteGeneratedBills,
                onRefresh: loadData,
                filteredPaymentTypes: filteredPaymentTypes,
                searchController: _searchController,
                hasActiveFilter: _hasActiveFilter,
                onShowFilterSheet: showFilterSheet,
                onClearAllFilters: clearAllFilters,
                buildFilterChips: () => buildFilterChips(languageProvider),
                getGoalDescription: getGoalDescription,
                getTranslatedPeriod: getTranslatedPeriod,
                onGenerateBills: (index) =>
                    confirmGenerateBills(filteredPaymentTypes[index]),
                onEdit: (index) => showAddEditPaymentType(
                  paymentType: filteredPaymentTypes[index],
                ),
                onDelete: (index) =>
                    deletePaymentType(filteredPaymentTypes[index]),
                pendingScrollController: _pendingScrollController,
                hasMorePending: _hasMorePending,
                onVerify: (index) =>
                    showVerificationDialog(_pendingPaymentList[index]),
                onShowProof: (index) =>
                    showPaymentProof(_pendingPaymentList[index]),
                classList: _classList,
                studentsByClass: _studentsByClass,
                billsByStudent: _billsByStudent,
                isLoading: _isLoading,
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
}
