// Teacher announcement screen — redesigned to match teacher role patterns.
//
// Uses TeacherPageHeader, pull-to-refresh, summary/list toggle view,
// detail via shared bottom sheet, and optimized backend queries.
// Follows the same architecture as TeacherLessonPlanScreen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/mixins/pagination_mixin.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/core/widgets/view_toggle_button.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/teacher_announcement_card.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/teacher_announcement_filter_sheet.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_summary_view.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_detail_sheet.dart';

/// Teacher-facing announcement screen with summary and list views.
class TeacherAnnouncementScreen extends ConsumerStatefulWidget {
  const TeacherAnnouncementScreen({super.key});

  @override
  TeacherAnnouncementScreenState createState() =>
      TeacherAnnouncementScreenState();
}

class TeacherAnnouncementScreenState
    extends ConsumerState<TeacherAnnouncementScreen>
    with PaginationMixin<TeacherAnnouncementScreen> {
  List<dynamic> _announcements = [];
  List<Map<String, dynamic>>? _summaryData;
  bool _isLoading = true;
  bool _isSummaryView = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final _service = AnnouncementService();

  // ── Filter state ─────────────────────────────────────────────────────
  // Mirrors the priority / status filter selections from
  // [showTeacherAnnouncementFilterSheet]. Null = "all".
  String? _filterPriority;
  String? _filterStatus;

  Color get _primaryColor => ColorUtils.getRoleColor('guru');

  /// Whether any filter (priority or status) is currently active —
  /// drives the filter-icon badge in the header.
  bool get _hasActiveFilter => _filterPriority != null || _filterStatus != null;

  @override
  void initState() {
    super.initState();
    initPagination();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    disposePagination();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Future<void> loadPage(int page) async {
    try {
      final result = await _service.getAnnouncementsPaginated(
        page: page,
        prioritas: _filterPriority,
        status: _filterStatus,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );
      final newItems = List<dynamic>.from(result['data'] ?? []);
      if (mounted) {
        setState(() {
          if (page == 1) {
            _announcements = newItems;
          } else {
            _announcements = [..._announcements, ...newItems];
          }
        });
        updatePaginationFromMeta(result['pagination'] as Map<String, dynamic>?);
      }
    } catch (e) {
      AppLogger.error('announcement', 'loadPage($page) error: $e');
      if (page == 1) rethrow;
    }
  }

  Future<void> _loadSummaryData() async {
    try {
      final data = await AnnouncementService.getAnnouncementSummary(
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );
      if (mounted) setState(() => _summaryData = data);
    } catch (e) {
      AppLogger.error('announcement', 'Load summary error: $e');
    }
  }

  Future<void> _loadAnnouncements({bool useCache = true}) async {
    final cacheKey = 'announcement_teacher_list';

    bool showedCached = false;
    if (useCache && _searchController.text.isEmpty) {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 1),
      );
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _announcements = List<dynamic>.from(cached);
            _isLoading = false;
            _errorMessage = null;
          });
        }
        showedCached = true;
      }
    }

    resetPagination();
    if (!showedCached && mounted) {
      setState(() {
        _announcements = [];
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await Future.wait([loadPage(1), _loadSummaryData()]);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (_searchController.text.isEmpty && _announcements.isNotEmpty) {
        await LocalCacheService.save(cacheKey, _announcements);
      }
    } catch (e) {
      AppLogger.error('announcement', 'Load error: $e');
      if (mounted && _announcements.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    } finally {
      endPaginationReset();
    }
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('announcement_');
    _summaryData = null;
    _loadAnnouncements(useCache: false);
  }

  /// Opens the priority + status filter sheet.
  void _openFilterSheet(LanguageProvider lp) {
    showTeacherAnnouncementFilterSheet(
      context: context,
      primaryColor: _primaryColor,
      languageProvider: lp,
      currentPriority: _filterPriority,
      currentStatus: _filterStatus,
      onApply: (priority, status) {
        setState(() {
          _filterPriority = priority;
          _filterStatus = status;
        });
        _loadAnnouncements(useCache: false);
      },
    );
  }

  /// Translated label for a priority filter chip.
  String _priorityChipLabel(String value, LanguageProvider lp) {
    switch (value) {
      case 'Penting':
        return lp.getTranslatedText({'en': 'Important', 'id': 'Penting'});
      case 'Biasa':
        return lp.getTranslatedText({'en': 'Normal', 'id': 'Biasa'});
      default:
        return value;
    }
  }

  /// Translated label for a status filter chip.
  String _statusChipLabel(String value, LanguageProvider lp) {
    switch (value) {
      case 'Aktif':
        return lp.getTranslatedText({'en': 'Active', 'id': 'Aktif'});
      case 'Terjadwal':
        return lp.getTranslatedText({'en': 'Scheduled', 'id': 'Terjadwal'});
      case 'Kedaluwarsa':
        return lp.getTranslatedText({'en': 'Expired', 'id': 'Kedaluwarsa'});
      default:
        return value;
    }
  }

  /// Active-filter chip row rendered below the header.
  List<ActiveFilter> _buildActiveFilters(LanguageProvider lp) {
    final filters = <ActiveFilter>[];
    if (_filterPriority != null) {
      filters.add(
        ActiveFilter(
          label: _priorityChipLabel(_filterPriority!, lp),
          onRemove: () {
            setState(() => _filterPriority = null);
            _loadAnnouncements(useCache: false);
          },
        ),
      );
    }
    if (_filterStatus != null) {
      filters.add(
        ActiveFilter(
          label: _statusChipLabel(_filterStatus!, lp),
          onRemove: () {
            setState(() => _filterStatus = null);
            _loadAnnouncements(useCache: false);
          },
        ),
      );
    }
    return filters;
  }

  void _clearAllFilters() {
    setState(() {
      _filterPriority = null;
      _filterStatus = null;
    });
    _loadAnnouncements(useCache: false);
  }

  void _showDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnnouncementDetailSheet(
        announcementData: item,
        primaryColor: _primaryColor,
      ),
    );
  }

  /// Fetches all announcements for a given month (for expanded summary).
  Future<List<Map<String, dynamic>>> _loadMonthItems(String monthKey) async {
    final parts = monthKey.split('-');
    if (parts.length != 2) return [];
    final year = int.tryParse(parts[0]) ?? 2026;
    final month = int.tryParse(parts[1]) ?? 1;
    final dateFrom = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final dateTo =
        '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    try {
      final result = await _service.getAnnouncementsPaginated(
        page: 1,
        limit: 200,
        prioritas: _filterPriority,
        status: _filterStatus,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );
      // Filter client-side by month since we don't have date_from/date_to in paginated endpoint
      final allItems = List<dynamic>.from(result['data'] ?? []);
      return allItems.cast<Map<String, dynamic>>().where((item) {
        final createdAt = item['created_at']?.toString() ?? '';
        return createdAt.startsWith(monthKey);
      }).toList();
    } catch (e) {
      AppLogger.error('announcement', 'Load month items error: $e');
      return [];
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'penting':
      case 'important':
        return 'Penting';
      case 'biasa':
      case 'normal':
        return 'Biasa';
      default:
        return priority;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'penting':
      case 'important':
        return ColorUtils.warning600;
      case 'biasa':
      case 'normal':
        return ColorUtils.info600;
      default:
        return ColorUtils.slate400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          TeacherPageHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Announcements',
              'id': 'Pengumuman',
            }),
            subtitle: languageProvider.getTranslatedText({
              'en': 'School announcements and information',
              'id': 'Pengumuman dan informasi sekolah',
            }),
            primaryColor: _primaryColor,
            showSearchFilter: true,
            searchController: _searchController,
            onSearchSubmitted: (_) => _loadAnnouncements(),
            searchHintText: languageProvider.getTranslatedText({
              'en': 'Search announcements...',
              'id': 'Cari pengumuman...',
            }),
            onFilterTap: () => _openFilterSheet(languageProvider),
            hasActiveFilter: _hasActiveFilter,
            activeFilters: _buildActiveFilters(languageProvider),
            onClearAllFilters: _clearAllFilters,
            trailing: ViewToggleButton(
              currentMode: _isSummaryView ? ViewMode.grid : ViewMode.list,
              availableModes: const [ViewMode.grid, ViewMode.list],
              onChanged: (mode) => setState(() {
                _isSummaryView = mode == ViewMode.grid;
              }),
            ),
          ),
          Expanded(child: _buildBody(languageProvider)),
        ],
      ),
    );
  }

  Widget _buildBody(LanguageProvider languageProvider) {
    return TeacherAsyncView(
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      isEmpty: _announcements.isEmpty,
      onRefresh: () => _forceRefresh(),
      role: 'guru',
      emptyTitle: languageProvider.getTranslatedText({
        'en': 'No Announcements',
        'id': 'Belum Ada Pengumuman',
      }),
      emptySubtitle: languageProvider.getTranslatedText({
        'en': _searchController.text.isNotEmpty
            ? 'No announcements match your search'
            : 'There are no announcements at this time',
        'id': _searchController.text.isNotEmpty
            ? 'Tidak ada pengumuman yang sesuai dengan pencarian'
            : 'Belum ada pengumuman saat ini',
      }),
      emptyIcon: Icons.campaign_outlined,
      emptyActionLabel: _searchController.text.isNotEmpty
          ? languageProvider.getTranslatedText({
              'en': 'Clear Search',
              'id': 'Hapus Pencarian',
            })
          : null,
      onEmptyAction: _searchController.text.isNotEmpty
          ? () {
              _searchController.clear();
              _loadAnnouncements();
            }
          : null,
      childBuilder: () => AppRefreshIndicator(
        onRefresh: () => _forceRefresh(),
        role: 'guru',
        child: _isSummaryView ? _buildSummaryView() : _buildListView(),
      ),
    );
  }

  Widget _buildSummaryView() {
    return AnnouncementSummaryView(
      summaryData: _summaryData,
      announcements: _announcements,
      primaryColor: _primaryColor,
      priorityLabel: _getPriorityLabel,
      priorityColor: _getPriorityColor,
      onView: _showDetail,
      onLoadMonthItems: _loadMonthItems,
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: paginationScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 100, left: 4, right: 4),
      itemCount: _announcements.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _announcements.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _primaryColor,
                ),
              ),
            ),
          );
        }

        final item = _announcements[index] as Map<String, dynamic>;
        return TeacherAnnouncementCard(
          announcementData: item,
          primaryColor: _primaryColor,
          onTap: () => _showDetail(item),
        );
      },
    );
  }
}
