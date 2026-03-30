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

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_form_sheet.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_screen_header.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_list_content.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_filter_sheet.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_delete_dialog.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_detail_dialog.dart';
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
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/mixins/pagination_mixin.dart';

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
/// - [_isLoading] / [isLoadingMore] - loading states for initial load vs infinite scroll
/// - [currentPage] / [hasMoreData] - pagination tracking (like Laravel's `paginate()`)
/// - [_selectedPriorityFilter] / [_selectedTargetFilter] / [_selectedStatusFilter] - filter states
/// - [_searchController] - search input with debounce (like Vue `watch` with debounce)
///
/// Implements auto-mark-as-read with debounced batching: when announcements scroll
/// into view, they're batched and sent to the API after 1 second of inactivity.
///
/// setState() is like Vue's reactivity - triggers a re-render when data changes.
class AdminAnnouncementScreenState
    extends ConsumerState<AdminAnnouncementScreen>
    with PaginationMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search dan filter
  final TextEditingController _searchController = TextEditingController();

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

  /// Like Vue's `mounted()` lifecycle hook.
  /// Sets up scroll listener for infinite scroll, search debounce,
  /// loads filter options, and fetches initial announcement data.
  @override
  void initState() {
    super.initState();
    perPage = 10;
    initPagination();

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
    disposePagination();
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
      AppLogger.debug(
        'announcement',
        'Admin Auto-marking ${ids.length} visible announcements as read...',
      );

      // Optimistic Update (update local list UI immediately)
      setState(() {
        for (var item in _announcements) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await AnnouncementService.markAnnouncementRead(ids);
    } catch (e) {
      AppLogger.error('announcement', "Error auto-marking read: $e");
    }
  }

  String? _buildAnnouncementCacheKey() {
    if (currentPage != 1) return null;
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
    await LocalCacheService.invalidate(
      CacheKeyBuilder.custom('announcement', 'filter_options'),
    );
    _loadData(resetPage: true, useCache: false);
  }

  /// Debounced search handler - waits 500ms after typing stops before searching.
  /// Like a Vue `watch` on a search input with `debounce: 500`.
  void _onSearchChanged() {
    // Manual search triggered by button/enter
  }

  void _handleSearch() {
    setState(() {
      currentPage = 1;
    });
    _loadData();
  }

  /// Loads available filter options (priorities, targets, statuses) from the API.
  /// Like fetching dropdown options in a Vue `mounted()` to populate `<select>` elements.
  Future<void> _loadFilterOptions() async {
    try {
      // ─── Cache-first: return early on hit ───
      final cacheKey = CacheKeyBuilder.custom('announcement', 'filter_options');
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null && mounted) {
          AppLogger.info(
            'announcement',
            'Announcement filter options loaded from cache',
          );
          return;
        }
      } catch (e) {
        AppLogger.error(
          'announcement',
          'Announcement filter cache load failed: $e',
        );
      }

      final response = await getIt<ApiAnnouncementService>()
          .getAnnouncementFilterOptions();

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
      AppLogger.error(
        'announcement',
        'Error loading announcement filter options: $e',
      );
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
      currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData(); // Reload data setelah clear filters
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnnouncementFilterSheet(
        initialPriority: _selectedPriorityFilter,
        initialTarget: _selectedTargetFilter,
        initialStatus: _selectedStatusFilter,
        primaryColor: _getPrimaryColor(),
        languageProvider: languageProvider,
        onApply: (priority, target, status) {
          setState(() {
            _selectedPriorityFilter = priority;
            _selectedTargetFilter = target;
            _selectedStatusFilter = status;
          });
          _checkActiveFilter();
          _loadData();
        },
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
        currentPage = 1;
        hasMoreData = true;
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
                hasMoreData = cached['pagination']?['has_next_page'] ?? false;
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
      final response = await getIt<ApiAnnouncementService>()
          .getAnnouncementsPaginated(
            page: currentPage,
            limit: perPage,
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
        final fetchedList = response['data'] ?? [];

        setState(() {
          _announcements = fetchedList;
          hasMoreData = response['pagination']?['has_next_page'] ?? false;
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
      SnackBarUtils.showError(
        context,
        '${ref.read(languageRiverpod).getTranslatedText({'en': 'Gagal memuat data pengumuman', 'id': 'Gagal memuat data pengumuman'})}: ${ErrorUtils.getFriendlyMessage(e)}',
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

  /// PaginationMixin callback — loads the given page of announcements.
  /// The mixin handles isLoadingMore, currentPage++, and scroll detection.
  @override
  Future<void> loadPage(int page) async {
    try {
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

      final response = await getIt<ApiAnnouncementService>()
          .getAnnouncementsPaginated(
            page: page,
            limit: perPage,
            prioritas: mappedPrioritas,
            roleTarget: mappedRoleTarget,
            status: mappedStatus,
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
          );

      if (!mounted) return;

      if (response.containsKey('data') && response.containsKey('pagination')) {
        final newItems = response['data'] ?? [];

        setState(() {
          if (newItems is List) {
            _announcements.addAll(newItems);
          }
          updatePaginationFromMeta(response['pagination']);
        });
      } else {
        AppLogger.error(
          'announcement',
          'Unexpected response structure for loadPage',
        );
        setState(() {
          currentPage--; // Revert page increment on error
        });
      }

      AppLogger.info(
        'announcement',
        'Loaded more announcements: Page $page, Total: ${_announcements.length}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        currentPage--; // Revert page increment on error
      });

      AppLogger.error('announcement', 'Error loading more announcements: $e');
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? announcementData}) {
    final languageProvider = ref.watch(languageRiverpod);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AnnouncementFormSheet(
          announcementData: announcementData,
          primaryColor: _getPrimaryColor(),
          languageProvider: languageProvider,
          onSaved: () => _loadData(resetPage: true, useCache: false),
        );
      },
    );
  }

  /// Deletes an announcement after confirmation dialog.
  /// Like a Vue method calling `DELETE /api/announcements/{id}` with a confirm modal.
  Future<void> _deleteAnnouncement(
    Map<String, dynamic> announcementData,
  ) async {
    final languageProvider = ref.read(languageRiverpod);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AnnouncementDeleteDialog(
        languageProvider: languageProvider,
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.delete('/announcement/${announcementData['id']}');
        await _loadData(resetPage: true, useCache: false);
        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            ref.read(languageRiverpod).getTranslatedText({
              'en': 'Announcement successfully deleted',
              'id': 'Pengumuman berhasil dihapus',
            }),
          );
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(
            context,
            ref.read(languageRiverpod).getTranslatedText({
              'en': 'Failed to delete announcement: $e',
              'id': 'Gagal menghapus pengumuman: $e',
            }),
          );
        }
      }
    }
  }

  // _buildAnnouncementCard extracted → AnnouncementCard widget
  // _buildInfoTag extracted → AnnouncementInfoTag widget

  void _showAnnouncementDetail(Map<String, dynamic> announcementData) {
    final languageProvider = ref.read(languageRiverpod);

    showDialog(
      context: context,
      builder: (context) => AnnouncementDetailDialog(
        announcementData: announcementData,
        primaryColor: _getPrimaryColor(),
        cardGradient: _getCardGradient(),
        languageProvider: languageProvider,
        formatDate: _formatDate,
        getTargetText: (item) => _getTargetText(item, languageProvider),
        onOpenFile: (path, fileName) =>
            _openFile(_getFileUrl(path), fileName),
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
          SnackBarUtils.showError(
            context,
            'Could not open file: ${result.message}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error opening file: $e');
      }
    }
  }

  // _buildDetailRow extracted → AnnouncementDetailRow widget

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
          // Header — extracted to AnnouncementScreenHeader widget
          AnnouncementScreenHeader(
            languageProvider: languageProvider,
            primaryColor: _getPrimaryColor(),
            cardGradient: _getCardGradient(),
            searchController: _searchController,
            searchKey: _searchKey,
            filterKey: _filterKey,
            hasActiveFilter: _hasActiveFilter,
            filterChips: _buildFilterChips(languageProvider),
            onBack: () => AppNavigator.pop(context),
            onRefresh: _forceRefresh,
            onFilterTap: _showFilterSheet,
            onSearch: _handleSearch,
            onClearAllFilters: _clearAllFilters,
          ),

          // Content — extracted to AnnouncementListContent widget
          Expanded(
            child: AnnouncementListContent(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              announcements: _announcements,
              isLoadingMore: isLoadingMore,
              primaryColor: _getPrimaryColor(),
              scrollController: paginationScrollController,
              languageProvider: languageProvider,
              searchText: _searchController.text,
              onRetry: _loadData,
              onCreateTap: _showAddEditDialog,
              onItemVisible: _onItemVisible,
              formatDate: _formatDate,
              getTargetText: (item) => _getTargetText(item, languageProvider),
              importantLabel: languageProvider.getTranslatedText({
                'en': 'Important',
                'id': 'Penting',
              }),
              onItemTap: _showAnnouncementDetail,
              onItemEdit: (item) => _showAddEditDialog(announcementData: item),
              onItemDelete: _deleteAnnouncement,
              onRefresh: _loadData,
            ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        key: _addKey,
        onPressed: _showAddEditDialog,
        backgroundColor: _getPrimaryColor(),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.add),
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('announcement', 'admin');
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
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
    final List<TargetFocus> targets = createTourTargets();
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
          name: 'admin_announcement_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('announcement', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'admin_announcement_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('announcement', 'admin'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];
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
