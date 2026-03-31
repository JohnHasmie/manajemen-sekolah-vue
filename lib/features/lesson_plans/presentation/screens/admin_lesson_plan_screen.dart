// Admin RPP (lesson plan) management screen.
//
// Like `pages/admin/lesson-plans.vue` - allows admins to review, approve, or reject
// teacher-submitted lesson plans (RPP). Uses drill-down: Teacher list -> RPP list.
// Supports pagination, status filtering, file download, and Excel export.
//
// In Laravel terms, this consumes RppController (GET /api/rpp, PATCH /api/rpp/{id}/approve).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/lesson_plans/exports/lesson_plan_export_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/update_status_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/teacher_select_card.dart';

/// Admin lesson plan (RPP) review screen with drill-down navigation.
///
/// Optionally accepts [teacherId]/[teacherName] to skip the teacher selection step.
/// This is like a Vue page with optional route params (`/admin/lessonPlan?teacherId=123`).
class AdminLessonPlanScreen extends ConsumerStatefulWidget {
  final String? teacherId;
  final String? teacherName;

  const AdminLessonPlanScreen({super.key, this.teacherId, this.teacherName});

  @override
  ConsumerState<AdminLessonPlanScreen> createState() =>
      _AdminLessonPlanScreenState();
}

/// Mutable state for [AdminLessonPlanScreen].
///
/// Key state (like Vue `data()`):
/// - [_showTeacherList] - whether showing teacher list or RPP list (drill-down)
/// - [_lessonPlanList] / [_teacherList] - paginated data lists
/// - [_selectedStatusFilter] - filter by approval status (Pending/Approved/Rejected)
/// - Pagination state for infinite scroll
///
/// setState() triggers re-render like Vue's reactivity system.
class _AdminLessonPlanScreenState extends ConsumerState<AdminLessonPlanScreen> {
  List<dynamic> _lessonPlanList = [];
  List<dynamic> _teacherList = [];
  bool _showTeacherList = true;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();

  // Pagination state
  int _currentPage = 1;
  final int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  // pagination meta kept server-side; not stored locally to avoid unused warnings
  Timer? _searchDebounce;

  // Filter States
  String?
  _selectedStatusFilter; // 'Pending', 'Approved', 'Rejected', or null for all
  bool _hasActiveFilter = false;

  /// Like Vue's `mounted()` - sets up scroll listener for infinite scroll
  /// and loads either teacher list or RPP list based on initial props.
  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMoreData &&
          !_isLoading) {
        if (_showTeacherList && widget.teacherId == null) {
          _loadTeachersPaginated();
        } else {
          _loadLessonPlansPaginated();
        }
      }
    });

    // Check if we start with a specific teacher (e.g. from deeper navigation)
    if (widget.teacherId != null) {
      _showTeacherList = false;
      _selectedTeacherId = widget.teacherId;
      _selectedTeacherName = widget.teacherName;
      _loadLessonPlansPaginated(reset: true);
    } else {
      _showTeacherList = true;
      _loadTeachersPaginated(reset: true);
    }

    // Check and show tour
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndShowTour();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = _selectedStatusFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _hasActiveFilter = false;
    });
  }

  String _buildFilterSummary(LanguageProvider languageProvider) {
    final List<String> filters = [];

    if (_selectedStatusFilter != null) {
      filters.add(
        '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $_selectedStatusFilter',
      );
    }

    return filters.join(' • ');
  }

  void _showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    // Temporary state for bottom sheet
    String? tempSelectedStatus = _selectedStatusFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Header (Pattern #11 gradient)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
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
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
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

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Filter
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                              color: ColorUtils.slate700,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Status',
                                'id': 'Status',
                              }),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: ColorUtils.slate900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusChip(
                              label: languageProvider.getTranslatedText({
                                'en': 'All',
                                'id': 'Semua',
                              }),
                              value: null,
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = null;
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Menunggu',
                              value: 'Pending',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Pending';
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Disetujui',
                              value: 'Approved',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Approved';
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Ditolak',
                              value: 'Rejected',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Rejected';
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Buttons
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.slate900.withValues(alpha: 0.05),
                        offset: Offset(0, -2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => AppNavigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: ColorUtils.slate300),
                            shape: RoundedRectangleBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatusFilter = tempSelectedStatus;
                            });
                            _checkActiveFilter();
                            AppNavigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getPrimaryColor(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
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
          );
        },
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required String? value,
    required String? selectedValue,
    required VoidCallback onSelected,
  }) {
    final isSelected = selectedValue == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: _getPrimaryColor().withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate600,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate300,
      ),
    );
  }

  String? _buildTeacherCacheKey() {
    if (_currentPage != 1) return null;
    if (_searchController.text.trim().isNotEmpty) return null;
    return 'rpp_teacher_list';
  }

  String? _buildLessonPlanCacheKey() {
    if (_currentPage != 1) return null;
    if (_selectedStatusFilter != null ||
        _searchController.text.trim().isNotEmpty) {
      return null;
    }
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'rpp_list_${_selectedTeacherId}_$yearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('tour_rpp_screen_');
    if (_showTeacherList && widget.teacherId == null) {
      final cacheKey = _buildTeacherCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      _loadTeachersPaginated(reset: true, useCache: false);
    } else {
      final cacheKey = _buildLessonPlanCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      _loadLessonPlansPaginated(reset: true, useCache: false);
    }
  }

  Future<void> _exportToExcel() async {
    await ExcelLessonPlanService.exportLessonPlansToExcel(
      lessonPlanList: _lessonPlanList,
      context: context,
    );
  }

  Future<void> _loadLessonPlansByTeacher() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _loadLessonPlansPaginated(reset: true, useCache: false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadAllLessonPlans() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _loadLessonPlansPaginated(reset: true, useCache: false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadTeachersPaginated({
    bool reset = false,
    bool useCache = true,
  }) async {
    try {
      if (reset) {
        _currentPage = 1;
        _hasMoreData = true;
      }

      // Step 1: Try cache for instant display (only on reset/first load)
      if (useCache && reset) {
        final cacheKey = _buildTeacherCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                _teacherList = cachedList;
                _hasMoreData = cached['hasMoreData'] ?? true;
                _isLoading = false;
              });
              AppLogger.info('lesson_plan', 'Teacher list loaded from cache');
              return;
            }
          }
        }
      }

      // Show skeleton only if list is empty
      if (reset && _teacherList.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      } else if (!reset) {
        setState(() {
          _isLoadingMore = true;
        });
      }

      // Step 2: Fetch fresh from API
      final result = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: _currentPage,
        limit: _perPage,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );

      if (result['success'] == true || result['data'] != null) {
        final List<dynamic> data = result['data'] ?? [];
        final pagination = result['pagination'] ?? {};

        if (mounted) {
          setState(() {
            if (reset) {
              _teacherList = data;
            } else {
              _teacherList.addAll(data);
            }

            _hasMoreData =
                pagination['has_next_page'] ?? (data.length == _perPage);
            _isLoading = false;
            _isLoadingMore = false;
          });

          // Step 3: Save to cache (only page 1 default view, non-blocking)
          if (reset) {
            final cacheKey = _buildTeacherCacheKey();
            if (cacheKey != null) {
              LocalCacheService.save(cacheKey, {
                'data': data,
                'hasMoreData': _hasMoreData,
              });
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
            if (_teacherList.isEmpty) {
              _errorMessage = 'Failed to load teachers';
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          if (_teacherList.isEmpty) {
            _errorMessage = ErrorUtils.getFriendlyMessage(e);
          }
        });
      }
    }
  }

  Future<void> _loadLessonPlansPaginated({
    bool reset = false,
    bool useCache = true,
  }) async {
    try {
      if (reset) {
        _currentPage = 1;
        _hasMoreData = true;
      }

      // Step 1: Try cache for instant display (only on reset/first load)
      if (useCache && reset) {
        final cacheKey = _buildLessonPlanCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                _lessonPlanList = cachedList;
                _hasMoreData = cached['hasMoreData'] ?? true;
                _isLoading = false;
              });
              AppLogger.info('lesson_plan', 'RPP list loaded from cache');
              return;
            }
          }
        }
      }

      // Show skeleton only if list is empty
      if (reset && _lessonPlanList.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      } else if (!reset) {
        setState(() {
          _isLoadingMore = true;
        });
      }

      // Step 2: Fetch fresh from API
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final result = await LessonPlanService.getLessonPlansPaginated(
        page: _currentPage,
        limit: _perPage,
        teacherId: _selectedTeacherId,
        status: _selectedStatusFilter,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        academicYearId: academicYearId,
      );

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        final pagination = result['pagination'] ?? {};

        if (mounted) {
          setState(() {
            if (reset) {
              _lessonPlanList = data;
            } else {
              _lessonPlanList.addAll(data);
            }

            _hasMoreData =
                pagination['has_next_page'] ?? (data.length == _perPage);
            _isLoading = false;
            _isLoadingMore = false;
          });

          // Step 3: Save to cache (only page 1 default view, non-blocking)
          if (reset) {
            final cacheKey = _buildLessonPlanCacheKey();
            if (cacheKey != null) {
              LocalCacheService.save(cacheKey, {
                'data': data,
                'hasMoreData': _hasMoreData,
              });
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
            if (_lessonPlanList.isEmpty) {
              _errorMessage = 'Failed to load RPP';
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          if (_lessonPlanList.isEmpty) {
            _errorMessage = ErrorUtils.getFriendlyMessage(e);
          }
        });
      }
    }
  }

  void _selectTeacher(Map<String, dynamic> teacher) {
    setState(() {
      _selectedTeacherId =
          teacher['user_id']?.toString() ??
          teacher['id'].toString(); // Try user_id first, fallback to id
      _selectedTeacherName = teacher['name'];
      _showTeacherList = false;
      _lessonPlanList = [];
      _searchController.clear();
      _currentPage = 1;
    });
    _loadLessonPlansPaginated(reset: true);
  }

  void _backToTeacherList() {
    setState(() {
      _selectedTeacherId = null;
      _selectedTeacherName = null;
      _showTeacherList = true;
      _lessonPlanList = [];
      _searchController.clear();
      _currentPage = 1;
    });
    _loadTeachersPaginated(reset: true);
  }

  void _handleSearch() {
    if (_showTeacherList && widget.teacherId == null) {
      _loadTeachersPaginated(reset: true);
    } else {
      _loadLessonPlansPaginated(reset: true);
    }
  }

  void _updateStatus(String lessonPlanId, String status) {
    final lessonPlan = _lessonPlanList.firstWhere(
      (lp) => lp['id'] == lessonPlanId,
    );
    showDialog(
      context: context,
      builder: (context) => UpdateStatusDialog(
        lessonPlanId: lessonPlanId,
        currentStatus: lessonPlan['status'],
        currentNote: lessonPlan['catatan'],
        onStatusUpdated: _loadAllLessonPlans,
      ),
    );
  }

  void _viewLessonPlanDetail(Map<String, dynamic> lessonPlan) async {
    await AppNavigator.push(
      context,
      LessonPlanAdminDetailPage(lessonPlan: lessonPlan),
    );
    // Refresh list after returning
    if (_showTeacherList && _selectedTeacherName != null) {
      _loadLessonPlansByTeacher();
    } else if (!_showTeacherList) {
      _loadLessonPlansByTeacher(); // Or logic to reload current list
    }
  }


  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.8)],
    );
  }


  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    if (_errorMessage != null) {
      return ErrorScreen(
        errorMessage: _errorMessage!,
        onRetry: _showTeacherList
            ? _loadTeachersPaginated
            : _loadAllLessonPlans,
      );
    }

    // Apply filters for RPP list (Teacher list is filtered by backend)
    final filteredLessonPlans = _lessonPlanList.where((lessonPlan) {
      if (_showTeacherList) {
        return true; // Don't filter if showing teachers (not used)
      }

      final searchTerm = _searchController.text.toLowerCase();
      final matchesSearch =
          searchTerm.isEmpty ||
          (lessonPlan['judul']?.toLowerCase().contains(searchTerm) ?? false) ||
          (lessonPlan['mata_pelajaran_nama']?.toLowerCase().contains(
                searchTerm,
              ) ??
              false) ||
          (lessonPlan['teacher_name']?.toLowerCase().contains(searchTerm) ??
              false) || // Updated to teacher_name
          (lessonPlan['guru_nama']?.toLowerCase().contains(searchTerm) ??
              false) || // Keep as fallback
          (lessonPlan['kelas_nama']?.toLowerCase().contains(searchTerm) ??
              false);

      // Status filter
      final matchesStatusFilter =
          _selectedStatusFilter == null ||
          lessonPlan['status'] == _selectedStatusFilter;

      return matchesSearch && matchesStatusFilter;
    }).toList();

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header — extracted to _AdminLessonPlanHeader
          _AdminLessonPlanHeader(
            primaryColor: _getPrimaryColor(),
            gradient: _getCardGradient(),
            title: _showTeacherList
                ? languageProvider.getTranslatedText({
                    'en': 'Select Teacher',
                    'id': 'Pilih Guru',
                  })
                : (_selectedTeacherName != null
                    ? 'RPP - $_selectedTeacherName'
                    : languageProvider.getTranslatedText({
                        'en': 'Manage RPP',
                        'id': 'Kelola RPP',
                      })),
            subtitle: (_showTeacherList || _selectedTeacherName == null)
                ? (_showTeacherList
                    ? languageProvider.getTranslatedText({
                        'en': 'Select a teacher to view RPP',
                        'id': 'Pilih guru untuk melihat RPP',
                      })
                    : languageProvider.getTranslatedText({
                        'en': 'Manage lesson plans',
                        'id': 'Kelola rencana pelaksanaan pembelajaran',
                      }))
                : null,
            showTeacherList: _showTeacherList,
            hasActiveFilter: _hasActiveFilter,
            filterSummary: _buildFilterSummary(languageProvider),
            menuKey: _menuKey,
            searchKey: _searchKey,
            filterKey: _filterKey,
            searchController: _searchController,
            searchHint: _showTeacherList
                ? languageProvider.getTranslatedText({
                    'en': 'Search Teacher...',
                    'id': 'Cari Guru...',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'Search RPP...',
                    'id': 'Cari RPP...',
                  }),
            exportLabel: languageProvider.getTranslatedText({
                'en': 'Export to Excel',
                'id': 'Export ke Excel',
              }),
            updateDataLabel: AppLocalizations.updateData.tr,
            filterTooltip: languageProvider.getTranslatedText({
                'en': 'Filter',
                'id': 'Filter',
              }),
            onBack: () {
              if (_showTeacherList) {
                AppNavigator.pop(context);
              } else if (widget.teacherId != null) {
                AppNavigator.pop(context);
              } else {
                _backToTeacherList();
              }
            },
            onSearch: _handleSearch,
            onExport: _exportToExcel,
            onRefresh: _forceRefresh,
            onShowFilter: _showFilterSheet,
            onClearFilter: _clearAllFilters,
          ),
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                : _showTeacherList
                ? (() {
                    final searchTerm = _searchController.text.toLowerCase();
                    final filteredTeachers = _teacherList.where((teacher) {
                      if (searchTerm.isEmpty) return true;
                      final name =
                          teacher['name']?.toString().toLowerCase() ?? '';
                      // Optional: Filter by NIP too if desired
                      // final nip = teacher['employee_number']?.toString().toLowerCase() ?? '';
                      return name.contains(searchTerm);
                    }).toList();

                    if (filteredTeachers.isEmpty) {
                      return EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No Teachers',
                          'id': 'Tidak ada Guru',
                        }),
                        subtitle: _searchController.text.isNotEmpty
                            ? languageProvider.getTranslatedText({
                                'en': 'No teachers found matching search',
                                'id':
                                    'Tidak ditemukan guru dengan pencarian tersebut',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No teacher data available',
                                'id': 'Tidak ada data guru',
                              }),
                        icon: Icons.people,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _forceRefresh,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        itemCount:
                            filteredTeachers.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= filteredTeachers.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return TeacherSelectCard(
                            teacher: filteredTeachers[index]
                                as Map<String, dynamic>,
                            index: index,
                            onTap: () =>
                                _selectTeacher(filteredTeachers[index]),
                          );
                        },
                      ),
                    );
                  })()
                : (filteredLessonPlans.isEmpty
                      ? EmptyState(
                          title: languageProvider.getTranslatedText({
                            'en': 'No RPP',
                            'id': 'Tidak ada RPP',
                          }),
                          subtitle:
                              _searchController.text.isEmpty &&
                                  !_hasActiveFilter
                              ? languageProvider.getTranslatedText({
                                  'en': 'No RPP data available',
                                  'id': 'Tidak ada data RPP',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'No search results found',
                                  'id': 'Tidak ditemukan hasil pencarian',
                                }),
                          icon: Icons.description,
                        )
                      : RefreshIndicator(
                          onRefresh: _forceRefresh,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(top: 16, bottom: 16),
                            itemCount:
                                filteredLessonPlans.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= filteredLessonPlans.length) {
                                // loading indicator
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final lessonPlan = filteredLessonPlans[index];
                              return LessonPlanAdminCard(
                                lessonPlan:
                                    lessonPlan as Map<String, dynamic>,
                                index: index,
                                primaryColor: _getPrimaryColor(),
                                onTap: () =>
                                    _viewLessonPlanDetail(lessonPlan),
                                onUpdateStatus: () => _updateStatus(
                                  lessonPlan['id'],
                                  lessonPlan['status'],
                                ),
                              );
                            },
                          ),
                        )),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('rpp_screen', 'admin');
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
      AppLogger.error('lesson_plan', e);
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
          name: 'admin_rpp_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('rpp_screen', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'admin_rpp_screen_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('rpp_screen', 'admin'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "RppSearch",
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
                      'en': 'Search RPP',
                      'id': 'Cari RPP',
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
                        'en': 'Quickly find RPP by name or subject here.',
                        'id':
                            'Temukan RPP dengan cepat berdasarkan nama atau mata pelajaran di sini.',
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
        identify: "RppMenuFilter",
        keyTarget: _filterKey,
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
                        'en': 'Filter RPP based on status.',
                        'id': 'Filter RPP berdasarkan status.',
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
        identify: "RppMenu",
        keyTarget: _menuKey,
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
                      'en': 'RPP Tools',
                      'id': 'Alat RPP',
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
                        'en': 'Export the list of RPPs to Excel.',
                        'id': 'Ekspor daftar RPP ke dalam file Excel.',
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

/// Gradient header for the admin lesson plan screen.
///
/// Extracted from [_AdminLessonPlanScreenState.build] to keep the build method
/// readable. Like a Blade partial: `@include('lesson_plans._header')`.
class _AdminLessonPlanHeader extends StatelessWidget {
  final Color primaryColor;
  final LinearGradient gradient;
  final String title;
  final String? subtitle;
  final bool showTeacherList;
  final bool hasActiveFilter;
  final String filterSummary;
  final GlobalKey menuKey;
  final GlobalKey searchKey;
  final GlobalKey filterKey;
  final TextEditingController searchController;
  final String searchHint;
  final String exportLabel;
  final String updateDataLabel;
  final String filterTooltip;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onExport;
  final VoidCallback onRefresh;
  final VoidCallback onShowFilter;
  final VoidCallback onClearFilter;

  const _AdminLessonPlanHeader({
    required this.primaryColor,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.showTeacherList,
    required this.hasActiveFilter,
    required this.filterSummary,
    required this.menuKey,
    required this.searchKey,
    required this.filterKey,
    required this.searchController,
    required this.searchHint,
    required this.exportLabel,
    required this.updateDataLabel,
    required this.filterTooltip,
    required this.onBack,
    required this.onSearch,
    required this.onExport,
    required this.onRefresh,
    required this.onShowFilter,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: back, title/subtitle, popup menu
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
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
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: menuKey,
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      onExport();
                      break;
                    case 'refresh':
                      onRefresh();
                      break;
                  }
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                itemBuilder: (BuildContext context) => [
                  if (!showTeacherList)
                    PopupMenuItem<String>(
                      value: 'export',
                      child: Row(
                        children: [
                          const Icon(Icons.download, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(exportLabel),
                        ],
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                        const SizedBox(width: AppSpacing.sm),
                        Text(updateDataLabel),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Search bar + optional filter button
          Row(
            children: [
              Expanded(
                key: searchKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onSubmitted: (_) => onSearch(),
                          style: TextStyle(color: ColorUtils.slate800),
                          decoration: InputDecoration(
                            hintText: searchHint,
                            hintStyle: TextStyle(color: ColorUtils.slate400),
                            prefixIcon: Icon(Icons.search, color: ColorUtils.slate400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.search, color: primaryColor),
                          onPressed: onSearch,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!showTeacherList) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  key: filterKey,
                  decoration: BoxDecoration(
                    color: hasActiveFilter ? Colors.white : Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Stack(
                    children: [
                      IconButton(
                        onPressed: onShowFilter,
                        icon: Icon(Icons.tune, color: hasActiveFilter ? primaryColor : Colors.white),
                        tooltip: filterTooltip,
                      ),
                      if (hasActiveFilter)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: ColorUtils.error600,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Filter chips (RPP only)
          if (!showTeacherList && hasActiveFilter) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.all(Radius.circular(16)),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                filterSummary,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              GestureDetector(
                                onTap: onClearFilter,
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
