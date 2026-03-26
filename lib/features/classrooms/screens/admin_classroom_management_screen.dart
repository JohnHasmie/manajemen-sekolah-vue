// Admin class management screen - full CRUD for school classes.
//
// Like `pages/admin/classes.vue` - manages school classes (create, edit, delete)
// with homeroom teacher assignment, student listing, and class promotion.
// Supports infinite scroll pagination, search, filtering, Excel import/export.
//
// In Laravel terms, this consumes ClassController (GET/POST/PUT/DELETE /api/classes).
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/classrooms/screens/class_promotion_wizard.dart';
import 'package:manajemensekolah/features/students/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/classrooms/services/classroom_service.dart';
import 'package:manajemensekolah/features/settings/services/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/classrooms/exports/classroom_export_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Admin class management screen with full CRUD, search, filters, and Excel import/export.
///
/// This is a [StatefulWidget] - like a Vue page component with local state for
/// class list, pagination, filters, and FAB (Floating Action Button) animations.
class AdminClassManagementScreen extends ConsumerStatefulWidget {
  const AdminClassManagementScreen({super.key});

  @override
  AdminClassManagementScreenState createState() =>
      AdminClassManagementScreenState();
}

/// Mutable state for [AdminClassManagementScreen].
///
/// Key state (like Vue `data()`):
/// - [_classes] / [_teachers] - data lists from API
/// - [_currentPage] / [_hasMoreData] / [_isLoadingMore] - infinite scroll pagination
/// - [_selectedGradeFilter] / [_selectedHomeroomFilter] - filter state
/// - [_isFabOpen] - animated FAB menu state (add class, import Excel, promote)
///
/// Uses [SingleTickerProviderStateMixin] for FAB animation (like Vue `<transition>`).
/// Listens to FCM sync triggers for real-time updates from other users.
class AdminClassManagementScreenState extends ConsumerState<AdminClassManagementScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _classes = [];
  List<dynamic> _teachers = [];
  bool _isLoading = true;
  String? _errorMessage;

  // FAB Animation
  late AnimationController _fabAnimationController;
  late Animation<double> _fabRotateAnimation;
  late Animation<double> _fabScaleAnimation;
  bool _isFabOpen = false;

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Filter States (Backend filtering)
  String? _selectedGradeFilter; // '1' to '12', or null for all
  String? _selectedHomeroomFilter; // 'true', 'false', or null
  bool _hasActiveFilter = false;

  // Tour Keys
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  String? _tourId;

  // Filter Options (from backend)
  final List<String> _availableGradeLevels = [];
  String? _schoolJenjang; // SD, SMP, or SMA

  // Search debounce removed

  /// Like Vue's `mounted()` lifecycle hook.
  /// Sets up FAB animations, scroll listener for infinite scroll,
  /// FCM sync listener, and loads initial data (school settings, teachers, classes).
  @override
  void initState() {
    super.initState();

    // FAB Init
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _fabRotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // Listen to search changes with debounce - Removed to match StudentManagement
    // _searchController.addListener(_onSearchChanged);

    // Listen to sync triggers from FCM
    FCMService().syncTrigger.addListener(_onSyncTriggered);

    _loadSchoolSettings(); // Load dynamic grade levels
    _fetchTeachers();
    _loadData();
  }

  /// Like Vue's `beforeUnmount()` - cleans up listeners, controllers, and timers.
  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _fabAnimationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    // _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null &&
        (trigger['type'] == 'refresh_classes' ||
            trigger['type'] == 'refresh_teachers')) {
      AppLogger.debug('classroom', 'Real-time sync triggered (${trigger['type']}): Reloading classes',);
      _loadData(resetPage: true, useCache: false);
    }
  }

  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // 200px before bottom
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadSchoolSettings() async {
    try {
      // ─── Cache-first: return early on hit ───
      const cacheKey = 'school_settings';
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 24),
        );
        if (cached != null && mounted) {
          setState(() {
            _schoolJenjang = cached['jenjang'];
            _generateGradeLevels();
          });
          AppLogger.info('classroom', 'School settings loaded from cache');
          return;
        }
      } catch (e) {
        AppLogger.error('classroom', 'School settings cache load failed: $e');
      }

      final settings = await getIt<ApiSettingsService>().getSchoolSettings();
      if (!mounted) return;

      setState(() {
        _schoolJenjang = settings['jenjang'];
        _generateGradeLevels();
      });
      // Non-blocking cache save
      LocalCacheService.save(cacheKey, settings);
    } catch (e) {
      AppLogger.error('classroom', 'Error loading school settings: $e');
      // Fallback if failed
      setState(() {
        _generateGradeLevels();
      });
    }
  }

  void _generateGradeLevels() {
    _availableGradeLevels.clear();
    int start = 1;
    int end = 12;

    if (_schoolJenjang != null) {
      final jenjang = _schoolJenjang!.toUpperCase();
      if (jenjang == 'SD') {
        start = 1;
        end = 6;
      } else if (jenjang == 'SMP') {
        start = 7;
        end = 9;
      } else if (jenjang == 'SMA' || jenjang == 'SMK') {
        start = 10;
        end = 12;
      }
    }

    for (int i = start; i <= end; i++) {
      _availableGradeLevels.add(i.toString());
    }
  }

  Future<void> _fetchTeachers() async {
    try {
      // ─── Cache-first: return early on hit ───
      const cacheKey = 'teachers_all_list';
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null && mounted) {
          setState(() {
            _teachers = List<dynamic>.from(cached);
          });
          AppLogger.info('classroom', 'Teachers list loaded from cache (${_teachers.length})');
          return;
        }
      } catch (e) {
        AppLogger.error('classroom', 'Teachers list cache load failed: $e');
      }

      // Fetch all teachers (limit 1000) to ensure we have the homeroom teacher in the list
      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        limit: 1000,
      );
      if (!mounted) return;

      setState(() {
        _teachers = response['data'] ?? [];
      });
      // Non-blocking cache save
      LocalCacheService.save(cacheKey, response['data'] ?? []);
      AppLogger.info('classroom', 'Loaded ${_teachers.length} teachers for wali kelas selection');
    } catch (e) {
      AppLogger.error('classroom', 'Error loading teachers: $e');
      // Continue with empty list - not critical error
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedGradeFilter != null || _selectedHomeroomFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedGradeFilter = null;
      _selectedHomeroomFilter = null;
      _searchController.clear();
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData(); // Reload data setelah clear filters
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedGradeFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})}: $_selectedGradeFilter',
        'onRemove': () {
          setState(() {
            _selectedGradeFilter = null;
          });
          _checkActiveFilter();
          _loadData(); // Reload data setelah remove filter
        },
      });
    }

    if (_selectedHomeroomFilter != null) {
      String label;
      if (_selectedHomeroomFilter == 'true') {
        label = languageProvider.getTranslatedText({
          'en': 'Has Homeroom Teacher',
          'id': 'Sudah Ada Wali Kelas',
        });
      } else {
        label = languageProvider.getTranslatedText({
          'en': 'No Homeroom Teacher',
          'id': 'Belum Ada Wali Kelas',
        });
      }

      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedHomeroomFilter = null;
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
    String? tempSelectedClass = _selectedGradeFilter;
    String? tempSelectedHomeroom = _selectedHomeroomFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Gradient header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColorUtils.corporateBlue600,
                      ColorUtils.corporateBlue600.withValues(alpha: 0.8),
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
                        Icon(
                          Icons.filter_list_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Filter Classes',
                            'id': 'Filter Kelas',
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
                          tempSelectedClass = null;
                          tempSelectedHomeroom = null;
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
              // Filter content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grade filter section
                      Row(
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            size: 16,
                            color: ColorUtils.slate600,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Grade Level',
                              'id': 'Tingkat Kelas',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableGradeLevels.map((gradeLevel) {
                          final isSelected = tempSelectedClass == gradeLevel;
                          return FilterChip(
                            label: Text(gradeLevel),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedClass = selected
                                    ? gradeLevel
                                    : null;
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: ColorUtils.corporateBlue600
                                .withValues(alpha: 0.15),
                            checkmarkColor: ColorUtils.corporateBlue600,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? ColorUtils.corporateBlue600
                                  : ColorUtils.slate700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? ColorUtils.corporateBlue600
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
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 24),

                      // Homeroom teacher status section
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: ColorUtils.slate600,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Homeroom Teacher',
                              'id': 'Status Wali Kelas',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              {
                                'value': null,
                                'label': languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                              },
                              {
                                'value': 'true',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Assigned',
                                  'id': 'Sudah Ada',
                                }),
                              },
                              {
                                'value': 'false',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Unassigned',
                                  'id': 'Belum Ada',
                                }),
                              },
                            ].map((item) {
                              final isSelected =
                                  tempSelectedHomeroom == item['value'];
                              return FilterChip(
                                label: Text(item['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempSelectedHomeroom = item['value'];
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: ColorUtils.corporateBlue600
                                    .withValues(alpha: 0.15),
                                checkmarkColor: ColorUtils.corporateBlue600,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
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
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer buttons
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
                            _selectedGradeFilter = tempSelectedClass;
                            _selectedHomeroomFilter = tempSelectedHomeroom;
                          });
                          _checkActiveFilter();
                          AppNavigator.pop(context);
                          _loadData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.corporateBlue600,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Apply Filter',
                            'id': 'Terapkan Filter',
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

  String? _buildClassCacheKey() {
    // Only cache default first-page view (no filters/search) for fast reload
    if (_currentPage != 1) return null;
    if (_selectedGradeFilter != null ||
        _selectedHomeroomFilter != null ||
        _searchController.text.trim().isNotEmpty) {
      return null;
    }

    final academicYearProvider = ref.read(academicYearRiverpod);
    final yearId = academicYearProvider.selectedAcademicYear?['id']?.toString() ?? 'default';
    return 'class_list_$yearId';
  }

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    try {
      if (resetPage) {
        _currentPage = 1;
        _hasMoreData = true;

        // ─── Step 1: Try loading from cache for instant display ───
        if (useCache) {
          final cacheKey = _buildClassCacheKey();
          if (cacheKey != null) {
            try {
              final cached = await LocalCacheService.load(
                cacheKey,
                ttl: const Duration(hours: 3),
              );
              if (cached != null && mounted) {
                final cachedData = Map<String, dynamic>.from(cached);
                setState(() {
                  _classes = List<dynamic>.from(cachedData['classes'] ?? []);
                  _hasMoreData = cachedData['pagination']?['has_next_page'] ?? false;
                  _isLoading = false;
                  _errorMessage = null;
                });
                AppLogger.info('classroom', 'Classes loaded from cache');
                // Cache hit → return early, no background API refresh
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _checkAndShowTour();
                });
                return;
              }
            } catch (e) {
              AppLogger.error('classroom', 'Class cache load failed: $e');
            }
          }
        }

        // Show loading skeleton only if we have no data yet (no cache hit)
        if (_classes.isEmpty && mounted) {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
        }
      }

      // ─── Step 2: Fetch fresh data from API ───
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiClassService>().getClassPaginated(
        page: _currentPage,
        limit: _perPage,
        gradeLevel: _selectedGradeFilter,
        hasHomeroomTeacher: _selectedHomeroomFilter,
        academicYearId: selectedYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        useCache: useCache,
      );

      if (!mounted) return;

      setState(() {
        _classes = response['data'] ?? [];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
      });

      // ─── Step 3: Save to cache (only for default view) ───
      final cacheKey = _buildClassCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'classes': response['data'] ?? [],
          'pagination': response['pagination'],
        });
      }
    } catch (e) {
      AppLogger.error('classroom', 'Load classes error: $e');
      if (!mounted) return;

      // Only show error if we don't have cached data displayed
      if (_classes.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      } else {
        setState(() => _isLoading = false);
      }

            SnackBarUtils.showError(context, '${ref.read(languageRiverpod).getTranslatedText({'en': 'Gagal memuat data kelas', 'id': 'Gagal memuat data kelas'})}: ${ErrorUtils.getFriendlyMessage(e)}');
    } finally {
      // Trigger tour
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    }
  }

  /// Force refresh: clear cache and reload from API
  Future<void> _forceRefresh() async {
    final cacheKey = _buildClassCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_class_management_');
    await LocalCacheService.invalidate('school_settings');
    await LocalCacheService.invalidate('teachers_all_list');
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _onRefresh() async {
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiClassService>().getClassPaginated(
        page: _currentPage,
        limit: _perPage,
        gradeLevel: _selectedGradeFilter,
        hasHomeroomTeacher: _selectedHomeroomFilter,
        academicYearId: selectedYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        // Append new data to existing list
        _classes.addAll(response['data'] ?? []);
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      AppLogger.info('classroom', 'Loaded more data: Page $_currentPage, Total items: ${_classes.length}',);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });

      AppLogger.error('classroom', 'Error loading more data: $e');
    }
  }

  // Export classes to Excel
  Future<void> _exportToExcel() async {
    await ExcelClassService.exportClassesToExcel(
      classes: _classes,
      context: context,
    );
  }

  // Import classes from Excel
  Future<void> _importFromExcel() async {
    final languageProvider = ref.read(languageRiverpod);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiClassService>().importClassesFromExcel(
          File(result.files.single.path!),
        );

        // Refresh data setelah import
        await _loadData();
      }
    } catch (e) {
      if (!mounted) return;
            SnackBarUtils.showError(context, '${languageProvider.getTranslatedText({'en': 'Gagal mengimpor file', 'id': 'Gagal mengimpor file'})}: ${ErrorUtils.getFriendlyMessage(e)}');
    }
  }

  // Download template
  Future<void> _downloadTemplate() async {
    await ExcelClassService.downloadTemplate(context);
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? classData}) async {
    // Refresh teacher list to avoid stale data (e.g. deleted teachers)
    await _fetchTeachers();

    // Fetch fresh data if editing to ensure we have all fields (especially IDs)
    if (classData != null) {
      try {
        // Show loading indicator if needed, or just await (fast usually)
        final freshData = await getIt<ApiClassService>().getClassById(
          classData['id'].toString(),
        );
        if (freshData != null && freshData is Map<String, dynamic>) {
          classData = freshData;

          // Ensure the current homeroom teacher is in the _teachers list
          // This handles cases where the teacher might be missing from the paginated list
          // or soft-deleted but still assigned
          String? homeroomId = classData['homeroom_teacher_id']?.toString();
          String? homeroomName = classData['homeroom_teacher_name']?.toString();

          // Handle Pivot/List structure
          if (homeroomId == null &&
              classData['homeroom_teacher'] is List &&
              (classData['homeroom_teacher'] as List).isNotEmpty) {
            homeroomId = classData['homeroom_teacher'][0]['id']?.toString();
            homeroomName = classData['homeroom_teacher'][0]['name']?.toString();
          } else if (homeroomId == null &&
              classData['homeroom_teacher'] is Map) {
            homeroomId = classData['homeroom_teacher']['id']?.toString();
            homeroomName = classData['homeroom_teacher']['name']?.toString();
          }

          if (homeroomId != null && homeroomName != null) {
            final exists = _teachers.any(
              (t) => t['id'].toString() == homeroomId,
            );
            if (!exists) {
              setState(() {
                _teachers.add({'id': homeroomId, 'name': homeroomName});
                // Sort teachers by name for better UX
                _teachers.sort(
                  (a, b) =>
                      (a['name'] ?? '').toString().compareTo(b['name'] ?? ''),
                );
              });
            }
          }
        }
      } catch (e) {
        AppLogger.error('classroom', 'Error fetching fresh class data: $e');
        // Fallback to existing classData
      }
    }

    if (!mounted) return;

    final nameController = TextEditingController(
      text: classData?['name'] ?? classData?['nama'] ?? '',
    );

    final isEdit = classData != null;

    // Initialize state variables outside builder to preserve state across rebuilds
    String? selectedGradeLevel = classData != null
        ? classData['grade_level']?.toString()
        : null;
    String? selectedHomeroomTeacherId;
    if (classData != null) {
      // Try flat keys
      selectedHomeroomTeacherId =
          classData['homeroom_teacher_id']?.toString() ??
          classData['wali_kelas_id']?.toString();

      // Try nested objects if flat key failed
      if (selectedHomeroomTeacherId == null) {
        if (classData['homeroom_teacher'] is List &&
            (classData['homeroom_teacher'] as List).isNotEmpty) {
          selectedHomeroomTeacherId = classData['homeroom_teacher'][0]['id']
              ?.toString();
        } else if (classData['homeroom_teacher'] is Map) {
          selectedHomeroomTeacherId = classData['homeroom_teacher']['id']
              ?.toString();
        } else if (classData['wali_kelas'] is Map) {
          selectedHomeroomTeacherId = classData['wali_kelas']['id']?.toString();
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final languageProvider = ref.watch(languageRiverpod);
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.92,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Header gradient (Pattern #9)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                ColorUtils.corporateBlue600,
                                ColorUtils.corporateBlue600.withValues(
                                  alpha: 0.8,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
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
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(
                                  isEdit
                                      ? Icons.edit_rounded
                                      : Icons.add_rounded,
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
                                          ? languageProvider.getTranslatedText({
                                              'en': 'Edit Class',
                                              'id': 'Edit Kelas',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en': 'Add Class',
                                              'id': 'Tambah Kelas',
                                            }),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      isEdit
                                          ? languageProvider.getTranslatedText({
                                              'en': 'Update class information',
                                              'id': 'Perbarui informasi kelas',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en': 'Fill in class information',
                                              'id': 'Isi informasi kelas',
                                            }),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => AppNavigator.pop(context),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDialogTextField(
                                  controller: nameController,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Class Name',
                                    'id': 'Nama Kelas',
                                  }),
                                  icon: Icons.school,
                                ),
                                SizedBox(height: 12),
                                _buildGradeLevelDropdown(
                                  value: selectedGradeLevel,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedGradeLevel = value;
                                    });
                                  },
                                  languageProvider: languageProvider,
                                ),
                                SizedBox(height: 12),
                                _buildHomeroomTeacherDropdown(
                                  value: selectedHomeroomTeacherId,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedHomeroomTeacherId = value;
                                    });
                                  },
                                  languageProvider: languageProvider,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Enhanced Footer
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: ColorUtils.slate200),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ColorUtils.slate900.withValues(
                                  alpha: 0.05,
                                ),
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
                                    side: BorderSide(
                                      color: ColorUtils.slate300,
                                    ),
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
                                  onPressed: () async {
                                    final nama = nameController.text.trim();

                                    if (nama.isEmpty ||
                                        selectedGradeLevel == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            languageProvider.getTranslatedText({
                                              'en':
                                                  'Class name and grade level must be filled',
                                              'id':
                                                  'Nama kelas dan grade level harus diisi',
                                            }),
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      final academicYearProvider =
                                          ref.read(academicYearRiverpod);
                                      final selectedYearId =
                                          academicYearProvider
                                              .selectedAcademicYear?['id']
                                              ?.toString();

                                      if (isEdit) {
                                        await getIt<ApiClassService>().updateClass(
                                          classData!['id'].toString(),
                                          {
                                            'name': nameController.text,
                                            'grade_level': selectedGradeLevel,
                                            'homeroom_teacher_id':
                                                selectedHomeroomTeacherId,
                                            'academic_year_id': selectedYearId,
                                          },
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                languageProvider.getTranslatedText({
                                                  'en':
                                                      'Class successfully updated',
                                                  'id':
                                                      'Kelas berhasil diperbarui',
                                                }),
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          AppNavigator.pop(context);
                                        }
                                      } else {
                                        await getIt<ApiClassService>().addClass({
                                          'name': nameController.text,
                                          'grade_level': selectedGradeLevel,
                                          'homeroom_teacher_id':
                                              selectedHomeroomTeacherId,
                                          'academic_year_id': selectedYearId,
                                        });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                languageProvider.getTranslatedText({
                                                  'en':
                                                      'Class successfully added',
                                                  'id':
                                                      'Kelas berhasil ditambahkan',
                                                }),
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          AppNavigator.pop(context);
                                        }
                                      }
                                      _loadData();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              languageProvider.getTranslatedText({
                                                'en':
                                                    'Failed to save class: ${ErrorUtils.getFriendlyMessage(e)}',
                                                'id':
                                                    'Gagal menyimpan kelas: ${ErrorUtils.getFriendlyMessage(e)}',
                                              }),
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        ColorUtils.corporateBlue600,
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    elevation: 2,
                                    shadowColor: ColorUtils.corporateBlue600
                                        .withValues(alpha: 0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    isEdit
                                        ? languageProvider.getTranslatedText({
                                            'en': 'Update',
                                            'id': 'Perbarui',
                                          })
                                        : AppLocalizations.save.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
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
            },
          );
        },
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }

  Widget _buildGradeLevelDropdown({
    required String? value,
    required Function(String?) onChanged,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Grade Level',
            'id': 'Tingkat Kelas',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(
            Icons.layers_outlined,
            color: ColorUtils.corporateBlue600,
            size: 18,
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: _availableGradeLevels.map((gradeStr) {
          final grade = int.tryParse(gradeStr) ?? 0;
          String gradeText;
          if (grade <= 6) {
            gradeText = 'Kelas $grade SD';
          } else if (grade <= 9) {
            gradeText = 'Kelas $grade SMP';
          } else {
            gradeText = 'Kelas $grade SMA';
          }
          return DropdownMenuItem<String>(
            value: gradeStr,
            child: Text(gradeText),
          );
        }).toList(),
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: ColorUtils.slate500,
        ),
      ),
    );
  }

  Widget _buildHomeroomTeacherDropdown({
    required String? value,
    required Function(String?) onChanged,
    required LanguageProvider languageProvider,
  }) {
    // Deduplicate teachers based on ID
    final uniqueTeachers = <String, Map<String, dynamic>>{};
    for (var teacher in _teachers) {
      if (teacher['id'] != null) {
        uniqueTeachers[teacher['id'].toString()] = teacher;
      }
    }

    // Validate value - ensure it exists in the list
    String? validValue = value;
    if (validValue != null && !uniqueTeachers.containsKey(validValue)) {
      validValue = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: validValue,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Homeroom Teacher',
            'id': 'Wali Kelas',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(
            Icons.person_outline,
            color: ColorUtils.corporateBlue600,
            size: 18,
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'No Homeroom Teacher',
                'id': 'Tidak ada wali kelas',
              }),
            ),
          ),
          ...uniqueTeachers.values.map((teacher) {
            final teacherName = teacher['name'] ?? 'Unknown';
            final teacherNip = teacher['nip']?.toString() ?? '';
            final displayText = teacherNip.isNotEmpty
                ? '$teacherName (NIP: $teacherNip)'
                : teacherName;
            return DropdownMenuItem<String>(
              value: teacher['id'].toString(),
              child: Text(displayText, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: ColorUtils.slate500,
        ),
      ),
    );
  }

  Future<void> _deleteClass(Map<String, dynamic> classData) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Delete Class',
          'id': 'Hapus Kelas',
        }),
        content: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Are you sure you want to delete this class?',
          'id': 'Yakin ingin menghapus kelas ini?',
        }),
        confirmText: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Delete',
          'id': 'Hapus',
        }),
        confirmColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      try {
        await getIt<ApiClassService>().deleteClass(classData['id'].toString());
        _loadData();
        if (mounted) {
                    SnackBarUtils.showSuccess(context, ref.read(languageRiverpod).getTranslatedText({
                  'en': 'Class successfully deleted',
                  'id': 'Kelas berhasil dihapus',
                }));
        }
      } catch (e) {
        if (mounted) {
                    SnackBarUtils.showError(context, '${ref.read(languageRiverpod).getTranslatedText({'en': 'Gagal menghapus kelas', 'id': 'Gagal menghapus kelas'})}: ${ErrorUtils.getFriendlyMessage(e)}');
        }
      }
    }
  }

  Widget _buildClassCard(Map<String, dynamic> classData, int index) {
    final languageProvider = ref.read(languageRiverpod);
    final avatarColor = ColorUtils.getColorForIndex(index);
    final className = classData['name'] ?? 'Class';
    final gradeText = _getGradeLevelText(
      classData['grade_level'],
      languageProvider,
    );
    final studentCount = classData['student_count'] ?? 0;
    final teacherName =
        (classData['homeroom_teacher'] is List &&
            (classData['homeroom_teacher'] as List).isNotEmpty)
        ? classData['homeroom_teacher'][0]['name']
        : (classData['homeroom_teacher'] is Map
              ? classData['homeroom_teacher']['name']
              : classData['homeroom_teacher_name'] ??
                    classData['wali_kelas_nama'] ??
                    languageProvider.getTranslatedText({
                      'en': 'Not Assigned',
                      'id': 'Belum Ditugaskan',
                    }));

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showClassDetail(classData),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              children: [
                // Colored initial avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    className.isNotEmpty ? className[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Name + info tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      _buildInfoTag(Icons.layers_outlined, gradeText),
                      SizedBox(height: 4),
                      _buildInfoTag(Icons.person_outline, teacherName),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Student count chip + action buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.corporateBlue600.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorUtils.corporateBlue600.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: ColorUtils.corporateBlue600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '$studentCount ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                            style: TextStyle(
                              color: ColorUtils.corporateBlue600,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final academicYearProvider = ref.watch(academicYearRiverpod);
                        if (academicYearProvider.isReadOnly) {
                          return SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            SizedBox(height: 8),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () =>
                                      _showAddEditDialog(classData: classData),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.corporateBlue600
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: ColorUtils.corporateBlue600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _deleteClass(classData),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.error600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: ColorUtils.error600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
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

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showClassDetail(Map<String, dynamic> classData) {
    final languageProvider = ref.read(languageRiverpod);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: colored avatar + grade badge + X close (Pattern #10)
              Builder(
                builder: (context) {
                  final name = classData['name'] ?? 'C';
                  final nameHash = name.codeUnits.fold(0, (sum, c) => sum + c);
                  final avatarColor = ColorUtils.getColorForIndex(nameHash);
                  final gradeText = _getGradeLevelText(
                    classData['grade_level'],
                    languageProvider,
                  );
                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ColorUtils.corporateBlue600,
                          ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: avatarColor,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.layers_outlined,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        gradeText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => AppNavigator.pop(context),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                      icon: Icons.people,
                      label: languageProvider.getTranslatedText({
                        'en': 'Total Students',
                        'id': 'Jumlah Siswa',
                      }),
                      value:
                          '${classData['student_count'] ?? 0} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                    ),
                    _buildDetailItem(
                      icon: Icons.person,
                      label: languageProvider.getTranslatedText({
                        'en': 'Homeroom Teacher',
                        'id': 'Wali Kelas',
                      }),
                      value:
                          // Handle Pivot/List structure for display
                          (classData['homeroom_teacher'] is List &&
                              (classData['homeroom_teacher'] as List)
                                  .isNotEmpty)
                          ? classData['homeroom_teacher'][0]['name']
                          : (classData['homeroom_teacher'] is Map
                                ? classData['homeroom_teacher']['name']
                                : classData['homeroom_teacher_name'] ??
                                      classData['wali_kelas_nama'] ??
                                      languageProvider.getTranslatedText({
                                        'en': 'Not Assigned',
                                        'id': 'Belum Ditugaskan',
                                      })),
                    ),

                    SizedBox(height: 20),

                    // View Students Button (Full Width)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          AppNavigator.pop(context);
                          // Navigate to student management screen with class filter
                          AppNavigator.push(context, StudentManagementScreen(
                                initialClassId: classData['id'].toString(),
                              ));
                        },
                        icon: Icon(Icons.list, color: Colors.white),
                        label: Text(
                          languageProvider.getTranslatedText({
                            'en': 'View Students',
                            'id': 'Lihat Daftar Siswa',
                          }),
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),
                    // Footer buttons (Pattern #10)
                    Container(
                      padding: EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: ColorUtils.slate100),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => AppNavigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 13),
                                side: BorderSide(color: ColorUtils.slate300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Close',
                                  'id': 'Tutup',
                                }),
                                style: TextStyle(
                                  color: ColorUtils.slate700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          if (!ref.read(academicYearRiverpod).isReadOnly) ...[
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  AppNavigator.pop(context);
                                  _showAddEditDialog(classData: classData);
                                },
                                icon: Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Edit',
                                    'id': 'Edit',
                                  }),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ColorUtils.corporateBlue600,
                                  padding: EdgeInsets.symmetric(vertical: 13),
                                  elevation: 2,
                                  shadowColor: ColorUtils.corporateBlue600
                                      .withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, size: 18, color: ColorUtils.corporateBlue600),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate800,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGradeLevelText(
    dynamic gradeLevel,
    LanguageProvider languageProvider,
  ) {
    if (gradeLevel == null) return '-';

    final level = int.tryParse(gradeLevel.toString());
    if (level == null) return '-';

    if (level <= 6) {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SD';
    } else if (level <= 9) {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SMP';
    } else {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SMA';
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
        if (_errorMessage != null) {
          return ErrorScreen(errorMessage: _errorMessage!, onRetry: _loadData);
        }

        // Backend handles all filtering, so we use _classes directly
        final filteredClasses = _classes;

        return Scaffold(
          backgroundColor: ColorUtils.lightGray,
          body: Column(
            children: [
              // Header
              GradientPageHeader(
                title: languageProvider.getTranslatedText({
                  'en': 'Class Management',
                  'id': 'Manajemen Kelas',
                }),
                subtitle: languageProvider.getTranslatedText({
                  'en': 'Manage and monitor classes',
                  'id': 'Kelola dan pantau kelas',
                }),
                primaryColor: _getPrimaryColor(),
                onBackPressed: () => AppNavigator.pop(context),
                actionMenu: PopupMenuButton<String>(
                  key: _menuKey,
                  onSelected: (value) {
                    switch (value) {
                      case 'refresh':
                        _forceRefresh();
                        break;
                      case 'export':
                        _exportToExcel();
                        break;
                      case 'import':
                        _importFromExcel();
                        break;
                      case 'template':
                        _downloadTemplate();
                        break;
                    }
                  },
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.more_vert, color: Colors.white, size: 20),
                  ),
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Refresh Data',
                              'id': 'Perbarui Data',
                            }),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 20),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Export to Excel',
                              'id': 'Export ke Excel',
                            }),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(Icons.upload, size: 20),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Import from Excel',
                              'id': 'Import dari Excel',
                            }),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'template',
                      child: Row(
                        children: [
                          Icon(Icons.file_download, size: 20),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Download Template',
                              'id': 'Download Template',
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                searchBar: Row(
                  children: [
                    Expanded(
                      child: Container(
                        key: _searchKey,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  hintText: languageProvider.getTranslatedText({
                                    'en': 'Search classes...',
                                    'id': 'Cari kelas...',
                                  }),
                                  hintStyle: TextStyle(color: Colors.grey),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.grey,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) {
                                  setState(() {
                                    _currentPage = 1;
                                  });
                                  _loadData();
                                },
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(right: 4),
                              child: IconButton(
                                key: _filterKey,
                                icon: Icon(
                                  Icons.search,
                                  color: _getPrimaryColor(),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _currentPage = 1;
                                  });
                                  _loadData();
                                },
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
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Stack(
                        children: [
                          IconButton(
                            onPressed: _showFilterSheet,
                            icon: Icon(
                              Icons.tune,
                              color: _hasActiveFilter
                                  ? _getPrimaryColor()
                                  : Colors.white,
                            ),
                            tooltip: languageProvider.getTranslatedText({
                              'en': 'Filter',
                              'id': 'Filter',
                            }),
                          ),
                          if (_hasActiveFilter)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
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
                filterChips: _hasActiveFilter
                    ? SizedBox(
                        height: 42,
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.filter_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ..._buildFilterChips(languageProvider).map((
                                    filter,
                                  ) {
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
                                          color: _getPrimaryColor().withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        labelPadding: EdgeInsets.only(left: 4),
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
                                  color: Colors.red,
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
                      )
                    : null,
              ),

              Expanded(
                child: _isLoading && _classes.isEmpty
                    ? SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                    : filteredClasses.isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No classes',
                          'id': 'Tidak ada kelas',
                        }),
                        subtitle:
                            _searchController.text.isEmpty && !_hasActiveFilter
                            ? languageProvider.getTranslatedText({
                                'en': 'Tap + to add a class',
                                'id': 'Tap + untuk menambah kelas',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.school_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount:
                              filteredClasses.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == filteredClasses.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            final classItem = filteredClasses[index];
                            return _buildClassCard(classItem, index);
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: Builder(
            builder: (context) {
              final academicYearProvider = ref.watch(academicYearRiverpod);
              final languageProvider = ref.read(languageRiverpod);

              if (academicYearProvider.isReadOnly) return SizedBox.shrink();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_isFabOpen) ...[
                    ScaleTransition(
                      scale: _fabScaleAnimation,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Promote Class',
                                'id': 'Naik Kelas / Promosi',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 8),
                          FloatingActionButton(
                            heroTag: 'fab_promote_class',
                            mini: true,
                            backgroundColor: Colors.orange,
                            onPressed: () {
                              setState(() {
                                _isFabOpen = false;
                                _fabAnimationController.reverse();
                              });
                              _showPromotionWizard();
                            },
                            child: Icon(Icons.upgrade, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    ScaleTransition(
                      scale: _fabScaleAnimation,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Create New Class',
                                'id': 'Buat Kelas Baru',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 8),
                          FloatingActionButton(
                            heroTag: 'fab_add_class',
                            mini: true,
                            backgroundColor: _getPrimaryColor(),
                            onPressed: () {
                              setState(() {
                                _isFabOpen = false;
                                _fabAnimationController.reverse();
                              });
                              _showAddEditDialog();
                            },
                            child: Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  FloatingActionButton(
                    key: _fabKey,
                    heroTag: 'fab_main_class',
                    onPressed: () {
                      setState(() {
                        _isFabOpen = !_isFabOpen;
                        if (_isFabOpen) {
                          _fabAnimationController.forward();
                        } else {
                          _fabAnimationController.reverse();
                        }
                      });
                    },
                    backgroundColor: _getPrimaryColor(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: RotationTransition(
                      turns: _fabRotateAnimation,
                      child: Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              );
            },
          ),
        );
  }

  void _showPromotionWizard() {
    AppNavigator.push(context, ClassPromotionWizard());
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('class_management', 'admin');

      // Only use cache (pre-fetched by dashboard), no API call
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
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
      AppLogger.error('classroom', 'Error checking tour status: $e');
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
          LocalCacheService.save(CacheKeyBuilder.tourStatus('class_management', 'admin'), {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save(CacheKeyBuilder.tourStatus('class_management', 'admin'), {'should_show': false});
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
        identify: "ClassMenu",
        keyTarget: _menuKey,
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
                      'en': 'Class Tools',
                      'id': 'Alat Manajemen Kelas',
                    }),
                    style: TextStyle(
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
                            'Export, import, or download class templates from here.',
                        'id':
                            'Ekspor, impor, atau unduh template data kelas dari sini.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
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
        identify: "ClassSearch",
        keyTarget: _searchKey,
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
                      'en': 'Find Classes',
                      'id': 'Cari Kelas',
                    }),
                    style: TextStyle(
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
                            'Quickly find classes by name using this search bar.',
                        'id':
                            'Temukan kelas dengan cepat berdasarkan nama menggunakan bilah pencarian ini.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
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
        identify: "ClassFilter",
        keyTarget: _filterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
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
                      'en': 'Filter Options',
                      'id': 'Opsi Filter',
                    }),
                    style: TextStyle(
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
                            'Filter classes by grade level or homeroom teacher status.',
                        'id':
                            'Filter kelas berdasarkan tingkat kelas atau status wali kelas.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
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
        identify: "AddClass",
        keyTarget: _fabKey,
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
                      'en': 'Add New Class',
                      'id': 'Tambah Kelas Baru',
                    }),
                    style: TextStyle(
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
                            'Create a new class and assign a homeroom teacher.',
                        'id': 'Buat kelas baru dan tugaskan wali kelas.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
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
}
