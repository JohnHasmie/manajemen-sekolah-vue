// Admin finance/billing management screen (keuangan).
//
// Like `pages/admin/finance.vue` - the main finance hub for managing:
// 1. Payment types (jenis payment) - recurring/one-time billing templates
// 2. Bills (tagihan) - actual bills sent to students
// 3. Pending payments - payments awaiting admin verification
//
// Uses a tab-based layout with 3 tabs. Supports CRUD operations, pagination,
// search, filtering, and payment verification with receipt upload.
//
// In Laravel terms, this consumes PaymentTypeController, BillController,
// and PaymentController endpoints.
import 'dart:async';

import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/admin_finance_controller.dart';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_report_tab.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_form_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/target_selection_modal.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_card.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/pending_payment_card.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_navigation_bar.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_pending_section.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/generate_bills_dialog.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_filter_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_proof_dialog.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/verification_dialog.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_dashboard_stats.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_generated_payment_types_section.dart';

/// Admin finance management screen with tabbed layout for payment types, bills, and verifications.
///
/// This is a [StatefulWidget] - like a Vue page component with tabs (`<v-tabs>`).
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  FinanceScreenState createState() => FinanceScreenState();
}

/// Mutable state for [FinanceScreen].
///
/// Key state (like Vue `data()`):
/// - [_currentTabIndex] - active tab (0=payment types, 1=bills, 2=pending payments)
/// - [_paymentTypeList] - payment type templates (monthly, yearly, one-time)
/// - [_billList] - generated bills with pagination and filtering
/// - [_pendingPaymentList] - payments awaiting verification
/// - [_dashboardData] - finance summary stats (total revenue, outstanding, etc.)
/// - Pagination and search state for each tab
///
/// setState() triggers re-render like Vue's reactivity system.
class FinanceScreenState extends ConsumerState<FinanceScreen> {
  // Convenience getter — delegates to the extracted controller, mirroring
  // the pattern used in grade_book_screen.dart.
  // Like a Vue computed: `get ctrl() { return this.$store.finance }`.
  AdminFinanceController get _ctrl =>
      ref.read(adminFinanceControllerProvider);

  // Convenience getter so any method in this State can call languageProvider
  // without needing ref.read() boilerplate everywhere.
  // Like a computed property in Vue: `get lang() { return this.$i18n }`.
  LanguageProvider get languageProvider => ref.read(languageRiverpod);

  String _formatCurrency(dynamic amount) => _ctrl.formatCurrency(amount);

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
  int _currentTabIndex = 0;

  final GlobalKey _tabBarKey = GlobalKey();
  final GlobalKey _addButtonKey = GlobalKey();

  // Pagination for pending payments
  final ScrollController _pendingScrollController = ScrollController();
  int _pendingPage = 1;
  final int _pendingPerPage = 10;
  bool _hasMorePending = true;
  bool _isLoadingMorePending = false;

  // Pagination for tagihan
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Timer? _searchDebounce;

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter; // 'aktif', 'non_aktif', or null for all
  String? _selectedPeriodFilter; // 'bulanan', 'tahunan', or null for all
  bool _hasActiveFilter = false;

  /// Like Vue's `mounted()` - sets up scroll listeners for both tabs'
  /// infinite scroll, search debounce, and loads initial data.
  @override
  void initState() {
    super.initState();

    // Listen to scroll for infinite scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMoreData && !_isLoading) {
          _loadMoreBills();
        }
      }
    });

    _loadData();

    // Listen to pending scroll
    _pendingScrollController.addListener(() {
      if (_pendingScrollController.position.pixels >=
          _pendingScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMorePending && _hasMorePending && !_isLoading) {
          _loadMorePendingPayments();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAndShowTour();
    });
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('finance', 'admin');
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('finance', e);
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'admin_finance_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(CacheKeyBuilder.tourStatus('finance', 'admin'), {
          'should_show': false,
        });
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'admin_finance_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(CacheKeyBuilder.tourStatus('finance', 'admin'), {
          'should_show': false,
        });
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "FinanceTabBar",
        keyTarget: _tabBarKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Finance Tabs',
                      'id': 'Tab Keuangan',
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Switch between different views like Dashboard, Payment Types, Bills, and Pending Payments.',
                        'id':
                            'Pindah antara tampilan berbeda seperti Dashboard, Jenis Pembayaran, Tagihan, dan Pembayaran Tertunda.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "FinanceAddButton",
        keyTarget: _addButtonKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Add Action',
                      'id': 'Aksi Tambah',
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Use this button to quickly add new payment types or generate bills based on the active tab.',
                        'id':
                            'Gunakan tombol ini untuk menambahkan jenis pembayaran baru atau membuat tagihan dengan cepat, tergantung tab yang aktif.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(() {});
    _scrollController.dispose();
    _pendingScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedStatusFilter != null || _selectedPeriodFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedPeriodFilter = null;
      _hasActiveFilter = false;
    });
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];

    if (_selectedStatusFilter != null) {
      final statusText = _selectedStatusFilter == 'aktif'
          ? languageProvider.getTranslatedText({'en': 'Active', 'id': 'Aktif'})
          : languageProvider.getTranslatedText({
              'en': 'Inactive',
              'id': 'Non-Aktif',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedStatusFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedPeriodFilter != null) {
      final periodText = _selectedPeriodFilter == 'bulanan'
          ? languageProvider.getTranslatedText({
              'en': 'Monthly',
              'id': 'Bulanan',
            })
          : languageProvider.getTranslatedText({
              'en': 'Yearly',
              'id': 'Tahunan',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Period', 'id': 'Periode'})}: $periodText',
        'onRemove': () {
          setState(() {
            _selectedPeriodFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    return filterChips;
  }

  // Delegates to the extracted [FinanceFilterSheet] widget.
  // Temporary selection state is owned by the widget; it calls [onApply]
  // with the new (status, period) pair when the admin taps "Apply".
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FinanceFilterSheet(
        currentStatus: _selectedStatusFilter,
        currentPeriod: _selectedPeriodFilter,
        languageProvider: ref.read(languageRiverpod),
        primaryColor: _getPrimaryColor(),
        onApply: (status, period) {
          setState(() {
            _selectedStatusFilter = status;
            _selectedPeriodFilter = period;
            _checkActiveFilter();
          });
        },
      ),
    );
  }

  String? _buildFinanceCacheKey() => _ctrl.buildFinanceCacheKey(
        selectedStatusFilter: _selectedStatusFilter,
        selectedPeriodFilter: _selectedPeriodFilter,
        searchText: _searchController.text,
      );

  Future<void> _forceRefresh() async {
    final cacheKey = _buildFinanceCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    // Also clear any finance-related cache keys
    await LocalCacheService.clearStartingWith('finance_');
    await LocalCacheService.clearStartingWith('tour_finance_');
    _loadData(useCache: false);
  }

  Future<void> _loadData({bool useCache = true}) async {
    final cacheKey = _buildFinanceCacheKey();

    // Step 1: Try loading from cache first for instant display
    if (useCache && cacheKey != null) {
      try {
        final cached = await LocalCacheService.load(cacheKey);
        if (cached != null && cached is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _paymentTypeList =
                  (cached['paymentTypes'] as List<dynamic>?) ?? [];
              _billList = (cached['bills'] as List<dynamic>?) ?? [];
              _pendingPaymentList =
                  (cached['pendingPayments'] as List<dynamic>?) ?? [];
              _totalPendingPayments = (cached['totalPending'] as int?) ?? 0;
              _dashboardData = Map<String, dynamic>.from(
                cached['dashboard'] ?? {},
              );
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
            AppLogger.info('finance', 'Finance data loaded from cache');
            return;
          }
        }
      } catch (e) {
        AppLogger.error('finance', e);
      }
    }

    // Step 2: Show skeleton only if no cached data is already displayed
    final hasData =
        _paymentTypeList.isNotEmpty ||
        _billList.isNotEmpty ||
        _dashboardData.isNotEmpty;
    if (!hasData) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    // Step 3: Fetch fresh data via controller methods (parallel)
    try {
      final results = await Future.wait([
        _ctrl.loadPaymentTypes(),
        _ctrl.loadBills(
          page: 1,
          perPage: _perPage,
          statusFilter: _selectedStatusFilter,
        ),
        _ctrl.loadPendingPayments(page: 1, perPage: _pendingPerPage),
        _ctrl.loadDashboardData(),
        _ctrl.loadClassData(),
      ]);

      final ptResult = results[0] as LoadPaymentTypesResult;
      final billResult = results[1] as LoadBillsResult;
      final pendingResult = results[2] as LoadPendingPaymentsResult;
      final dashResult = results[3] as LoadDashboardResult;
      final classResult = results[4] as LoadClassDataResult;

      if (mounted) {
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

      // Persist to cache (non-blocking)
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'paymentTypes': _paymentTypeList,
          'bills': _billList,
          'pendingPayments': _pendingPaymentList,
          'totalPending': _totalPendingPayments,
          'dashboard': _dashboardData,
          'classes': _classList,
          'students': _studentList,
          'studentsByClass': _studentsByClass,
          'billsByStudent': _billsByStudent,
        });
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (!hasData) {
            _errorMessage = ErrorUtils.getFriendlyMessage(error);
          }
        });
      }
    }
  }

  // _loadClassData and _loadBillsForStudents have been moved to
  // AdminFinanceController. The screen uses _ctrl.loadClassData() directly
  // inside _loadData().

  String _getGoalDescription(dynamic goalData) =>
      _ctrl.getGoalDescription(goalData);

  void _showTargetSelectionModal({
    Map<String, dynamic>? paymentType,
    required Function(Map<String, dynamic>) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TargetSelectionModal(
        paymentType: paymentType,
        onSave: onSave,
        primaryColor: _getPrimaryColor(),
        classList: _classList,
        studentsByClass: _studentsByClass,
      ),
    );
  }

  // _loadPaymentTypes has been moved to AdminFinanceController.loadPaymentTypes().
  // The screen applies results via _loadData().

  Future<void> _loadBills({bool resetPage = true}) async {
    if (resetPage) {
      _currentPage = 1;
      _billList = [];
      _hasMoreData = true;
    }

    setState(() {
      _isLoading = resetPage;
      _isLoadingMore = !resetPage;
    });

    final result = await _ctrl.loadBills(
      page: _currentPage,
      perPage: _perPage,
      statusFilter: _selectedStatusFilter,
    );

    if (mounted) {
      setState(() {
        if (result.error != null) {
          SnackBarUtils.showError(
            context,
            '${AppLocalizations.failedToLoad.tr}: ${result.error}',
          );
        } else {
          _billList.addAll(result.bills);
          _hasMoreData = result.hasMoreData;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreBills() async {
    if (!_hasMoreData) return;
    _currentPage += 1;
    await _loadBills(resetPage: false);
  }

  Future<void> _loadMorePendingPayments() async {
    if (!_hasMorePending) return;
    setState(() => _isLoadingMorePending = true);
    _pendingPage++;
    final result = await _ctrl.loadPendingPayments(
      page: _pendingPage,
      perPage: _pendingPerPage,
      loadMore: true,
    );
    if (mounted) {
      setState(() {
        if (result.error == null) {
          _pendingPaymentList.addAll(result.pendingPaymentList);
          _hasMorePending = result.hasMorePending;
        } else {
          _pendingPage--; // revert on error
        }
        _isLoadingMorePending = false;
      });
    }
  }


  // _loadDashboardData has been moved to AdminFinanceController.loadDashboardData().
  // The screen applies results via _loadData().

  List<dynamic> _calculateBatchesFromBills(List<dynamic> bills) =>
      _ctrl.calculateBatchesFromBills(bills);

  void _showAddEditPaymentType({Map<String, dynamic>? paymentType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentTypeFormSheet(
        paymentType: paymentType,
        primaryColor: _getPrimaryColor(),
        onSaved: () => _loadData(useCache: false),
        onShowTargetSelection: _showTargetSelectionModal,
      ),
    );
  }

  Future<void> _deletePaymentType(Map<String, dynamic> paymentType) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: languageProvider.getTranslatedText(
          AppLocalizations.deletePaymentType,
        ),
        content:
            'Yakin ingin menghapus jenis pembayaran "${paymentType['name']}"?',
        confirmColor: ColorUtils.error600,
      ),
    );

    if (confirmed == true) {
      final error = await _ctrl.deletePaymentType(paymentType);
      if (mounted) {
        if (error == null) {
          SnackBarUtils.showSuccess(
            context,
            'Jenis pembayaran berhasil dihapus',
          );
          _loadData(useCache: false);
        } else {
          SnackBarUtils.showError(
            context,
            '${AppLocalizations.failedToDelete.tr}: $error',
          );
        }
      }
    }
  }

  // Delegates to the extracted [GenerateBillsDialog] widget.
  // Loading state is managed inside the widget; it calls [onGenerated] on success.
  void _confirmGenerateBills(Map<String, dynamic> paymentType) {
    showDialog(
      context: context,
      builder: (context) => GenerateBillsDialog(
        paymentType: paymentType,
        primaryColor: _getPrimaryColor(),
        cardGradient: _getCardGradient(),
        onGenerated: () => _loadData(useCache: false),
      ),
    );
  }

  // Delegates to the extracted [VerificationDialog] widget.
  // Like calling `<VerificationDialog :payment="p" @success="reload" />` in Vue.
  void _showVerificationDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => VerificationDialog(
        payment: payment,
        apiService: ApiService(),
        formatCurrency: _formatCurrency,
        primaryColor: _getPrimaryColor(),
        onSuccess: () => _loadData(useCache: false),
        onShowPaymentProof: () => _showPaymentProof(payment),
      ),
    );
  }

  List<dynamic> _getFilteredPaymentTypes() =>
      _ctrl.getFilteredPaymentTypes(
        paymentTypeList: _paymentTypeList,
        searchTerm: _searchController.text,
        statusFilter: _selectedStatusFilter,
        periodFilter: _selectedPeriodFilter,
      );



  String _formatMonth(String? monthStr) => _ctrl.formatMonth(monthStr);

  Future<void> _deleteGeneratedBills(Map<String, dynamic> item) async {
    final name = item['name'] ?? 'Tagihan';
    final monthStr = item['month'] ?? '';
    final formattedMonth = _ctrl.formatMonth(monthStr);

    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Hapus Tagihan',
        content:
            'Apakah Anda yakin ingin menghapus SEMUA tagihan untuk "$name" periode $formattedMonth? Ini tidak akan menghapus Jenis Pembayarannya.',
        confirmText: 'Hapus Tagihan',
        confirmColor: ColorUtils.error600,
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final error = await _ctrl.deleteGeneratedBills(
        paymentTypeId: item['payment_type_id'].toString(),
        month: monthStr,
      );
      if (mounted) {
        if (error == null) {
          SnackBarUtils.showSuccess(
            context,
            'Tagihan "$name" periode $formattedMonth berhasil dihapus',
          );
          _loadData(useCache: false);
        } else {
          setState(() => _isLoading = false);
          SnackBarUtils.showError(
            context,
            '${AppLocalizations.failedToDelete.tr}: $error',
          );
        }
      }
    }
  }

  Color _getPrimaryColor() => _ctrl.getPrimaryColor();

  LinearGradient _getCardGradient() => _ctrl.getCardGradient();

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: SkeletonListLoading(itemCount: 6, infoTagCount: 1),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return ErrorScreen(errorMessage: _errorMessage, onRetry: _loadData);
    }

    final filteredPaymentTypes = _getFilteredPaymentTypes();

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Custom Gradient Header (matches student_management.dart)
          Container(
            width: double.infinity,
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
                colors: [
                  _getPrimaryColor(),
                  _getPrimaryColor().withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getTranslatedText(
                          AppLocalizations.financialManagement,
                        ),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Manage payments & bills',
                          'id': 'Kelola pembayaran & tagihan',
                        }),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu button
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'refresh') {
                      _forceRefresh();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 20,
                            color: ColorUtils.info600,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(AppLocalizations.updateData.tr),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          FinanceNavigationBar(
            currentIndex: _currentTabIndex,
            tabBarKey: _tabBarKey,
            pendingCount: _totalPendingPayments,
            primaryColor: _getPrimaryColor(),
            onTabSelected: (index) => setState(() => _currentTabIndex = index),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  // Tab Dashboard
                  RefreshIndicator(
                    onRefresh: _loadData,
                    color: _getPrimaryColor(),
                    child: ListView(
                      padding: EdgeInsets.only(bottom: 20),
                      children: [
                        FinanceDashboardStats(
                          unpaidCount: _dashboardData['tagihan_belum_dibayar'],
                          verifiedCount: _dashboardData['tagihan_terverifikasi'],
                          totalPendingPayments: _totalPendingPayments,
                          languageProvider: languageProvider,
                          primaryColor: _getPrimaryColor(),
                        ),
                        if (_pendingPaymentList.isNotEmpty)
                          FinancePendingSection(
                            pendingCount: _pendingPaymentList.length,
                            isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
                            onVerifyNow: () => setState(() => _currentTabIndex = 2),
                            verifyNowLabel: languageProvider.getTranslatedText({
                              'en': 'Verify Now',
                              'id': 'Verifikasi Sekarang',
                            }),
                            paymentsNeedVerificationLabel:
                                languageProvider.getTranslatedText({
                              'en': 'payments need verification',
                              'id': 'pembayaran perlu diverifikasi',
                            }),
                          ),
                        FinanceGeneratedPaymentTypesSection(
                          generatedBatches: () {
                            List<dynamic> batches = _dashboardData['generated_batches'] ?? [];
                            if (batches.isEmpty && _billList.isNotEmpty) {
                              batches = _calculateBatchesFromBills(_billList);
                            }
                            return batches;
                          }(),
                          formatMonth: _formatMonth,
                          formatCurrency: _formatCurrency,
                          primaryColor: _getPrimaryColor(),
                          languageProvider: languageProvider,
                          onDeleteBatch: _deleteGeneratedBills,
                        ),
                        SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),

                  // Tab Jenis Pembayaran
                  Column(
                    children: [
                      // Search Bar and Filter
                      Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: ColorUtils.slate200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onSubmitted: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          hintText: 'Cari jenis pembayaran...',
                                          prefixIcon: Icon(
                                            Icons.search,
                                            color: ColorUtils.slate400,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: EdgeInsets.only(right: 4),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.search,
                                          color: _getPrimaryColor(),
                                        ),
                                        onPressed: () => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            // Filter Button
                            Container(
                              decoration: BoxDecoration(
                                color: _hasActiveFilter
                                    ? _getPrimaryColor()
                                    : ColorUtils.slate50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasActiveFilter
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate200,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  IconButton(
                                    onPressed: _showFilterSheet,
                                    icon: Icon(
                                      Icons.tune,
                                      color: _hasActiveFilter
                                          ? Colors.white
                                          : ColorUtils.slate700,
                                    ),
                                    tooltip: 'Filter',
                                  ),
                                  if (_hasActiveFilter)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: EdgeInsets.all(AppSpacing.xs),
                                        decoration: BoxDecoration(
                                          color: ColorUtils.error600,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: BoxConstraints(
                                          minWidth: 8,
                                          minHeight: 8,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filter Chips
                      if (_hasActiveFilter) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            height: 32,
                            child: Row(
                              children: [
                                Expanded(
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      ..._buildFilterChips(
                                        ref.read(languageRiverpod),
                                      ).map((filter) {
                                        return Container(
                                          margin: EdgeInsets.only(right: 6),
                                          child: Chip(
                                            label: Text(
                                              filter['label'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _getPrimaryColor(),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            deleteIcon: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: _getPrimaryColor(),
                                            ),
                                            onDeleted: filter['onRemove'],
                                            backgroundColor: _getPrimaryColor()
                                                .withValues(alpha: 0.1),
                                            side: BorderSide(
                                              color: _getPrimaryColor()
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            labelPadding: EdgeInsets.only(
                                              left: 4,
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                InkWell(
                                  onTap: _clearAllFilters,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.error600,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.clear_all,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                      ],

                      if (filteredPaymentTypes.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                '${filteredPaymentTypes.length} jenis pembayaran ditemukan',
                                style: TextStyle(
                                  color: ColorUtils.slate600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: AppSpacing.xs),
                      Expanded(
                        child: filteredPaymentTypes.isEmpty
                            ? EmptyState(
                                title: 'Tidak ada jenis pembayaran',
                                subtitle:
                                    _searchController.text.isEmpty &&
                                        !_hasActiveFilter
                                    ? 'Tap + untuk menambah jenis pembayaran'
                                    : 'Tidak ditemukan hasil pencarian',
                                icon: Icons.payment,
                              )
                            : ListView.builder(
                                itemCount: filteredPaymentTypes.length,
                                itemBuilder: (context, index) {
                                  return PaymentTypeCard(
                                    item: filteredPaymentTypes[index],
                                    index: index,
                                    formatCurrency: _formatCurrency,
                                    primaryColor: _getPrimaryColor(),
                                    getGoalDescription: _getGoalDescription,
                                    getTranslatedPeriod: _getTranslatedPeriod,
                                    onGenerateBills: () => _confirmGenerateBills(filteredPaymentTypes[index]),
                                    onEdit: () => _showAddEditPaymentType(paymentType: filteredPaymentTypes[index]),
                                    onDelete: () => _deletePaymentType(filteredPaymentTypes[index]),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // Tab Verifikasi
                  _pendingPaymentList.isEmpty
                      ? EmptyState(
                          title: 'Tidak ada pembayaran menunggu verifikasi',
                          subtitle: 'Semua pembayaran telah diverifikasi',
                          icon: Icons.verified_user,
                        )
                      : ListView.builder(
                          controller: _pendingScrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          itemCount:
                              _pendingPaymentList.length +
                              (_hasMorePending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _pendingPaymentList.length) {
                              return Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return PendingPaymentCard(
                              payment: _pendingPaymentList[index],
                              index: index,
                              isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
                              onVerify: () => _showVerificationDialog(_pendingPaymentList[index]),
                              onShowProof: () => _showPaymentProof(_pendingPaymentList[index]),
                              formatCurrency: _formatCurrency,
                              primaryColor: _getPrimaryColor(),
                            );
                          },
                        ),
                  ClassReportTab(
                    isLoading: _isLoading,
                    classList: _classList,
                    studentsByClass: _studentsByClass,
                    billsByStudent: _billsByStudent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _getFloatingActionButton(),
    );
  }

  Widget? _getFloatingActionButton() {
    if (ref.read(academicYearRiverpod).isReadOnly) return null;

    if (_currentTabIndex == 1) {
      // Tab Jenis Pembayaran
      return FloatingActionButton(
        onPressed: _showAddEditPaymentType,
        backgroundColor: _getPrimaryColor(),
        child: Icon(Icons.add, color: Colors.white),
      );
    }

    return null;
  }

  // Delegates to the extracted [PaymentProofDialog] widget.
  // Guards against a missing proof file before pushing the dialog —
  // like a Vue method that checks `if (!payment.proof) return` before
  // emitting an open-modal event.
  void _showPaymentProof(Map<String, dynamic> payment) {
    final imageFile = payment['payment_proof'] ?? payment['payment_receipt'];

    if (imageFile == null) {
      SnackBarUtils.showWarning(context, AppLocalizations.noPaymentProof.tr);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => PaymentProofDialog(
        payment: payment,
        formatCurrency: _formatCurrency,
        primaryColor: _getPrimaryColor(),
        cardGradient: _getCardGradient(),
      ),
    );
  }

  String _getTranslatedPeriod(String? period) =>
      _ctrl.getTranslatedPeriod(period);

}
