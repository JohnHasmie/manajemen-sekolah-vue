// Parent billing / payment screen for school fees.
// Like `pages/parent/Billing.vue` in a Vue app.
//
// Displays a list of billing items per student with status tracking
// (unpaid/pending/verified), payment upload with image/PDF, search,
// filter, pagination, and read tracking. Parents can upload payment
// proof and view payment details.
// In Laravel terms: `BillingController@index` + `PaymentController@store`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Parent billing screen with payment status, upload, and filtering.
///
/// A StatefulWidget with no constructor params -- reads parent/student data
/// from SharedPreferences. Supports multiple children (student selector).
class ParentBillingScreen extends ConsumerStatefulWidget {
  const ParentBillingScreen({super.key});

  @override
  ParentBillingScreenState createState() => ParentBillingScreenState();
}

/// State for [ParentBillingScreen].
///
/// Like a Vue page component with `data() { return {...} }`. Key state:
/// - [_billingList] -- billing items from API
/// - [_students] / [_selectedStudentId] -- child selector (for parents with multiple kids)
/// - [_processedIds] / [_pendingReadIds] -- read tracking (like announcement screen)
/// - Pagination, search, and filter state
///
/// `setState()` is like Vue's reactivity -- triggers a re-render.
class ParentBillingScreenState extends ConsumerState<ParentBillingScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _billingList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Pagination
  final ScrollController _scrollController = ScrollController();
  // int _currentPage = 1; // Unused
  // final int _perPage = 10; // Unused
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  // Map<String, dynamic>? _paginationMeta; // Unused

  // Student list
  List<Student> _students = [];
  String? _selectedStudentId;
  Student? _selectedStudent;

  // Track processed and pending read IDs
  final Set<String> _processedIds = {};
  final Set<String> _pendingReadIds = {};
  Timer? _markReadTimer;

  // Search and Enhanced Filters
  final TextEditingController _searchController = TextEditingController();

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
      return 'Rp $amount';
    }
  }

  String? _selectedStatusFilter; // 'unpaid', 'pending', 'verified'
  String? _selectedPeriodeFilter; // 'bulanan', 'tahunan'
  bool _hasActiveFilter = false;

  File? selectedFile;

  String? _tourId;
  final GlobalKey _studentSelectorKey = GlobalKey();
  final GlobalKey _billingListKey = GlobalKey();

  /// Like Vue's `mounted()` -- sets up infinite scroll and loads initial data.
  @override
  void initState() {
    super.initState();

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    _loadInitialData();
  }

  @override
  void dispose() {
    // Flush pending read IDs before departing
    if (_pendingReadIds.isNotEmpty) {
      final idsToMark = List<String>.from(_pendingReadIds);
      _pendingReadIds.clear();
      _markAsReadBulk(idsToMark);
    }
    _markReadTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _buildStudentsCacheKey() {
    return 'parent_billing_students';
  }

  String _buildBillingCacheKey() {
    return 'parent_billing_list_${_selectedStudentId ?? "unknown"}';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('parent_billing_');
    await LocalCacheService.clearStartingWith('tour_parent_billing_');
    _loadInitialData(useCache: false);
  }

  Future<void> _loadData() async {
    await _loadInitialData();
  }

  /// Loads parent profile and student list, then fetches billing data.
  /// Like a Vue `mounted()` that chains several async API calls.
  Future<void> _loadInitialData({bool useCache = true}) async {
    // Step 1: Try cache — return early on hit
    if (useCache) {
      final studentsCacheKey = _buildStudentsCacheKey();
      final cachedStudents = await LocalCacheService.load(studentsCacheKey, ttl: const Duration(hours: 6));
      if (cachedStudents != null && cachedStudents is List && cachedStudents.isNotEmpty) {
        if (!mounted) return;
        final parsedStudents = cachedStudents.map((s) => Student.fromJson(s)).toList();
        setState(() {
          _students = parsedStudents;
          if (_selectedStudentId == null && _students.isNotEmpty) {
            _selectedStudentId = _students[0].id;
            _selectedStudent = _students[0];
          }
          _isLoading = false;
          _errorMessage = '';
        });
        // Load cached billing then return early
        await _loadTagihan(useCache: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _students.isNotEmpty) _checkAndShowTour();
        });
        return;
      }
    }

    // Step 2: Show skeleton only if list is empty
    if (_students.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    // Step 3: Fetch fresh from API
    try {
      final prefs = PreferencesService();
      final userString = prefs.getString('user');
      if (userString == null) throw Exception('User not logged in');
      final userData = json.decode(userString);
      final userId = userData['id'].toString();
      final guardianEmail = userData['email'];

      final allStudents = await getIt<ApiStudentService>().getStudent(
        userId: userId,
        guardianEmail: guardianEmail,
      );

      List<dynamic> filteredStudents = [];

      if (userData['siswa_id'] != null && userData['siswa_id'].isNotEmpty) {
        final student = allStudents.firstWhere(
          (student) => student['id'] == userData['siswa_id'],
          orElse: () => null,
        );
        if (student != null) {
          filteredStudents = [student];
        }
      }

      if (filteredStudents.isEmpty) {
        filteredStudents = allStudents.where((student) {
          final emailMatch = student['guardian_email'] == userData['email'];
          final nameMatch = student['guardian_name'] == userData['name'];
          final userIdMatch = student['user_id'].toString() == userId;
          return emailMatch || nameMatch || userIdMatch;
        }).toList();
      }

      if (!mounted) return;

      // Save students to cache (non-blocking)
      LocalCacheService.save(_buildStudentsCacheKey(), filteredStudents);

      if (filteredStudents.isNotEmpty) {
        _students = filteredStudents.map((s) => Student.fromJson(s)).toList();

        if (_selectedStudentId == null && _students.isNotEmpty) {
          _selectedStudentId = _students[0].id;
          _selectedStudent = _students[0];
        }
      }

      await _loadTagihan(useCache: false);

      setState(() {
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (error) {
      AppLogger.error('finance', error);
      if (!mounted) return;
      // Only show error if no cached data
      if (_students.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(error);
        });
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _students.isNotEmpty) _checkAndShowTour();
      });
    }
  }

  Future<void> _checkAndShowTour() async {
    try {
      // Cache-only: tour status pre-fetched from dashboard
      const tourCacheKey = 'tour_parent_billing_screen_wali';
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id'];
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
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_parent_billing_screen_wali', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_parent_billing_screen_wali', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "StudentSelector",
        keyTarget: _studentSelectorKey,
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
                      'en': 'Select Child',
                      'id': 'Pilih Anak',
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
                            'Select your child to view their billings and payments.',
                        'id':
                            'Pilih anak Anda untuk melihat tagihan dan pembayaran mereka.',
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
        identify: "BillingList",
        keyTarget: _billingListKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
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
                      'en': 'Billing List',
                      'id': 'Daftar Tagihan',
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
                            'See your child\'s bill status here, pay bills, and view history.',
                        'id':
                            'Lihat status tagihan anak Anda di sini, bayar tagihan, dan lihat riwayat.',
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

  Future<void> _loadTagihan({bool useCache = true}) async {
    if (_selectedStudentId == null) return;

    final cacheKey = _buildBillingCacheKey();

    // Step 1: Try cache — return early on hit
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 3));
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _billingList = List<dynamic>.from(cached);
        });
        // Mark read only if there are unread items
        _markBillReadIfNeeded();
        return;
      }
    }

    // Step 2: Fetch fresh from API
    try {
      final response = await _apiService.get(
        '/bill/parent',
        params: {'student_id': _selectedStudentId},
      );
      if (!mounted) return;

      final freshList = response is List ? response : [];
      // Non-blocking save
      LocalCacheService.save(cacheKey, freshList);

      setState(() {
        _billingList = freshList;
      });

      // Mark read only if there are unread items
      _markBillReadIfNeeded();
    } catch (error) {
      AppLogger.error('finance', error);
    }
  }

  void _markBillReadIfNeeded() {
    if (_selectedStudentId == null) return;
    final hasUnread = _billingList.any((b) =>
        b['is_read'] != true && b['is_read'] != 1 && b['is_read'] != '1');
    if (hasUnread) {
      ApiService.markBillRead(studentId: _selectedStudentId!);
    }
  }

  void _scheduleMarkRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingReadIds.isNotEmpty) {
        final idsToMark = List<String>.from(_pendingReadIds);
        _pendingReadIds.clear();
        _markAsReadBulk(idsToMark);
      }
    });
  }

  Future<void> _markAsReadBulk(List<String> ids) async {
    if (_selectedStudentId == null) return;

    // Optimistic Update
    if (mounted) {
      setState(() {
        for (var item in _billingList) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });
    }

    try {
      await ApiService.markBillRead(
        studentId: _selectedStudentId!,
        billIds: ids,
      );
    } catch (e) {
      AppLogger.error('finance', e);
    }
  }

  void _onItemVisible(String id, bool isRead) {
    if (!isRead && !_processedIds.contains(id)) {
      _processedIds.add(id);
      _pendingReadIds.add(id);
      _scheduleMarkRead();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreTagihan();
      }
    }
  }

  Future<void> _loadMoreTagihan() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // _currentPage++;
      // For now, since backend might not support pagination,
      // we'll just mark hasMoreData as false
      setState(() {
        _hasMoreData = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('finance', e);
      setState(() {
        _isLoadingMore = false;
      });
      if (mounted) {
                SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
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
    _loadData();
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedStatusFilter != null) {
      String statusText;
      switch (_selectedStatusFilter) {
        case 'unpaid':
          statusText = languageProvider.getTranslatedText({
            'en': 'Unpaid',
            'id': 'Belum Bayar',
          });
          break;
        case 'pending':
          statusText = languageProvider.getTranslatedText({
            'en': 'Pending',
            'id': 'Pending',
          });
          break;
        case 'verified':
          statusText = languageProvider.getTranslatedText({
            'en': 'Verified',
            'id': 'Lunas',
          });
          break;
        default:
          statusText = _selectedStatusFilter!;
      }
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
        'label': '${AppLocalizations.paymentPeriod.tr}: $periodeText',
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorUtils.slate700),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    final primaryColor = _getPrimaryColor();
    String? tempSelectedStatus = _selectedStatusFilter;
    String? tempSelectedPeriode = _selectedPeriodeFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Gradient header
              Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.filter.tr,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempSelectedStatus = null;
                              tempSelectedPeriode = null;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              AppLocalizations.reset.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Filter Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        AppLocalizations.paymentStatus.tr,
                        Icons.check_circle_outline_rounded,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              {
                                'value': 'unpaid',
                                'label': AppLocalizations.unpaid.tr,
                              },
                              {
                                'value': 'pending',
                                'label': AppLocalizations.pending.tr,
                              },
                              {
                                'value': 'verified',
                                'label': AppLocalizations.paid.tr,
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
                                selectedColor: primaryColor.withValues(
                                  alpha: 0.15,
                                ),
                                checkmarkColor: primaryColor,
                                side: BorderSide(
                                  color: isSelected
                                      ? primaryColor
                                      : ColorUtils.slate300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? primaryColor
                                      : ColorUtils.slate700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              );
                            }).toList(),
                      ),
                      _buildSectionHeader(
                        AppLocalizations.paymentPeriod.tr,
                        Icons.date_range_rounded,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              {
                                'value': 'bulanan',
                                'label': AppLocalizations.monthly.tr,
                              },
                              {
                                'value': 'tahunan',
                                'label': AppLocalizations.yearly.tr,
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
                                selectedColor: primaryColor.withValues(
                                  alpha: 0.15,
                                ),
                                checkmarkColor: primaryColor,
                                side: BorderSide(
                                  color: isSelected
                                      ? primaryColor
                                      : ColorUtils.slate300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? primaryColor
                                      : ColorUtils.slate700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                ),
                child: SafeArea(
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
                            AppLocalizations.cancel.tr,
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
                          onPressed: () {
                            setState(() {
                              _selectedStatusFilter = tempSelectedStatus;
                              _selectedPeriodeFilter = tempSelectedPeriode;
                            });
                            _checkActiveFilter();
                            AppNavigator.pop(context);
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.apply.tr,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dalam tagihan_wali.dart - Perbaiki _pickImage
  Future<void> _pickImage(StateSetter setDialogState) async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show option to choose from gallery or camera
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.chooseSource.tr),
          content: Text(AppLocalizations.chooseImageSource.tr),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context, ImageSource.gallery),
              child: Text(AppLocalizations.gallery.tr),
            ),
            TextButton(
              onPressed: () => AppNavigator.pop(context, ImageSource.camera),
              child: Text(AppLocalizations.camera.tr),
            ),
          ],
        ),
      );

      if (source != null) {
        final XFile? file = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (file != null && context.mounted) {
          // Validasi yang lebih ketat
          final allowedExtensions = ['.jpg', '.jpeg', '.png'];
          final filePath = file.path.toLowerCase();

          bool isValidFile = allowedExtensions.any(
            (ext) => filePath.endsWith(ext),
          );

          if (!isValidFile) {
            if (context.mounted) {
                            SnackBarUtils.showError(context, AppLocalizations.unsupportedFileFormat.tr);
            }
            return;
          }

          setDialogState(() {
            selectedFile = File(file.path);
          });

          AppLogger.debug('finance', 'File selected: ${file.path}');
        }
      }
    } catch (e) {
      AppLogger.error('finance', e);
      if (context.mounted) {
                SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  // Tambahkan method ini di tagihan_wali.dart
  Future<void> _pickPDF(StateSetter setDialogState) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        setDialogState(() {
          selectedFile = file;
        });

        AppLogger.debug('finance', 'PDF selected: ${file.path}');
      }
    } catch (e) {
      AppLogger.error('finance', e);
      if (context.mounted) {
                SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _pickFile(StateSetter setDialogState) async {
    try {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.chooseFileType.tr),
          content: Text(AppLocalizations.uploadPaymentProof.tr),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context, 'image'),
              child: Text(AppLocalizations.imageCameraGallery.tr),
            ),
            TextButton(
              onPressed: () => AppNavigator.pop(context, 'pdf'),
              child: Text(AppLocalizations.pdfDocument.tr),
            ),
          ],
        ),
      );

      if (action == 'image') {
        await _pickImage(setDialogState);
      } else if (action == 'pdf') {
        await _pickPDF(setDialogState);
      }
    } catch (e) {
      AppLogger.error('finance', e);
      if (context.mounted) {
                SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  List<dynamic> _getFilteredBilling() {
    return _billingList.where((item) {
      final searchTerm = _searchController.text.toLowerCase();
      final name =
          item['jenis_pembayaran_nama']?.toString().toLowerCase() ?? '';
      final description =
          item['jenis_pembayaran_deskripsi']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          name.contains(searchTerm) ||
          description.contains(searchTerm);

      // Status filter matching
      final matchesStatus =
          _selectedStatusFilter == null ||
          (_selectedStatusFilter == 'unpaid' && item['status'] == 'unpaid') ||
          (_selectedStatusFilter == 'pending' &&
              item['pembayaran_status'] == 'pending') ||
          (_selectedStatusFilter == 'verified' &&
              (item['status'] == 'verified' ||
                  item['pembayaran_status'] == 'verified'));

      // Period filter matching
      final matchesPeriode =
          _selectedPeriodeFilter == null ||
          item['periode']?.toString().toLowerCase() == _selectedPeriodeFilter;

      return matchesSearch && matchesStatus && matchesPeriode;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'verified':
        return ColorUtils.success600;
      case 'pending':
        return ColorUtils.warning600;
      case 'rejected':
        return ColorUtils.error600;
      default:
        return ColorUtils.slate400;
    }
  }

  String _getStatusText(Map<String, dynamic> billing) {
    if (billing['pembayaran_status'] == 'verified') {
      return AppLocalizations.paid.tr;
    } else if (billing['pembayaran_status'] == 'pending') {
      return AppLocalizations.waitingForVerification.tr;
    } else if (billing['pembayaran_status'] == 'rejected') {
      return AppLocalizations.rejected.tr;
    } else {
      return AppLocalizations.unpaid.tr;
    }
  }

  String _getFileTypeText(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'Gambar JPEG';
      case 'png':
        return 'Gambar PNG';
      case 'pdf':
        return 'Dokumen PDF';
      default:
        return 'File $extension';
    }
  }

  void _showUploadPaymentDialog(Map<String, dynamic> billing) {
    final primaryColor = _getPrimaryColor();
    final paymentMethodController = TextEditingController();
    final amountController = TextEditingController(
      text: billing['jumlah'] != null
          ? _formatCurrency(billing['jumlah']).replaceAll('Rp ', '')
          : '',
    );
    final paymentDateController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Gradient header
              Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.upload_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.uploadPaymentProof.tr,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                billing['jenis_pembayaran_nama'] ?? '-',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Informasi Tagihan
                      _buildSectionHeader(
                        'Informasi Tagihan',
                        Icons.receipt_long_rounded,
                      ),
                      _buildDetailRow(
                        Icons.receipt_long_rounded,
                        AppLocalizations.paymentTypes.tr,
                        billing['jenis_pembayaran_nama'] ?? '-',
                      ),
                      _buildDetailRow(
                        Icons.attach_money_rounded,
                        AppLocalizations.billAmount.tr,
                        _formatCurrency(billing['jumlah']),
                        iconColor: primaryColor,
                      ),
                      _buildDetailRow(
                        Icons.person_rounded,
                        AppLocalizations.student.tr,
                        billing['siswa_nama'] ?? '-',
                      ),
                      _buildDetailRow(
                        Icons.school_rounded,
                        AppLocalizations.classString.tr,
                        billing['kelas_nama'] ?? '-',
                      ),

                      // Section: Form Pembayaran
                      _buildSectionHeader(
                        'Form Pembayaran',
                        Icons.edit_note_rounded,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethodController.text.isNotEmpty
                            ? paymentMethodController.text
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Metode Pembayaran',
                          labelStyle: TextStyle(
                            color: ColorUtils.slate600,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.payment_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ColorUtils.slate200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ColorUtils.slate200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          filled: true,
                          fillColor: ColorUtils.slate50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Transfer Bank',
                            child: Text('Transfer Bank'),
                          ),
                          DropdownMenuItem(
                            value: 'Tunai',
                            child: Text('Tunai'),
                          ),
                          DropdownMenuItem(
                            value: 'Kartu Kredit/Debit',
                            child: Text('Kartu Kredit/Debit'),
                          ),
                          DropdownMenuItem(
                            value: 'Lainnya',
                            child: Text('Lainnya'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            paymentMethodController.text = value;
                          }
                        },
                      ),
                      SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: amountController,
                        label: 'Jumlah Bayar',
                        icon: Icons.attach_money_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12),
                      _buildDialogTextField(
                        controller: paymentDateController,
                        label: 'Tanggal Bayar',
                        icon: Icons.calendar_today_rounded,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            paymentDateController.text = date.toString().split(
                              ' ',
                            )[0];
                          }
                        },
                      ),

                      // Section: Bukti Pembayaran
                      _buildSectionHeader(
                        'Bukti Pembayaran',
                        Icons.cloud_upload_rounded,
                      ),
                      GestureDetector(
                        onTap: () => _pickFile(setDialogState),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedFile != null
                                ? ColorUtils.success600.withValues(alpha: 0.04)
                                : ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedFile != null
                                  ? ColorUtils.success600.withValues(alpha: 0.4)
                                  : ColorUtils.slate200,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: selectedFile != null
                                      ? ColorUtils.success600.withValues(
                                          alpha: 0.1,
                                        )
                                      : primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  selectedFile != null
                                      ? Icons.check_circle_rounded
                                      : Icons.upload_file_rounded,
                                  color: selectedFile != null
                                      ? ColorUtils.success600
                                      : primaryColor,
                                  size: 24,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                selectedFile != null
                                    ? selectedFile!.path.split('/').last
                                    : 'Pilih bukti pembayaran',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selectedFile != null
                                      ? ColorUtils.success600
                                      : ColorUtils.slate700,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              if (selectedFile != null)
                                Text(
                                  _getFileTypeText(selectedFile!.path),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: ColorUtils.slate500,
                                  ),
                                ),
                              if (selectedFile == null)
                                Text(
                                  'Format: JPG, JPEG, PNG, PDF',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: ColorUtils.slate400,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                ),
                child: SafeArea(
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
                            AppLocalizations.cancel.tr,
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
                          onPressed:
                              selectedFile == null ||
                                  paymentMethodController.text.isEmpty ||
                                  amountController.text.isEmpty ||
                                  paymentDateController.text.isEmpty
                              ? null
                              : () async {
                                  // Frontend guard: prevent overpayment
                                  final enteredAmount = double.tryParse(
                                    amountController.text
                                        .replaceAll('.', '')
                                        .replaceAll(',', ''),
                                  );
                                  final billAmount =
                                      double.tryParse(
                                        billing['jumlah']?.toString() ?? '0',
                                      ) ??
                                      0;

                                  if (enteredAmount == null ||
                                      enteredAmount <= 0) {
                                                                        SnackBarUtils.showError(context, 'Jumlah bayar tidak valid');
                                    return;
                                  }

                                  if (enteredAmount > billAmount) {
                                                                        SnackBarUtils.showError(context, 'Jumlah bayar tidak boleh melebihi total tagihan (${_formatCurrency(billing['jumlah'])})');
                                    return;
                                  }
                                  try {
                                    await _uploadPayment(
                                      billingId: billing['id'],
                                      paymentMethod:
                                          paymentMethodController.text,
                                      amount: enteredAmount,
                                      paymentDate: paymentDateController.text,
                                      file: selectedFile!,
                                    );

                                    if (context.mounted) {
                                      AppNavigator.pop(context);
                                      _loadData();

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Bukti pembayaran berhasil diupload',
                                          ),
                                          backgroundColor:
                                              ColorUtils.success600,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ErrorUtils.getFriendlyMessage(
                                              error,
                                            ),
                                          ),
                                          backgroundColor: ColorUtils.error600,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Upload',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDetailDialog(Map<String, dynamic> billing) {
    final payment = billing['latest_payment'];
    if (payment == null) return;
    final primaryColor = _getPrimaryColor();
    final statusColor = _getStatusColor(
      billing['pembayaran_status'] ?? billing['status'],
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.75),
                    ],
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
                        Icons.receipt_long_rounded,
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
                            'Detail Pembayaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            billing['jenis_pembayaran_nama'] ?? '-',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
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
                  children: [
                    _buildDetailRow(
                      Icons.info_outline_rounded,
                      'Status',
                      _getStatusText(billing),
                      iconColor: statusColor,
                    ),
                    _buildDetailRow(
                      Icons.payment_rounded,
                      'Metode Pembayaran',
                      payment['payment_method'] ?? '-',
                    ),
                    _buildDetailRow(
                      Icons.calendar_today_rounded,
                      'Tanggal Bayar',
                      payment['payment_date'] ?? '-',
                    ),
                    _buildDetailRow(
                      Icons.attach_money_rounded,
                      'Jumlah Dibayar',
                      _formatCurrency(payment['amount']),
                      iconColor: primaryColor,
                    ),

                    if (payment['payment_receipt'] != null) ...[
                      SizedBox(height: 8),
                      Divider(color: ColorUtils.slate200),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.image_rounded,
                              size: 18,
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Bukti Pembayaran',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          '${ApiService.baseUrl.replaceAll('/api', '')}/storage/${payment['payment_receipt']}',
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: ColorUtils.slate100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_rounded,
                                      color: ColorUtils.slate400,
                                      size: 40,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Gagal memuat gambar',
                                      style: TextStyle(
                                        color: ColorUtils.slate500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Footer
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                ),
                child: SizedBox(
                  width: double.infinity,
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
                      AppLocalizations.close.tr,
                      style: TextStyle(
                        color: ColorUtils.slate700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Uploads payment proof (image/PDF) to the API.
  /// Like `axios.post('/api/billing/{id}/payment', formData)` in Vue
  /// with multipart file upload. In Laravel: `PaymentController@store`.
  Future<void> _uploadPayment({
    required String billingId,
    required String paymentMethod,
    required double amount,
    required String paymentDate,
    required File file,
  }) async {
    try {
      // Validasi file type sebelum upload
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.pdf'];
      final filePath = file.path.toLowerCase();

      if (!allowedExtensions.any((ext) => filePath.endsWith(ext))) {
        throw Exception(
          'Format file tidak didukung. Gunakan JPG, JPEG, PNG, atau PDF.',
        );
      }

      // print('=== UPLOAD DEBUG INFO ===');
      // print('File path: ${file.path}');
      // print('File extension: $fileExtension');
      // print('File size: ${await file.length()} bytes');
      // print('Tagihan ID: $billingId');
      // print('Metode Bayar: $metodeBayar');
      // print('Jumlah Bayar: $jumlahBayar');
      // print('Tanggal Bayar: $tanggalBayar');
      // print('========================');

      // Upload file menggunakan multipart
      await _apiService.uploadFile(
        '/payments',
        file,
        fileField: 'payment_receipt',
        data: {
          'bill_id': billingId,
          'payment_method': paymentMethod,
          'amount': amount.toString(),
          'payment_date': paymentDate,
        },
      );
    } catch (error) {
      AppLogger.error('finance', error);
      rethrow;
    }
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    final primaryColor = _getPrimaryColor();
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onTap: onTap,
        readOnly: onTap != null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate600, fontSize: 14),
          hintText: hint,
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    final c = iconColor ?? ColorUtils.slate600;
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: c),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pattern #8 info tag chip
  Widget _buildInfoTag(IconData icon, String text, {Color? tagColor}) {
    final c = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tagColor != null
              ? tagColor.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagihanCard(Map<String, dynamic> billing, int index) {
    final status = _getStatusText(billing);
    final statusColor = _getStatusColor(
      billing['pembayaran_status'] ?? billing['status'],
    );
    final isRead =
        billing['is_read'] == true ||
        billing['is_read'] == 1 ||
        billing['is_read'] == '1' ||
        billing['is_read'] == 'true';
    final primaryColor = _getPrimaryColor();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (billing['pembayaran_status'] != 'verified' &&
                billing['pembayaran_status'] != 'pending') {
              _showUploadPaymentDialog(billing);
            } else {
              _showPaymentDetailDialog(billing);
            }
          },
          child: Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount container
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    billing['pembayaran_status'] == 'verified'
                        ? Icons.check_circle_rounded
                        : billing['pembayaran_status'] == 'pending'
                        ? Icons.hourglass_top_rounded
                        : billing['pembayaran_status'] == 'rejected'
                        ? Icons.cancel_rounded
                        : Icons.receipt_long_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              billing['jenis_pembayaran_nama'] ?? 'No Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: ColorUtils.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isRead) ...[
                            SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: ColorUtils.error600,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatCurrency(billing['jumlah']),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                      if (billing['jenis_pembayaran_deskripsi'] != null &&
                          billing['jenis_pembayaran_deskripsi']
                              .toString()
                              .isNotEmpty) ...[
                        SizedBox(height: 3),
                        Text(
                          billing['jenis_pembayaran_deskripsi'],
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.slate600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 8),
                      // Info tags
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildInfoTag(
                            Icons.check_circle_outline_rounded,
                            status,
                            tagColor: statusColor,
                          ),
                          if (billing['siswa_nama'] != null)
                            _buildInfoTag(
                              Icons.person_outlined,
                              billing['siswa_nama'],
                            ),
                          if (billing['kelas_nama'] != null)
                            _buildInfoTag(
                              Icons.school_outlined,
                              billing['kelas_nama'],
                            ),
                          if (billing['jatuh_tempo'] != null)
                            _buildInfoTag(
                              Icons.calendar_today_outlined,
                              billing['jatuh_tempo']?.split('T')[0] ?? '-',
                            ),
                        ],
                      ),
                      // Rejected notes
                      if (billing['pembayaran_status'] == 'rejected' &&
                          billing['admin_notes'] != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ColorUtils.error600.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ColorUtils.error600.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: ColorUtils.error600,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  billing['admin_notes'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ColorUtils.error600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Pay now button
                      if (billing['pembayaran_status'] != 'verified' &&
                          billing['pembayaran_status'] != 'pending') ...[
                        SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.upload_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  AppLocalizations.payNow.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('wali');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.85)],
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
    final primaryColor = _getPrimaryColor();
    final unreadCount = _billingList.where((b) => b['is_read'] == false).length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
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
              GestureDetector(
                onTap: () => AppNavigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          AppLocalizations.myBills.tr,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: EdgeInsets.only(left: 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      _selectedStudent != null
                          ? _selectedStudent!.name
                          : AppLocalizations.selectChild.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (_students.length > 1)
                GestureDetector(
                  key: _studentSelectorKey,
                  onTap: () => _showStudentPicker(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'refresh') _forceRefresh();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                        const SizedBox(width: 8),
                        const Text('Perbarui Data'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.searchBills.tr,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _hasActiveFilter
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: _hasActiveFilter ? primaryColor : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStudentPicker() {
    final primaryColor = _getPrimaryColor();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                AppLocalizations.selectChild.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
            ..._students.map((student) {
              final isSelected = student.id == _selectedStudentId;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.1)
                        : ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: isSelected ? primaryColor : ColorUtils.slate400,
                    size: 20,
                  ),
                ),
                title: Text(
                  student.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primaryColor : ColorUtils.slate900,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: primaryColor, size: 20)
                    : null,
                onTap: () {
                  if (student.id != _selectedStudentId) {
                    setState(() {
                      _selectedStudentId = student.id;
                      _selectedStudent = student;
                      _billingList = [];
                      _processedIds.clear();
                      _pendingReadIds.clear();
                    });
                    _loadTagihan();
                  }
                  AppNavigator.pop(context);
                },
              );
            }),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
        final filteredBilling = _getFilteredBilling();

        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: Column(
            children: [
              _buildHeader(languageProvider),
              if (_hasActiveFilter)
                Container(
                  height: 50,
                  margin: EdgeInsets.only(top: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ..._buildFilterChips(languageProvider).map((filter) {
                        return Container(
                          margin: EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(
                              filter['label'],
                              style: TextStyle(
                                fontSize: 12,
                                color: _getPrimaryColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            deleteIcon: Icon(
                              Icons.close,
                              size: 16,
                              color: _getPrimaryColor(),
                            ),
                            onDeleted: filter['onRemove'],
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: _getPrimaryColor().withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }),
                      if (_hasActiveFilter)
                        Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: _clearAllFilters,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: ColorUtils.error600.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: ColorUtils.error600.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.clear_all,
                                    size: 16,
                                    color: ColorUtils.error600,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    AppLocalizations.reset.tr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ColorUtils.error600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? SkeletonListLoading(
                        itemCount: 6,
                        infoTagCount: 2,
                        baseColor: _getPrimaryColor().withValues(alpha: 0.15),
                        highlightColor: _getPrimaryColor().withValues(
                          alpha: 0.05,
                        ),
                      )
                    : _errorMessage.isNotEmpty
                    ? ErrorScreen(
                        errorMessage: _errorMessage,
                        onRetry: _loadData,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: filteredBilling.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(height: 100),
                                  EmptyState(
                                    title: 'No Bills',
                                    subtitle:
                                        _searchController.text.isEmpty &&
                                            !_hasActiveFilter
                                        ? 'All bills are paid'
                                        : 'No results found',
                                    icon: Icons.receipt,
                                  ),
                                ],
                              )
                            : ListView.builder(
                                key: _billingListKey,
                                controller: _scrollController,
                                padding: EdgeInsets.only(top: 8, bottom: 16),
                                itemCount:
                                    filteredBilling.length +
                                    (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == filteredBilling.length) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      alignment: Alignment.center,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _getPrimaryColor(),
                                            ),
                                      ),
                                    );
                                  }
                                  return Builder(
                                    builder: (context) {
                                      // Track visibility for read status
                                      final bill = filteredBilling[index];
                                      _onItemVisible(
                                        bill['id'].toString(),
                                        bill['is_read'] == true ||
                                            bill['is_read'] == 1 ||
                                            bill['is_read'] == 'true',
                                      );
                                      return _buildTagihanCard(
                                        filteredBilling[index],
                                        index,
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        );
  }
}
