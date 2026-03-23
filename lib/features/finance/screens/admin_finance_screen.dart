// Admin finance/billing management screen (keuangan).
//
// Like `pages/admin/finance.vue` - the main finance hub for managing:
// 1. Payment types (jenis pembayaran) - recurring/one-time billing templates
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/finance/screens/class_finance_report_screen.dart';
import 'package:manajemensekolah/features/settings/services/academic_service.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/currency_formatter.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Admin finance management screen with tabbed layout for payment types, bills, and verifications.
///
/// This is a [StatefulWidget] - like a Vue page component with tabs (`<v-tabs>`).
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  FinanceScreenState createState() => FinanceScreenState();
}

/// Mutable state for [FinanceScreen].
///
/// Key state (like Vue `data()`):
/// - [_currentTabIndex] - active tab (0=payment types, 1=bills, 2=pending payments)
/// - [_jenisPembayaranList] - payment type templates (monthly, yearly, one-time)
/// - [_tagihanList] - generated bills with pagination and filtering
/// - [_pembayaranPendingList] - payments awaiting verification
/// - [_dashboardData] - finance summary stats (total revenue, outstanding, etc.)
/// - Pagination and search state for each tab
///
/// setState() triggers re-render like Vue's reactivity system.
class FinanceScreenState extends State<FinanceScreen> {
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

  List<dynamic> _jenisPembayaranList = [];
  List<dynamic> _tagihanList = [];
  List<dynamic> _pembayaranPendingList = [];
  int _totalPembayaranPending = 0;
  List<dynamic> _kelasList = [];
  List<dynamic> _siswaList = [];
  Map<String, List<dynamic>> _siswaByKelas = {};
  Map<String, List<dynamic>> _tagihanBySiswa = {};
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentTabIndex = 0;

  String? _tourId;
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
  Map<String, dynamic>? _paginationMeta;
  Timer? _searchDebounce;

  // Search dan filter
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter; // 'aktif', 'non_aktif', atau null untuk semua
  String? _selectedPeriodeFilter; // 'bulanan', 'tahunan', atau null untuk semua
  bool _hasActiveFilter = false;

  // Variabel untuk modal pemilihan tujuan
  List<dynamic> _selectedKelas = [];
  Map<String, List<dynamic>> _selectedSiswaByKelas = {};
  final List<dynamic> _allSiswaList = [];
  final TextEditingController _searchSiswaController = TextEditingController();

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

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _checkAndShowTour();
    });
  }

  Future<void> _checkAndShowTour() async {
    try {
      // Check tour cache first
      const tourCacheKey = 'tour_finance_admin';
      final cachedTour = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cachedTour != null) {
        if (cachedTour['should_show'] == false) return;
        if (cachedTour['should_show'] == true && cachedTour['tour'] != null) {
          _tourId = cachedTour['tour']['id']?.toString();
          if (!mounted) return;
          _showTour();
          return;
        }
      }

      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'admin',
        name: 'admin_finance_screen_tour',
      );

      // Save tour status to cache (non-blocking)
      LocalCacheService.save(tourCacheKey, status);

      if (status['should_show'] == true && status['tour'] != null) {
        _tourId = status['tour']['id'];

        if (!mounted) return;
        _showTour();
      }
    } catch (e) {
      if (kDebugMode) print('Error checking tour status: $e');
    }
  }

  void _showTour() {
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = context.read<LanguageProvider>();

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
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
        }
        LocalCacheService.save('tour_finance_admin', {'should_show': false});
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
        }
        LocalCacheService.save('tour_finance_admin', {'should_show': false});
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = context.read<LanguageProvider>();

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
    _searchSiswaController.dispose();
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
    final languageProvider = context.read<LanguageProvider>();

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
                          SizedBox(width: 8),
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
                      SizedBox(height: 12),
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

                      SizedBox(height: 20),
                      Divider(color: ColorUtils.slate100),
                      SizedBox(height: 8),

                      // Periode Filter
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: 8),
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
                      SizedBox(height: 12),
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
                padding: EdgeInsets.all(20),
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
                        onPressed: () => Navigator.pop(context),
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
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
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
    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
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
              _jenisPembayaranList =
                  (cached['jenisPembayaran'] as List<dynamic>?) ?? [];
              _tagihanList = (cached['tagihan'] as List<dynamic>?) ?? [];
              _pembayaranPendingList =
                  (cached['pendingPayments'] as List<dynamic>?) ?? [];
              _totalPembayaranPending =
                  (cached['totalPending'] as int?) ?? 0;
              _dashboardData =
                  Map<String, dynamic>.from(cached['dashboard'] ?? {});
              _kelasList = (cached['kelas'] as List<dynamic>?) ?? [];
              _siswaList = (cached['siswa'] as List<dynamic>?) ?? [];
              _siswaByKelas = (cached['siswaByKelas'] as Map<String, dynamic>?)
                      ?.map((k, v) => MapEntry(k, List<dynamic>.from(v))) ??
                  {};
              _tagihanBySiswa =
                  (cached['tagihanBySiswa'] as Map<String, dynamic>?)
                          ?.map(
                            (k, v) => MapEntry(k, List<dynamic>.from(v)),
                          ) ??
                      {};
              _isLoading = false;
              _errorMessage = '';
            });
            if (kDebugMode) print('Finance data loaded from cache');
            return;
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error loading finance cache: $e');
      }
    }

    // Step 2: Show skeleton only if no cached data displayed
    final hasData = _jenisPembayaranList.isNotEmpty ||
        _tagihanList.isNotEmpty ||
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
        _loadJenisPembayaran(),
        _loadTagihan(),
        _loadPembayaranPending(),
        _loadDashboardData(),
        _loadKelasData(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Save to cache (non-blocking)
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'jenisPembayaran': _jenisPembayaranList,
          'tagihan': _tagihanList,
          'pendingPayments': _pembayaranPendingList,
          'totalPending': _totalPembayaranPending,
          'dashboard': _dashboardData,
          'kelas': _kelasList,
          'siswa': _siswaList,
          'siswaByKelas': _siswaByKelas,
          'tagihanBySiswa': _tagihanBySiswa,
        });
      }
    } catch (error) {
      if (kDebugMode) print('Error loading data: $error');
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

  // Tambahkan method baru untuk load data kelas dan siswa
  Future<void> _loadKelasData() async {
    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      // Load data kelas
      String url = '/classes?limit=1000';
      if (academicYearId != null) {
        url += '&academic_year_id=$academicYearId';
      }

      final kelasResponse = await _apiService.get(url);
      if (mounted) {
        setState(() {
          if (kelasResponse is Map && kelasResponse.containsKey('data')) {
            _kelasList = kelasResponse['data'] is List
                ? kelasResponse['data']
                : [];
          } else {
            _kelasList = kelasResponse is List ? kelasResponse : [];
          }
        });
      }

      // Load data siswa
      final siswaResponse = await _apiService.get('/students?limit=1000');
      final List<dynamic> allSiswa;
      if (siswaResponse is Map && siswaResponse.containsKey('data')) {
        allSiswa = siswaResponse['data'] is List ? siswaResponse['data'] : [];
      } else {
        allSiswa = siswaResponse is List ? siswaResponse : [];
      }

      // Kelompokkan siswa berdasarkan kelas
      Map<String, List<dynamic>> siswaByKelas = {};
      for (var siswa in allSiswa) {
        String? classId = siswa['class_id']?.toString();
        // Fallback to nested class object if class_id is null (new schema)
        if (classId == null && siswa['class'] != null) {
          classId = siswa['class']['id']?.toString();
        }

        if (classId != null) {
          if (!siswaByKelas.containsKey(classId)) {
            siswaByKelas[classId] = [];
          }
          siswaByKelas[classId]!.add(siswa);
        }
      }

      if (mounted) {
        setState(() {
          _siswaByKelas = siswaByKelas;
          _siswaList = allSiswa;
        });
      }

      // Load tagihan untuk setiap siswa
      await _loadTagihanForSiswa(allSiswa);
    } catch (error) {
      if (kDebugMode) print('Error loading kelas data: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat data kelas: ${ErrorUtils.getFriendlyMessage(error)}',
            ),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    }
  }

  Future<void> _loadTagihanForSiswa(List<dynamic> siswaList) async {
    try {
      Map<String, List<dynamic>> tagihanBySiswa = {};

      for (var siswa in siswaList) {
        final siswaId = siswa['id']?.toString();
        if (siswaId != null) {
          final tagihanResponse = await _apiService.get(
            '/bills?student_id=$siswaId',
          );

          List<dynamic> tagihanSiswa = [];
          if (tagihanResponse is Map<String, dynamic> &&
              tagihanResponse.containsKey('data')) {
            tagihanSiswa = tagihanResponse['data'] is List
                ? tagihanResponse['data']
                : [];
          } else if (tagihanResponse is List) {
            tagihanSiswa = tagihanResponse;
          }

          tagihanBySiswa[siswaId] = tagihanSiswa;
        }
      }

      if (mounted) {
        setState(() {
          _tagihanBySiswa = tagihanBySiswa;
        });
      }
    } catch (error) {
      if (kDebugMode) print('Error loading tagihan for siswa: $error');
    }
  }

  // Method helper untuk parsing tujuan
  Map<String, dynamic> _parseTujuan(dynamic tujuanData) {
    if (tujuanData == null) {
      return {};
    }

    if (tujuanData is Map<String, dynamic>) {
      return tujuanData;
    }

    if (tujuanData is String) {
      try {
        return json.decode(tujuanData) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing tujuan JSON: $e');
        return {};
      }
    }

    return {};
  }

  String _getTujuanDescription(dynamic tujuanData) {
    final parsedTujuan = _parseTujuan(tujuanData);
    return parsedTujuan['description'] ?? 'Tujuan pembayaran';
  }

  void _showPemilihanTujuanModal({
    Map<String, dynamic>? jenisPembayaran,
    required Function(Map<String, dynamic>) onSave,
  }) {
    // Reset state
    _selectedKelas = [];
    _selectedSiswaByKelas = {};
    _searchSiswaController.clear();

    // Jika edit, load data tujuan yang sudah dipilih
    if (jenisPembayaran?['goal'] != null) {
      _loadExistingTujuan(jenisPembayaran!['goal']);
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
                  padding: EdgeInsets.all(16),
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
                      SizedBox(width: 12),
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
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Search Siswa
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: ColorUtils.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorUtils.slate200),
                    ),
                    child: TextField(
                      controller: _searchSiswaController,
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
                      SizedBox(width: 8),
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
                Expanded(child: _buildKelasListForSelection(setModalState)),

                // Footer dengan summary
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                  ),
                  child: Column(
                    children: [
                      _buildSelectionSummary(),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Batal'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final tujuan = _buildTujuanData();
                                onSave(tujuan);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getPrimaryColor(),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Simpan',
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

  void _loadExistingTujuan(dynamic tujuanData) {
    final tujuan = _parseTujuan(tujuanData);

    if (tujuan['type'] == 'all') {
      // Pilih semua kelas
      _selectedKelas = List.from(_kelasList);
      for (var kelas in _kelasList) {
        final classId = kelas['id'].toString();
        _selectedSiswaByKelas[classId] = List.from(
          _siswaByKelas[classId] ?? [],
        );
      }
    } else if (tujuan['type'] == 'custom') {
      // Load custom selection
      _selectedKelas = _kelasList.where((kelas) {
        return tujuan['kelas']?.contains(kelas['id'].toString()) == true;
      }).toList();

      for (var classId in tujuan['kelas'] ?? []) {
        _selectedSiswaByKelas[classId] = (tujuan['siswa']?[classId] ?? [])
            .map((siswaId) => _findSiswaById(siswaId))
            .where((siswa) => siswa != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
    }
  }

  dynamic _findSiswaById(String siswaId) {
    for (var siswaList in _siswaByKelas.values) {
      for (var siswa in siswaList) {
        if (siswa['id'].toString() == siswaId) {
          return siswa;
        }
      }
    }
    return null;
  }

  Widget _buildKelasListForSelection(StateSetter setModalState) {
    final searchTerm = _searchSiswaController.text.toLowerCase();

    return ListView.builder(
      itemCount: _kelasList.length,
      itemBuilder: (context, index) {
        final kelas = _kelasList[index];
        final classId = kelas['id'].toString();
        final isKelasSelected = _selectedKelas.any(
          (k) => k['id'].toString() == classId,
        );
        final siswaList = _siswaByKelas[classId] ?? [];

        // Filter siswa berdasarkan search
        final filteredSiswa = siswaList.where((siswa) {
          final nama = siswa['name']?.toString().toLowerCase() ?? '';
          final nis = siswa['student_number']?.toString().toLowerCase() ?? '';
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
              value: isKelasSelected,
              onChanged: (value) {
                setModalState(() {
                  if (value == true) {
                    _selectedKelas.add(kelas);
                    _selectedSiswaByKelas[classId] = List.from(siswaList);
                  } else {
                    _selectedKelas.removeWhere(
                      (k) => k['id'].toString() == classId,
                    );
                    _selectedSiswaByKelas.remove(classId);
                  }
                });
              },
            ),
            title: Text(
              kelas['name'] ?? 'Kelas',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isKelasSelected
                    ? _getPrimaryColor()
                    : ColorUtils.slate900,
              ),
            ),
            subtitle: Text(
              '${siswaList.length} ${languageProvider.getTranslatedText(AppLocalizations.students)}',
              style: TextStyle(fontSize: 12),
            ),
            trailing: isKelasSelected
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedSiswaByKelas[classId]?.length ?? 0}/${siswaList.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getPrimaryColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            children: [
              if (filteredSiswa.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
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
                ...filteredSiswa.map(
                  (siswa) => _buildSiswaCheckbox(
                    siswa: siswa,
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

  Widget _buildSiswaCheckbox({
    required Map<String, dynamic> siswa,
    required String classId,
    required StateSetter setModalState,
  }) {
    final isSelected =
        _selectedSiswaByKelas[classId]?.any(
          (s) => s['id'].toString() == siswa['id'].toString(),
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
            final siswaList = _selectedSiswaByKelas[classId] ?? [];
            if (value == true) {
              siswaList.add(siswa);
            } else {
              siswaList.removeWhere(
                (s) => s['id'].toString() == siswa['id'].toString(),
              );
            }
            _selectedSiswaByKelas[classId] = siswaList;

            // Update kelas selection
            if (siswaList.isEmpty) {
              _selectedKelas.removeWhere((k) => k['id'].toString() == classId);
            } else if (!_selectedKelas.any(
              (k) => k['id'].toString() == classId,
            )) {
              _selectedKelas.add(
                _kelasList.firstWhere((k) => k['id'].toString() == classId),
              );
            }
          });
        },
        title: Text(siswa['name'] ?? 'Siswa', style: TextStyle(fontSize: 14)),
        subtitle: Text(
          'NIS: ${siswa['student_number'] ?? '-'}',
          style: TextStyle(fontSize: 11, color: ColorUtils.slate600),
        ),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildSelectionSummary() {
    int totalKelas = _selectedKelas.length;
    int totalSiswa = _selectedSiswaByKelas.values.fold(
      0,
      (sum, siswaList) => sum + siswaList.length,
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
              '$totalKelas Kelas • $totalSiswa Siswa',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getPrimaryColor(),
              ),
            ),
          ],
        ),
        if (totalKelas == _kelasList.length && totalSiswa == _getTotalSiswa())
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

  int _getTotalSiswa() {
    return _siswaByKelas.values.fold(
      0,
      (sum, siswaList) => sum + siswaList.length,
    );
  }

  void _selectAllKelas(StateSetter setModalState) {
    setModalState(() {
      _selectedKelas = List.from(_kelasList);
      for (var kelas in _kelasList) {
        final classId = kelas['id'].toString();
        _selectedSiswaByKelas[classId] = List.from(
          _siswaByKelas[classId] ?? [],
        );
      }
    });
  }

  void _clearAllSelection(StateSetter setModalState) {
    setModalState(() {
      _selectedKelas.clear();
      _selectedSiswaByKelas.clear();
    });
  }

  Map<String, dynamic> _buildTujuanData() {
    final totalKelas = _selectedKelas.length;
    final totalSiswa = _getTotalSiswa();
    final selectedSiswaCount = _selectedSiswaByKelas.values.fold(
      0,
      (sum, siswaList) => sum + siswaList.length,
    );

    // Jika semua kelas dan semua siswa terpilih
    if (totalKelas == _kelasList.length && selectedSiswaCount == totalSiswa) {
      return {'type': 'all', 'description': 'Semua siswa di semua kelas'};
    }

    // Custom selection
    final classIds = _selectedKelas.map((k) => k['id'].toString()).toList();
    final siswaMap = <String, List<String>>{};

    _selectedSiswaByKelas.forEach((classId, siswaList) {
      siswaMap[classId] = siswaList.map((s) => s['id'].toString()).toList();
    });

    return {
      'type': 'custom',
      'kelas': classIds,
      'siswa': siswaMap,
      'description': '$selectedSiswaCount siswa di $totalKelas kelas',
    };
  }

  // Widget untuk tab Laporan Kelas
  Widget _buildLaporanKelasTab() {
    if (_isLoading) {
      return SkeletonListLoading(itemCount: 6, infoTagCount: 1);
    }

    if (_kelasList.isEmpty) {
      return EmptyState(
        title: 'Belum ada data kelas',
        subtitle: 'Data kelas akan muncul di sini',
        icon: Icons.class_,
      );
    }

    return ListView.builder(
      itemCount: _kelasList.length,
      itemBuilder: (context, index) {
        final kelas = _kelasList[index];
        final classId = kelas['id']?.toString();
        final siswaList = _siswaByKelas[classId] ?? [];

        return _buildKelasCard(kelas, siswaList, index);
      },
    );
  }

  Widget _buildKelasCard(
    Map<String, dynamic> kelas,
    List<dynamic> siswaList,
    int index,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassFinanceReportScreen(
                classId: kelas['id'].toString(),
                className: kelas['name'] ?? 'Kelas',
              ),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          padding: EdgeInsets.all(16),
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
                      kelas['name'] ?? 'Kelas',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${kelas['student_count'] ?? siswaList.length} siswa',
                      style: TextStyle(
                        color: ColorUtils.slate500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildKelasSummary(siswaList),
              SizedBox(width: 8),
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

  Widget _buildKelasSummary(List<dynamic> siswaList) {
    int totalLunas = 0;
    int totalPending = 0;
    int totalBelumBayar = 0;

    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    final selectedAcademicYearId = academicYearProvider
        .selectedAcademicYear?['id']
        ?.toString();

    for (var siswa in siswaList) {
      final siswaId = siswa['id']?.toString();
      final tagihanList = _tagihanBySiswa[siswaId] ?? [];

      for (var tagihan in tagihanList) {
        // Filter based on academic year
        final tagihanAcademicYearId = tagihan['academic_year_id']?.toString();
        if (selectedAcademicYearId != null &&
            tagihanAcademicYearId != null &&
            tagihanAcademicYearId != selectedAcademicYearId) {
          continue;
        }

        final status = tagihan['status'];

        // 1. Check Verified/Lunas
        if (status == 'verified') {
          totalLunas++;
        }
        // 2. Check Pending Verification (Menunggu)
        // Logic: Has a payment with status 'pending' (regardless of bill status being pending/unpaid)
        else {
          bool hasPendingPayment = false;
          if (tagihan['payments'] != null && tagihan['payments'] is List) {
            for (var p in tagihan['payments']) {
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
            // 3. Fallback: Belum Bayar
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

  Future<void> _loadJenisPembayaran() async {
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
          _jenisPembayaranList = rawData.map((item) {
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
      if (kDebugMode) print('Error loading jenis pembayaran: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat jenis pembayaran: ${ErrorUtils.getFriendlyMessage(error)}',
            ),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    }
  }

  Future<void> _loadTagihan({bool resetPage = true}) async {
    try {
      if (resetPage) {
        _currentPage = 1;
        _tagihanList = [];
        _hasMoreData = true;
        _paginationMeta = null;
      }

      setState(() {
        _isLoading = resetPage;
        _isLoadingMore = !resetPage;
      });

      final res = await ApiService.getTagihanPaginated(
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
            _tagihanList.addAll(pageData);
            _paginationMeta = pagination;
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
            _tagihanList.addAll(pageData);
            _paginationMeta = pagination;
            _hasMoreData =
                pagination['has_next_page'] ?? (pageData.length == _perPage);
          });
        }
      }
    } catch (error) {
      if (kDebugMode) print('Error loading tagihan (paginated): $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat daftar tagihan: ${ErrorUtils.getFriendlyMessage(error)}',
            ),
            backgroundColor: ColorUtils.error600,
          ),
        );
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
    await _loadPembayaranPending(loadMore: true);
    setState(() {
      _isLoadingMorePending = false;
    });
  }

  Future<void> _loadPembayaranPending({bool loadMore = false}) async {
    try {
      if (!loadMore) {
        setState(() {
          _pendingPage = 1;
          _hasMorePending = true;
        });
      } else {
        _pendingPage++;
      }

      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
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
              _totalPembayaranPending =
                  int.tryParse(response['total'].toString()) ?? 0;
            } else if (response.containsKey('meta') &&
                response['meta'] is Map) {
              _totalPembayaranPending =
                  int.tryParse(response['meta']['total'].toString()) ?? 0;
            }
          } else {
            rawList = response is List ? response : [];
            if (!loadMore) {
              _totalPembayaranPending = rawList.length; // Fallback if no meta
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
            _pembayaranPendingList.addAll(mappedList);
          } else {
            _pembayaranPendingList = mappedList;
          }
        });
      }
    } catch (error) {
      if (kDebugMode) print('Error loading pembayaran pending: $error');
      // Revert page if error
      if (loadMore) _pendingPage--;
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
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
          final res = await ApiService.getTagihanPaginated(limit: 500);
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
      if (kDebugMode) print('Error loading dashboard data: $error');
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

  void _showAddEditJenisPembayaran({Map<String, dynamic>? jenisPembayaran}) {
    final namaController = TextEditingController(
      text: jenisPembayaran?['name'],
    );
    final deskripsiController = TextEditingController(
      text: jenisPembayaran?['description'],
    );
    final jumlahController = TextEditingController(
      text: jenisPembayaran?['amount'] != null
          ? NumberFormat.currency(
              locale: 'id_ID',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(
              double.tryParse(jenisPembayaran!['amount'].toString()) ?? 0,
            )
          : '',
    );
    final periodeController = TextEditingController(
      text: jenisPembayaran?['periode'] ?? 'bulanan',
    );

    Map<String, dynamic>? tujuanData = jenisPembayaran != null
        ? _parseTujuan(jenisPembayaran['goal'])
        : null;
    String? status = (jenisPembayaran?['status'] == 'active')
        ? 'aktif'
        : (jenisPembayaran?['status'] == 'inactive' ? 'non-aktif' : 'aktif');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          String selectedPeriode = periodeController.text.isEmpty
              ? 'bulanan'
              : periodeController.text;
          final isEdit = jenisPembayaran != null;
          final languageProvider = context.read<LanguageProvider>();

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
                    SizedBox(height: 4),
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
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(20),
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
                          SizedBox(height: 12),
                          // Deskripsi
                          _buildDialogTextField(
                            controller: deskripsiController,
                            label: 'Deskripsi (Opsional)',
                            icon: Icons.description_rounded,
                            maxLines: 2,
                          ),
                          SizedBox(height: 12),
                          // Jumlah
                          _buildDialogTextField(
                            controller: jumlahController,
                            label: 'Jumlah (Rp)',
                            icon: Icons.attach_money_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                          ),

                          SizedBox(height: 16),
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

                          SizedBox(height: 16),
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
                              _showPemilihanTujuanModal(
                                jenisPembayaran: jenisPembayaran,
                                onSave: (tujuan) {
                                  setModalState(() => tujuanData = tujuan);
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
                                    tujuanData != null && tujuanData!.isNotEmpty
                                    ? ColorUtils.success600.withValues(
                                        alpha: 0.06,
                                      )
                                    : ColorUtils.slate50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      tujuanData != null &&
                                          tujuanData!.isNotEmpty
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
                                          (tujuanData != null &&
                                                      tujuanData!.isNotEmpty
                                                  ? ColorUtils.success600
                                                  : ColorUtils.corporateBlue600)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      tujuanData != null &&
                                              tujuanData!.isNotEmpty
                                          ? Icons.check_circle_rounded
                                          : Icons.groups_rounded,
                                      size: 18,
                                      color:
                                          tujuanData != null &&
                                              tujuanData!.isNotEmpty
                                          ? ColorUtils.success600
                                          : ColorUtils.corporateBlue600,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tujuanData != null &&
                                                  tujuanData!.isNotEmpty
                                              ? 'Tujuan Dipilih'
                                              : 'Belum ada tujuan',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                tujuanData != null &&
                                                    tujuanData!.isNotEmpty
                                                ? ColorUtils.success600
                                                : ColorUtils.slate600,
                                          ),
                                        ),
                                        Text(
                                          _getTujuanDescription(tujuanData),
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

                          SizedBox(height: 16),
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
                  padding: EdgeInsets.all(20),
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
                            onPressed: () => Navigator.pop(context),
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
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (namaController.text.isEmpty ||
                                  jumlahController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Nama dan jumlah harus diisi',
                                    ),
                                    backgroundColor: ColorUtils.error600,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              final parsedAmount =
                                  CurrencyInputFormatter.parseCurrency(
                                    jumlahController.text,
                                  );

                              if (parsedAmount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Jumlah harus lebih besar dari Rp 0',
                                    ),
                                    backgroundColor: ColorUtils.error600,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              if (tujuanData == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Tujuan pembayaran harus dipilih',
                                    ),
                                    backgroundColor: ColorUtils.error600,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              try {
                                final data = {
                                  'name': namaController.text,
                                  'description': deskripsiController.text,
                                  'amount':
                                      CurrencyInputFormatter.parseCurrency(
                                        jumlahController.text,
                                      ),
                                  'periode': periodeController.text,
                                  'status': status == 'aktif'
                                      ? 'active'
                                      : 'inactive',
                                  'goal': tujuanData,
                                };

                                if (jenisPembayaran == null) {
                                  await _apiService.post(
                                    '/payment-types',
                                    data,
                                  );
                                } else {
                                  await _apiService.put(
                                    '/payment-types/${jenisPembayaran['id']}',
                                    data,
                                  );
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                _loadData(useCache: false);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Data berhasil disimpan'),
                                      backgroundColor: ColorUtils.success600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (kDebugMode) {
                                  print('Error saving payment type: $error');
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Gagal menyimpan jenis pembayaran: ${ErrorUtils.getFriendlyMessage(error)}',
                                      ),
                                      backgroundColor: ColorUtils.error600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
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
    // Pastikan value yang diberikan ada dalam items
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
          initialValue: selectedValue, // Gunakan value yang sudah divalidasi
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

  Future<void> _deleteJenisPembayaran(
    Map<String, dynamic> jenisPembayaran,
  ) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: languageProvider.getTranslatedText(
          AppLocalizations.deletePaymentType,
        ),
        content:
            'Yakin ingin menghapus jenis pembayaran "${jenisPembayaran['name']}"?',
        confirmText: 'Hapus',
        confirmColor: ColorUtils.error600,
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.delete('/payment-type/${jenisPembayaran['id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jenis pembayaran berhasil dihapus'),
              backgroundColor: ColorUtils.success600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadData(useCache: false);
      } catch (error) {
        if (kDebugMode) print('Error deleting payment type: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal menghapus jenis pembayaran: ${ErrorUtils.getFriendlyMessage(error)}',
              ),
              backgroundColor: ColorUtils.error600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmGenerateBills(
    Map<String, dynamic> jenisPembayaran,
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
            ApiAcademicServices.getAcademicYears()
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
                        paymentTypeId: jenisPembayaran['id'].toString(),
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
                    padding: EdgeInsets.all(20),
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
                                jenisPembayaran['name'] ?? '',
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
                    padding: EdgeInsets.all(20),
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
                              padding: EdgeInsets.all(16),
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
                                      paymentTypeId: jenisPembayaran['id']
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

                        SizedBox(height: 20),

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
                              padding: EdgeInsets.all(20),
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
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(color: ColorUtils.slate600),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                (selectedAcademicYearId == null ||
                                    generatedMonths.contains(selectedMonth))
                                ? null
                                : () {
                                    Navigator.pop(context, {
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
          paymentTypeId: jenisPembayaran['id'].toString(),
          month: result['month']!,
          academicYearId: result['academicYearId']!,
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: ColorUtils.success600,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadData(useCache: false);
        }
      } catch (error) {
        if (kDebugMode) print('Error generating bills: $error');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal mengenerate tagihan: ${ErrorUtils.getFriendlyMessage(error)}',
              ),
              backgroundColor: ColorUtils.error600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showVerifikasiDialog(Map<String, dynamic> pembayaran) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final catatanController = TextEditingController();
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
                    padding: EdgeInsets.all(20),
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
                        SizedBox(width: 12),
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
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Info Pembayaran
                        _buildInfoItem(
                          'Siswa',
                          pembayaran['siswa_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          'Kelas',
                          pembayaran['kelas_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          languageProvider.getTranslatedText(
                            AppLocalizations.paymentTypes,
                          ),
                          pembayaran['jenis_pembayaran_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          'Jumlah Bayar',
                          _formatCurrency(pembayaran['amount']),
                        ),
                        _buildInfoItem(
                          'Metode Bayar',
                          pembayaran['metode_bayar'] ?? '-',
                        ),

                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 16),

                        if (pembayaran['payment_receipt'] != null) ...[
                          SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _showBuktiPembayaran(pembayaran),
                            child: Container(
                              padding: EdgeInsets.all(12),
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
                                  SizedBox(width: 8),
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
                          SizedBox(height: 12),
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

                        SizedBox(height: 12),

                        // Catatan
                        _buildDialogTextField(
                          controller: catatanController,
                          label: 'Catatan (Opsional)',
                          icon: Icons.note,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(color: ColorUtils.slate700),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await _apiService.put(
                                  '/payment/${pembayaran['id']}/verify',
                                  {
                                    'status': status,
                                    'admin_notes':
                                        catatanController.text.isEmpty
                                        ? null
                                        : catatanController.text,
                                  },
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _loadData(useCache: false);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Pembayaran berhasil ${status == 'verified' ? 'diverifikasi' : 'ditolak'}',
                                      ),
                                      backgroundColor: ColorUtils.success600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (kDebugMode) {
                                  print('Error verifying payment: $error');
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Gagal memverifikasi: ${ErrorUtils.getFriendlyMessage(error)}',
                                      ),
                                      backgroundColor: ColorUtils.error600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
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
    return _jenisPembayaranList.where((item) {
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

  Widget _buildJenisPembayaranCard(Map<String, dynamic> item, int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            padding: EdgeInsets.all(16),
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
                    SizedBox(width: 12),
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
                    SizedBox(width: 8),
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
                          SizedBox(width: 4),
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
                            SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 160),
                              child: Text(
                                _getTujuanDescription(item['goal']),
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

                SizedBox(height: 12),

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
                    SizedBox(width: 8),
                    _buildCircleActionButton(
                      icon: Icons.edit_rounded,
                      color: _getPrimaryColor(),
                      onPressed: () =>
                          _showAddEditJenisPembayaran(jenisPembayaran: item),
                      tooltip: 'Edit',
                    ),
                    SizedBox(width: 8),
                    _buildCircleActionButton(
                      icon: Icons.delete_rounded,
                      color: ColorUtils.error600,
                      onPressed: () => _deleteJenisPembayaran(item),
                      tooltip: 'Hapus',
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
      padding: EdgeInsets.all(16),
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
              value: '$_totalPembayaranPending',
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
          SizedBox(height: 8),
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
    if (generatedBatches.isEmpty && _tagihanList.isNotEmpty) {
      generatedBatches = _calculateBatchesFromBills(_tagihanList);
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
            padding: EdgeInsets.all(16),
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
          SizedBox(width: 12),
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
            tooltip: 'Hapus',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tagihan "$name" periode $formattedMonth berhasil dihapus',
              ),
              backgroundColor: ColorUtils.success600,
            ),
          );
          _loadData(useCache: false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus tagihan: $e'),
              backgroundColor: ColorUtils.error600,
            ),
          );
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return Scaffold(
            backgroundColor: ColorUtils.slate50,
            body: SkeletonListLoading(itemCount: 6, infoTagCount: 1),
          );
        }

        if (_errorMessage.isNotEmpty) {
          return ErrorScreen(errorMessage: _errorMessage, onRetry: _loadData);
        }

        final filteredJenisPembayaran = _getFilteredJenisPembayaran();

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
                      onTap: () => Navigator.pop(context),
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
                    SizedBox(width: 12),
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
                              SizedBox(width: 8),
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
                            if (_pembayaranPendingList.isNotEmpty)
                              _buildPendingSection(),
                            _buildGeneratedPaymentTypesSection(),
                            SizedBox(height: 16),
                          ],
                        ),
                      ),

                      // Tab Jenis Pembayaran
                      Column(
                        children: [
                          // Search Bar and Filter
                          Padding(
                            padding: EdgeInsets.all(16),
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
                                SizedBox(width: 8),
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
                                            padding: EdgeInsets.all(4),
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
                                            context.read<LanguageProvider>(),
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
                                    SizedBox(width: 8),
                                    InkWell(
                                      onTap: _clearAllFilters,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: EdgeInsets.all(8),
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
                            SizedBox(height: 8),
                          ],

                          if (filteredJenisPembayaran.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Text(
                                    '${filteredJenisPembayaran.length} jenis pembayaran ditemukan',
                                    style: TextStyle(
                                      color: ColorUtils.slate600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: 4),
                          Expanded(
                            child: filteredJenisPembayaran.isEmpty
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
                                    itemCount: filteredJenisPembayaran.length,
                                    itemBuilder: (context, index) {
                                      return _buildJenisPembayaranCard(
                                        filteredJenisPembayaran[index],
                                        index,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),

                      // Tab Verifikasi
                      _pembayaranPendingList.isEmpty
                          ? EmptyState(
                              title: 'Tidak ada pembayaran menunggu verifikasi',
                              subtitle: 'Semua pembayaran telah diverifikasi',
                              icon: Icons.verified_user,
                            )
                          : ListView.builder(
                              controller: _pendingScrollController,
                              physics: AlwaysScrollableScrollPhysics(),
                              itemCount:
                                  _pembayaranPendingList.length +
                                  (_hasMorePending ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _pembayaranPendingList.length) {
                                  return Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                return _buildPembayaranPendingCard(
                                  _pembayaranPendingList[index],
                                  index,
                                );
                              },
                            ),
                      _buildLaporanKelasTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: _getFloatingActionButton(),
        );
      },
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
        'badge': _totalPembayaranPending,
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
                    SizedBox(height: 4),
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
            SizedBox(width: 8),
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
      padding: EdgeInsets.all(16),
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
              SizedBox(width: 12),
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
                      '${_pembayaranPendingList.length} ${languageProvider.getTranslatedText({'en': 'payments need verification', 'id': 'pembayaran perlu diverifikasi'})}',
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
                  '${_pembayaranPendingList.length}',
                  style: TextStyle(
                    color: ColorUtils.warning600,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!Provider.of<AcademicYearProvider>(
            context,
            listen: false,
          ).isReadOnly) ...[
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
    Map<String, dynamic> pembayaran,
    int index,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showVerifikasiDialog(pembayaran),
          child: Container(
            padding: EdgeInsets.all(16),
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
                          (pembayaran['siswa_nama'] ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.getColorForIndex(index),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pembayaran['siswa_nama'] ?? '-',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kelas ${pembayaran['kelas_nama'] ?? '-'}',
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
                          SizedBox(width: 4),
                          Text(
                            pembayaran['jenis_pembayaran_nama'] ?? '-',
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
                          SizedBox(width: 4),
                          Text(
                            _formatCurrency(pembayaran['amount']),
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
                          SizedBox(width: 4),
                          Text(
                            pembayaran['payment_date']?.split('T')[0] ?? '-',
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
                if (pembayaran['payment_receipt'] != null) ...[
                  SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showBuktiPembayaran(pembayaran),
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
                if (!Provider.of<AcademicYearProvider>(
                  context,
                  listen: false,
                ).isReadOnly) ...[
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showVerifikasiDialog(pembayaran),
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
    if (Provider.of<AcademicYearProvider>(context).isReadOnly) return null;

    if (_currentTabIndex == 1) {
      // Tab Jenis Pembayaran
      return FloatingActionButton(
        onPressed: () => _showAddEditJenisPembayaran(),
        backgroundColor: _getPrimaryColor(),
        child: Icon(Icons.add, color: Colors.white),
      );
    }

    return null;
  }

  // Restored methods needed by other dialogs
  void _showBuktiPembayaran(Map<String, dynamic> pembayaran) {
    final imageFile =
        pembayaran['payment_proof'] ?? pembayaran['payment_receipt'];

    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak ada bukti pembayaran'),
          backgroundColor: ColorUtils.warning600,
        ),
      );
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
                padding: EdgeInsets.all(16),
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
                    SizedBox(width: 8),
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
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Image
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
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
                            SizedBox(height: 8),
                            Text(
                              'Gagal memuat gambar',
                              style: TextStyle(color: ColorUtils.error600),
                            ),
                            SizedBox(height: 8),
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
                padding: EdgeInsets.all(16),
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
                    SizedBox(height: 8),
                    _buildInfoRow('Siswa', pembayaran['siswa_nama'] ?? '-'),
                    _buildInfoRow('Kelas', pembayaran['kelas_nama'] ?? '-'),
                    _buildInfoRow(
                      'Jenis',
                      pembayaran['jenis_pembayaran_nama'] ?? '-',
                    ),
                    _buildInfoRow(
                      'Jumlah',
                      _formatCurrency(pembayaran['amount']),
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

    final languageProvider = context.read<LanguageProvider>();
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
