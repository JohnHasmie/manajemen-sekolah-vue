// Admin student management screen - full CRUD for students.
//
// Wraps [AdminCrudScaffold] with a Siswa-specific data layer:
//   • header       → AdminCrudScaffold (SchoolPill + AdminDataMenu trailing)
//   • body         → paginated student list
//   • add/edit     → AppEditBottomSheet via showStudentAddEditDialog()
//   • filter       → AppFilterBottomSheet via showStudentFilterSheet()
//   • bulk actions → none yet (Phase 2 scope if ever needed for Siswa)
//
// Refactored from 354 lines + 5 mixins (data_loading / filter_helper /
// excel_operations / student_actions / tour_helper) into a single
// flattened ConsumerState that delegates all data work to
// [AdminStudentController]. The per-feature gradient header and tour
// plumbing are retired — every admin CRUD screen now shares the same
// shell.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_crud_scaffold.dart';
import 'package:manajemensekolah/core/widgets/admin_data_menu.dart';
import 'package:manajemensekolah/core/widgets/admin_entity_detail_sheet.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/bulk_action_bar.dart';
import 'package:manajemensekolah/core/widgets/bulk_delete_confirm_dialog.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_add_edit_dialog.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_card.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_filter_sheet.dart';

/// Admin student management screen with full CRUD, search, filters, and
/// Excel import/export.
///
/// Optionally accepts [initialClassId] to pre-filter by class (e.g., when
/// navigating from a class detail screen).
class StudentManagementScreen extends ConsumerStatefulWidget {
  final String? initialClassId;

  const StudentManagementScreen({super.key, this.initialClassId});

  @override
  StudentManagementScreenState createState() => StudentManagementScreenState();
}

/// Mutable state for [StudentManagementScreen].
///
/// Everything lives here now — no more mixin-based state smuggling. The
/// controller ([AdminStudentController]) owns data fetching, cache
/// invalidation, Excel flows, and deletion; this State owns only the UI
/// flags (loading / error / filters / pagination cursor) and the
/// dispatch glue.
class StudentManagementScreenState
    extends ConsumerState<StudentManagementScreen>
    with AdminAcademicYearReloadMixin<StudentManagementScreen> {
  // Search field controller — reused across rebuilds and disposed in
  // [dispose]. The AdminCrudScaffold wires it into its header.
  final TextEditingController _searchController = TextEditingController();

  // Data loaded from the API.
  List<dynamic> _students = [];
  List<dynamic> _classList = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Infinite-scroll pagination cursor.
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Active filters. `_hasActiveFilter` is the denormalized OR of these +
  // the search text — kept as a field so the filter-icon badge rebuilds
  // without re-traversing the state each frame.
  String? _selectedStatusFilter;
  List<String> _selectedClassIds = [];
  String? _selectedGenderFilter;
  String? _selectedGuardian;
  bool _hasActiveFilter = false;

  // FAB key kept for potential reintroduction of onboarding tour later;
  // the per-header menu/search/filter keys are intentionally retired.
  final GlobalKey _fabKey = GlobalKey();

  // ── Bulk-select state ──
  // Set of student ids currently selected. Long-press a card to enter
  // bulk mode; tapping a card while in bulk mode toggles its selection.
  final Set<String> _selectedIds = <String>{};
  bool get _bulkMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();

    // If we arrived from a class detail screen, pre-apply that class id as
    // the only filter.
    if (widget.initialClassId != null) {
      _selectedClassIds = [widget.initialClassId!];
      _hasActiveFilter = true;
    }

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────

  /// Loads the first page of students and the class list for filters.
  /// Any user-driven reload (search submit, filter apply, pull-to-refresh)
  /// calls this with `resetPage: true`.
  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    final controller = ref.read(adminStudentControllerProvider);

    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
      if (_students.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    final result = await controller.loadData(
      resetPage: resetPage,
      useCache: useCache,
      currentPage: _currentPage,
      perPage: _perPage,
      selectedClassIds: _selectedClassIds,
      selectedGradeLevel: null,
      selectedGenderFilter: _selectedGenderFilter,
      selectedGuardian: _selectedGuardian,
      selectedStatusFilter: _selectedStatusFilter,
      searchText: _searchController.text,
    );

    if (!mounted) return;

    if (result.errorMessage != null && _students.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
      return;
    }

    setState(() {
      _students = result.students;
      _classList = result.classList;
      _hasMoreData = result.hasMoreData;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  /// Appends the next page of students. Called by [PaginatedListView]'s
  /// scroll-near-bottom callback.
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    final result = await ref
        .read(adminStudentControllerProvider)
        .loadMoreData(
          nextPage: _currentPage + 1,
          perPage: _perPage,
          selectedClassIds: _selectedClassIds,
          selectedGradeLevel: null,
          selectedGenderFilter: _selectedGenderFilter,
          selectedGuardian: _selectedGuardian,
          selectedStatusFilter: _selectedStatusFilter,
          searchText: _searchController.text,
        );

    if (!mounted) return;

    if (result == null) {
      setState(() => _isLoadingMore = false);
      return;
    }

    _currentPage++;
    setState(() {
      _students = [..._students, ...result.additionalStudents];
      _hasMoreData = result.hasMoreData;
      _isLoadingMore = false;
    });
  }

  /// Pull-to-refresh handler. Skips the cache so users see fresh data.
  Future<void> _onRefresh() => _loadData(resetPage: true, useCache: false);

  /// Force-refresh handler for the "Refresh Data" overflow menu item —
  /// also evicts the server-side cache.
  Future<void> _forceRefresh() async {
    await ref
        .read(adminStudentControllerProvider)
        .forceRefreshCaches(
          currentPage: _currentPage,
          selectedClassIds: _selectedClassIds,
          selectedGradeLevel: null,
          selectedGenderFilter: _selectedGenderFilter,
          selectedGuardian: _selectedGuardian,
          selectedStatusFilter: _selectedStatusFilter,
          searchText: _searchController.text,
        );
    await _loadData(resetPage: true, useCache: false);
  }

  @override
  void onAcademicYearChanged() {
    if (mounted) _loadData();
  }

  // ── Filter state ────────────────────────────────────────────────────

  /// Recomputes the `_hasActiveFilter` flag after any filter mutation.
  void _refreshHasActiveFilter() {
    setState(() {
      _hasActiveFilter = ref
          .read(adminStudentControllerProvider)
          .checkActiveFilter(
            selectedStatusFilter: _selectedStatusFilter,
            selectedClassIds: _selectedClassIds,
            selectedGenderFilter: _selectedGenderFilter,
            selectedGradeLevel: null,
            selectedGuardian: _selectedGuardian,
            searchText: _searchController.text,
          );
    });
  }

  void _openFilterSheet() {
    showStudentFilterSheet(
      context: context,
      classList: _classList,
      primaryColor: ColorUtils.getRoleColor('admin'),
      initialStatus: _selectedStatusFilter,
      initialClassIds: _selectedClassIds,
      initialGender: _selectedGenderFilter,
      initialGuardian: _selectedGuardian,
      translate: ref.read(languageRiverpod).getTranslatedText,
      onApply:
          ({
            required String? status,
            required List<String> classIds,
            required String? gender,
            required String? guardian,
          }) {
            setState(() {
              _selectedStatusFilter = status;
              _selectedClassIds = classIds;
              _selectedGenderFilter = gender;
              _selectedGuardian = guardian;
            });
            _refreshHasActiveFilter();
            _loadData();
          },
    );
  }

  /// Clears every filter and search and reloads from scratch.
  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatusFilter = null;
      _selectedClassIds = [];
      _selectedGenderFilter = null;
      _selectedGuardian = null;
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData();
  }

  // ── Bulk-select actions ─────────────────────────────────────────────

  /// Enter bulk mode (or toggle this id within an existing selection).
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// Clear all selections — leaves bulk mode.
  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(_selectedIds.clear);
  }

  /// Delete every selected student in one batch. Shows the shared
  /// type-to-confirm dialog with a multi-entity preview.
  Future<void> _bulkDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final lang = ref.read(languageRiverpod);

    final selected = _students
        .cast<Map<String, dynamic>>()
        .where((s) => _selectedIds.contains(s['id']?.toString()))
        .toList();

    final ok = await showBulkDeleteConfirm(
      context,
      entityNoun: lang.getTranslatedText(const {
        'en': 'students',
        'id': 'siswa',
      }),
      items: selected
          .map(
            (s) => BulkDeleteItem(
              id: s['id'].toString(),
              title: (s['name'] ?? '?').toString(),
              subtitle: (s['class_name'] ?? '').toString().isEmpty
                  ? null
                  : 'Kelas ${s['class_name']}',
            ),
          )
          .toList(),
    );
    if (ok != true || !mounted) return;

    // Reuse the controller's per-id deleteStudent — the backend doesn't
    // currently expose a bulk endpoint, so loop sequentially. Cap UI
    // disruption by clearing selection first.
    final controller = ref.read(adminStudentControllerProvider);
    final ids = List<Map<String, dynamic>>.from(selected);
    setState(_selectedIds.clear);

    var deleted = 0;
    for (final s in ids) {
      // Pass `confirm: false` is not supported on this controller — we
      // already confirmed via the dialog. The per-row deleteStudent
      // currently includes its own confirm dialog; treat each item as a
      // separate call. If the controller learns a `bulkDelete` later,
      // swap this loop for a single call.
      final removed = await controller.deleteStudent(s, context);
      if (removed) deleted++;
      if (!mounted) return;
    }
    if (!mounted) return;
    await _loadData();
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      lang.getTranslatedText({
        'en': '$deleted of ${ids.length} students deleted',
        'id': '$deleted dari ${ids.length} siswa terhapus',
      }),
    );
  }

  // ── Row-level actions ───────────────────────────────────────────────

  void _openStudentDetail(Map<String, dynamic> student) {
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    final lang = ref.read(languageRiverpod);
    final model = Student.fromJson(student);

    // Canonical NIS field is `student_number` (matches the form +
    // backend column). Fall back to legacy keys only if missing.
    final nis =
        (student['student_number'] ?? student['nis'] ?? student['nisn'] ?? '')
            .toString();
    final className = model.className.isNotEmpty ? model.className : '-';
    final genderText = ref
        .read(adminStudentControllerProvider)
        .getGenderText(model.gender, lang);
    final guardianName =
        (student['guardian_name'] ?? student['parent_name'] ?? '-').toString();
    final guardianPhone =
        (student['guardian_phone'] ?? student['parent_phone'] ?? '-')
            .toString();
    final birthDate = (student['birth_date'] ?? student['tanggal_lahir'] ?? '-')
        .toString();
    final address = (student['address'] ?? student['alamat'] ?? '-').toString();
    final email = (student['email'] ?? '-').toString();

    showAdminEntityDetailSheet(
      context,
      kicker: lang.getTranslatedText(const {'en': 'STUDENT', 'id': 'SISWA'}),
      title: model.name.isNotEmpty ? model.name : 'No Name',
      meta: nis.isNotEmpty ? '$className · NIS $nis' : className,
      initials: model.name.isNotEmpty ? model.name : '?',
      status: EntityStatus.success(
        lang.getTranslatedText(const {'en': 'Active', 'id': 'Aktif'}),
      ),
      sections: [
        EntityDetailSection(
          label: lang.getTranslatedText(const {
            'en': 'Academic',
            'id': 'Data Akademik',
          }),
          rows: [
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Class',
                'id': 'Kelas',
              }),
              value: className,
            ),
            EntityDetailRow(label: 'NIS', value: nis.isEmpty ? '-' : nis),
          ],
        ),
        EntityDetailSection(
          label: lang.getTranslatedText(const {
            'en': 'Personal',
            'id': 'Data Pribadi',
          }),
          rows: [
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Gender',
                'id': 'Jenis kelamin',
              }),
              value: genderText,
            ),
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Birth date',
                'id': 'Tanggal lahir',
              }),
              value: birthDate,
            ),
            EntityDetailRow(label: 'Email', value: email),
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
            'en': 'Guardian',
            'id': 'Wali / Orang Tua',
          }),
          rows: [
            EntityDetailRow(
              label: lang.getTranslatedText(const {'en': 'Name', 'id': 'Nama'}),
              value: guardianName,
            ),
            EntityDetailRow(
              label: lang.getTranslatedText(const {
                'en': 'Phone',
                'id': 'No. HP',
              }),
              value: guardianPhone,
            ),
          ],
        ),
      ],
      onEdit: () => _openAddEditSheet(student: student),
      onDelete: () => _deleteStudent(student),
      isReadOnly: isReadOnly,
    );
  }

  void _openAddEditSheet({Map<String, dynamic>? student}) {
    showStudentAddEditDialog(
      context: context,
      ref: ref,
      classList: _classList,
      primaryColor: ColorUtils.getRoleColor('admin'),
      student: student,
      onSave: _loadData,
    );
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final deleted = await ref
        .read(adminStudentControllerProvider)
        .deleteStudent(student, context);
    if (!deleted || !mounted) return;
    await _loadData();
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      ref.read(languageRiverpod).getTranslatedText(const {
        'en': 'Student successfully deleted',
        'id': 'Siswa berhasil dihapus',
      }),
    );
  }

  // ── Excel flows ─────────────────────────────────────────────────────

  Future<void> _exportToExcel() {
    return ref
        .read(adminStudentControllerProvider)
        .exportToExcel(
          context: context,
          selectedClassIds: _selectedClassIds,
          selectedGradeLevel: null,
          selectedGenderFilter: _selectedGenderFilter,
          searchText: _searchController.text,
        );
  }

  Future<void> _importFromExcel() async {
    final imported = await ref
        .read(adminStudentControllerProvider)
        .importFromExcel(context);
    if (!imported || !mounted) return;
    await _loadData();
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      ref.read(languageRiverpod).getTranslatedText(const {
        'en': 'Students imported successfully',
        'id': 'Data siswa berhasil diimpor',
      }),
    );
  }

  Future<void> _downloadTemplate() {
    return ref.read(adminStudentControllerProvider).downloadTemplate(context);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final academicYear = ref.watch(academicYearRiverpod);
    final primaryColor = ColorUtils.getRoleColor('admin');

    // Build v3 brand chips — chips live INSIDE the gradient hero so the
    // active filter state stays visible while the user scrolls (parent
    // Tagihan/Nilai pattern). Tapping a chip opens the full filter sheet
    // pre-scrolled to that section. When backend supports per-filter
    // pickers, swap each onTap to its single-filter BrandHeroSheet picker.
    final brandChips = <BrandFilterChip>[
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Status', 'id': 'Status'}),
        value: _selectedStatusFilter == null
            ? null
            : lang.getTranslatedText(switch (_selectedStatusFilter) {
                'active' => const {'en': 'Active', 'id': 'Aktif'},
                'inactive' => const {'en': 'Inactive', 'id': 'Nonaktif'},
                'unverified' => const {
                  'en': 'Unverified',
                  'id': 'Belum diverifikasi',
                },
                _ => {
                  'en': _selectedStatusFilter!,
                  'id': _selectedStatusFilter!,
                },
              }),
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Class', 'id': 'Kelas'}),
        value: _selectedClassIds.isEmpty
            ? null
            : (_selectedClassIds.length == 1
                  ? _classList
                        .cast<Map<String, dynamic>>()
                        .firstWhere(
                          (c) => c['id']?.toString() == _selectedClassIds.first,
                          orElse: () => const {'name': '1 kelas'},
                        )['name']
                        .toString()
                  : '${_selectedClassIds.length} kelas'),
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Gender', 'id': 'Gender'}),
        value: _selectedGenderFilter == null
            ? null
            : lang.getTranslatedText(switch (_selectedGenderFilter) {
                'L' => const {'en': 'Male', 'id': 'Laki-laki'},
                'P' => const {'en': 'Female', 'id': 'Perempuan'},
                _ => {
                  'en': _selectedGenderFilter!,
                  'id': _selectedGenderFilter!,
                },
              }),
        onTap: _openFilterSheet,
      ),
    ];

    return AdminCrudScaffold(
      title: lang.getTranslatedText(const {'en': 'Students', 'id': 'Siswa'}),
      subtitle: lang.getTranslatedText(const {
        'en': 'Manage and monitor students',
        'id': 'Kelola dan pantau siswa',
      }),
      primaryColor: primaryColor,
      searchController: _searchController,
      searchHint: lang.getTranslatedText(const {
        'en': 'Search students...',
        'id': 'Cari siswa...',
      }),
      onSearchChanged: (_) => _refreshHasActiveFilter(),
      onSearchSubmitted: (_) => _loadData(),
      onFilterTap: _openFilterSheet,
      hasActiveFilter: _hasActiveFilter,
      brandChips: brandChips,
      headerKicker: lang.getTranslatedText(const {
        'en': 'DATA MANAGEMENT',
        'id': 'MANAJEMEN DATA',
      }),
      counterLabel:
          '${_students.length} ${lang.getTranslatedText(const {'en': 'students', 'id': 'siswa'})}',
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
      isEmpty: _students.isEmpty,
      onRefresh: _onRefresh,
      emptyTitle: lang.getTranslatedText(const {
        'en': 'No students',
        'id': 'Tidak ada siswa',
      }),
      emptySubtitle: _searchController.text.isEmpty && !_hasActiveFilter
          ? lang.getTranslatedText(const {
              'en': 'Tap + to add a student',
              'id': 'Tap + untuk menambah siswa',
            })
          : lang.getTranslatedText(const {
              'en': 'No search results found',
              'id': 'Tidak ditemukan hasil pencarian',
            }),
      emptyIcon: Icons.people_outline,
      childBuilder: () => PaginatedListView<Map<String, dynamic>>(
        items: _students.cast<Map<String, dynamic>>(),
        itemBuilder: (context, student, index) {
          final id = student['id']?.toString() ?? '';
          final isSelected = _selectedIds.contains(id);
          return StudentCard(
            student: student,
            index: index,
            isReadOnly: academicYear.isReadOnly,
            primaryColor: primaryColor,
            genderText: ref
                .read(adminStudentControllerProvider)
                .getGenderText(Student.fromJson(student).gender, lang),
            // Bulk-mode tap toggles selection; otherwise opens detail.
            onTap: () =>
                _bulkMode ? _toggleSelection(id) : _openStudentDetail(student),
            // Long-press always toggles selection (entry into bulk mode).
            onLongPress: () => _toggleSelection(id),
            selected: isSelected,
            onEdit: () => _openAddEditSheet(student: student),
            onDelete: () => _deleteStudent(student),
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
      // ── Bulk-action wiring ──
      selectedCount: _selectedIds.length,
      onClearSelection: _clearSelection,
      bulkItemNoun: lang.getTranslatedText(const {
        'en': 'student',
        'id': 'siswa',
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
