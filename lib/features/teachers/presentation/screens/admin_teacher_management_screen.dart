// Admin teacher management screen — full CRUD for teachers.
//
// Refactored from the 5-mixin (DataLoading + Crud + Filter + Tour + Ui)
// implementation into a single flat [ConsumerState] that delegates all
// data/Excel/CRUD work to [AdminTeacherController]. The per-feature
// gradient header (`TeacherScreenHeader`) and list wrapper
// (`TeacherListContent`) are retired in favor of the shared
// [AdminCrudScaffold] + [AdminDataMenu] + [PaginatedListView] stack.
//
// What lives here: UI flags (loading / error / filters / pagination
// cursor) + dispatch glue that hands state down to the controller.
// Everything else has moved out.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_crud_scaffold.dart';
import 'package:manajemensekolah/core/widgets/admin_data_menu.dart';
import 'package:manajemensekolah/core/widgets/admin_entity_detail_sheet.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/bulk_action_bar.dart';
import 'package:manajemensekolah/core/widgets/bulk_delete_confirm_dialog.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/features/teachers/presentation/controllers/admin_teacher_controller.dart';
import 'package:manajemensekolah/features/teachers/presentation/controllers/helpers/teacher_filter_helper.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_card.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_filter_sheet.dart';

/// Admin-facing teacher management screen.
class TeacherAdminScreen extends ConsumerStatefulWidget {
  const TeacherAdminScreen({super.key});

  @override
  TeacherAdminScreenState createState() => TeacherAdminScreenState();
}

/// Mutable state for [TeacherAdminScreen].
///
/// Holds the pagination cursor, filter selections, and loaded-data cache
/// that feed [AdminCrudScaffold]. All network + cache + Excel work is
/// delegated to [AdminTeacherController].
class TeacherAdminScreenState extends ConsumerState<TeacherAdminScreen>
    with AdminAcademicYearReloadMixin<TeacherAdminScreen> {
  // Search text — shared with [AdminCrudScaffold] via [searchController].
  final TextEditingController _searchController = TextEditingController();

  // Loaded data.
  List<dynamic> _teachers = [];
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination cursor.
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Filter selections.
  String? _selectedClassId;
  String? _selectedHomeroomFilter;
  String? _selectedGender;
  String? _selectedEmploymentStatus;
  String? _selectedTeachingClassId;
  bool _showAllTeachers = false;
  bool _hasActiveFilter = false;

  // Bulk-select state — long-press a card to enter, tap to toggle.
  final Set<String> _selectedIds = <String>{};
  bool get _bulkMode => _selectedIds.isNotEmpty;

  // Filter-option lists (populated once from /filter-options).
  List<dynamic> _availableClass = [];
  List<dynamic> _availableGenders = [];
  List<dynamic> _availableEmploymentStatus = [];

  // FAB GlobalKey reserved for potential reintroduction of tour plumbing.
  final GlobalKey _fabKey = GlobalKey();

  // Search debounce.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    FCMService().syncTrigger.addListener(_onSyncTriggered);
    _loadFilterOptions();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────

  Future<void> _loadFilterOptions() async {
    final options = await ref
        .read(adminTeacherControllerProvider)
        .loadFilterOptions();
    if (!mounted || options == null) return;
    setState(() {
      _availableClass = options.availableClass;
      _availableGenders = options.availableGenders;
      _availableEmploymentStatus = options.availableEmploymentStatus;
    });
  }

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
      if (_teachers.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    final result = await ref
        .read(adminTeacherControllerProvider)
        .loadData(
          useCache: useCache,
          currentPage: _currentPage,
          perPage: _perPage,
          selectedClassId: _selectedClassId,
          selectedHomeroomFilter: _selectedHomeroomFilter,
          selectedGender: _selectedGender,
          selectedEmploymentStatus: _selectedEmploymentStatus,
          selectedTeachingClassId: _selectedTeachingClassId,
          showAllTeachers: _showAllTeachers,
          searchText: _searchController.text,
        );

    if (!mounted) return;

    if (result.errorMessage != null && _teachers.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
      return;
    }

    setState(() {
      _teachers = result.teachers;
      _subjects = result.subjects;
      _classes = result.classes;
      _hasMoreData = result.hasMoreData;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    final result = await ref
        .read(adminTeacherControllerProvider)
        .loadMoreData(
          nextPage: _currentPage + 1,
          perPage: _perPage,
          selectedClassId: _selectedClassId,
          selectedHomeroomFilter: _selectedHomeroomFilter,
          selectedGender: _selectedGender,
          selectedEmploymentStatus: _selectedEmploymentStatus,
          selectedTeachingClassId: _selectedTeachingClassId,
          showAllTeachers: _showAllTeachers,
          searchText: _searchController.text,
        );

    if (!mounted) return;

    if (result == null) {
      setState(() => _isLoadingMore = false);
      return;
    }

    _currentPage++;
    setState(() {
      _teachers = [..._teachers, ...result.additionalTeachers];
      _hasMoreData = result.hasMoreData;
      _isLoadingMore = false;
    });
    AppLogger.info(
      'teacher',
      'Loaded more data: Page $_currentPage, Total items: ${_teachers.length}',
    );
  }

  Future<void> _onRefresh() => _loadData(resetPage: true, useCache: false);

  Future<void> _forceRefresh() async {
    await ref
        .read(adminTeacherControllerProvider)
        .forceRefreshCaches(
          currentPage: _currentPage,
          selectedClassId: _selectedClassId,
          selectedHomeroomFilter: _selectedHomeroomFilter,
          selectedGender: _selectedGender,
          selectedEmploymentStatus: _selectedEmploymentStatus,
          selectedTeachingClassId: _selectedTeachingClassId,
          showAllTeachers: _showAllTeachers,
          searchText: _searchController.text,
        );
    await _loadFilterOptions();
    await _loadData(resetPage: true, useCache: false);
  }

  @override
  void onAcademicYearChanged() {
    if (!mounted) return;
    _loadFilterOptions();
    _loadData();
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger == null || !mounted) return;
    if (trigger['type'] == 'refresh_teachers' ||
        trigger['type'] == 'refresh_schedules') {
      AppLogger.debug('teacher', 'Sync triggered: ${trigger['type']}');
      _loadData(useCache: false);
    }
  }

  // ── Search ──────────────────────────────────────────────────────────

  void _onSearchChanged(String _) {
    _refreshHasActiveFilter();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadData();
    });
  }

  // ── Filter state ────────────────────────────────────────────────────

  void _refreshHasActiveFilter() {
    setState(() {
      _hasActiveFilter = TeacherFilterHelper.checkActiveFilter(
        selectedHomeroomFilter: _selectedHomeroomFilter,
        selectedGender: _selectedGender,
        selectedEmploymentStatus: _selectedEmploymentStatus,
        selectedTeachingClassId: _selectedTeachingClassId,
        searchText: _searchController.text,
      );
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TeacherFilterSheet(
        initialHomeroom: _selectedHomeroomFilter,
        initialGender: _selectedGender,
        initialEmploymentStatus: _selectedEmploymentStatus,
        initialTeachingClass: _selectedTeachingClassId,
        initialShowAll: _showAllTeachers,
        availableGenders: _availableGenders,
        availableEmploymentStatus: _availableEmploymentStatus,
        availableClass: _availableClass,
        languageProvider: ref.read(languageRiverpod),
        onApply: (homeroom, gender, employment, teachingClass, showAll) {
          setState(() {
            _selectedHomeroomFilter = homeroom;
            _selectedGender = gender;
            _selectedEmploymentStatus = employment;
            _selectedTeachingClassId = teachingClass;
            _showAllTeachers = showAll;
          });
          _refreshHasActiveFilter();
          _loadData();
        },
      ),
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedClassId = null;
      _selectedHomeroomFilter = null;
      _selectedGender = null;
      _selectedEmploymentStatus = null;
      _selectedTeachingClassId = null;
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData();
  }

  // ── Bulk-select actions ─────────────────────────────────────────────

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
    final selected = _teachers
        .cast<Map<String, dynamic>>()
        .where((t) => _selectedIds.contains(t['id']?.toString()))
        .toList();

    final ok = await showBulkDeleteConfirm(
      context,
      entityNoun: lang.getTranslatedText(const {
        'en': 'teachers',
        'id': 'guru',
      }),
      items: selected
          .map(
            (t) => BulkDeleteItem(
              id: t['id'].toString(),
              title: (t['name'] ?? t['user']?['name'] ?? '?').toString(),
              subtitle: (t['email'] ?? '').toString().isEmpty
                  ? null
                  : t['email'].toString(),
            ),
          )
          .toList(),
    );
    if (ok != true || !mounted) return;

    final ctrl = ref.read(adminTeacherControllerProvider);
    final ids = List<Map<String, dynamic>>.from(selected);
    setState(_selectedIds.clear);

    var deleted = 0;
    for (final t in ids) {
      final removed = await ctrl.deleteTeacher(t, context);
      if (removed) deleted++;
      if (!mounted) return;
    }
    if (!mounted) return;
    await _loadData();
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      lang.getTranslatedText({
        'en': '$deleted of ${ids.length} teachers deleted',
        'id': '$deleted dari ${ids.length} guru terhapus',
      }),
    );
  }

  // ── Row-level actions ───────────────────────────────────────────────

  void _openTeacherDetail(Map<String, dynamic> teacher) {
    final lang = ref.read(languageRiverpod);
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    final model = Teacher.fromJson(teacher);
    final name = model.name.isNotEmpty ? model.name : 'No Name';
    final nip = (model.employeeNumber ?? '').isNotEmpty
        ? model.employeeNumber!
        : '-';
    final email = model.email.isNotEmpty ? model.email : '-';
    final phone = (model.phoneNumber ?? '').isNotEmpty
        ? model.phoneNumber!
        : '-';

    // Gender display
    final rawGender = (teacher['gender'] ?? '').toString();
    // Backend canonical: `male` / `female` (was `L` / `P`).
    final genderDisplay = switch (rawGender) {
      'male' ||
      'L' => lang.getTranslatedText(const {'en': 'Male', 'id': 'Laki-laki'}),
      'female' ||
      'P' => lang.getTranslatedText(const {'en': 'Female', 'id': 'Perempuan'}),
      _ => '-',
    };

    // Employment status display
    final rawStatus = (teacher['employment_status'] ?? '')
        .toString()
        .toLowerCase();
    // Backend canonical: `permanent` / `civil_servant` (was `tetap`
    // / `PNS`). Legacy aliases remain for back-compat.
    final statusDisplay = switch (rawStatus) {
      'permanent' || 'tetap' || 'active' => lang.getTranslatedText(const {
        'en': 'Permanent',
        'id': 'Tetap',
      }),
      'civil_servant' || 'pns' => lang.getTranslatedText(const {
        'en': 'Civil Servant',
        'id': 'PNS',
      }),
      'contract' || 'kontrak' || 'tidak_tetap' => lang.getTranslatedText(const {
        'en': 'Contract',
        'id': 'Kontrak',
      }),
      'temporary' || 'honorer' || 'honor' => lang.getTranslatedText(const {
        'en': 'Honorary',
        'id': 'Honorer',
      }),
      'probation' || 'probasi' => lang.getTranslatedText(const {
        'en': 'Probation',
        'id': 'Probasi',
      }),
      _ => rawStatus.isNotEmpty ? rawStatus : '-',
    };

    // Homeroom
    final isHomeroom = model.isHomeroomTeacher;
    final homeroomClass = model.homeroomClassName ?? '-';

    // Subjects
    final subjects =
        (teacher['subjects'] as List<dynamic>?)
            ?.map((s) => (s is Map ? s['name'] : s).toString())
            .where((s) => s.isNotEmpty)
            .join(', ') ??
        '-';

    // Teaching classes
    final teachingClasses =
        (teacher['classes'] as List<dynamic>?)
            ?.map((c) => (c is Map ? c['name'] : c).toString())
            .where((c) => c.isNotEmpty)
            .join(', ') ??
        '-';

    // Address (from user object or direct)
    final address = (model.address ?? '').isNotEmpty ? model.address! : '-';

    showAdminEntityDetailSheet(
      context,
      kicker: lang.getTranslatedText(const {'en': 'TEACHER', 'id': 'GURU'}),
      title: name,
      meta: nip != '-' ? 'NIP $nip' : email,
      initials: name,
      status: EntityStatus.success(
        lang.getTranslatedText(const {'en': 'Active', 'id': 'Aktif'}),
      ),
      sections: [
        EntityDetailSection(
          label: lang.getTranslatedText(const {
            'en': 'Identity',
            'id': 'Identitas',
          }),
          rows: [
            EntityDetailRow(label: 'NIP / NUPTK', value: nip),
            EntityDetailRow(label: 'Email', value: email),
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Phone',
                'id': 'No. HP',
              }),
              value: phone,
            ),
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Gender',
                'id': 'Jenis Kelamin',
              }),
              value: genderDisplay,
            ),
            if (address != '-')
              EntityDetailRow(
                label: lang.getTranslatedText(const {
                  'en': 'Address',
                  'id': 'Alamat',
                }),
                value: address,
              ),
          ],
        ),
        EntityDetailSection(
          label: lang.getTranslatedText(const {
            'en': 'Assignment',
            'id': 'Penugasan',
          }),
          rows: [
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Role',
                'id': 'Peran',
              }),
              value: isHomeroom
                  ? '${lang.getTranslatedText(const {'en': 'Homeroom', 'id': 'Wali Kelas'})} $homeroomClass'
                  : lang.getTranslatedText(const {
                      'en': 'Subject Teacher',
                      'id': 'Guru Mapel',
                    }),
            ),
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Subjects',
                'id': 'Mapel',
              }),
              value: subjects,
            ),
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Teaching Classes',
                'id': 'Kelas Mengajar',
              }),
              value: teachingClasses,
            ),
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Employment Status',
                'id': 'Status Kepegawaian',
              }),
              value: statusDisplay,
            ),
          ],
        ),
      ],
      onEdit: () => _openAddEditSheet(teacher: teacher),
      onDelete: () => _deleteTeacher(teacher),
      isReadOnly: isReadOnly,
    );
  }

  void _openAddEditSheet({Map<String, dynamic>? teacher}) {
    ref
        .read(adminTeacherControllerProvider)
        .openTeacherFormDialog(
          context: context,
          subjects: _subjects,
          classes: _classes,
          teacher: teacher,
          onSaved: _loadData,
        );
  }

  Future<void> _deleteTeacher(Map<String, dynamic> teacher) async {
    final deleted = await ref
        .read(adminTeacherControllerProvider)
        .deleteTeacher(teacher, context);
    if (!deleted || !mounted) return;
    await _loadData();
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      ref.read(languageRiverpod).getTranslatedText(const {
        'en': 'Teacher successfully deleted',
        'id': 'Guru berhasil dihapus',
      }),
    );
  }

  // ── Excel flows ─────────────────────────────────────────────────────

  Future<void> _exportToExcel() {
    return ref
        .read(adminTeacherControllerProvider)
        .exportToExcel(
          context: context,
          selectedClassId: _selectedClassId,
          showAllTeachers: _showAllTeachers,
          searchText: _searchController.text,
        );
  }

  Future<void> _importFromExcel() async {
    final imported = await ref
        .read(adminTeacherControllerProvider)
        .importFromExcel(context);
    if (!imported || !mounted) return;
    await _loadData();
  }

  Future<void> _downloadTemplate() {
    return ref.read(adminTeacherControllerProvider).downloadTemplate(context);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final academicYear = ref.watch(academicYearRiverpod);
    final primaryColor = ColorUtils.getRoleColor('admin');

    // v3 brand chips — sticky inside hero. Tapping any chip routes to the
    // full filter sheet (single-filter pickers can be added later).
    String? classNameForId(String? id) {
      if (id == null) return null;
      final match = _availableClass.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id']?.toString() == id,
        orElse: () => const {'name': '1 kelas'},
      );
      return match['name']?.toString();
    }

    final brandChips = <BrandFilterChip>[
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Role', 'id': 'Status'}),
        value: _selectedHomeroomFilter == null
            ? null
            : lang.getTranslatedText(switch (_selectedHomeroomFilter) {
                'wali_kelas' => const {'en': 'Homeroom', 'id': 'Wali Kelas'},
                'guru_mapel' => const {
                  'en': 'Subject Teacher',
                  'id': 'Guru Mapel',
                },
                _ => {
                  'en': _selectedHomeroomFilter!,
                  'id': _selectedHomeroomFilter!,
                },
              }),
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Class', 'id': 'Kelas'}),
        value: classNameForId(_selectedTeachingClassId),
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {
          'en': 'Employment',
          'id': 'Status Kerja',
        }),
        value: _selectedEmploymentStatus,
        onTap: _openFilterSheet,
      ),
    ];

    return AdminCrudScaffold(
      title: lang.getTranslatedText(const {'en': 'Teachers', 'id': 'Guru'}),
      subtitle: lang.getTranslatedText(const {
        'en': 'Manage and monitor teachers',
        'id': 'Kelola dan pantau guru',
      }),
      primaryColor: primaryColor,
      searchController: _searchController,
      searchHint: lang.getTranslatedText(const {
        'en': 'Search teachers...',
        'id': 'Cari guru...',
      }),
      onSearchChanged: _onSearchChanged,
      onSearchSubmitted: (_) => _loadData(),
      onFilterTap: _openFilterSheet,
      hasActiveFilter: _hasActiveFilter,
      brandChips: brandChips,
      headerKicker: lang.getTranslatedText(const {
        'en': 'DATA MANAGEMENT',
        'id': 'MANAJEMEN DATA',
      }),
      counterLabel:
          '${_teachers.length} ${lang.getTranslatedText(const {'en': 'teachers', 'id': 'guru'})}',
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
      isEmpty: _teachers.isEmpty,
      onRefresh: _onRefresh,
      emptyTitle: lang.getTranslatedText(const {
        'en': 'No teachers',
        'id': 'Tidak ada guru',
      }),
      emptySubtitle: _searchController.text.isEmpty && !_hasActiveFilter
          ? lang.getTranslatedText(const {
              'en': 'Tap + to add a teacher',
              'id': 'Tap + untuk menambah guru',
            })
          : lang.getTranslatedText(const {
              'en': 'No search results found',
              'id': 'Tidak ditemukan hasil pencarian',
            }),
      emptyIcon: Icons.person_outline,
      childBuilder: () => PaginatedListView<Map<String, dynamic>>(
        items: _teachers.cast<Map<String, dynamic>>(),
        itemBuilder: (context, teacher, index) {
          final id = teacher['id']?.toString() ?? '';
          final isSelected = _selectedIds.contains(id);
          return TeacherCard(
            teacher: teacher,
            index: index,
            onTap: () =>
                _bulkMode ? _toggleSelection(id) : _openTeacherDetail(teacher),
            onLongPress: () => _toggleSelection(id),
            selected: isSelected,
            onEdit: () => _openAddEditSheet(teacher: teacher),
            onDelete: () => _deleteTeacher(teacher),
          );
        },
        onLoadMore: _loadMoreData,
        hasMore: _hasMoreData,
        isLoadingMore: _isLoadingMore,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
      ),
      onFabTap: academicYear.isReadOnly ? null : _openAddEditSheet,
      fabKey: _fabKey,
      hideFab: academicYear.isReadOnly,
      selectedCount: _selectedIds.length,
      onClearSelection: _clearSelection,
      bulkItemNoun: lang.getTranslatedText(const {
        'en': 'teacher',
        'id': 'guru',
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
