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
import 'dart:convert';

import 'package:manajemensekolah/core/utils/cache_key_builder.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/finance/screens/class_finance_report_screen.dart';
import 'package:manajemensekolah/features/settings/services/academic_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/currency_formatter.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

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
  final ApiService _apiService = ApiService();

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      double value = double.parse(amount.toString());
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(value);
    } catch (e) {
      return 'Rp 0';
    }
  }

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
  String? _selectedPeriodeFilter; // 'bulanan', 'tahunan', or null for all
  bool _hasActiveFilter = false;

  // Variables for target selection modal
  List<dynamic> _selectedClasses = [];
  Map<String, List<dynamic>> _selectedStudentsByClass = {};
  final TextEditingController _searchStudentController = TextEditingController();

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
          _loadMoreTagihan();
        }
      }
    });

    _loadData();

    // Listen to pending scroll
    _pendingScrollController.addListener(() {
      if (_pendingScrollController.position.pixels >=
          _pendingScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMorePending && _hasMorePending && !_isLoading) {
          _loadMorePembayaranPending();
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
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
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
    List<TargetFocus> targets = _createTourTargets();
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
        getIt<ApiTourService>().completeTour(name: 'admin_finance_screen_tour', role: 'admin', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('finance', 'admin'), {'should_show': false});
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(name: 'admin_finance_screen_tour', role: 'admin', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('finance', 'admin'), {'should_show': false});
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
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
    _searchStudentController.dispose();
    _scrollController.removeListener(() {});
    _scrollController.dispose();
    _pendingScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedStatusFilter != null || _selectedPeriodeFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedPeriodeFilter = null;
      _hasActiveFilter = false;
    });
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

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

    if (_selectedPeriodeFilter != null) {
      final periodeText = _selectedPeriodeFilter == 'bulanan'
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
            '${languageProvider.getTranslatedText({'en': 'Period', 'id': 'Periode'})}: $periodeText',
        'onRemove': () {
          setState(() {
            _selectedPeriodeFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    // Temporary state for bottom sheet
    String? tempSelectedStatus = _selectedStatusFilter;
    String? tempSelectedPeriode = _selectedPeriodeFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header - Gradient (Pattern #11)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getPrimaryColor(),
                      _getPrimaryColor().withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Filter',
                            'id': 'Filter',
                          }),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempSelectedStatus = null;
                          tempSelectedPeriode = null;
                        });
                      },
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Reset',
                          'id': 'Reset',
                        }),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Filter
                      Row(
                        children: [
                          Icon(
                            Icons.toggle_on_rounded,
                            size: 18,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Status',
                              'id': 'Status',
                            }),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              {
                                'value': 'aktif',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Active',
                                  'id': 'Aktif',
                                }),
                              },
                              {
                                'value': 'non_aktif',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Inactive',
                                  'id': 'Non-Aktif',
                                }),
                              },
                            ].map((item) {
                              final isSelected =
                                  tempSelectedStatus == item['value'];
                              return FilterChip(
                                label: Text(item['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempSelectedStatus = selected
                                        ? item['value']
                                        : null;
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: _getPrimaryColor().withValues(
                                  alpha: 0.15,
                                ),
                                checkmarkColor: _getPrimaryColor(),
                                side: BorderSide(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate300,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                      ),

                      SizedBox(height: AppSpacing.xl),
                      Divider(color: ColorUtils.slate100),
                      SizedBox(height: AppSpacing.sm),

                      // Periode Filter
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Payment Period',
                              'id': 'Periode Pembayaran',
                            }),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              {
                                'value': 'bulanan',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Monthly',
                                  'id': 'Bulanan',
                                }),
                              },
                              {
                                'value': 'tahunan',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Yearly',
                                  'id': 'Tahunan',
                                }),
                              },
                            ].map((item) {
                              final isSelected =
                                  tempSelectedPeriode == item['value'];
                              return FilterChip(
                                label: Text(item['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempSelectedPeriode = selected
                                        ? item['value']
                                        : null;
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: _getPrimaryColor().withValues(
                                  alpha: 0.15,
                                ),
                                checkmarkColor: _getPrimaryColor(),
                                side: BorderSide(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate300,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.slate900.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => AppNavigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: ColorUtils.slate300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Cancel',
                            'id': 'Batal',
                          }),
                          style: TextStyle(color: ColorUtils.slate600),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          AppNavigator.pop(context);
                          setState(() {
                            _selectedStatusFilter = tempSelectedStatus;
                            _selectedPeriodeFilter = tempSelectedPeriode;
                            _checkActiveFilter();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: _getPrimaryColor(),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Apply Filter',
                            'id': 'Terapkan',
                          }),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _buildFinanceCacheKey() {
    // Don't cache when filters or search are active
    if (_selectedStatusFilter != null ||
        _selectedPeriodeFilter != null ||
        _searchController.text.isNotEmpty) {
      return null;
    }
    final academicYearProvider = ref.read(academicYearRiverpod);
    final yearId =
        academicYearProvider.selectedAcademicYear?['id']?.toString() ?? 'all';
    return 'finance_data_$yearId';
  }

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
              _totalPendingPayments =
                  (cached['totalPending'] as int?) ?? 0;
              _dashboardData =
                  Map<String, dynamic>.from(cached['dashboard'] ?? {});
              _classList = (cached['kelas'] as List<dynamic>?) ?? [];
              _studentList = (cached['siswa'] as List<dynamic>?) ?? [];
              _studentsByClass = (cached['studentsByClass'] as Map<String, dynamic>?)
                      ?.map((k, v) => MapEntry(k, List<dynamic>.from(v))) ??
                  {};
              _billsByStudent =
                  (cached['tagihanBySiswa'] as Map<String, dynamic>?)
                          ?.map(
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

    // Step 2: Show skeleton only if no cached data displayed
    final hasData = _paymentTypeList.isNotEmpty ||
        _billList.isNotEmpty ||
        _dashboardData.isNotEmpty;
    if (!hasData) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    // Step 3: Fetch fresh data from API
    try {
      await Future.wait([
        _loadPaymentTypes(),
        _loadTagihan(),
        _loadPendingPayments(),
        _loadDashboardData(),
        _loadClassData(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Save to cache (non-blocking)
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'paymentTypes': _paymentTypeList,
          'bills': _billList,
          'pendingPayments': _pendingPaymentList,
          'totalPending': _totalPendingPayments,
          'dashboard': _dashboardData,
          'kelas': _classList,
          'siswa': _studentList,
          'studentsByClass': _studentsByClass,
          'tagihanBySiswa': _billsByStudent,
        });
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Only show error if no cached data displayed
          if (!hasData) {
            _errorMessage = ErrorUtils.getFriendlyMessage(error);
          }
        });
      }
    }
  }

  // Method to load class and student data
  Future<void> _loadClassData() async {
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      // Load class data
      String url = '/classes?limit=1000';
      if (academicYearId != null) {
        url += '&academic_year_id=$academicYearId';
      }

      final classResponse = await _apiService.get(url);
      if (mounted) {
        setState(() {
          if (classResponse is Map && classResponse.containsKey('data')) {
            _classList = classResponse['data'] is List
                ? classResponse['data']
                : [];
          } else {
            _classList = classResponse is List ? classResponse : [];
          }
        });
      }

      // Load student data
      final studentResponse = await _apiService.get('/students?limit=1000');
      final List<dynamic> allStudents;
      if (studentResponse is Map && studentResponse.containsKey('data')) {
        allStudents = studentResponse['data'] is List ? studentResponse['data'] : [];
      } else {
        allStudents = studentResponse is List ? studentResponse : [];
      }

      // Group students by class
      Map<String, List<dynamic>> studentsByClass = {};
      for (var student in allStudents) {
        String? classId = student['class_id']?.toString();
        // Fallback to nested class object if class_id is null (new schema)
        if (classId == null && student['class'] != null) {
          classId = student['class']['id']?.toString();
        }

        if (classId != null) {
          if (!studentsByClass.containsKey(classId)) {
            studentsByClass[classId] = [];
          }
          studentsByClass[classId]!.add(student);
        }
      }

      if (mounted) {
        setState(() {
          _studentsByClass = studentsByClass;
          _studentList = allStudents;
        });
      }

      // Load bills for each student
      await _loadBillsForStudents(allStudents);
    } catch (error) {
      AppLogger.error('finance', error);
      if (mounted) {
                SnackBarUtils.showError(context, 'Gagal memuat data kelas: ${ErrorUtils.getFriendlyMessage(error)}');
      }
    }
  }

  Future<void> _loadBillsForStudents(List<dynamic> studentList) async {
    try {
      // Fetch all bills in a single API call instead of one per student
      final tagihanResponse = await _apiService.get('/bills?limit=10000');

      List<dynamic> allBills = [];
      if (tagihanResponse is Map<String, dynamic> &&
          tagihanResponse.containsKey('data')) {
        allBills = tagihanResponse['data'] is List
            ? tagihanResponse['data']
            : [];
      } else if (tagihanResponse is List) {
        allBills = tagihanResponse;
      }

      // Group bills by student_id client-side
      Map<String, List<dynamic>> tagihanBySiswa = {};
      for (var bill in allBills) {
        final studentId = bill['student_id']?.toString();
        if (studentId != null) {
          tagihanBySiswa.putIfAbsent(studentId, () => []).add(bill);
        }
      }

      if (mounted) {
        setState(() {
          _billsByStudent = tagihanBySiswa;
        });
      }
    } catch (error) {
      AppLogger.error('finance', error);
    }
  }

  // Helper method for parsing target/goal
  Map<String, dynamic> _parseGoal(dynamic goalData) {
    if (goalData == null) {
      return {};
    }

    if (goalData is Map<String, dynamic>) {
      return goalData;
    }

    if (goalData is String) {
      try {
        return json.decode(goalData) as Map<String, dynamic>;
      } catch (e) {
        AppLogger.error('finance', e);
        return {};
      }
    }

    return {};
  }

  String _getGoalDescription(dynamic goalData) {
    final parsedGoal = _parseGoal(goalData);
    return parsedGoal['description'] ?? 'Tujuan pembayaran';
  }

  void _showTargetSelectionModal({
    Map<String, dynamic>? paymentType,
    required Function(Map<String, dynamic>) onSave,
  }) {
    // Reset state
    _selectedClasses = [];
    _selectedStudentsByClass = {};
    _searchStudentController.clear();

    // If editing, load previously selected target data
    if (paymentType?['goal'] != null) {
      _loadExistingGoal(paymentType!['goal']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: _getPrimaryColor(),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.groups, color: Colors.white, size: 24),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Pilih Tujuan Pembayaran',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => AppNavigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Search Siswa
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Container(
                    decoration: BoxDecoration(
                      color: ColorUtils.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorUtils.slate200),
                    ),
                    child: TextField(
                      controller: _searchStudentController,
                      decoration: InputDecoration(
                        hintText: 'Cari siswa...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: ColorUtils.slate400,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (value) {
                        setModalState(() {});
                      },
                    ),
                  ),
                ),

                // Quick Actions
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _selectAllKelas(setModalState),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: _getPrimaryColor()),
                          ),
                          child: Text(
                            'Pilih Semua Kelas',
                            style: TextStyle(
                              fontSize: 12,
                              color: _getPrimaryColor(),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _clearAllSelection(setModalState),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: ColorUtils.error600),
                          ),
                          child: Text(
                            'Hapus Semua',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.error600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // List Kelas
                Expanded(child: _buildClassListForSelection(setModalState)),

                // Footer with summary
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                  ),
                  child: Column(
                    children: [
                      _buildSelectionSummary(),
                      SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => AppNavigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(AppLocalizations.cancel.tr),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final goal = _buildGoalData();
                                onSave(goal);
                                AppNavigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getPrimaryColor(),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                AppLocalizations.save.tr,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _loadExistingGoal(dynamic goalData) {
    final goal = _parseGoal(goalData);

    if (goal['type'] == 'all') {
      // Select all classes
      _selectedClasses = List.from(_classList);
      for (var classItem in _classList) {
        final classId = classItem['id'].toString();
        _selectedStudentsByClass[classId] = List.from(
          _studentsByClass[classId] ?? [],
        );
      }
    } else if (goal['type'] == 'custom') {
      // Load custom selection
      _selectedClasses = _classList.where((classItem) {
        return goal['kelas']?.contains(classItem['id'].toString()) == true;
      }).toList();

      for (var classId in goal['kelas'] ?? []) {
        _selectedStudentsByClass[classId] = (goal['siswa']?[classId] ?? [])
            .map((id) => _findStudentById(id))
            .where((student) => student != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
    }
  }

  dynamic _findStudentById(String studentId) {
    for (var studentList in _studentsByClass.values) {
      for (var student in studentList) {
        if (student['id'].toString() == studentId) {
          return student;
        }
      }
    }
    return null;
  }

  Widget _buildClassListForSelection(StateSetter setModalState) {
    final searchTerm = _searchStudentController.text.toLowerCase();

    return ListView.builder(
      itemCount: _classList.length,
      itemBuilder: (context, index) {
        final classItem = _classList[index];
        final classId = classItem['id'].toString();
        final isClassSelected = _selectedClasses.any(
          (k) => k['id'].toString() == classId,
        );
        final studentList = _studentsByClass[classId] ?? [];

        // Filter students by search term
        final filteredStudents = studentList.where((student) {
          final nama = student['name']?.toString().toLowerCase() ?? '';
          final nis = student['student_number']?.toString().toLowerCase() ?? '';
          return searchTerm.isEmpty ||
              nama.contains(searchTerm) ||
              nis.contains(searchTerm);
        }).toList();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: ExpansionTile(
            leading: Checkbox(
              value: isClassSelected,
              onChanged: (value) {
                setModalState(() {
                  if (value == true) {
                    _selectedClasses.add(classItem);
                    _selectedStudentsByClass[classId] = List.from(studentList);
                  } else {
                    _selectedClasses.removeWhere(
                      (k) => k['id'].toString() == classId,
                    );
                    _selectedStudentsByClass.remove(classId);
                  }
                });
              },
            ),
            title: Text(
              classItem['name'] ?? 'Kelas',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isClassSelected
                    ? _getPrimaryColor()
                    : ColorUtils.slate900,
              ),
            ),
            subtitle: Text(
              '${studentList.length} ${languageProvider.getTranslatedText(AppLocalizations.students)}',
              style: TextStyle(fontSize: 12),
            ),
            trailing: isClassSelected
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedStudentsByClass[classId]?.length ?? 0}/${studentList.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getPrimaryColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            children: [
              if (filteredStudents.isEmpty)
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Tidak ada siswa yang cocok dengan pencarian',
                    style: TextStyle(
                      color: ColorUtils.slate400,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                ...filteredStudents.map(
                  (student) => _buildStudentCheckbox(
                    student: student,
                    classId: classId,
                    setModalState: setModalState,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentCheckbox({
    required Map<String, dynamic> student,
    required String classId,
    required StateSetter setModalState,
  }) {
    final isSelected =
        _selectedStudentsByClass[classId]?.any(
          (s) => s['id'].toString() == student['id'].toString(),
        ) ==
        true;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setModalState(() {
            final studentList = _selectedStudentsByClass[classId] ?? [];
            if (value == true) {
              studentList.add(student);
            } else {
              studentList.removeWhere(
                (s) => s['id'].toString() == student['id'].toString(),
              );
            }
            _selectedStudentsByClass[classId] = studentList;

            // Update kelas selection
            if (studentList.isEmpty) {
              _selectedClasses.removeWhere((k) => k['id'].toString() == classId);
            } else if (!_selectedClasses.any(
              (k) => k['id'].toString() == classId,
            )) {
              _selectedClasses.add(
                _classList.firstWhere((k) => k['id'].toString() == classId),
              );
            }
          });
        },
        title: Text(student['name'] ?? 'Siswa', style: TextStyle(fontSize: 14)),
        subtitle: Text(
          'NIS: ${student['student_number'] ?? '-'}',
          style: TextStyle(fontSize: 11, color: ColorUtils.slate600),
        ),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildSelectionSummary() {
    int totalClasses = _selectedClasses.length;
    int totalStudents = _selectedStudentsByClass.values.fold(
      0,
      (sum, studentList) => sum + studentList.length,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Terpilih:',
              style: TextStyle(fontSize: 12, color: ColorUtils.slate600),
            ),
            Text(
              '$totalClasses Kelas • $totalStudents Siswa',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getPrimaryColor(),
              ),
            ),
          ],
        ),
        if (totalClasses == _classList.length && totalStudents == _getTotalStudents())
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ColorUtils.success600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Semua Siswa',
              style: TextStyle(
                fontSize: 10,
                color: ColorUtils.success600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  int _getTotalStudents() {
    return _studentsByClass.values.fold(
      0,
      (sum, studentList) => sum + studentList.length,
    );
  }

  void _selectAllKelas(StateSetter setModalState) {
    setModalState(() {
      _selectedClasses = List.from(_classList);
      for (var classItem in _classList) {
        final classId = classItem['id'].toString();
        _selectedStudentsByClass[classId] = List.from(
          _studentsByClass[classId] ?? [],
        );
      }
    });
  }

  void _clearAllSelection(StateSetter setModalState) {
    setModalState(() {
      _selectedClasses.clear();
      _selectedStudentsByClass.clear();
    });
  }

  Map<String, dynamic> _buildGoalData() {
    final totalClasses = _selectedClasses.length;
    final totalStudents = _getTotalStudents();
    final selectedStudentCount = _selectedStudentsByClass.values.fold(
      0,
      (sum, studentList) => sum + studentList.length,
    );

    // If all classes and all students are selected
    if (totalClasses == _classList.length && selectedStudentCount == totalStudents) {
      return {'type': 'all', 'description': 'Semua siswa di semua kelas'};
    }

    // Custom selection
    final classIds = _selectedClasses.map((k) => k['id'].toString()).toList();
    final studentMap = <String, List<String>>{};

    _selectedStudentsByClass.forEach((classId, studentList) {
      studentMap[classId] = studentList.map((s) => s['id'].toString()).toList();
    });

    return {
      'type': 'custom',
      'kelas': classIds,
      'siswa': studentMap,
      'description': '$selectedStudentCount siswa di $totalClasses kelas',
    };
  }

  // Widget for Class Report tab
  Widget _buildClassReportTab() {
    if (_isLoading) {
      return SkeletonListLoading(itemCount: 6, infoTagCount: 1);
    }

    if (_classList.isEmpty) {
      return EmptyState(
        title: 'Belum ada data kelas',
        subtitle: 'Data kelas akan muncul di sini',
        icon: Icons.class_,
      );
    }

    return ListView.builder(
      itemCount: _classList.length,
      itemBuilder: (context, index) {
        final classItem = _classList[index];
        final classId = classItem['id']?.toString();
        final studentList = _studentsByClass[classId] ?? [];

        return _buildClassCard(classItem, studentList, index);
      },
    );
  }

  Widget _buildClassCard(
    Map<String, dynamic> classItem,
    List<dynamic> studentList,
    int index,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          AppNavigator.push(context, ClassFinanceReportScreen(
                classId: classItem['id'].toString(),
                className: classItem['name'] ?? 'Kelas',
              ));
        },
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200, width: 1),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getPrimaryColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getPrimaryColor().withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(Icons.class_, color: _getPrimaryColor(), size: 22),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classItem['name'] ?? 'Kelas',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${classItem['student_count'] ?? studentList.length} siswa',
                      style: TextStyle(
                        color: ColorUtils.slate500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildClassSummary(studentList),
              SizedBox(width: AppSpacing.sm),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: ColorUtils.slate500,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassSummary(List<dynamic> studentList) {
    int totalLunas = 0;
    int totalPending = 0;
    int totalBelumBayar = 0;

    final academicYearProvider = ref.read(academicYearRiverpod);
    final selectedAcademicYearId = academicYearProvider
        .selectedAcademicYear?['id']
        ?.toString();

    for (var student in studentList) {
      final studentId = student['id']?.toString();
      final billList = _billsByStudent[studentId] ?? [];

      for (var bill in billList) {
        // Filter based on academic year
        final billAcademicYearId = bill['academic_year_id']?.toString();
        if (selectedAcademicYearId != null &&
            billAcademicYearId != null &&
            billAcademicYearId != selectedAcademicYearId) {
          continue;
        }

        final status = bill['status'];

        // 1. Check Verified/Lunas
        if (status == 'verified') {
          totalLunas++;
        }
        // 2. Check Pending Verification (Menunggu)
        // Logic: Has a payment with status 'pending' (regardless of bill status being pending/unpaid)
        else {
          bool hasPendingPayment = false;
          if (bill['payments'] != null && bill['payments'] is List) {
            for (var p in bill['payments']) {
              final pStatus = p['status'];
              if (pStatus == 'pending' || pStatus == 'test_status') {
                hasPendingPayment = true;
                break;
              }
            }
          }

          if (hasPendingPayment) {
            totalPending++;
          } else {
            // 3. Fallback: Not Paid
            // Typically bill status is 'unpaid' or 'pending' here with no pending proof
            totalBelumBayar++;
          }
        }
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (totalLunas > 0)
          _buildStatusIndicator(ColorUtils.success600, totalLunas),
        if (totalPending > 0)
          _buildStatusIndicator(ColorUtils.warning600, totalPending),
        if (totalBelumBayar > 0)
          _buildStatusIndicator(ColorUtils.error600, totalBelumBayar),
      ],
    );
  }

  Widget _buildStatusIndicator(Color color, int count) {
    return Container(
      margin: EdgeInsets.only(left: 4),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _loadPaymentTypes() async {
    try {
      final response = await _apiService.get('/payment-types');
      final List<dynamic> rawData;
      if (response is Map && response.containsKey('data')) {
        rawData = response['data'] is List ? response['data'] : [];
      } else {
        rawData = response is List ? response : [];
      }

      if (mounted) {
        setState(() {
          _paymentTypeList = rawData.map((item) {
            if (item is Map<String, dynamic>) {
              final newItem = Map<String, dynamic>.from(item);

              // Map Status
              if (newItem['status'] == 'active') {
                newItem['status'] = 'aktif';
              } else if (newItem['status'] == 'inactive') {
                newItem['status'] = 'non-aktif';
              }

              // Map Periode (Normalize to lowercase / Indonesian)
              final periode = newItem['periode']?.toString().toUpperCase();
              if (periode == 'MONTHLY') {
                newItem['periode'] = 'bulanan';
              } else if (periode == 'YEARLY') {
                newItem['periode'] = 'tahunan';
              } else if (periode == 'SEMESTER') {
                newItem['periode'] = 'semester';
              } else if (periode == 'ONCE') {
                newItem['periode'] = 'sekali bayar';
              } else if (newItem['periode'] != null) {
                // Ensure lowercase for consistency if it was 'Bulanan' etc
                newItem['periode'] = newItem['periode']
                    .toString()
                    .toLowerCase();
              }

              return newItem;
            }
            return item;
          }).toList();
        });
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (mounted) {
                SnackBarUtils.showError(context, 'Gagal memuat jenis pembayaran: ${ErrorUtils.getFriendlyMessage(error)}');
      }
    }
  }

  Future<void> _loadTagihan({bool resetPage = true}) async {
    try {
      if (resetPage) {
        _currentPage = 1;
        _billList = [];
        _hasMoreData = true;
      }

      setState(() {
        _isLoading = resetPage;
        _isLoadingMore = !resetPage;
      });

      final res = await ApiService.getBillsPaginated(
        page: _currentPage,
        limit: _perPage,
        status: _selectedStatusFilter,
      );

      if (res['success'] == true) {
        final List<dynamic> pageData = res['data'] ?? [];
        final Map<String, dynamic> pagination =
            (res['pagination'] as Map?)?.cast<String, dynamic>() ?? {};

        if (mounted) {
          setState(() {
            _billList.addAll(pageData);
            _hasMoreData =
                pagination['has_next_page'] ?? (pageData.length == _perPage);
          });
        }
      } else if (res.containsKey('data')) {
        final List<dynamic> pageData = res['data'] ?? [];
        final Map<String, dynamic> pagination =
            (res['pagination'] as Map?)?.cast<String, dynamic>() ?? {};
        if (mounted) {
          setState(() {
            _billList.addAll(pageData);
            _hasMoreData =
                pagination['has_next_page'] ?? (pageData.length == _perPage);
          });
        }
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (mounted) {
                SnackBarUtils.showError(context, 'Gagal memuat daftar tagihan: ${ErrorUtils.getFriendlyMessage(error)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreTagihan() async {
    if (!_hasMoreData) return;
    _currentPage += 1;
    await _loadTagihan(resetPage: false);
  }

  Future<void> _loadMorePembayaranPending() async {
    if (!_hasMorePending) return;
    setState(() {
      _isLoadingMorePending = true;
    });
    await _loadPendingPayments(loadMore: true);
    setState(() {
      _isLoadingMorePending = false;
    });
  }

  Future<void> _loadPendingPayments({bool loadMore = false}) async {
    try {
      if (!loadMore) {
        setState(() {
          _pendingPage = 1;
          _hasMorePending = true;
        });
      } else {
        _pendingPage++;
      }

      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      String url =
          '/payments?status=pending&limit=$_pendingPerPage&page=$_pendingPage';
      if (academicYearId != null) {
        url += '&academic_year_id=$academicYearId';
      }

      final response = await _apiService.get(url);
      if (mounted) {
        setState(() {
          final List<dynamic> rawList;
          if (response is Map && response.containsKey('data')) {
            rawList = response['data'] is List ? response['data'] : [];
            // Parse total from pagination
            if (response.containsKey('total')) {
              _totalPendingPayments =
                  int.tryParse(response['total'].toString()) ?? 0;
            } else if (response.containsKey('meta') &&
                response['meta'] is Map) {
              _totalPendingPayments =
                  int.tryParse(response['meta']['total'].toString()) ?? 0;
            }
          } else {
            rawList = response is List ? response : [];
            if (!loadMore) {
              _totalPendingPayments = rawList.length; // Fallback if no meta
            }
          }

          if (rawList.length < _pendingPerPage) {
            _hasMorePending = false;
          }

          final mappedList = rawList.map((item) {
            if (item is Map<String, dynamic>) {
              final newItem = Map<String, dynamic>.from(item);
              final bill = newItem['bill'] ?? {};
              final student = bill['student'] ?? {};
              final paymentType = bill['payment_type'] ?? {};

              // Map nested data to flat keys used by UI
              newItem['siswa_nama'] ??= student['name'];
              newItem['jenis_pembayaran_nama'] ??= paymentType['name'];

              // Safe extraction of class name
              if (newItem['kelas_nama'] == null) {
                if (student['classes'] is List &&
                    (student['classes'] as List).isNotEmpty) {
                  newItem['kelas_nama'] = student['classes'][0]['name'];
                } else if (student['class_name'] != null) {
                  newItem['kelas_nama'] = student['class_name'];
                } else if (student['class'] != null) {
                  newItem['kelas_nama'] = student['class']['name'];
                }
              }

              return newItem;
            }
            return item;
          }).toList();

          if (loadMore) {
            _pendingPaymentList.addAll(mappedList);
          } else {
            _pendingPaymentList = mappedList;
          }
        });
      }
    } catch (error) {
      AppLogger.error('finance', error);
      // Revert page if error
      if (loadMore) _pendingPage--;
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      String url = '/finance/dashboard';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final response = await _apiService.get(url);
      if (mounted) {
        final data = Map<String, dynamic>.from(response is Map ? response : {});

        // Fallback: If generated_batches is empty, fetch more bills to calculate summary
        final List<dynamic> batches = data['generated_batches'] ?? [];
        if (batches.isEmpty) {
          final res = await ApiService.getBillsPaginated(limit: 500);
          final List<dynamic>? billsData = res['data'] is List
              ? res['data']
              : (res is List ? res : null);

          if (billsData != null) {
            data['generated_batches'] = _calculateBatchesFromBills(billsData);
          }
        }

        setState(() {
          _dashboardData = data;
        });
      }
    } catch (error) {
      AppLogger.error('finance', error);
    }
  }

  List<dynamic> _calculateBatchesFromBills(List<dynamic> bills) {
    final Map<String, Map<String, dynamic>> batches = {};

    for (var t in bills) {
      final type = t['payment_type'] ?? {};
      final typeId = (t['payment_type_id'] ?? type['id'])?.toString();
      final dueDateStr = t['due_date']?.toString() ?? '';

      if (typeId == null || dueDateStr.isEmpty) continue;

      // Extract YYYY-MM
      final month = dueDateStr.length >= 7
          ? dueDateStr.substring(0, 7)
          : 'Unknown';
      final key = '${typeId}_$month';

      if (!batches.containsKey(key)) {
        batches[key] = {
          'payment_type_id': typeId,
          'name': type['name'] ?? 'No Name',
          'amount': type['amount'] ?? t['amount'] ?? 0,
          'month': month,
          'count': 0,
        };
      }
      batches[key]!['count']++;
    }

    final result = batches.values.toList();
    // Sort by month desc
    result.sort((a, b) => (b['month'] ?? '').compareTo(a['month'] ?? ''));
    return result;
  }

  void _showAddEditPaymentType({Map<String, dynamic>? paymentType}) {
    final namaController = TextEditingController(
      text: paymentType?['name'],
    );
    final descriptionController = TextEditingController(
      text: paymentType?['description'],
    );
    final jumlahController = TextEditingController(
      text: paymentType?['amount'] != null
          ? NumberFormat.currency(
              locale: 'id_ID',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(
              double.tryParse(paymentType!['amount'].toString()) ?? 0,
            )
          : '',
    );
    final periodeController = TextEditingController(
      text: paymentType?['periode'] ?? 'bulanan',
    );

    Map<String, dynamic>? goalData = paymentType != null
        ? _parseGoal(paymentType!['goal'])
        : null;
    String? status = (paymentType?['status'] == 'active')
        ? 'aktif'
        : (paymentType?['status'] == 'inactive' ? 'non-aktif' : 'aktif');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          String selectedPeriode = periodeController.text.isEmpty
              ? 'bulanan'
              : periodeController.text;
          final isEdit = paymentType != null;
          final languageProvider = ref.read(languageRiverpod);

          Widget buildPeriodeChip(String value, String label, IconData icon) {
            final isSelected = selectedPeriode == value;
            return GestureDetector(
              onTap: () {
                setModalState(() {
                  selectedPeriode = value;
                  periodeController.text = value;
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getPrimaryColor().withValues(alpha: 0.12)
                      : ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? _getPrimaryColor()
                        : ColorUtils.slate200,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected
                          ? _getPrimaryColor()
                          : ColorUtils.slate500,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? _getPrimaryColor()
                            : ColorUtils.slate600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          Widget buildStatusChip(
            String value,
            String label,
            Color color,
            IconData icon,
          ) {
            final isSelected = (status ?? 'aktif') == value;
            return GestureDetector(
              onTap: () => setModalState(() => status = value),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : ColorUtils.slate200,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected ? color : ColorUtils.slate400,
                    ),
                    SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? color : ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Header Grid (Pattern #10 style adopted to BottomSheet)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPrimaryColor(),
                        _getPrimaryColor().withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit
                                  ? languageProvider.getTranslatedText(
                                      AppLocalizations.editPaymentType,
                                    )
                                  : languageProvider.getTranslatedText(
                                      AppLocalizations.addPaymentType,
                                    ),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              isEdit
                                  ? 'Ubah data jenis pembayaran'
                                  : 'Tambah jenis pembayaran baru',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => AppNavigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nama
                          _buildDialogTextField(
                            controller: namaController,
                            label: 'Nama Pembayaran',
                            icon: Icons.payment_rounded,
                          ),
                          SizedBox(height: AppSpacing.md),
                          // Deskripsi
                          _buildDialogTextField(
                            controller: descriptionController,
                            label: 'Deskripsi (Opsional)',
                            icon: Icons.description_rounded,
                            maxLines: 2,
                          ),
                          SizedBox(height: AppSpacing.md),
                          // Jumlah
                          _buildDialogTextField(
                            controller: jumlahController,
                            label: 'Jumlah (Rp)',
                            icon: Icons.attach_money_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                          ),

                          SizedBox(height: AppSpacing.lg),
                          // Periode section
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: ColorUtils.slate600,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Periode Pembayaran',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ColorUtils.slate800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: buildPeriodeChip(
                                  'sekali bayar',
                                  'Sekali Bayar',
                                  Icons.looks_one_rounded,
                                ),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: buildPeriodeChip(
                                  'bulanan',
                                  'Bulanan',
                                  Icons.calendar_view_month_rounded,
                                ),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: buildPeriodeChip(
                                  'semester',
                                  'Semester',
                                  Icons.date_range_rounded,
                                ),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: buildPeriodeChip(
                                  'tahunan',
                                  'Tahunan',
                                  Icons.calendar_today_rounded,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: AppSpacing.lg),
                          // Tujuan Pembayaran
                          Row(
                            children: [
                              Icon(
                                Icons.groups_rounded,
                                size: 15,
                                color: ColorUtils.slate600,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Tujuan Pembayaran',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ColorUtils.slate800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              _showTargetSelectionModal(
                                paymentType: paymentType,
                                onSave: (goal) {
                                  setModalState(() => goalData = goal);
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    goalData != null && goalData!.isNotEmpty
                                    ? ColorUtils.success600.withValues(
                                        alpha: 0.06,
                                      )
                                    : ColorUtils.slate50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      goalData != null &&
                                          goalData!.isNotEmpty
                                      ? ColorUtils.success600.withValues(
                                          alpha: 0.4,
                                        )
                                      : ColorUtils.slate200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          (goalData != null &&
                                                      goalData!.isNotEmpty
                                                  ? ColorUtils.success600
                                                  : ColorUtils.corporateBlue600)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      goalData != null &&
                                              goalData!.isNotEmpty
                                          ? Icons.check_circle_rounded
                                          : Icons.groups_rounded,
                                      size: 18,
                                      color:
                                          goalData != null &&
                                              goalData!.isNotEmpty
                                          ? ColorUtils.success600
                                          : ColorUtils.corporateBlue600,
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          goalData != null &&
                                                  goalData!.isNotEmpty
                                              ? 'Tujuan Dipilih'
                                              : 'Belum ada tujuan',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                goalData != null &&
                                                    goalData!.isNotEmpty
                                                ? ColorUtils.success600
                                                : ColorUtils.slate600,
                                          ),
                                        ),
                                        Text(
                                          _getGoalDescription(goalData),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.slate500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: ColorUtils.slate400,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: AppSpacing.lg),
                          // Status section
                          Row(
                            children: [
                              Icon(
                                Icons.toggle_on_rounded,
                                size: 15,
                                color: ColorUtils.slate600,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ColorUtils.slate800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: buildStatusChip(
                                  'aktif',
                                  'Aktif',
                                  ColorUtils.success600,
                                  Icons.check_circle_rounded,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: buildStatusChip(
                                  'non-aktif',
                                  'Non-Aktif',
                                  ColorUtils.error600,
                                  Icons.cancel_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Enhanced Footer Actions
                Container(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.slate900.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Cancel',
                                'id': 'Batal',
                              }),
                              style: TextStyle(
                                color: ColorUtils.slate700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (namaController.text.isEmpty ||
                                  jumlahController.text.isEmpty) {
                                                                SnackBarUtils.showError(context, 'Nama dan jumlah harus diisi');
                                return;
                              }

                              final parsedAmount =
                                  CurrencyInputFormatter.parseCurrency(
                                    jumlahController.text,
                                  );

                              if (parsedAmount <= 0) {
                                                                SnackBarUtils.showError(context, 'Jumlah harus lebih besar dari Rp 0');
                                return;
                              }

                              if (goalData == null) {
                                                                SnackBarUtils.showError(context, 'Tujuan pembayaran harus dipilih');
                                return;
                              }

                              try {
                                final data = {
                                  'name': namaController.text,
                                  'description': descriptionController.text,
                                  'amount':
                                      CurrencyInputFormatter.parseCurrency(
                                        jumlahController.text,
                                      ),
                                  'periode': periodeController.text,
                                  'status': status == 'aktif'
                                      ? 'active'
                                      : 'inactive',
                                  'goal': goalData,
                                };

                                if (paymentType == null) {
                                  await _apiService.post(
                                    '/payment-types',
                                    data,
                                  );
                                } else {
                                  await _apiService.put(
                                    '/payment-types/${paymentType['id']}',
                                    data,
                                  );
                                }

                                if (context.mounted) {
                                  AppNavigator.pop(context);
                                }
                                _loadData(useCache: false);

                                if (context.mounted) {
                                                                    SnackBarUtils.showSuccess(context, 'Data berhasil disimpan');
                                }
                              } catch (error) {
                                AppLogger.error('finance', error);
                                if (context.mounted) {
                                                                    SnackBarUtils.showError(context, 'Gagal menyimpan jenis pembayaran: ${ErrorUtils.getFriendlyMessage(error)}');
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Save',
                                'id': 'Simpan',
                              }),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    // Ensure the given value exists in the items list
    String selectedValue = items.contains(value) ? value : items.first;

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonFormField<String>(
          initialValue: selectedValue, // Use the validated value
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
            border: InputBorder.none,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item == 'aktif'
                    ? 'Aktif'
                    : item == 'non-aktif'
                    ? 'Non-Aktif'
                    : item == 'sekali bayar'
                    ? 'Sekali Bayar'
                    : item == 'bulanan'
                    ? 'Bulanan'
                    : item == 'semester'
                    ? 'Semester'
                    : item == 'tahunan'
                    ? 'Tahunan'
                    : item == 'verified'
                    ? languageProvider.getTranslatedText(
                        AppLocalizations.verified,
                      )
                    : item == 'rejected'
                    ? 'Ditolak'
                    : item,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _deletePaymentType(
    Map<String, dynamic> paymentType,
  ) async {
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
      try {
        await _apiService.delete('/payment-type/${paymentType['id']}');
        if (mounted) {
                    SnackBarUtils.showSuccess(context, 'Jenis pembayaran berhasil dihapus');
        }
        _loadData(useCache: false);
      } catch (error) {
        AppLogger.error('finance', error);
        if (mounted) {
                    SnackBarUtils.showError(context, 'Gagal menghapus jenis pembayaran: ${ErrorUtils.getFriendlyMessage(error)}');
        }
      }
    }
  }

  Future<void> _confirmGenerateBills(
    Map<String, dynamic> paymentType,
  ) async {
    String selectedMonth = DateFormat('MMMM', 'id_ID').format(DateTime.now());
    String? selectedAcademicYearId;
    List<dynamic> academicYears = [];
    List<String> generatedMonths = [];
    bool isLoadingYears = true;
    bool isLoadingGenerated = false;

    // Pre-calculate months
    final List<String> months = [
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

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Fetch Academic Years once
          if (isLoadingYears && academicYears.isEmpty) {
            getIt<ApiAcademicServices>().getAcademicYears()
                .then((years) {
                  if (context.mounted) {
                    setDialogState(() {
                      academicYears = years;
                      isLoadingYears = false;
                      final activeYear = years.firstWhere(
                        (y) => y['current'] == true || y['status'] == 'active',
                        orElse: () => years.isNotEmpty ? years.first : null,
                      );
                      if (activeYear != null) {
                        selectedAcademicYearId = activeYear['id'].toString();
                        // Initial fetch for generated months
                        isLoadingGenerated = true;
                      }
                    });

                    if (selectedAcademicYearId != null) {
                      ApiService.getGeneratedMonths(
                        paymentTypeId: paymentType['id'].toString(),
                        academicYearId: selectedAcademicYearId!,
                      ).then((genMonths) {
                        if (context.mounted) {
                          setDialogState(() {
                            generatedMonths = genMonths;
                            isLoadingGenerated = false;
                          });
                        }
                      });
                    }
                  }
                })
                .catchError((e) {
                  if (context.mounted) {
                    setDialogState(() => isLoadingYears = false);
                  }
                });
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gradient Header (Pattern #10)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(gradient: _getCardGradient()),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Generate Tagihan',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                paymentType['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Academic Year Selection
                        Row(
                          children: [
                            Icon(
                              Icons.school_rounded,
                              size: 15,
                              color: ColorUtils.slate600,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Tahun Ajaran',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ColorUtils.slate800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        if (isLoadingYears)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: CircularProgressIndicator(
                                color: _getPrimaryColor(),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: ColorUtils.slate50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ColorUtils.slate200),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedAcademicYearId,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.calendar_today_rounded,
                                    color: _getPrimaryColor(),
                                    size: 18,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: ColorUtils.slate900,
                                  fontSize: 14,
                                ),
                                items: academicYears.map((y) {
                                  return DropdownMenuItem<String>(
                                    value: y['id'].toString(),
                                    child: Text(y['year'] ?? 'Unknown'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedAcademicYearId = val;
                                      isLoadingGenerated = true;
                                      generatedMonths = [];
                                    });
                                    ApiService.getGeneratedMonths(
                                      paymentTypeId: paymentType['id']
                                          .toString(),
                                      academicYearId: val,
                                    ).then((genMonths) {
                                      if (context.mounted) {
                                        setDialogState(() {
                                          generatedMonths = genMonths;
                                          isLoadingGenerated = false;
                                        });
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ),

                        SizedBox(height: AppSpacing.xl),

                        // Month Grid
                        Row(
                          children: [
                            Icon(
                              Icons.date_range_rounded,
                              size: 15,
                              color: ColorUtils.slate600,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Pilih Bulan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ColorUtils.slate800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        if (isLoadingGenerated)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: CircularProgressIndicator(
                                color: _getPrimaryColor(),
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: months.length,
                            itemBuilder: (context, index) {
                              final month = months[index];
                              final isGenerated = generatedMonths.contains(
                                month,
                              );
                              final isSelected = selectedMonth == month;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isGenerated
                                      ? null
                                      : () => setDialogState(
                                          () => selectedMonth = month,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isGenerated
                                          ? ColorUtils.slate100
                                          : isSelected
                                          ? _getPrimaryColor()
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isGenerated
                                            ? ColorUtils.slate200
                                            : isSelected
                                            ? _getPrimaryColor()
                                            : ColorUtils.slate200,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: _getPrimaryColor()
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Text(
                                            month,
                                            style: TextStyle(
                                              color: isGenerated
                                                  ? ColorUtils.slate400
                                                  : isSelected
                                                  ? Colors.white
                                                  : ColorUtils.slate700,
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (isGenerated)
                                          Positioned(
                                            right: 3,
                                            top: 3,
                                            child: Icon(
                                              Icons.check_circle_rounded,
                                              size: 12,
                                              color: ColorUtils.success600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  // Footer
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              AppLocalizations.cancel.tr,
                              style: TextStyle(color: ColorUtils.slate600),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                (selectedAcademicYearId == null ||
                                    generatedMonths.contains(selectedMonth))
                                ? null
                                : () {
                                    AppNavigator.pop(context, {
                                      'month': selectedMonth,
                                      'academicYearId': selectedAcademicYearId!,
                                    });
                                  },
                            icon: Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Generate',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              disabledBackgroundColor: ColorUtils.slate300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      try {
        if (mounted) {
          setState(() => _isLoading = true);
        }

        final response = await ApiService.generateBills(
          paymentTypeId: paymentType['id'].toString(),
          month: result['month'] ?? '',
          academicYearId: result['academicYearId'] ?? '',
        );

        if (mounted) {
          String message = 'Tagihan berhasil dibuat';
          if (response != null && response['message'] != null) {
            message = response['message'];
          }

          // Handle partial errors if any
          if (response != null &&
              response['errors'] != null &&
              (response['errors'] as List).isNotEmpty) {
            message = (response['errors'] as List).join('\n');
          }

                    SnackBarUtils.showSuccess(context, message);
          _loadData(useCache: false);
        }
      } catch (error) {
        AppLogger.error('finance', error);
        if (mounted) {
          setState(() => _isLoading = false);
                    SnackBarUtils.showError(context, 'Gagal mengenerate tagihan: ${ErrorUtils.getFriendlyMessage(error)}');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showVerificationDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final notesController = TextEditingController();
          String status = 'verified';

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: _getCardGradient(),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Verifikasi Pembayaran',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Info Pembayaran
                        _buildInfoItem(
                          'Siswa',
                          payment['siswa_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          'Kelas',
                          payment['kelas_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          languageProvider.getTranslatedText(
                            AppLocalizations.paymentTypes,
                          ),
                          payment['jenis_pembayaran_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          'Jumlah Bayar',
                          _formatCurrency(payment['amount']),
                        ),
                        _buildInfoItem(
                          'Metode Bayar',
                          payment['metode_bayar'] ?? '-',
                        ),

                        SizedBox(height: AppSpacing.lg),
                        Divider(),
                        SizedBox(height: AppSpacing.lg),

                        if (payment['payment_receipt'] != null) ...[
                          SizedBox(height: AppSpacing.md),
                          GestureDetector(
                            onTap: () => _showPaymentProof(payment),
                            child: Container(
                              padding: EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: ColorUtils.corporateBlue600.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ColorUtils.corporateBlue600.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.photo_library,
                                    color: ColorUtils.corporateBlue600,
                                    size: 20,
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bukti Pembayaran Tersedia',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: ColorUtils.corporateBlue600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Klik untuk melihat gambar',
                                          style: TextStyle(
                                            color: ColorUtils.corporateBlue600,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: ColorUtils.corporateBlue600,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.md),
                        ],

                        // Status Verifikasi
                        _buildDropdownField(
                          value: status,
                          label: 'Status Verifikasi',
                          icon: Icons.check_circle,
                          items: ['verified', 'rejected'],
                          onChanged: (value) {
                            setDialogState(() {
                              status = value!;
                            });
                          },
                        ),

                        SizedBox(height: AppSpacing.md),

                        // Catatan
                        _buildDialogTextField(
                          controller: notesController,
                          label: 'Catatan (Opsional)',
                          icon: Icons.note,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              AppLocalizations.cancel.tr,
                              style: TextStyle(color: ColorUtils.slate700),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await _apiService.put(
                                  '/payment/${payment['id']}/verify',
                                  {
                                    'status': status,
                                    'admin_notes':
                                        notesController.text.isEmpty
                                        ? null
                                        : notesController.text,
                                  },
                                );

                                if (context.mounted) {
                                  AppNavigator.pop(context);
                                  _loadData(useCache: false);

                                                                    SnackBarUtils.showSuccess(context, 'Pembayaran berhasil ${status == 'verified' ? 'diverifikasi' : 'ditolak'}');
                                }
                              } catch (error) {
                                AppLogger.error('finance', error);
                                if (context.mounted) {
                                                                    SnackBarUtils.showError(context, 'Gagal memverifikasi: ${ErrorUtils.getFriendlyMessage(error)}');
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: status == 'verified'
                                  ? ColorUtils.success600
                                  : ColorUtils.error600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              status == 'verified' ? 'Terima' : 'Tolak',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: ColorUtils.slate900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getFilteredJenisPembayaran() {
    return _paymentTypeList.where((item) {
      final searchTerm = _searchController.text.toLowerCase();
      final nama = item['name']?.toString().toLowerCase() ?? '';
      final deskripsi = item['description']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          nama.contains(searchTerm) ||
          deskripsi.contains(searchTerm);

      // Status filter
      final matchesStatus =
          _selectedStatusFilter == null ||
          (_selectedStatusFilter == 'aktif' && item['status'] == 'aktif') ||
          (_selectedStatusFilter == 'non_aktif' &&
              item['status'] == 'non-aktif');

      // Periode filter
      final matchesPeriode =
          _selectedPeriodeFilter == null ||
          (_selectedPeriodeFilter == 'bulanan' &&
              item['periode'] == 'bulanan') ||
          (_selectedPeriodeFilter == 'tahunan' && item['periode'] == 'tahunan');

      return matchesSearch && matchesStatus && matchesPeriode;
    }).toList();
  }

  Widget _buildPaymentTypeCard(Map<String, dynamic> item, int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + name + status chip
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ColorUtils.getColorForIndex(
                          index,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ColorUtils.getColorForIndex(
                            index,
                          ).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.payment_rounded,
                        color: ColorUtils.getColorForIndex(index),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'No Name',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            _formatCurrency(item['amount']),
                            style: TextStyle(
                              fontSize: 13,
                              color: ColorUtils.slate600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // Status chip
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            (item['status'] == 'aktif'
                                    ? ColorUtils.success600
                                    : ColorUtils.error600)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              (item['status'] == 'aktif'
                                      ? ColorUtils.success600
                                      : ColorUtils.error600)
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: item['status'] == 'aktif'
                                  ? ColorUtils.success600
                                  : ColorUtils.error600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5),
                          Text(
                            item['status'] == 'aktif' ? 'Aktif' : 'Non-Aktif',
                            style: TextStyle(
                              color: item['status'] == 'aktif'
                                  ? ColorUtils.success600
                                  : ColorUtils.error600,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (item['description'] != null &&
                    item['description'].isNotEmpty) ...[
                  SizedBox(height: 10),
                  Text(
                    item['description'],
                    style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                SizedBox(height: 10),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),

                // Tags row: periode + tujuan
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 10,
                            color: _getPrimaryColor(),
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            _getTranslatedPeriode(item['periode']),
                            style: TextStyle(
                              color: _getPrimaryColor(),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item['goal'] != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ColorUtils.info600.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 10,
                              color: ColorUtils.info600,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 160),
                              child: Text(
                                _getGoalDescription(item['goal']),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ColorUtils.info600,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                SizedBox(height: AppSpacing.md),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildCircleActionButton(
                      icon: Icons.autorenew_rounded,
                      color: ColorUtils.corporateBlue600,
                      onPressed: () => _confirmGenerateBills(item),
                      tooltip: 'Generate Tagihan',
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _buildCircleActionButton(
                      icon: Icons.edit_rounded,
                      color: _getPrimaryColor(),
                      onPressed: () =>
                          _showAddEditPaymentType(paymentType: item),
                      tooltip: AppLocalizations.edit.tr,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _buildCircleActionButton(
                      icon: Icons.delete_rounded,
                      color: ColorUtils.error600,
                      onPressed: () => _deletePaymentType(item),
                      tooltip: AppLocalizations.delete.tr,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }

  Widget _buildDashboardStats() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.receipt_long_rounded,
              value: '${_dashboardData['tagihan_belum_dibayar'] ?? 0}',
              label: languageProvider.getTranslatedText(
                AppLocalizations.unpaid,
              ),
              color: ColorUtils.warning600,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              icon: Icons.verified_rounded,
              value: '${_dashboardData['tagihan_terverifikasi'] ?? 0}',
              label: languageProvider.getTranslatedText(
                AppLocalizations.verified,
              ),
              color: ColorUtils.success600,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              icon: Icons.pending_actions_rounded,
              value: '$_totalPendingPayments',
              label: languageProvider.getTranslatedText({
                'en': 'Pending',
                'id': 'Menunggu',
              }),
              color: ColorUtils.corporateBlue600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedPaymentTypesSection() {
    List<dynamic> generatedBatches = _dashboardData['generated_batches'] ?? [];

    // Additional Fallback: If still empty but we have some tagihan, use them
    if (generatedBatches.isEmpty && _billList.isNotEmpty) {
      generatedBatches = _calculateBatchesFromBills(_billList);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          languageProvider.getTranslatedText({
            'en': 'Active Bills',
            'id': 'Tagihan Berjalan',
          }),
          Icons.receipt_long_rounded,
        ),
        if (generatedBatches.isEmpty)
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Text(
                'Belum ada tagihan yang digenerate',
                textAlign: TextAlign.center,
                style: TextStyle(color: ColorUtils.slate400, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: generatedBatches.length,
            itemBuilder: (context, index) {
              return _buildGeneratedPaymentBatchItem(generatedBatches[index]);
            },
          ),
      ],
    );
  }

  Widget _buildGeneratedPaymentBatchItem(Map<String, dynamic> item) {
    final name = item['name'] ?? 'No Name';
    final monthStr = item['month'] ?? '';
    final formattedMonth = _formatMonth(monthStr);
    final amount = _formatCurrency(item['amount']);
    final count = item['count'] ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getPrimaryColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getPrimaryColor().withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: _getPrimaryColor(),
              size: 22,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: ColorUtils.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  formattedMonth,
                  style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        amount,
                        style: TextStyle(
                          fontSize: 11,
                          color: _getPrimaryColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.info600.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$count Tagihan',
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.info600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildCircleActionButton(
            icon: Icons.delete_outline_rounded,
            color: ColorUtils.error600,
            onPressed: () => _deleteGeneratedBills(item),
            tooltip: AppLocalizations.delete.tr,
          ),
        ],
      ),
    );
  }

  String _formatMonth(String? monthStr) {
    if (monthStr == null || monthStr.isEmpty) return '';
    try {
      final parts = monthStr.split('-');
      if (parts.length != 2) return monthStr;

      final year = parts[0];
      final month = int.tryParse(parts[1]) ?? 1;

      const monthNames = [
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

      return '${monthNames[month - 1]} $year';
    } catch (e) {
      return monthStr;
    }
  }

  Future<void> _deleteGeneratedBills(Map<String, dynamic> item) async {
    final name = item['name'] ?? 'Tagihan';
    final monthStr = item['month'] ?? '';
    final formattedMonth = _formatMonth(monthStr);

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
      try {
        setState(() => _isLoading = true);
        await ApiService.deleteBillsByType(
          item['payment_type_id'].toString(),
          month: monthStr,
        );

        if (mounted) {
                    SnackBarUtils.showSuccess(context, 'Tagihan "$name" periode $formattedMonth berhasil dihapus');
          _loadData(useCache: false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
                    SnackBarUtils.showError(context, 'Gagal menghapus tagihan: $e');
        }
      }
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.85)],
    );
  }

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

        final filteredPaymentTypes = _getFilteredJenisPembayaran();

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
                              Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                              SizedBox(width: AppSpacing.sm),
                              Text('Perbarui Data'),
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
              _buildNavigationBar(languageProvider),
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
                            _buildDashboardStats(),
                            if (_pendingPaymentList.isNotEmpty)
                              _buildPendingSection(),
                            _buildGeneratedPaymentTypesSection(),
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
                                              hintText:
                                                  'Cari jenis pembayaran...',
                                              prefixIcon: Icon(
                                                Icons.search,
                                                color: ColorUtils.slate400,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
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
                                                backgroundColor:
                                                    _getPrimaryColor()
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                      return _buildPaymentTypeCard(
                                        filteredPaymentTypes[index],
                                        index,
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
                                return _buildPembayaranPendingCard(
                                  _pendingPaymentList[index],
                                  index,
                                );
                              },
                            ),
                      _buildClassReportTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: _getFloatingActionButton(),
        );
  }

  Widget _buildNavigationBar(LanguageProvider languageProvider) {
    final items = [
      {
        'icon': Icons.dashboard_rounded,
        'label': languageProvider.getTranslatedText(AppLocalizations.dashboard),
        'index': 0,
      },
      {
        'icon': Icons.payment_rounded,
        'label': languageProvider.getTranslatedText(
          AppLocalizations.paymentTypes,
        ),
        'index': 1,
      },
      {
        'icon': Icons.verified_rounded,
        'label': languageProvider.getTranslatedText(
          AppLocalizations.verification,
        ),
        'index': 2,
        'badge': _totalPendingPayments,
      },
      {
        'icon': Icons.school_rounded,
        'label': languageProvider.getTranslatedText(
          AppLocalizations.classReport,
        ),
        'index': 3,
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: items.map((item) {
          final index = item['index'] as int;
          final isSelected = _currentTabIndex == index;
          final badge = item['badge'] as int? ?? 0;

          return Expanded(
            child: GestureDetector(
              key: isSelected ? _tabBarKey : null,
              onTap: () => setState(() => _currentTabIndex = index),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 3),
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getPrimaryColor().withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? _getPrimaryColor().withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: 22,
                          color: isSelected
                              ? _getPrimaryColor()
                              : ColorUtils.slate400,
                        ),
                        if (badge > 0)
                          Positioned(
                            right: -8,
                            top: -4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: badge > 9 ? 4 : 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ColorUtils.error600,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                badge > 99 ? '99+' : '$badge',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? _getPrimaryColor()
                            : ColorUtils.slate500,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    final sectionColor = color ?? _getPrimaryColor();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: sectionColor, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: sectionColor),
            SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.warning600.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.warning600.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorUtils.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.pending_actions_rounded,
                  color: ColorUtils.warning600,
                  size: 20,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getTranslatedText(
                        AppLocalizations.paymentsPendingVerification,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${_pendingPaymentList.length} ${languageProvider.getTranslatedText({'en': 'payments need verification', 'id': 'pembayaran perlu diverifikasi'})}',
                      style: TextStyle(
                        color: ColorUtils.slate500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ColorUtils.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_pendingPaymentList.length}',
                  style: TextStyle(
                    color: ColorUtils.warning600,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!ref.read(academicYearRiverpod).isReadOnly) ...[
            SizedBox(height: 14),
            Builder(
              builder: (context) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _currentTabIndex = 2);
                    },
                    icon: Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Verify Now',
                        'id': 'Verifikasi Sekarang',
                      }),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.warning600,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPembayaranPendingCard(
    Map<String, dynamic> payment,
    int index,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showVerificationDialog(payment),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: avatar + name + status badge
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ColorUtils.getColorForIndex(
                          index,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ColorUtils.getColorForIndex(
                            index,
                          ).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (payment['siswa_nama'] ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.getColorForIndex(index),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment['siswa_nama'] ?? '-',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kelas ${payment['kelas_nama'] ?? '-'}',
                            style: TextStyle(
                              color: ColorUtils.slate500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorUtils.warning600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorUtils.warning600.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: ColorUtils.warning600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Menunggu',
                            style: TextStyle(
                              color: ColorUtils.warning600,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),

                // Info rows
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payment_rounded,
                            size: 10,
                            color: ColorUtils.slate500,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            payment['jenis_pembayaran_nama'] ?? '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_money_rounded,
                            size: 10,
                            color: ColorUtils.slate500,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            _formatCurrency(payment['amount']),
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: ColorUtils.slate500,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            payment['payment_date']?.split('T')[0] ?? '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bukti Pembayaran
                if (payment['payment_receipt'] != null) ...[
                  SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showPaymentProof(payment),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.corporateBlue600.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorUtils.corporateBlue600.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.photo_library_rounded,
                            size: 14,
                            color: ColorUtils.corporateBlue600,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Lihat Bukti Pembayaran',
                              style: TextStyle(
                                fontSize: 11,
                                color: ColorUtils.corporateBlue600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: ColorUtils.corporateBlue600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Verifikasi button
                if (!ref.read(academicYearRiverpod).isReadOnly) ...[
                  SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showVerificationDialog(payment),
                      icon: Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Verifikasi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getPrimaryColor(),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _getFloatingActionButton() {
    if (ref.read(academicYearRiverpod).isReadOnly) return null;

    if (_currentTabIndex == 1) {
      // Tab Jenis Pembayaran
      return FloatingActionButton(
        onPressed: () => _showAddEditPaymentType(),
        backgroundColor: _getPrimaryColor(),
        child: Icon(Icons.add, color: Colors.white),
      );
    }

    return null;
  }

  // Restored methods needed by other dialogs
  void _showPaymentProof(Map<String, dynamic> payment) {
    final imageFile =
        payment['payment_proof'] ?? payment['payment_receipt'];

    if (imageFile == null) {
            SnackBarUtils.showWarning(context, 'Tidak ada bukti pembayaran');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: _getCardGradient(),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.photo_library, color: Colors.white, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Bukti Pembayaran',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => AppNavigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Image
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _getImageUrl(imageFile),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: ColorUtils.error600,
                              size: 40,
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              'Gagal memuat gambar',
                              style: TextStyle(color: ColorUtils.error600),
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              'File: $imageFile',
                              style: TextStyle(
                                fontSize: 10,
                                color: ColorUtils.slate400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Info
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Pembayaran',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    _buildInfoRow('Siswa', payment['siswa_nama'] ?? '-'),
                    _buildInfoRow('Kelas', payment['kelas_nama'] ?? '-'),
                    _buildInfoRow(
                      'Jenis',
                      payment['jenis_pembayaran_nama'] ?? '-',
                    ),
                    _buildInfoRow(
                      'Jumlah',
                      _formatCurrency(payment['amount']),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTranslatedPeriode(String? periode) {
    if (periode == null) return '-';

    final languageProvider = ref.read(languageRiverpod);
    final lower = periode.toLowerCase();

    if (lower == 'once' || lower == 'sekali') {
      return languageProvider.getTranslatedText({
        'en': 'One Time',
        'id': 'Sekali',
      });
    } else if (lower == 'bulanan' || lower == 'monthly') {
      return languageProvider.getTranslatedText({
        'en': 'Monthly',
        'id': 'Bulanan',
      });
    } else if (lower == 'tahunan' || lower == 'yearly') {
      return languageProvider.getTranslatedText({
        'en': 'Yearly',
        'id': 'Tahunan',
      });
    } else if (lower == 'semester') {
      return languageProvider.getTranslatedText({
        'en': 'Semester',
        'id': 'Semester',
      });
    }

    return periode;
  }

  String _getImageUrl(String? filename) {
    if (filename == null) return '';
    return '${ApiService.baseUrl.replaceFirst('/api', '')}/uploads/bukti-pembayaran/$filename';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
            ),
          ),
          Text(
            ': ',
            style: TextStyle(color: ColorUtils.slate400, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: ColorUtils.slate800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
