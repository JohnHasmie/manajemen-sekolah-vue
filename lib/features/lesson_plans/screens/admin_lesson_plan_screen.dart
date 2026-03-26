// Admin RPP (lesson plan) management screen.
//
// Like `pages/admin/lesson-plans.vue` - allows admins to review, approve, or reject
// teacher-submitted lesson plans (RPP). Uses drill-down: Teacher list -> RPP list.
// Supports pagination, status filtering, file download, and Excel export.
//
// In Laravel terms, this consumes RppController (GET /api/rpp, PATCH /api/rpp/{id}/approve).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/lesson_plans/exports/lesson_plan_export_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Admin lesson plan (RPP) review screen with drill-down navigation.
///
/// Optionally accepts [teacherId]/[teacherName] to skip the teacher selection step.
/// This is like a Vue page with optional route params (`/admin/rpp?teacherId=123`).
class AdminRppScreen extends ConsumerStatefulWidget {
  final String? teacherId;
  final String? teacherName;

  const AdminRppScreen({super.key, this.teacherId, this.teacherName});

  @override
  ConsumerState<AdminRppScreen> createState() => _AdminRppScreenState();
}

/// Mutable state for [AdminRppScreen].
///
/// Key state (like Vue `data()`):
/// - [_showTeacherList] - whether showing teacher list or RPP list (drill-down)
/// - [_rppList] / [_teacherList] - paginated data lists
/// - [_selectedStatusFilter] - filter by approval status (Pending/Approved/Rejected)
/// - Pagination state for infinite scroll
///
/// setState() triggers re-render like Vue's reactivity system.
class _AdminRppScreenState extends ConsumerState<AdminRppScreen> {
  List<dynamic> _rppList = [];
  List<dynamic> _teacherList = [];
  bool _showTeacherList = true;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _tourId;
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
          _loadRppPaginated();
        }
      }
    });

    // Check if we start with a specific teacher (e.g. from deeper navigation)
    if (widget.teacherId != null) {
      _showTeacherList = false;
      _selectedTeacherId = widget.teacherId;
      _selectedTeacherName = widget.teacherName;
      _loadRppPaginated(reset: true);
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
    List<String> filters = [];

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
                          Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
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
                    padding: EdgeInsets.all(20),
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
                            SizedBox(width: 8),
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
                        SizedBox(height: 12),
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
                  padding: EdgeInsets.all(16),
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
                            setState(() {
                              _selectedStatusFilter = tempSelectedStatus;
                            });
                            _checkActiveFilter();
                            AppNavigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getPrimaryColor(),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
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

  String? _buildRppCacheKey() {
    if (_currentPage != 1) return null;
    if (_selectedStatusFilter != null ||
        _searchController.text.trim().isNotEmpty) {
      return null;
    }
    final yearId = ref.read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString() ?? 'default';
    return 'rpp_list_${_selectedTeacherId}_$yearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('tour_rpp_screen_');
    if (_showTeacherList && widget.teacherId == null) {
      final cacheKey = _buildTeacherCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      _loadTeachersPaginated(reset: true, useCache: false);
    } else {
      final cacheKey = _buildRppCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      _loadRppPaginated(reset: true, useCache: false);
    }
  }

  Future<void> _exportToExcel() async {
    await ExcelRppService.exportRppToExcel(rppList: _rppList, context: context);
  }

  Future<void> _loadRppByTeacher() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _loadRppPaginated(reset: true, useCache: false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadAllRpp() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _loadRppPaginated(reset: true, useCache: false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadTeachersPaginated({bool reset = false, bool useCache = true}) async {
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

  Future<void> _loadRppPaginated({bool reset = false, bool useCache = true}) async {
    try {
      if (reset) {
        _currentPage = 1;
        _hasMoreData = true;
      }

      // Step 1: Try cache for instant display (only on reset/first load)
      if (useCache && reset) {
        final cacheKey = _buildRppCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                _rppList = cachedList;
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
      if (reset && _rppList.isEmpty && mounted) {
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

      final result = await ApiService.getLessonPlansPaginated(
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
              _rppList = data;
            } else {
              _rppList.addAll(data);
            }

            _hasMoreData =
                pagination['has_next_page'] ?? (data.length == _perPage);
            _isLoading = false;
            _isLoadingMore = false;
          });

          // Step 3: Save to cache (only page 1 default view, non-blocking)
          if (reset) {
            final cacheKey = _buildRppCacheKey();
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
            if (_rppList.isEmpty) {
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
          if (_rppList.isEmpty) {
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
      _rppList = [];
      _searchController.clear();
      _currentPage = 1;
    });
    _loadRppPaginated(reset: true);
  }

  void _backToTeacherList() {
    setState(() {
      _selectedTeacherId = null;
      _selectedTeacherName = null;
      _showTeacherList = true;
      _rppList = [];
      _searchController.clear();
      _currentPage = 1;
    });
    _loadTeachersPaginated(reset: true);
  }

  void _handleSearch() {
    if (_showTeacherList && widget.teacherId == null) {
      _loadTeachersPaginated(reset: true);
    } else {
      _loadRppPaginated(reset: true);
    }
  }

  void _updateStatus(String rppId, String status) {
    final rpp = _rppList.firstWhere((rpp) => rpp['id'] == rppId);
    showDialog(
      context: context,
      builder: (context) => UpdateStatusDialog(
        rppId: rppId,
        currentStatus: rpp['status'],
        currentNote: rpp['catatan'],
        onStatusUpdated: _loadAllRpp,
      ),
    );
  }

  void _viewRppDetail(Map<String, dynamic> rpp) async {
    await AppNavigator.push(context, RppAdminDetailPage(rpp: rpp));
    // Refresh list after returning
    if (_showTeacherList && _selectedTeacherName != null) {
      _loadRppByTeacher();
    } else if (!_showTeacherList) {
      _loadRppByTeacher(); // Or logic to reload current list
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return ColorUtils.success600;
      case 'Pending':
      case 'Menunggu':
        return ColorUtils.warning600;
      case 'Rejected':
      case 'Ditolak':
        return ColorUtils.error600;
      case 'Draft':
      case 'draft':
        return ColorUtils.info600;
      default:
        return ColorUtils.slate400;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return 'Disetujui';
      case 'Pending':
      case 'Menunggu':
        return 'Menunggu';
      case 'Draft':
      case 'draft':
        return 'Draft';
      case 'Rejected':
      case 'Ditolak':
        return 'Ditolak';
      default:
        return status ?? '-';
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

  Widget _buildInfoTag({
    required IconData icon,
    required String label,
    Color? tagColor,
  }) {
    final color = tagColor ?? ColorUtils.slate500;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
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

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildRppCard(Map<String, dynamic> rpp, int index) {
    final accentColor = ColorUtils.getColorForIndex(index);
    final statusColor = _getStatusColor(rpp['status'] ?? '');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewRppDetail(rpp),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon + title/subject + status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rpp['judul'] ?? rpp['title'] ?? 'No Title',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Text(
                            rpp['mata_pelajaran_nama'] ??
                                rpp['subject_name'] ??
                                'No Subject',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _getStatusLabel(rpp['status']),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),
                // Info tags: class + teacher
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildInfoTag(
                      icon: Icons.class_,
                      label:
                          rpp['kelas_nama'] ?? rpp['class_name'] ?? 'No Class',
                    ),
                    _buildInfoTag(
                      icon: Icons.person_outline,
                      label:
                          rpp['teacher_name'] ??
                          rpp['guru_nama'] ??
                          'No Teacher',
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildCircleActionButton(
                      icon: Icons.visibility_outlined,
                      color: _getPrimaryColor(),
                      onPressed: () => _viewRppDetail(rpp),
                    ),
                    SizedBox(width: 8),
                    _buildCircleActionButton(
                      icon: Icons.edit_outlined,
                      color: ColorUtils.warning600,
                      onPressed: () => _updateStatus(rpp['id'], rpp['status']),
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

  Widget _buildTeacherCard(Map<String, dynamic> teacher, int index) {
    final avatarColor = ColorUtils.getColorForIndex(index);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectTeacher(teacher),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    teacher['name'] != null &&
                            (teacher['name'] as String).isNotEmpty
                        ? (teacher['name'] as String)[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        teacher['employee_number'] != null
                            ? 'NIP: ${teacher['employee_number']}'
                            : 'No NIP',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: ColorUtils.slate400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
        if (_errorMessage != null) {
          return ErrorScreen(
            errorMessage: _errorMessage!,
            onRetry: _showTeacherList ? _loadTeachersPaginated : _loadAllRpp,
          );
        }

        // Apply filters for RPP list (Teacher list is filtered by backend)
        final filteredRpp = _rppList.where((rpp) {
          if (_showTeacherList) {
            return true; // Don't filter if showing teachers (not used)
          }

          final searchTerm = _searchController.text.toLowerCase();
          final matchesSearch =
              searchTerm.isEmpty ||
              (rpp['judul']?.toLowerCase().contains(searchTerm) ?? false) ||
              (rpp['mata_pelajaran_nama']?.toLowerCase().contains(searchTerm) ??
                  false) ||
              (rpp['teacher_name']?.toLowerCase().contains(searchTerm) ??
                  false) || // Updated to teacher_name
              (rpp['guru_nama']?.toLowerCase().contains(searchTerm) ??
                  false) || // Keep as fallback
              (rpp['kelas_nama']?.toLowerCase().contains(searchTerm) ?? false);

          // Status filter
          final matchesStatusFilter =
              _selectedStatusFilter == null ||
              rpp['status'] == _selectedStatusFilter;

          return matchesSearch && matchesStatusFilter;
        }).toList();

        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: Column(
            children: [
              // Header
              Container(
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
                      color: _getPrimaryColor().withValues(alpha: 0.3),
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
                          onTap: () {
                            if (_showTeacherList) {
                              AppNavigator.pop(context);
                            } else {
                              if (widget.teacherId != null) {
                                // Came from outside with fixed teacher
                                AppNavigator.pop(context);
                              } else {
                                // Navigate back to teacher list
                                _backToTeacherList();
                              }
                            }
                          },
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _showTeacherList
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
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_showTeacherList ||
                                  _selectedTeacherName == null)
                                SizedBox(height: 2),
                              if (_showTeacherList ||
                                  _selectedTeacherName == null)
                                Text(
                                  _showTeacherList
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Select a teacher to view RPP',
                                          'id': 'Pilih guru untuk melihat RPP',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Manage lesson plans',
                                          'id':
                                              'Kelola rencana pelaksanaan pembelajaran',
                                        }),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                            key: _menuKey,
                            onSelected: (value) {
                              switch (value) {
                                case 'export':
                                  _exportToExcel();
                                  break;
                                case 'refresh':
                                  _forceRefresh();
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
                              child: Icon(
                                Icons.more_vert,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            itemBuilder: (BuildContext context) => [
                              if (!_showTeacherList)
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
                          ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Search Bar
                    Row(
                      children: [
                        Expanded(
                          key: _searchKey,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onSubmitted: (_) => _handleSearch(),
                                    style: TextStyle(
                                      color: ColorUtils.slate800,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _showTeacherList
                                          ? languageProvider.getTranslatedText({
                                              'en': 'Search Teacher...',
                                              'id': 'Cari Guru...',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en': 'Search RPP...',
                                              'id': 'Cari RPP...',
                                            }),
                                      hintStyle: TextStyle(
                                        color: ColorUtils.slate400,
                                      ),
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
                                    onPressed: _handleSearch,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_showTeacherList) ...[
                          SizedBox(width: 8),
                          // Filter Button (RPP only)
                          Container(
                            key: _filterKey,
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
                      ],
                    ),

                    // Filter Chips (RPP only)
                    if (!_showTeacherList && _hasActiveFilter) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            Expanded(
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _buildFilterSummary(languageProvider),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _clearAllFilters,
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
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
                            padding: EdgeInsets.only(top: 16, bottom: 16),
                            itemCount:
                                filteredTeachers.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= filteredTeachers.length) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return _buildTeacherCard(
                                filteredTeachers[index],
                                index,
                              );
                            },
                          ),
                        );
                      })()
                    : (filteredRpp.isEmpty
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
                                padding: EdgeInsets.only(top: 16, bottom: 16),
                                itemCount:
                                    filteredRpp.length +
                                    (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= filteredRpp.length) {
                                    // loading indicator
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  final rpp = filteredRpp[index];
                                  return _buildRppCard(rpp, index);
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
      const tourCacheKey = 'tour_rpp_screen_admin';
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
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
        }
        LocalCacheService.save('tour_rpp_screen_admin', {'should_show': false});
      },
      onSkip: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
        }
        LocalCacheService.save('tour_rpp_screen_admin', {'should_show': false});
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
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

// ... (UpdateStatusDialog dan RppAdminDetailPage tetap sama seperti sebelumnya)
class UpdateStatusDialog extends ConsumerStatefulWidget {
  final String rppId;
  final String currentStatus;
  final String? currentNote;
  final VoidCallback onStatusUpdated;

  const UpdateStatusDialog({
    super.key,
    required this.rppId,
    required this.currentStatus,
    this.currentNote,
    required this.onStatusUpdated,
  });

  @override
  ConsumerState<UpdateStatusDialog> createState() => _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends ConsumerState<UpdateStatusDialog> {
  bool isUpdating = false;
  late TextEditingController catatanController;
  String selectedStatus = 'Pending';

  @override
  void initState() {
    super.initState();
    catatanController = TextEditingController(text: widget.currentNote ?? '');
    mapInitialStatus();
  }

  @override
  void dispose() {
    catatanController.dispose();
    super.dispose();
  }

  void mapInitialStatus() {
    // Map Indonesian/Display status to Backend/Value status
    String status = widget.currentStatus;
    if (status == 'Menunggu' || status == 'Pending') {
      selectedStatus = 'Pending';
    } else if (status == 'Disetujui' || status == 'Approved') {
      selectedStatus = 'Approved';
    } else if (status == 'Ditolak' || status == 'Rejected') {
      selectedStatus = 'Rejected';
    } else {
      selectedStatus = 'Pending';
    }
  }

  Color getPrimaryColor() => ColorUtils.getRoleColor('admin');

  Color getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return ColorUtils.success600;
      case 'Rejected':
        return ColorUtils.error600;
      case 'Pending':
      default:
        return ColorUtils.warning600;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle_outline;
      case 'Rejected':
        return Icons.cancel_outlined;
      case 'Pending':
      default:
        return Icons.access_time_rounded;
    }
  }

  Future<void> updateStatus() async {
    bool statusChanged = selectedStatus != widget.currentStatus;
    bool noteChanged = catatanController.text != (widget.currentNote ?? '');

    if (!statusChanged && !noteChanged) {
      AppNavigator.pop(context);
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      await ApiService.updateLessonPlanStatus(
        widget.rppId,
        selectedStatus,
        catatan: catatanController.text.isNotEmpty
            ? catatanController.text
            : null,
      );
      if (mounted) {
        AppNavigator.pop(context);
        widget.onStatusUpdated();
                SnackBarUtils.showSuccess(context, 'Status RPP berhasil diupdate');
      }
    } catch (e) {
      if (mounted) {
                SnackBarUtils.showError(context, 'Gagal mengupdate: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Widget buildStatusOption(String value, String label, Color color) {
    final isSelected = selectedStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedStatus = value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : ColorUtils.slate200,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : ColorUtils.slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  getStatusIcon(value),
                  size: 16,
                  color: isSelected ? color : ColorUtils.slate400,
                ),
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : ColorUtils.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = getPrimaryColor();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
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
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Status RPP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ubah status persetujuan RPP',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Form Content
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status label
                Text(
                  'Status Persetujuan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate700,
                  ),
                ),
                SizedBox(height: 10),
                // Status option chips
                Row(
                  children: [
                    buildStatusOption(
                      'Pending',
                      'Menunggu',
                      ColorUtils.warning600,
                    ),
                    SizedBox(width: 8),
                    buildStatusOption(
                      'Approved',
                      'Disetujui',
                      ColorUtils.success600,
                    ),
                    SizedBox(width: 8),
                    buildStatusOption(
                      'Rejected',
                      'Ditolak',
                      ColorUtils.error600,
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Catatan label
                Text(
                  'Catatan (Opsional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate700,
                  ),
                ),
                SizedBox(height: 8),
                // Styled text field
                Container(
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  child: TextField(
                    controller: catatanController,
                    maxLines: 3,
                    style: TextStyle(color: ColorUtils.slate900, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                      hintText: 'Berikan catatan untuk guru...',
                      hintStyle: TextStyle(
                        color: ColorUtils.slate400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer Buttons
          Container(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ColorUtils.slate100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isUpdating ? null : () => AppNavigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Batal',
                      style: TextStyle(color: ColorUtils.slate600),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isUpdating ? null : updateStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isUpdating
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Update Status',
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
  }
}

// Halaman Detail RPP untuk Admin
class RppAdminDetailPage extends StatelessWidget {
  final Map<String, dynamic> rpp;

  const RppAdminDetailPage({super.key, required this.rpp});
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(rpp['status'] ?? '');

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Pattern #7 Inline Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  getPrimaryColor(),
                  getPrimaryColor().withValues(alpha: 0.85),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
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
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail RPP',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if ((rpp['judul'] ?? rpp['title'] ?? '').isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          rpp['judul'] ?? rpp['title'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton(
                  onSelected: (value) {
                    if (value == 'approve') {
                      showUpdateStatusDialog(context, 'Disetujui');
                    } else if (value == 'reject') {
                      showUpdateStatusDialog(context, 'Ditolak');
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
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'approve',
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: ColorUtils.success600,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text('Setujui RPP'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reject',
                      child: Row(
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            color: ColorUtils.error600,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text('Tolak RPP'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rpp['judul'] ?? rpp['title'] ?? '-',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                getStatusLabelDetail(rpp['status']),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Informasi Detail
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi RPP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.slate600,
                          ),
                        ),
                        SizedBox(height: 12),
                        buildDetailItem(
                          'Guru Pengajar',
                          rpp['teacher_name'] ?? rpp['teacher']?['name'] ?? '-',
                        ),
                        buildDetailItem(
                          'Mata Pelajaran',
                          rpp['subject_name'] ??
                              rpp['mata_pelajaran_nama'] ??
                              '-',
                        ),
                        buildDetailItem(
                          'Kelas',
                          rpp['class_name'] ?? rpp['kelas_nama'] ?? '-',
                        ),
                        buildDetailItem(
                          'Tahun Ajaran',
                          '${rpp['academic_year'] ?? rpp['tahun_ajaran'] ?? '-'}',
                        ),
                        buildDetailItem('Semester', rpp['semester'] ?? '-'),
                        buildDetailItem(
                          'Tanggal Dibuat',
                          rpp['created_at']?.toString().substring(0, 10) ?? '-',
                        ),
                        if (rpp['catatan'] != null &&
                            rpp['catatan'].toString().isNotEmpty)
                          buildDetailItem('Catatan', rpp['catatan']),

                        if (rpp['catatan_admin'] != null) ...[
                          SizedBox(height: 8),
                          Divider(),
                          SizedBox(height: 8),
                          Text(
                            'Catatan Admin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            rpp['catatan_admin']!,
                            style: TextStyle(
                              fontSize: 14,
                              color: ColorUtils.slate600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Isi RPP
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Isi RPP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.slate600,
                          ),
                        ),
                        SizedBox(height: 12),
                        buildContentSection(
                          'Kompetensi Inti',
                          rpp['core_competence'],
                        ),
                        buildContentSection(
                          'Kompetensi Dasar',
                          rpp['basic_competence'],
                        ),
                        buildContentSection('Indikator', rpp['indicator']),
                        buildContentSection(
                          'Tujuan Pembelajaran',
                          rpp['learning_objective'],
                        ),
                        buildContentSection(
                          'Materi Pokok',
                          rpp['main_material'],
                        ),
                        buildContentSection(
                          'Metode Pembelajaran',
                          rpp['learning_method'],
                        ),
                        buildContentSection('Media/Alat', rpp['media_tools']),
                        buildContentSection(
                          'Sumber Belajar',
                          rpp['learning_source'],
                        ),
                        buildContentSection(
                          'Langkah-langkah Pembelajaran',
                          rpp['learning_activities'],
                        ),
                        buildContentSection('Penilaian', rpp['assessment']),
                      ],
                    ),
                  ),

                  // File Attachment
                  if (rpp['file_path'] != null) ...[
                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ColorUtils.slate200),
                        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lampiran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate600,
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () =>
                                downloadAndOpenFile(context, rpp['file_path']),
                            icon: Icon(Icons.download),
                            label: Text('Download RPP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getStatusLabelDetail(String? status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return 'Disetujui';
      case 'Pending':
      case 'Menunggu':
        return 'Menunggu';
      case 'Draft':
      case 'draft':
        return 'Draft';
      case 'Rejected':
      case 'Ditolak':
        return 'Ditolak';
      default:
        return status ?? '-';
    }
  }

  void showUpdateStatusDialog(BuildContext context, String status) {
    showDialog(
      context: context,
      builder: (context) => UpdateStatusDialog(
        rppId: rpp['id'],
        currentStatus: rpp['status'],
        currentNote: rpp['catatan'],
        onStatusUpdated: () {
          AppNavigator.pop(context); // Kembali ke list
        },
      ),
    );
  }

  Widget buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate600,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(value, style: TextStyle(color: ColorUtils.slate700)),
          ),
        ],
      ),
    );
  }

  Widget buildContentSection(String title, String? content) {
    if (content == null || content.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate800,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Text(
              content,
              style: TextStyle(color: ColorUtils.slate800, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> downloadAndOpenFile(
    BuildContext context,
    String? filePath,
  ) async {
    if (filePath == null) return;

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mengunduh file...')));

      // Create proper URL
      // ApiService.baseUrl usually ends with /api
      // We need base URL without /api
      final baseUrlBase = ApiService.baseUrl.replaceAll('/api', '');
      String fileUrl;
      if (filePath.startsWith('http')) {
        fileUrl = filePath;
      } else {
        fileUrl = '$baseUrlBase/storage/$filePath';
      }

      AppLogger.debug('lesson_plan', 'Downloading from: $fileUrl');

      final dio = Dio();
      final response = await dio.get<List<int>>(
        fileUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = filePath.split('/').last;
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(response.data ?? []);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
            SnackBarUtils.showInfo(context, 'Download berhasil! Membuka file...');

      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done) {
                SnackBarUtils.showInfo(context, 'Gagal membuka file: ${result.message}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengunduh file: $e')));
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return ColorUtils.success600;
      case 'Pending':
      case 'Menunggu':
        return ColorUtils.warning600;
      case 'Rejected':
      case 'Ditolak':
        return ColorUtils.error600;
      case 'Draft':
      case 'draft':
        return ColorUtils.info600;
      default:
        return ColorUtils.slate400;
    }
  }
}
