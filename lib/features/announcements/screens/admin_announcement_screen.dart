// Admin announcement management screen - CRUD for school announcements.
//
// Like `pages/admin/announcements.vue` - manages school-wide announcements
// with create, read, update, delete operations. Supports file attachments,
// priority levels, target audience filtering, and infinite scroll pagination.
//
// In Laravel terms, this consumes the AnnouncementController endpoints
// (GET /api/announcements, POST /api/announcements, etc.).
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/announcements/services/announcement_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Admin announcement management screen.
///
/// This is a [StatefulWidget] - like a Vue page component with its own local state
/// (`data() { return { announcements: [], isLoading: true, ... } }`).
class AdminAnnouncementScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementScreen({super.key});

  @override
  AdminAnnouncementScreenState createState() => AdminAnnouncementScreenState();
}

/// The mutable state for [AdminAnnouncementScreen].
///
/// Key state variables (like Vue `data()` properties):
/// - [_announcements] - paginated list of announcement objects
/// - [_isLoading] / [_isLoadingMore] - loading states for initial load vs infinite scroll
/// - [_currentPage] / [_hasMoreData] - pagination tracking (like Laravel's `paginate()`)
/// - [_selectedPriorityFilter] / [_selectedTargetFilter] / [_selectedStatusFilter] - filter states
/// - [_searchController] - search input with debounce (like Vue `watch` with debounce)
///
/// Implements auto-mark-as-read with debounced batching: when announcements scroll
/// into view, they're batched and sent to the API after 1 second of inactivity.
///
/// setState() is like Vue's reactivity - triggers a re-render when data changes.
class AdminAnnouncementScreenState extends ConsumerState<AdminAnnouncementScreen> {
  final ApiService _apiService = ApiService();
  File? _selectedFile;
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  // Search dan filter
  final TextEditingController _searchController = TextEditingController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Filter States (Backend filtering)
  String? _selectedPriorityFilter; // 'Important', 'Normal', or null for all
  String?
  _selectedTargetFilter; // 'Teacher', 'Student', 'Parent', 'All', or null
  String? _selectedStatusFilter; // 'Active', 'Scheduled', 'Expired', or null
  bool _hasActiveFilter = false;

  // Search debounce
  Timer? _searchDebounce;

  // Tour Keys
  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  String? _tourId;

  /// Like Vue's `mounted()` lifecycle hook.
  /// Sets up scroll listener for infinite scroll, search debounce,
  /// loads filter options, and fetches initial announcement data.
  @override
  void initState() {
    super.initState();

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // Listen to search changes with debounce
    _searchController.addListener(_onSearchChanged);

    _loadFilterOptions();
    _loadData();
  }

  final Set<String> _processedIds = {}; // IDs we've already handled/queued
  final Set<String> _pendingReadIds = {}; // IDs waitng to be sent to API
  Timer? _markReadDebounce;

  /// Like Vue's `beforeUnmount()` / `unmounted()` lifecycle hook.
  /// Cleans up controllers and cancels pending timers to prevent memory leaks.
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel(); // Cancel search debounce
    _markReadDebounce?.cancel(); // Cancel visibility debounce
    super.dispose();
  }

  void _onItemVisible(Map<String, dynamic> announcement) {
    final id = announcement['id'].toString();
    final isRead =
        announcement['is_read'] == null ||
        announcement['is_read'] == true ||
        announcement['is_read'] == 1 ||
        announcement['is_read'] == '1';

    if (!isRead && !_processedIds.contains(id)) {
      _processedIds.add(id);
      _pendingReadIds.add(id);
      _scheduleMarkRead();
    }
  }

  void _scheduleMarkRead() {
    if (_markReadDebounce?.isActive ?? false) return;

    _markReadDebounce = Timer(const Duration(seconds: 1), () {
      if (_pendingReadIds.isNotEmpty) {
        final idsToMark = _pendingReadIds.toList();
        _pendingReadIds.clear(); // Clear pending first to avoid duplicates
        _flushMarkRead(idsToMark);
      }
    });
  }

  Future<void> _flushMarkRead(List<String> ids) async {
    try {
      AppLogger.debug('announcement', 'Admin Auto-marking ${ids.length} visible announcements as read...',);

      // Optimistic Update (update local list UI immediately)
      setState(() {
        for (var item in _announcements) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await ApiService.markAnnouncementRead(ids);
    } catch (e) {
      AppLogger.error('announcement', "Error auto-marking read: $e");
    }
  }

  String? _buildAnnouncementCacheKey() {
    if (_currentPage != 1) return null;
    if (_selectedPriorityFilter != null ||
        _selectedTargetFilter != null ||
        _selectedStatusFilter != null ||
        _searchController.text.trim().isNotEmpty) {
      return null;
    }
    return 'announcement_list';
  }

  /// Invalidates cache and reloads data from API. Like a Vue method for manual refresh.
  Future<void> _forceRefresh() async {
    final cacheKey = _buildAnnouncementCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_announcement_');
    await LocalCacheService.invalidate('announcement_filter_options');
    _loadData(resetPage: true, useCache: false);
  }

  /// Detects when user scrolls near the bottom to trigger loading more items.
  /// This implements "infinite scroll" - like a Vue `@scroll` handler or
  /// an Intersection Observer that loads more data when reaching the bottom.
  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreAnnouncements();
      }
    }
  }

  /// Debounced search handler - waits 500ms after typing stops before searching.
  /// Like a Vue `watch` on a search input with `debounce: 500`.
  void _onSearchChanged() {
    // Manual search triggered by button/enter
  }

  void _handleSearch() {
    setState(() {
      _currentPage = 1;
    });
    _loadData();
  }

  /// Loads available filter options (priorities, targets, statuses) from the API.
  /// Like fetching dropdown options in a Vue `mounted()` to populate `<select>` elements.
  Future<void> _loadFilterOptions() async {
    try {
      // ─── Cache-first: return early on hit ───
      const cacheKey = 'announcement_filter_options';
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null && mounted) {
          AppLogger.info('announcement', 'Announcement filter options loaded from cache');
          return;
        }
      } catch (e) {
        AppLogger.error('announcement', 'Announcement filter cache load failed: $e');
      }

      final response =
          await getIt<ApiAnnouncementService>().getAnnouncementFilterOptions();

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        // Non-blocking cache save
        LocalCacheService.save(cacheKey, {
          'prioritas_options': response['data']['prioritas_options'] ?? [],
          'target_options': response['data']['target_options'] ?? [],
          'status_options': response['data']['status_options'] ?? [],
        });
        AppLogger.info('announcement', 'Announcement filter options loaded');
      }
    } catch (e) {
      AppLogger.error('announcement', 'Error loading announcement filter options: $e');
      // Continue with empty options - not critical error
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedPriorityFilter != null ||
          _selectedTargetFilter != null ||
          _selectedStatusFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedPriorityFilter = null;
      _selectedTargetFilter = null;
      _selectedStatusFilter = null;
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

    if (_selectedPriorityFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Priority', 'id': 'Prioritas'})}: $_selectedPriorityFilter',
        'onRemove': () {
          setState(() {
            _selectedPriorityFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedTargetFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Target', 'id': 'Target'})}: $_selectedTargetFilter',
        'onRemove': () {
          setState(() {
            _selectedTargetFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedStatusFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $_selectedStatusFilter',
        'onRemove': () {
          setState(() {
            _selectedStatusFilter = null;
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
    String? tempSelectedPrioritas = _selectedPriorityFilter;
    String? tempSelectedTarget = _selectedTargetFilter;
    String? tempSelectedStatus = _selectedStatusFilter;

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
              // --- Pattern #11 Gradient Header ---
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getPrimaryColor(),
                      _getPrimaryColor().withValues(alpha: 0.8),
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
                          tempSelectedPrioritas = null;
                          tempSelectedTarget = null;
                          tempSelectedStatus = null;
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

              // --- Filter Content ---
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Priority Filter
                      Row(
                        children: [
                          Icon(
                            Icons.priority_high,
                            size: 16,
                            color: ColorUtils.slate600,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Priority',
                              'id': 'Prioritas',
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
                        children: ['Penting', 'Biasa'].map((prioritas) {
                          final isSelected = tempSelectedPrioritas == prioritas;
                          return FilterChip(
                            label: Text(prioritas),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedPrioritas = selected
                                    ? prioritas
                                    : null;
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: _getPrimaryColor().withValues(
                              alpha: 0.15,
                            ),
                            checkmarkColor: _getPrimaryColor(),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getPrimaryColor()
                                  : ColorUtils.slate700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
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
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 20),

                      // Target Filter
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 16,
                            color: ColorUtils.slate600,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Target',
                              'id': 'Target',
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
                                'value': 'Semua',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                              },
                              {
                                'value': 'Guru',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Teachers',
                                  'id': 'Guru',
                                }),
                              },
                              {
                                'value': 'Siswa',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Students',
                                  'id': 'Siswa',
                                }),
                              },
                              {
                                'value': 'Orang Tua',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Parents',
                                  'id': 'Orang Tua',
                                }),
                              },
                            ].map((item) {
                              final isSelected =
                                  tempSelectedTarget == item['value'];
                              return FilterChip(
                                label: Text(item['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempSelectedTarget = selected
                                        ? item['value']
                                        : null;
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: _getPrimaryColor().withValues(
                                  alpha: 0.15,
                                ),
                                checkmarkColor: _getPrimaryColor(),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
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
                              );
                            }).toList(),
                      ),

                      SizedBox(height: 20),

                      // Status Filter
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: ColorUtils.slate600,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Status',
                              'id': 'Status',
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
                                'value': 'Aktif',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Active',
                                  'id': 'Aktif',
                                }),
                              },
                              {
                                'value': 'Terjadwal',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Scheduled',
                                  'id': 'Terjadwal',
                                }),
                              },
                              {
                                'value': 'Kedaluwarsa',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Expired',
                                  'id': 'Kedaluwarsa',
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
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
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
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Pattern #11 Footer ---
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
                            _selectedPriorityFilter = tempSelectedPrioritas;
                            _selectedTargetFilter = tempSelectedTarget;
                            _selectedStatusFilter = tempSelectedStatus;
                          });
                          _checkActiveFilter();
                          Navigator.pop(context);
                          _loadData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
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

  /// Loads announcements from the API with pagination, search, and filters.
  /// Like calling `GET /api/announcements?page=1&search=...&status=...` in Vue.
  /// Uses cache-first pattern: shows cached data instantly, then refreshes from API.
  /// In Laravel terms, this is like `Announcement::paginate(10)->filter(...)`.
  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    try {
      if (resetPage) {
        _currentPage = 1;
        _hasMoreData = true;
        _errorMessage = null;
        _processedIds.clear();
      }

      // Step 1: Try cache for instant display
      if (useCache && resetPage) {
        final cacheKey = _buildAnnouncementCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                _announcements = cachedList;
                _hasMoreData = cached['pagination']?['has_next_page'] ?? false;
                _isLoading = false;
              });
              AppLogger.info('announcement', 'Announcements loaded from cache');
              // Cache hit → return early, no background API refresh
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _checkAndShowTour();
              });
              return;
            }
          }
        }
      }

      // Show skeleton only if list is empty
      if (_announcements.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Step 2: Fetch fresh from API
      // Map display values to backend values
      String? mappedPrioritas;
      if (_selectedPriorityFilter != null) {
        if (_selectedPriorityFilter == 'Penting' ||
            _selectedPriorityFilter == 'Important') {
          mappedPrioritas = 'important';
        } else if (_selectedPriorityFilter == 'Biasa' ||
            _selectedPriorityFilter == 'Normal') {
          mappedPrioritas = 'normal';
        } else {
          mappedPrioritas = _selectedPriorityFilter!.toLowerCase();
        }
      }

      String? mappedRoleTarget;
      if (_selectedTargetFilter != null) {
        switch (_selectedTargetFilter) {
          case 'Semua':
          case 'All':
            mappedRoleTarget = 'all';
            break;
          case 'Guru':
          case 'Teachers':
            mappedRoleTarget = 'teacher';
            break;
          case 'Siswa':
          case 'Students':
            mappedRoleTarget = 'student';
            break;
          case 'Orang Tua':
          case 'Parents':
            mappedRoleTarget = 'parent';
            break;
          default:
            mappedRoleTarget = _selectedTargetFilter!.toLowerCase();
        }
      }

      String? mappedStatus;
      if (_selectedStatusFilter != null) {
        switch (_selectedStatusFilter) {
          case 'Aktif':
          case 'Active':
            mappedStatus = 'aktif';
            break;
          case 'Terjadwal':
          case 'Scheduled':
            mappedStatus = 'terjadwal';
            break;
          case 'Kedaluwarsa':
          case 'Expired':
            mappedStatus = 'kedaluwarsa';
            break;
          default:
            mappedStatus = _selectedStatusFilter!.toLowerCase();
        }
      }

      // Load with pagination and backend filtering
      final response = await getIt<ApiAnnouncementService>().getAnnouncementsPaginated(
        page: _currentPage,
        limit: _perPage,
        prioritas: mappedPrioritas,
        roleTarget: mappedRoleTarget,
        status: mappedStatus,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      // Check if response has the expected structure
      if (response.containsKey('data') && response.containsKey('pagination')) {
        var fetchedList = response['data'] ?? [];

        setState(() {
          _announcements = fetchedList;
          _hasMoreData = response['pagination']?['has_next_page'] ?? false;
          _isLoading = false;
          _errorMessage = null;
        });

        // Step 3: Save to cache (non-blocking)
        final cacheKey = _buildAnnouncementCacheKey();
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {
            'data': fetchedList,
            'pagination': response['pagination'],
          });
        }
      } else {
        AppLogger.error('announcement', 'Unexpected response structure');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unexpected response structure';
        });
      }
    } catch (e) {
      if (!mounted) return;

      // Only show error if we don't have cached data
      if (_announcements.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ref.read(languageRiverpod).getTranslatedText({'en': 'Gagal memuat data pengumuman', 'id': 'Gagal memuat data pengumuman'})}: ${ErrorUtils.getFriendlyMessage(e)}',
          ),
          backgroundColor: ColorUtils.error600,
        ),
      );
    } finally {
      // Trigger tour after initial load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    }
  }

  /// Loads the next page of announcements for infinite scroll.
  /// Like incrementing `page` param in a Vue API call when user scrolls to bottom.
  Future<void> _loadMoreAnnouncements() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      // Map display values to backend values (same logic as _loadData)
      String? mappedPrioritas;
      if (_selectedPriorityFilter != null) {
        if (_selectedPriorityFilter == 'Penting' ||
            _selectedPriorityFilter == 'Important') {
          mappedPrioritas = 'important';
        } else if (_selectedPriorityFilter == 'Biasa' ||
            _selectedPriorityFilter == 'Normal') {
          mappedPrioritas = 'normal';
        } else {
          mappedPrioritas = _selectedPriorityFilter!.toLowerCase();
        }
      }

      String? mappedRoleTarget;
      if (_selectedTargetFilter != null) {
        switch (_selectedTargetFilter) {
          case 'Semua':
          case 'All':
            mappedRoleTarget = 'all';
            break;
          case 'Guru':
          case 'Teachers':
            mappedRoleTarget = 'teacher';
            break;
          case 'Siswa':
          case 'Students':
            mappedRoleTarget = 'student';
            break;
          case 'Orang Tua':
          case 'Parents':
            mappedRoleTarget = 'parent';
            break;
          default:
            mappedRoleTarget = _selectedTargetFilter!.toLowerCase();
        }
      }

      String? mappedStatus;
      if (_selectedStatusFilter != null) {
        switch (_selectedStatusFilter) {
          case 'Aktif':
          case 'Active':
            mappedStatus = 'aktif';
            break;
          case 'Terjadwal':
          case 'Scheduled':
            mappedStatus = 'terjadwal';
            break;
          case 'Kedaluwarsa':
          case 'Expired':
            mappedStatus = 'kedaluwarsa';
            break;
          default:
            mappedStatus = _selectedStatusFilter!.toLowerCase();
        }
      }

      final response = await getIt<ApiAnnouncementService>().getAnnouncementsPaginated(
        page: _currentPage,
        limit: _perPage,
        prioritas: mappedPrioritas,
        roleTarget: mappedRoleTarget,
        status: mappedStatus,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      if (response.containsKey('data') && response.containsKey('pagination')) {
        var newItems = response['data'] ?? [];

        // Keep all items (including read ones) as per user request
        if (newItems is List) {
          // No filtering
        }

        setState(() {
          if (newItems is List) {
            _announcements.addAll(newItems);
          }
          _hasMoreData = response['pagination']?['has_next_page'] ?? false;
          _isLoadingMore = false;
        });
      } else {
        AppLogger.error('announcement', 'Unexpected response structure for _loadMoreAnnouncements');
        setState(() {
          _isLoadingMore = false;
          _currentPage--; // Revert page increment on error
        });
      }

      // Removed eager marking
      // if (response['data'] != null && (response['data'] as List).isNotEmpty) {
      //   _markAnnouncementsAsRead(response['data']);
      // }

      AppLogger.info('announcement', 'Loaded more announcements: Page $_currentPage, Total: ${_announcements.length}',);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });

      AppLogger.error('announcement', 'Error loading more announcements: $e');
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? announcementData}) {
    final judulController = TextEditingController(
      text: announcementData?['title'] ?? '',
    );
    final kontenController = TextEditingController(
      text: announcementData?['content'] ?? '',
    );
    String? selectedClassId = announcementData?['kelas_id'];
    String? selectedRole = announcementData?['role_target'] ?? 'all';
    String? rawPrioritas = announcementData?['priority'];
    String? selectedPrioritas;
    if (rawPrioritas != null) {
      if (rawPrioritas.toLowerCase() == 'biasa') {
        selectedPrioritas = 'normal';
      } else if (rawPrioritas.toLowerCase() == 'penting') {
        selectedPrioritas = 'important';
      } else {
        selectedPrioritas = rawPrioritas.toLowerCase();
      }
    } else {
      selectedPrioritas = 'normal';
    }
    DateTime? tanggalAwal = announcementData?['start_date'] != null
        ? DateTime.parse(announcementData!['start_date'])
        : null;
    DateTime? tanggalAkhir = announcementData?['end_date'] != null
        ? DateTime.parse(announcementData!['end_date'])
        : null;

    final isEdit = announcementData != null;
    _selectedFile = null; // Reset selected file

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
                        // --- Pattern #13 Gradient Header ---
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _getPrimaryColor(),
                                _getPrimaryColor().withValues(alpha: 0.8),
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
                                      : Icons.announcement_rounded,
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
                                              'en': 'Edit Announcement',
                                              'id': 'Edit Pengumuman',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en': 'Add Announcement',
                                              'id': 'Tambah Pengumuman',
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
                                              'en':
                                                  'Update announcement information',
                                              'id':
                                                  'Perbarui informasi pengumuman',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en':
                                                  'Fill in announcement details',
                                              'id': 'Isi detail pengumuman',
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
                                onTap: () => Navigator.pop(context),
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

                        // --- Scrollable Form Body ---
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDialogTextField(
                                  controller: judulController,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Title',
                                    'id': 'Judul',
                                  }),
                                  icon: Icons.title,
                                ),
                                SizedBox(height: 12),
                                _buildDialogTextField(
                                  controller: kontenController,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Content',
                                    'id': 'Konten',
                                  }),
                                  icon: Icons.description,
                                  maxLines: 4,
                                ),
                                SizedBox(height: 12),
                                _buildPrioritasDropdown(
                                  value: selectedPrioritas,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedPrioritas = value;
                                    });
                                  },
                                  languageProvider: languageProvider,
                                ),
                                SizedBox(height: 12),
                                _buildRoleTargetDropdown(
                                  value: selectedRole,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedRole = value;
                                    });
                                  },
                                  languageProvider: languageProvider,
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDateField(
                                        label: languageProvider
                                            .getTranslatedText({
                                              'en': 'Start Date',
                                              'id': 'Tanggal Mulai',
                                            }),
                                        value: tanggalAwal,
                                        onTap: () =>
                                            _selectDate(context, true, (date) {
                                              setDialogState(() {
                                                tanggalAwal = date;
                                              });
                                            }),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDateField(
                                        label: languageProvider
                                            .getTranslatedText({
                                              'en': 'End Date',
                                              'id': 'Tanggal Berakhir',
                                            }),
                                        value: tanggalAkhir,
                                        onTap: () =>
                                            _selectDate(context, false, (date) {
                                              setDialogState(() {
                                                tanggalAkhir = date;
                                              });
                                            }),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildFilePicker(
                                  setDialogState,
                                  languageProvider,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- Enhanced Footer ---
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
                                  onPressed: () => Navigator.pop(context),
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
                                    final judul = judulController.text.trim();
                                    final konten = kontenController.text.trim();

                                    if (judul.isEmpty || konten.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            languageProvider.getTranslatedText({
                                              'en':
                                                  'Title and content must be filled',
                                              'id':
                                                  'Judul dan konten harus diisi',
                                            }),
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      final Map<String, String> data = {
                                        'title': judulController.text,
                                        'content': kontenController.text,
                                        'role_target': selectedRole ?? 'all',
                                        'priority':
                                            selectedPrioritas ?? 'normal',
                                        'type': 'general',
                                      };

                                      if (selectedClassId != null) {
                                        data['class_id'] = selectedClassId;
                                      }
                                      if (tanggalAwal != null) {
                                        data['start_date'] = tanggalAwal!
                                            .toIso8601String();
                                      }
                                      if (tanggalAkhir != null) {
                                        data['end_date'] = tanggalAkhir!
                                            .toIso8601String();
                                      }

                                      if (isEdit) {
                                        await getIt<ApiAnnouncementService>().updateAnnouncement(
                                          announcementData['id'],
                                          data,
                                          _selectedFile,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                languageProvider.getTranslatedText({
                                                  'en':
                                                      'Announcement successfully updated',
                                                  'id':
                                                      'Pengumuman berhasil diperbarui',
                                                }),
                                              ),
                                              backgroundColor:
                                                  ColorUtils.success600,
                                            ),
                                          );
                                          Navigator.pop(context);
                                        }
                                      } else {
                                        await getIt<ApiAnnouncementService>().createAnnouncement(
                                          data,
                                          _selectedFile,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                languageProvider.getTranslatedText({
                                                  'en':
                                                      'Announcement successfully added',
                                                  'id':
                                                      'Pengumuman berhasil ditambahkan',
                                                }),
                                              ),
                                              backgroundColor:
                                                  ColorUtils.success600,
                                            ),
                                          );
                                          Navigator.pop(context);
                                        }
                                      }
                                      _loadData(resetPage: true, useCache: false);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              languageProvider.getTranslatedText({
                                                'en':
                                                    'Failed to save announcement: $e',
                                                'id':
                                                    'Gagal menyimpan pengumuman: $e',
                                              }),
                                            ),
                                            backgroundColor:
                                                ColorUtils.error600,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getPrimaryColor(),
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    elevation: 2,
                                    shadowColor: _getPrimaryColor().withValues(
                                      alpha: 0.4,
                                    ),
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
                                        : languageProvider.getTranslatedText({
                                            'en': 'Save',
                                            'id': 'Simpan',
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
            },
          );
        },
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
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
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _getPrimaryColor(), width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPrioritasDropdown({
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
            'en': 'Priority',
            'id': 'Prioritas',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(
            Icons.priority_high,
            color: _getPrimaryColor(),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          DropdownMenuItem(
            value: 'normal',
            child: Row(
              children: [
                Icon(Icons.circle, color: ColorUtils.slate400, size: 16),
                SizedBox(width: 8),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Normal',
                    'id': 'Biasa',
                  }),
                ),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'important',
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Important',
                    'id': 'Penting',
                  }),
                ),
              ],
            ),
          ),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }

  Widget _buildRoleTargetDropdown({
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
            'en': 'Target Role',
            'id': 'Role Target',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(Icons.people, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'All Users',
                'id': 'Semua Pengguna',
              }),
            ),
          ),
          DropdownMenuItem(value: 'admin', child: Text('Admin')),
          DropdownMenuItem(value: 'teacher', child: Text('Guru')),
          DropdownMenuItem(value: 'student', child: Text('Siswa')),
          DropdownMenuItem(value: 'parent', child: Text('Wali')),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: _getPrimaryColor(), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                value != null
                    ? '${value.day}/${value.month}/${value.year}'
                    : label,
                style: TextStyle(
                  color: value != null
                      ? ColorUtils.slate800
                      : ColorUtils.slate500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isStartDate,
    Function(DateTime) onDateSelected,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  /// Deletes an announcement after confirmation dialog.
  /// Like a Vue method calling `DELETE /api/announcements/{id}` with a confirm modal.
  Future<void> _deleteAnnouncement(
    Map<String, dynamic> announcementData,
  ) async {
    final languageProvider = ref.read(languageRiverpod);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Danger gradient header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.error600,
                    ColorUtils.error600.withValues(alpha: 0.8),
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
                      Icons.delete_outline,
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
                          languageProvider.getTranslatedText({
                            'en': 'Delete Announcement',
                            'id': 'Hapus Pengumuman',
                          }),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'This action cannot be undone',
                            'id': 'Tindakan ini tidak dapat dibatalkan',
                          }),
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
            // Message body
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                languageProvider.getTranslatedText({
                  'en':
                      'Are you sure you want to delete this announcement? All related data will be permanently removed.',
                  'id':
                      'Yakin ingin menghapus pengumuman ini? Semua data terkait akan dihapus secara permanen.',
                }),
                style: TextStyle(
                  fontSize: 14,
                  color: ColorUtils.slate700,
                  height: 1.5,
                ),
              ),
            ),
            // Footer buttons
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 13),
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: ColorUtils.error600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Delete',
                          'id': 'Hapus',
                        }),
                        style: TextStyle(fontWeight: FontWeight.bold),
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

    if (confirmed == true) {
      try {
        await _apiService.delete('/announcement/${announcementData['id']}');
        await _loadData(resetPage: true, useCache: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ref.read(languageRiverpod).getTranslatedText({
                  'en': 'Announcement successfully deleted',
                  'id': 'Pengumuman berhasil dihapus',
                }),
              ),
              backgroundColor: ColorUtils.success600,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ref.read(languageRiverpod).getTranslatedText({
                  'en': 'Failed to delete announcement: $e',
                  'id': 'Gagal menghapus pengumuman: $e',
                }),
              ),
              backgroundColor: ColorUtils.error600,
            ),
          );
        }
      }
    }
  }

  Widget _buildAnnouncementCard(
    Map<String, dynamic> announcementData,
    int index,
  ) {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = _getPrimaryColor();
    final isUnread =
        announcementData['is_read'] != null &&
        announcementData['is_read'] != true &&
        announcementData['is_read'] != 1 &&
        announcementData['is_read'] != '1';
    final isImportant = [
      'penting',
      'important',
    ].contains(announcementData['priority']);
    final accentColor = isImportant ? Colors.orange : primaryColor;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAnnouncementDetail(announcementData),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: colored icon container (like Pattern #8 avatar)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    isImportant
                        ? Icons.campaign_rounded
                        : Icons.announcement_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),

                // Middle: title + preview + info chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        announcementData['title'] ?? 'No Title',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3),
                      // Content preview
                      Text(
                        announcementData['content'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      // Info chips row
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _buildInfoTag(
                            Icons.access_time_outlined,
                            _formatDate(announcementData['created_at']),
                          ),
                          _buildInfoTag(
                            Icons.people_outline,
                            _getTargetText(announcementData, languageProvider),
                          ),
                          if (isImportant)
                            _buildInfoTag(
                              Icons.warning_amber_rounded,
                              languageProvider.getTranslatedText({
                                'en': 'Important',
                                'id': 'Penting',
                              }),
                              tagColor: Colors.orange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),

                // Right: unread dot + icon action buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: ColorUtils.error600,
                          shape: BoxShape.circle,
                        ),
                      ),
                    // Edit icon button
                    InkWell(
                      onTap: () => _showAddEditDialog(
                        announcementData: announcementData,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    // Delete icon button
                    InkWell(
                      onTap: () => _deleteAnnouncement(announcementData),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ColorUtils.error600.withValues(alpha: 0.1),
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
            ),
          ),
        ),
      ),
    );
  }

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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: c,
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

  void _showAnnouncementDetail(Map<String, dynamic> announcementData) {
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
              // Header dengan gradient
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.announcement,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            announcementData['title'] ?? 'No Title',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _formatDate(announcementData['created_at']),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Priority badge
                    if ([
                      'penting',
                      'important',
                    ].contains(announcementData['priority']))
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, size: 14, color: Colors.orange),
                            SizedBox(width: 6),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Important Announcement',
                                'id': 'Pengumuman Penting',
                              }),
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16),

                    // Content text
                    Text(
                      announcementData['content'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: ColorUtils.slate800,
                      ),
                    ),

                    SizedBox(height: 20),

                    // Attachment Section
                    if (announcementData['file_path'] != null) ...[
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Attachment',
                          'id': 'Lampiran',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate600,
                        ),
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () => _openFile(
                          _getFileUrl(announcementData['file_path']),
                          announcementData['file_name'] ?? 'attachment',
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorUtils.slate200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: ColorUtils.slate200,
                                  ),
                                ),
                                child: Icon(
                                  Icons.attach_file,
                                  color: _getPrimaryColor(),
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      announcementData['file_name'] ??
                                          languageProvider.getTranslatedText({
                                            'en': 'Download File',
                                            'id': 'Unduh File',
                                          }),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtils.slate800,
                                      ),
                                    ),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Tap to open',
                                        'id': 'Ketuk untuk membuka',
                                      }),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ColorUtils.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.download_rounded,
                                color: ColorUtils.slate400,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],

                    // Metadata
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.person,
                            label: languageProvider.getTranslatedText({
                              'en': 'Created by',
                              'id': 'Dibuat oleh',
                            }),
                            value:
                                announcementData['creator']?['name'] ??
                                announcementData['creator_name'] ??
                                'Unknown',
                          ),
                          SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.people,
                            label: languageProvider.getTranslatedText({
                              'en': 'Target Role',
                              'id': 'Role Target',
                            }),
                            value: _getTargetText(
                              announcementData,
                              languageProvider,
                            ),
                          ),
                          if (announcementData['start_date'] != null)
                            SizedBox(height: 8),
                          if (announcementData['start_date'] != null)
                            _buildDetailRow(
                              icon: Icons.calendar_today,
                              label: languageProvider.getTranslatedText({
                                'en': 'Start Date',
                                'id': 'Tanggal Mulai',
                              }),
                              value: _formatDate(
                                announcementData['start_date'],
                              ),
                            ),
                          if (announcementData['end_date'] != null)
                            SizedBox(height: 8),
                          if (announcementData['end_date'] != null)
                            _buildDetailRow(
                              icon: Icons.event_busy,
                              label: languageProvider.getTranslatedText({
                                'en': 'End Date',
                                'id': 'Tanggal Berakhir',
                              }),
                              value: _formatDate(announcementData['end_date']),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Close',
                            'id': 'Tutup',
                          }),
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
      ),
    );
  }

  String _getFileUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = ApiService.baseUrl.replaceAll('/api', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$base/storage/$cleanPath';
  }

  Future<void> _openFile(String url, String fileName) async {
    try {
      AppLogger.debug('announcement', 'Downloading file from: $url');

      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.data ?? []);

      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: ColorUtils.error600,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _getPrimaryColor()),
        SizedBox(width: 8),
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
    );
  }

  String _getTargetText(
    Map<String, dynamic> announcementData,
    LanguageProvider languageProvider,
  ) {
    final roleTarget = announcementData['role_target'] ?? 'all';
    final classNama = announcementData['class_name'];

    if (roleTarget == 'all' && classNama == null) {
      return languageProvider.getTranslatedText({
        'en': 'All Users',
        'id': 'Semua Pengguna',
      });
    } else if (classNama != null) {
      return '$classNama (${roleTarget.toUpperCase()})';
    } else {
      return roleTarget.toUpperCase();
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    // Use AppDateUtils for consistent date formatting with timezone handling
    final date = AppDateUtils.parseApiDate(dateString);
    if (date == null) return dateString;

    // Format as: dd/MM/yyyy HH:mm
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  Widget _buildFilePicker(
    StateSetter setDialogState,
    LanguageProvider languageProvider,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getTranslatedText({
              'en': 'Attachment (Optional)',
              'id': 'Lampiran (Opsional)',
            }),
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate600,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          if (_selectedFile != null)
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ColorUtils.slate300),
              ),
              child: Row(
                children: [
                  Icon(Icons.description, color: _getPrimaryColor(), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedFile!.path.split('/').last,
                      style: TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: ColorUtils.error600,
                      size: 20,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        _selectedFile = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
          if (_selectedFile == null)
            InkWell(
              onTap: () => _pickFile(setDialogState),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getPrimaryColor().withValues(alpha: 0.5),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: _getPrimaryColor(),
                      size: 24,
                    ),
                    SizedBox(height: 4),
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Tap to upload file',
                        'id': 'Ketuk untuk unggah file',
                      }),
                      style: TextStyle(
                        color: _getPrimaryColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'PDF, DOC, DOCX, JPG, PNG (Max 5MB)',
                      style: TextStyle(
                        color: ColorUtils.slate500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFile(StateSetter setDialogState) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        setDialogState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      AppLogger.error('announcement', 'Error picking file: $e');
    }
  }

  @override
  /// Main build method - like Vue's `<template>`.
  /// Renders the announcement list with search bar, filter chips, FAB for creating,
  /// and infinite scroll list of announcement cards.
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Announcement Management',
                                  'id': 'Manajemen Pengumuman',
                                }),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Manage and create announcements',
                                  'id': 'Kelola dan buat pengumuman',
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
                          onSelected: (value) {
                            if (value == 'refresh') {
                              _forceRefresh();
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
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Search Bar with Filter Button
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: _searchKey,
                                    controller: _searchController,
                                    // onChanged: (value) => setState(() {}), // Disabling this to prevent excessive rebuilds
                                    style: TextStyle(
                                      color: ColorUtils.slate800,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: languageProvider
                                          .getTranslatedText({
                                            'en': 'Search announcements...',
                                            'id': 'Cari pengumuman...',
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
                                    onSubmitted: (_) => _handleSearch(),
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
                        SizedBox(width: 8),
                        // Filter Button
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
                    ),

                    // Show active filters as chips
                    if (_hasActiveFilter) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        height: 36,
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
                                size: 16,
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
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        deleteIcon: Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white70,
                                        ),
                                        onDeleted: filter['onRemove'],
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.2),
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 0,
                                        ),
                                        labelPadding: EdgeInsets.only(left: 2),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
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
                                padding: EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: ColorUtils.error600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.clear_all,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? SkeletonListLoading(
                        padding: EdgeInsets.only(top: 8, bottom: 80),
                      )
                    : _errorMessage != null
                    ? ErrorScreen(
                        errorMessage: _errorMessage!,
                        onRetry: _loadData,
                      )
                    : _announcements.isEmpty
                    ? EmptyState(
                        icon: Icons.announcement_outlined,
                        title: languageProvider.getTranslatedText({
                          'en': 'No Announcements',
                          'id': 'Tidak Ada Pengumuman',
                        }),
                        subtitle: languageProvider.getTranslatedText({
                          'en': _searchController.text.isNotEmpty
                              ? 'No announcements found for your search'
                              : 'Start creating announcements to share information',
                          'id': _searchController.text.isNotEmpty
                              ? 'Tidak ada pengumuman yang sesuai dengan pencarian'
                              : 'Mulai buat pengumuman untuk berbagi informasi',
                        }),
                        buttonText: languageProvider.getTranslatedText({
                          'en': 'Create Announcement',
                          'id': 'Buat Pengumuman',
                        }),
                        onPressed: () => _showAddEditDialog(),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: _getPrimaryColor(),
                        backgroundColor: Colors.white,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount:
                              _announcements.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == _announcements.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _getPrimaryColor(),
                                ),
                              );
                            }

                            return Builder(
                              builder: (context) {
                                // Trigger visibility check
                                _onItemVisible(_announcements[index]);
                                return _buildAnnouncementCard(
                                  _announcements[index],
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

          // Floating Action Button
          floatingActionButton: FloatingActionButton(
            key: _addKey,
            onPressed: () => _showAddEditDialog(),
            backgroundColor: _getPrimaryColor(),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add),
          ),
        );
  }

  Future<void> _checkAndShowTour() async {
    try {
      const tourCacheKey = 'tour_announcement_admin';
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id'];
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('announcement', 'Error checking tour status: $e');
    }
  }

  void showTour() {
    List<TargetFocus> targets = createTourTargets();
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
          LocalCacheService.save('tour_announcement_admin', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_announcement_admin', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "AnnouncementAdd",
        keyTarget: _addKey,
        alignSkip: Alignment.bottomRight,
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
                      'en': 'Create Announcement',
                      'id': 'Buat Pengumuman',
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
                            'Tap here to create a new announcement for school users.',
                        'id':
                            'Ketuk di sini untuk membuat pengumuman baru bagi pengguna sekolah.',
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
        identify: "AnnouncementSearch",
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
                      'en': 'Search Announcements',
                      'id': 'Cari Pengumuman',
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
                            'Quickly find announcements by title or content keywords.',
                        'id':
                            'Temukan pengumuman dengan cepat berdasarkan judul atau kata kunci konten.',
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
        identify: "AnnouncementFilter",
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
                        'en':
                            'Narrow down announcements by priority, target role, or status.',
                        'id':
                            'Persempit pengumuman berdasarkan prioritas, peran target, atau status.',
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
