// Admin subject (mata pelajaran) management screen — full CRUD for Mapel.
//
// Refactored from the 5-mixin pattern
// (Data + Filter + Actions + UIBuilder + Tour)
// into a single flat [ConsumerState] that delegates data/Excel/CRUD work to
// [AdminSubjectController]. The bespoke gradient header and per-feature chip
// widgets are retired in favor of the shared
// [AdminCrudScaffold] + [AdminDataMenu] + [PaginatedListView] stack.
//
// What lives here: UI flags (loading / error / filters / pagination cursor),
// the master-subject + grade-level + class-name lookup lists, and dispatch
// glue that hands state down to the controller + sheets. Everything else has
// moved out.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/core/widgets/admin_crud_scaffold.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/bulk_action_bar.dart';
import 'package:manajemensekolah/core/widgets/bulk_delete_confirm_dialog.dart';
import 'package:manajemensekolah/core/widgets/admin_data_menu.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/subjects/presentation/controllers/admin_subject_controller.dart';
import 'package:manajemensekolah/features/subjects/presentation/screens/subject_class_management_page.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_add_edit_sheet.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_card.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_filter_sheet.dart';

/// Admin subject management screen with full CRUD, search, filters, and
/// Excel import/export.
class AdminSubjectManagementScreen extends ConsumerStatefulWidget {
  const AdminSubjectManagementScreen({super.key});

  @override
  AdminSubjectManagementScreenState createState() =>
      AdminSubjectManagementScreenState();
}

/// Mutable state for [AdminSubjectManagementScreen].
///
/// Holds pagination cursor, filter selections, loaded data, and the
/// master-subject + class-name + grade-level lookup lists that populate
/// the add/edit sheet and filter sheet.
class AdminSubjectManagementScreenState
    extends ConsumerState<AdminSubjectManagementScreen> {
  // Search — shared with [AdminCrudScaffold] via [searchController].
  final TextEditingController _searchController = TextEditingController();

  // Loaded data.
  List<dynamic> _subjects = [];
  List<dynamic> _availableMasterSubjects = [];
  List<String> _availableClassNames = [];
  List<String> _availableGradeLevels = [];

  // UI flags.
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination cursor.
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Filter selections.
  String? _selectedStatusFilter;
  String? _selectedClassesStatusFilter;
  String? _selectedGradeLevelFilter;
  String? _selectedClassNameFilter;
  bool _hasActiveFilter = false;

  // Bulk-select state.
  final Set<String> _selectedIds = <String>{};
  bool get _bulkMode => _selectedIds.isNotEmpty;

  // Search debounce — avoids spamming the API on every keystroke.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    FCMService().syncTrigger.addListener(_onSyncTriggered);
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    super.dispose();
  }

  // ── Initialization ──────────────────────────────────────────────────

  Future<void> _initialize() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    // Fire-and-forget filter-option warm-up; the result is not needed here —
    // the subject list response includes the same class/grade lookups.
    await ctrl.loadFilterOptions();
    await _loadMasterSubjects();
    await _loadSubjects();
  }

  Future<void> _loadMasterSubjects() async {
    final data = await ref
        .read(adminSubjectControllerProvider)
        .loadMasterSubjects();
    if (!mounted) return;
    setState(() => _availableMasterSubjects = data);
  }

  // ── Data loading ────────────────────────────────────────────────────

  Future<void> _loadSubjects({
    bool resetPage = true,
    bool useCache = true,
  }) async {
    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
      if (_subjects.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    final result = await ref
        .read(adminSubjectControllerProvider)
        .loadSubjects(
          selectedStatusFilter: _selectedStatusFilter,
          selectedGradeLevelFilter: _selectedGradeLevelFilter,
          selectedClassesStatusFilter: _selectedClassesStatusFilter,
          selectedClassNameFilter: _selectedClassNameFilter,
          searchText: _searchController.text,
          perPage: _perPage,
          useCache: useCache,
        );

    if (!mounted) return;

    if (result.errorMessage != null && result.subjects.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
    } else {
      setState(() {
        _subjects = result.subjects;
        _hasMoreData = result.hasMoreData;
        _isLoading = false;
        _errorMessage = null;
        _availableClassNames = result.availableClassNames;
        _availableGradeLevels = result.availableGradeLevels;
      });
    }
  }

  Future<void> _loadMoreSubjects() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final result = await ref
        .read(adminSubjectControllerProvider)
        .loadMoreSubjects(
          nextPage: nextPage,
          perPage: _perPage,
          selectedStatusFilter: _selectedStatusFilter,
          selectedGradeLevelFilter: _selectedGradeLevelFilter,
          searchText: _searchController.text,
          existingClassNames: _availableClassNames,
          existingGradeLevels: _availableGradeLevels,
          academicYearId: ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString(),
        );

    if (!mounted) return;

    if (result.errorMessage != null) {
      AppLogger.error(
        'subject',
        'Load more subjects error: ${result.errorMessage}',
      );
      setState(() => _isLoadingMore = false);
    } else {
      setState(() {
        _currentPage = nextPage;
        _subjects.addAll(result.additionalSubjects);
        _availableClassNames = result.availableClassNames;
        _availableGradeLevels = result.availableGradeLevels;
        _hasMoreData = result.hasMoreData;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _onRefresh() => _loadSubjects(resetPage: true, useCache: false);

  Future<void> _forceRefresh() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    await ctrl.invalidateSubjectCache(
      selectedStatusFilter: _selectedStatusFilter,
      selectedGradeLevelFilter: _selectedGradeLevelFilter,
      selectedClassesStatusFilter: _selectedClassesStatusFilter,
      selectedClassNameFilter: _selectedClassNameFilter,
      searchText: _searchController.text,
    );
    if (!mounted) return;
    await _loadSubjects(resetPage: true, useCache: false);
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger == null || !mounted) return;
    if (trigger['type'] == 'refresh_subjects') {
      AppLogger.debug(
        'subject',
        'Real-time sync triggered (refresh_subjects): Reloading',
      );
      _loadSubjects(resetPage: true, useCache: false);
    }
  }

  // ── Search ──────────────────────────────────────────────────────────

  void _onSearchChanged(String _) {
    _refreshHasActiveFilter();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadSubjects();
    });
  }

  // ── Filter state ────────────────────────────────────────────────────

  void _refreshHasActiveFilter() {
    setState(() {
      _hasActiveFilter = ref
          .read(adminSubjectControllerProvider)
          .checkActiveFilter(
            selectedStatusFilter: _selectedStatusFilter,
            selectedClassesStatusFilter: _selectedClassesStatusFilter,
            selectedGradeLevelFilter: _selectedGradeLevelFilter,
            selectedClassNameFilter: _selectedClassNameFilter,
          );
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubjectFilterSheet(
        initialStatus: _selectedStatusFilter,
        initialClassStatus: _selectedClassesStatusFilter,
        initialGradeLevel: _selectedGradeLevelFilter,
        initialClassName: _selectedClassNameFilter,
        availableGradeLevels: _availableGradeLevels,
        availableClassNames: _availableClassNames,
        onApply: (status, classStatus, gradeLevel, className) {
          setState(() {
            _selectedStatusFilter = status;
            _selectedClassesStatusFilter = classStatus;
            _selectedGradeLevelFilter = gradeLevel;
            _selectedClassNameFilter = className;
          });
          _refreshHasActiveFilter();
          _loadSubjects();
        },
      ),
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatusFilter = null;
      _selectedClassesStatusFilter = null;
      _selectedGradeLevelFilter = null;
      _selectedClassNameFilter = null;
      _hasActiveFilter = false;
      _currentPage = 1;
    });
    _loadSubjects();
  }

  // ── Row-level actions ───────────────────────────────────────────────

  void _openAddEditSheet({Map<String, dynamic>? subject}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubjectAddEditSheet(
        subject: subject,
        availableMasterSubjects: _availableMasterSubjects,
        onSaved: _loadSubjects,
      ),
    );
  }

  Future<void> _deleteSubject(Map<String, dynamic> subject) async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    final lp = ref.read(languageRiverpod);
    final model = Subject.fromJson(subject);

    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: lp.getTranslatedText(const {
        'en': 'Delete Subject',
        'id': 'Hapus Mata Pelajaran',
      }),
      message: lp.getTranslatedText({
        'en': 'Are you sure you want to delete subject "${model.name}"?',
        'id': 'Yakin ingin menghapus mata pelajaran "${model.name}"?',
      }),
      confirmText: lp.getTranslatedText(const {'en': 'Delete', 'id': 'Hapus'}),
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final errorMsg = await ctrl.deleteSubject(model.id);

    if (!mounted) return;

    if (errorMsg == null) {
      ctrl.showSuccessSnackBar(
        context,
        lp.getTranslatedText(const {
          'en': 'Subject successfully deleted',
          'id': 'Mata pelajaran berhasil dihapus',
        }),
      );
      _loadSubjects();
    } else {
      final prefix = lp.getTranslatedText(const {
        'en': 'Failed to delete: ',
        'id': 'Gagal menghapus: ',
      });
      ctrl.showErrorSnackBar(context, '$prefix$errorMsg');
    }
  }

  // ── Bulk-select actions ──

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
    final lang = ref.read(languageRiverpod);
    final selected = _subjects
        .cast<Map<String, dynamic>>()
        .where((s) => _selectedIds.contains(s['id']?.toString()))
        .toList();

    final ok = await showBulkDeleteConfirm(
      context,
      entityNoun: lang.getTranslatedText(const {
        'en': 'subjects',
        'id': 'mapel',
      }),
      items: selected
          .map(
            (s) => BulkDeleteItem(
              id: s['id'].toString(),
              title: (s['name'] ?? '?').toString(),
              subtitle: (s['code'] ?? '').toString().isEmpty
                  ? null
                  : 'Kode ${s['code']}',
            ),
          )
          .toList(),
    );
    if (ok != true || !mounted) return;

    final ctrl = ref.read(adminSubjectControllerProvider);
    final ids = List<Map<String, dynamic>>.from(selected);
    setState(_selectedIds.clear);

    var deleted = 0;
    for (final s in ids) {
      final errorMsg = await ctrl.deleteSubject(s['id'].toString());
      if (errorMsg == null) deleted++;
      if (!mounted) return;
    }
    if (!mounted) return;
    await _loadSubjects();
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      lang.getTranslatedText({
        'en': '$deleted of ${ids.length} subjects deleted',
        'id': '$deleted dari ${ids.length} mapel terhapus',
      }),
    );
  }

  void _openSubjectClassManagement(Map<String, dynamic> subject) {
    AppNavigator.push(context, SubjectClassManagementPage(subject: subject));
  }

  // ── Excel flows ─────────────────────────────────────────────────────

  Future<void> _exportToExcel() {
    return ref
        .read(adminSubjectControllerProvider)
        .exportToExcel(subjects: _subjects, context: context);
  }

  Future<void> _importFromExcel() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    final lp = ref.read(languageRiverpod);

    final errorMsg = await ctrl.importFromExcel();

    if (!mounted) return;

    if (errorMsg == null) {
      await _loadSubjects();
      if (mounted) {
        ctrl.showSuccessSnackBar(
          context,
          lp.getTranslatedText(const {
            'en': 'Subjects imported successfully',
            'id': 'Mata pelajaran berhasil diimpor',
          }),
        );
      }
    } else {
      final prefix = lp.getTranslatedText(const {
        'en': 'Failed to import file: ',
        'id': 'Gagal mengimpor berkas: ',
      });
      ctrl.showErrorSnackBar(context, '$prefix$errorMsg');
    }
  }

  Future<void> _downloadTemplate() {
    return ref.read(adminSubjectControllerProvider).downloadTemplate(context);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final academicYear = ref.watch(academicYearRiverpod);
    final primaryColor = ColorUtils.getRoleColor('admin');

    // Client-side filter overlay: server returns the status + grade-level
    // slice, then we apply class-name + class-status + search on top.
    final filteredSubjects = ref
        .read(adminSubjectControllerProvider)
        .getFilteredSubjects(
          subjectList: _subjects,
          searchText: _searchController.text,
          selectedClassesStatusFilter: _selectedClassesStatusFilter,
          selectedClassNameFilter: _selectedClassNameFilter,
        );

    // v3 brand chips — sticky inside hero (parent Tagihan/Nilai pattern).
    final brandChips = <BrandFilterChip>[
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Status', 'id': 'Status'}),
        value: _selectedStatusFilter == null
            ? null
            : lang.getTranslatedText(switch (_selectedStatusFilter) {
                'active' => const {'en': 'Active', 'id': 'Aktif'},
                'inactive' => const {'en': 'Inactive', 'id': 'Nonaktif'},
                _ => {
                  'en': _selectedStatusFilter!,
                  'id': _selectedStatusFilter!,
                },
              }),
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Grade', 'id': 'Tingkat'}),
        value: _selectedGradeLevelFilter == null
            ? null
            : 'Tingkat $_selectedGradeLevelFilter',
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Class', 'id': 'Kelas'}),
        value: _selectedClassNameFilter,
        onTap: _openFilterSheet,
      ),
    ];

    return AdminCrudScaffold(
      title: lang.getTranslatedText(const {'en': 'Subjects', 'id': 'Mapel'}),
      subtitle: lang.getTranslatedText(const {
        'en': 'Manage and monitor subjects',
        'id': 'Kelola dan pantau mata pelajaran',
      }),
      primaryColor: primaryColor,
      searchController: _searchController,
      searchHint: lang.getTranslatedText(const {
        'en': 'Search subjects...',
        'id': 'Cari mata pelajaran...',
      }),
      onSearchChanged: _onSearchChanged,
      onSearchSubmitted: (_) => _loadSubjects(),
      onFilterTap: _openFilterSheet,
      hasActiveFilter: _hasActiveFilter,
      brandChips: brandChips,
      headerKicker: lang.getTranslatedText(const {
        'en': 'DATA MANAGEMENT',
        'id': 'MANAJEMEN DATA',
      }),
      counterLabel:
          '${filteredSubjects.length} ${lang.getTranslatedText(const {'en': 'subjects', 'id': 'mapel'})}',
      onClearAllFilters: _clearAllFilters,
      actionMenu: AdminDataMenu(
        languageProvider: lang,
        onRefresh: _forceRefresh,
        onExport: _exportToExcel,
        onImport: _importFromExcel,
        onDownloadTemplate: _downloadTemplate,
      ),
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      isEmpty: filteredSubjects.isEmpty,
      onRefresh: _onRefresh,
      emptyTitle: lang.getTranslatedText(const {
        'en': 'No subjects',
        'id': 'Tidak ada mata pelajaran',
      }),
      emptySubtitle: _searchController.text.isEmpty && !_hasActiveFilter
          ? lang.getTranslatedText(const {
              'en': 'Tap + to add a subject',
              'id': 'Tap + untuk menambah mata pelajaran',
            })
          : lang.getTranslatedText(const {
              'en': 'No search results found',
              'id': 'Tidak ditemukan hasil pencarian',
            }),
      emptyIcon: Icons.book_outlined,
      childBuilder: () => PaginatedListView<dynamic>(
        items: filteredSubjects,
        itemBuilder: (context, subject, index) {
          final id = subject['id']?.toString() ?? '';
          final isSelected = _selectedIds.contains(id);
          return SubjectCard(
            subject: subject,
            index: index,
            primaryColor: primaryColor,
            onTap: () => _bulkMode
                ? _toggleSelection(id)
                : _openSubjectClassManagement(subject),
            onLongPress: () => _toggleSelection(id),
            selected: isSelected,
            onEdit: () => _openAddEditSheet(subject: subject),
            onDelete: () => _deleteSubject(subject),
          );
        },
        onLoadMore: _loadMoreSubjects,
        hasMore: _hasMoreData,
        isLoadingMore: _isLoadingMore,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
      ),
      onFabTap: _openAddEditSheet,
      fabIcon: Icons.add,
      hideFab: academicYear.isReadOnly,
      selectedCount: _selectedIds.length,
      onClearSelection: _clearSelection,
      bulkItemNoun: lang.getTranslatedText(const {
        'en': 'subject',
        'id': 'mapel',
      }),
      bulkActions: [
        BulkAction(
          icon: Icons.delete_outline_rounded,
          label: lang.getTranslatedText(const {'en': 'Delete', 'id': 'Hapus'}),
          onTap: _bulkDeleteSelected,
          isDestructive: true,
        ),
      ],
    );
  }
}
