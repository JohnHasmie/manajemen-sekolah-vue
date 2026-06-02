/// Admin announcement management screen — CRUD for school announcements.
///
/// v3 admin shell (Mockup #10): wraps [AdminCrudScaffold] so the navy
/// gradient hero, sticky filter chips inside the hero, search bar, and
/// counter all match the Manajemen Siswa/Guru pattern. The body uses
/// [AnnouncementGroupedList] which interleaves Pinned / Terjadwal /
/// Terkirim / Draft section headers above the existing
/// [AnnouncementCard] rows.
///
/// Mixin breakdown is unchanged from the previous revision so no other
/// presentation widgets need updates:
///   PaginationMixin           — infinite scroll cursor
///   AnnouncementStateMixin    — search controller / state
///   AnnouncementUiMixin       — color + formatting helpers
///   AdminReadTrackingMixin    — auto-mark-as-read debounce
///   AdminFilterMixin          — Priority / Target / Status filter state
///   AdminDataLoadingMixin     — fetch + cache + filterOptions load
///   AdminDialogMixin          — add/edit/detail/delete entry points
///   AdminFileOperationsMixin  — file download
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/mixins/pagination_mixin.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_crud_scaffold.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/bulk_action_bar.dart';
import 'package:manajemensekolah/core/widgets/bulk_delete_confirm_dialog.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_data_loading_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_dialog_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_file_operations_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_filter_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_read_tracking_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/announcement_state_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/announcement_ui_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_grouped_list.dart';

/// Admin announcement management screen — full CRUD with v3 hero,
/// search, filter chips, and lifecycle-grouped body.
class AdminAnnouncementScreen extends ConsumerStatefulWidget {
  /// Optional status filter seeded before the first build.
  ///
  /// Set when the admin dashboard's PendingInboxCard drills into "Draft
  /// pengumuman" — e.g., `'draft'` so the list lands pre-scoped instead of
  /// forcing the user to open the filter sheet.
  final String? initialStatusFilter;

  const AdminAnnouncementScreen({super.key, this.initialStatusFilter});

  @override
  AdminAnnouncementScreenState createState() => AdminAnnouncementScreenState();
}

class AdminAnnouncementScreenState
    extends ConsumerState<AdminAnnouncementScreen>
    with
        PaginationMixin,
        AnnouncementStateMixin,
        AnnouncementUiMixin,
        AdminReadTrackingMixin,
        AdminFilterMixin,
        AdminDataLoadingMixin,
        AdminDialogMixin,
        AdminFileOperationsMixin,
        AdminAcademicYearReloadMixin<AdminAnnouncementScreen> {
  /// Reload announcements when the dashboard AY picker flips. The
  /// announcement list is school-wide but new entries are AY-scoped
  /// on the server, so refreshing the data fetches the right slice
  /// for the year admin just switched to.
  @override
  void onAcademicYearChanged() {
    if (!mounted) return;
    loadFilterOptions();
    loadData();
  }

  // ── Bulk Selection State ──
  final Set<String> _selectedIds = <String>{};
  bool get _bulkMode => _selectedIds.isNotEmpty;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(_selectedIds.clear);
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selectedIds.isEmpty) return;

    // We filter the announcements list to get the objects for the preview list
    final selectedItems = announcements
        .where((a) => _selectedIds.contains(a['id'].toString()))
        .toList();

    final ok = await showBulkDeleteConfirm(
      context,
      entityNoun: 'pengumuman',
      items: selectedItems
          .map(
            (a) => BulkDeleteItem(
              id: a['id'].toString(),
              title: (a['title'] ?? 'Tanpa Judul').toString(),
              subtitle:
                  'Target: ${getTargetText(a, ref.read(languageRiverpod))}',
            ),
          )
          .toList(),
    );

    if (ok != true || !mounted) return;

    setState(() => errorMessage = null);

    // Call individual deletes (the service doesn't have a bulk-delete endpoint yet,
    // so we loop it just like the Student Management screen does)
    try {
      final api = ApiService();
      for (final id in _selectedIds) {
        await api.delete('/announcement/$id');
      }
      _clearSelection();
      forceRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = e.toString());
    }
  }

  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();

  GlobalKey? get addKey => _addKey;

  GlobalKey? get searchKey => _searchKey;

  GlobalKey? get filterKey => _filterKey;

  @override
  void initState() {
    super.initState();
    perPage = 10;
    initPagination();
    initializeState();

    // Seed the status filter before loadData() so the first API request
    // already has the scope applied — avoids a flash of unfiltered content
    // when deep-linked from the admin dashboard inbox.
    final seed = widget.initialStatusFilter;
    if (seed != null && seed.isNotEmpty) {
      selectedStatusFilter = seed;
      hasActiveFilter = true;
    }

    loadFilterOptions();
    loadData();
  }

  @override
  void dispose() {
    disposePagination();
    cleanupState();
    super.dispose();
  }

  // ── Brand chip helpers ──────────────────────────────────────────────
  //
  // The chip "value" string controls whether the chip renders the
  // active outline + label combination ("Status · Draft") or the
  // dim default ("Status"). Tapping any chip opens the full filter
  // sheet; finer single-filter pickers can land later.

  String? _statusValueLabel(LanguageProvider lang) {
    if (selectedStatusFilter == null) return null;
    return lang.getTranslatedText(switch (selectedStatusFilter) {
      'draft' => const {'en': 'Draft', 'id': 'Draft'},
      'published' || 'aktif' => const {'en': 'Published', 'id': 'Terkirim'},
      'archived' => const {'en': 'Archived', 'id': 'Arsip'},
      'terjadwal' => const {'en': 'Scheduled', 'id': 'Terjadwal'},
      'kedaluwarsa' => const {'en': 'Expired', 'id': 'Kedaluwarsa'},
      _ => {'en': selectedStatusFilter!, 'id': selectedStatusFilter!},
    });
  }

  String? _priorityValueLabel(LanguageProvider lang) {
    if (selectedPriorityFilter == null) return null;
    // Backend canonical priorities: `low` / `normal` / `high` / `urgent`.
    // Legacy: `biasa` → normal, `penting` → high.
    return lang.getTranslatedText(switch (selectedPriorityFilter) {
      'urgent' => const {'en': 'Urgent', 'id': 'Mendesak'},
      'high' ||
      'important' ||
      'penting' => const {'en': 'Important', 'id': 'Penting'},
      'normal' || 'biasa' => const {'en': 'Normal', 'id': 'Biasa'},
      'low' => const {'en': 'Low', 'id': 'Rendah'},
      _ => {'en': selectedPriorityFilter!, 'id': selectedPriorityFilter!},
    });
  }

  String? _targetValueLabel(LanguageProvider lang) {
    if (selectedTargetFilter == null) return null;
    return lang.getTranslatedText(switch (selectedTargetFilter) {
      'all' => const {'en': 'Everyone', 'id': 'Semua'},
      'teacher' => const {'en': 'Teachers', 'id': 'Guru'},
      'student' => const {'en': 'Students', 'id': 'Siswa'},
      'parent' => const {'en': 'Parents', 'id': 'Wali Murid'},
      _ => {'en': selectedTargetFilter!, 'id': selectedTargetFilter!},
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final primaryColor = getPrimaryColor();

    final brandChips = <BrandFilterChip>[
      BrandFilterChip(
        label: languageProvider.getTranslatedText(const {
          'en': 'Status',
          'id': 'Status',
        }),
        value: _statusValueLabel(languageProvider),
        onTap: showFilterSheet,
      ),
      BrandFilterChip(
        label: languageProvider.getTranslatedText(const {
          'en': 'Priority',
          'id': 'Prioritas',
        }),
        value: _priorityValueLabel(languageProvider),
        onTap: showFilterSheet,
      ),
      BrandFilterChip(
        label: languageProvider.getTranslatedText(const {
          'en': 'Audience',
          'id': 'Target',
        }),
        value: _targetValueLabel(languageProvider),
        onTap: showFilterSheet,
      ),
    ];

    return AdminCrudScaffold(
      title: languageProvider.getTranslatedText(const {
        'en': 'Announcements',
        'id': 'Pengumuman',
      }),
      subtitle: languageProvider.getTranslatedText(const {
        'en': 'Compose and broadcast school updates',
        'id': 'Susun dan kirim kabar sekolah',
      }),
      headerKicker: languageProvider.getTranslatedText(const {
        'en': 'COMMUNICATION',
        'id': 'KOMUNIKASI',
      }),
      counterLabel:
          '${announcements.length} ${languageProvider.getTranslatedText(const {'en': 'announcements', 'id': 'pengumuman'})}',
      primaryColor: primaryColor,
      searchController: searchController,
      searchHint: languageProvider.getTranslatedText(const {
        'en': 'Search announcements...',
        'id': 'Cari pengumuman...',
      }),
      onSearchSubmitted: (_) => loadData(),
      onFilterTap: showFilterSheet,
      hasActiveFilter: hasActiveFilter,
      brandChips: brandChips,
      onClearAllFilters: clearAllFilters,

      // Bulk Actions
      selectedCount: _selectedIds.length,
      onClearSelection: _clearSelection,
      bulkItemNoun: 'pengumuman',
      bulkActions: [
        BulkAction(
          icon: Icons.delete_outline_rounded,
          label: languageProvider.getTranslatedText(const {
            'en': 'Delete',
            'id': 'Hapus',
          }),
          onTap: _bulkDeleteSelected,
          isDestructive: true,
        ),
      ],

      isLoading: isLoading && announcements.isEmpty,
      errorMessage: errorMessage,
      isEmpty: announcements.isEmpty && !isLoading && errorMessage == null,
      onRefresh: forceRefresh,
      emptyTitle: languageProvider.getTranslatedText(const {
        'en': 'No Announcements',
        'id': 'Tidak Ada Pengumuman',
      }),
      emptySubtitle: searchController.text.isEmpty && !hasActiveFilter
          ? languageProvider.getTranslatedText(const {
              'en': 'Tap + to compose an announcement',
              'id': 'Tap + untuk membuat pengumuman',
            })
          : languageProvider.getTranslatedText(const {
              'en': 'No announcements match these filters',
              'id': 'Tidak ada pengumuman sesuai filter',
            }),
      emptyIcon: Icons.announcement_outlined,
      childBuilder: () => AnnouncementGroupedList(
        isLoading: isLoading,
        errorMessage: errorMessage,
        announcements: announcements,
        isLoadingMore: isLoadingMore,
        hasMoreData: hasMoreData,
        primaryColor: primaryColor,
        scrollController: paginationScrollController,
        languageProvider: languageProvider,
        searchText: searchController.text,
        onRetry: loadData,
        onCreateTap: showAddEditDialog,
        onItemVisible: onItemVisible,
        formatDate: formatDate,
        getTargetText: (item) => getTargetText(item, languageProvider),
        importantLabel: languageProvider.getTranslatedText(const {
          'en': 'Important',
          'id': 'Penting',
        }),
        onItemTap: (item) {
          if (_bulkMode) {
            _toggleSelection(item['id'].toString());
          } else {
            showAnnouncementDetail(item);
          }
        },
        selectedIds: _selectedIds,
        onToggleSelection: _toggleSelection,
        onRefresh: loadData,
        onLoadMore: () => loadPage(currentPage + 1),
      ),
      onFabTap: showAddEditDialog,
      fabKey: _addKey,
      fabIcon: Icons.add,
    );
  }
}

// =====================================================================
// Color helpers exposed as private extension to satisfy AnnouncementUi
// mixin contract — kept colocated with the screen so refactors of the
// gradient stay obvious.
// =====================================================================
