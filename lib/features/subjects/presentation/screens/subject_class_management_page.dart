// Page for managing class assignments for a specific subject.
// Extracted from admin_subject_management_screen.dart to reduce
// file size. Uses mixins for decomposition.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/search_filter_bar.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart'
    as model_subject;
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_data_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_filter_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_actions_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_ui_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_ui_builder_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_add_edit_sheet.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_bulk_add_classes_sheet.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_class_filter_sheet.dart';

class SubjectClassManagementPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> subject;

  const SubjectClassManagementPage({super.key, required this.subject});

  @override
  SubjectClassManagementPageState createState() =>
      SubjectClassManagementPageState();
}

class SubjectClassManagementPageState
    extends ConsumerState<SubjectClassManagementPage>
    with
        AdminAcademicYearReloadMixin<SubjectClassManagementPage>,
        SubjectClassDataMixin,
        SubjectClassFilterMixin,
        SubjectClassActionsMixin,
        SubjectClassUiMixin,
        SubjectClassUiBuilderMixin {
  /// Bridges the AY mixin's getter into the data mixin so the API
  /// calls always include the dashboard-selected year.
  @override
  String? getCurrentAcademicYearId() => currentAcademicYearId;

  /// Reload data when the user switches academic year on the
  /// dashboard. The mixin guards against fire-after-dispose.
  @override
  void onAcademicYearChanged() => loadData();

  @override
  final Set<String> selectedIds = <String>{};

  @override
  bool get bulkMode => selectedIds.isNotEmpty;

  @override
  void toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  @override
  void clearSelection() {
    if (selectedIds.isEmpty) return;
    setState(selectedIds.clear);
  }

  @override
  Future<void> bulkDetachSelected() async {
    if (selectedIds.isEmpty) return;
    final lang = ref.read(languageRiverpod);

    final selected = assignedClasses0
        .cast<Map<String, dynamic>>()
        .where((s) => selectedIds.contains(s['id']?.toString()))
        .toList();

    if (selected.isEmpty) {
      setState(selectedIds.clear);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: lang.getTranslatedText(const {
          'en': 'Remove Classes',
          'id': 'Lepas Kelas',
        }),
        content: lang.getTranslatedText({
          'en':
              'Are you sure you want to remove ${selected.length} class(es) '
              'from this subject?',
          'id':
              'Yakin ingin melepas ${selected.length} kelas dari mata '
              'pelajaran ini?',
        }),
        confirmColor: Colors.red,
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      isLoading = true;
    });

    final subjectIdStr = getSubjectId().toString();
    final idsToDetach = selected.map((c) => c['id'].toString()).toList();
    var detached = 0;

    try {
      final res = await getIt<ApiSubjectService>().bulkDetachClasses(
        subjectIdStr,
        idsToDetach,
      );
      detached = res['detached_count'] as int? ?? idsToDetach.length;
    } catch (e) {
      // Ignored
    }

    if (!mounted) return;

    setState(selectedIds.clear);
    await loadData();

    if (context.mounted) {
      SnackBarUtils.showSuccess(
        context,
        lang.getTranslatedText({
          'en': '$detached class(es) removed successfully',
          'id': '$detached kelas berhasil dilepas',
        }),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    selectedFilter = 'All';
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Gets subject ID from widget
  @override
  dynamic getSubjectId() => model_subject.Subject.fromJson(widget.subject).id;

  /// Gets subject display name (Indonesian/English normalized)
  String _subjectName() => model_subject.Subject.fromJson(widget.subject).name;

  /// Shows confirmation before removing class
  @override
  Future<bool?> showRemoveConfirmation(Map<String, dynamic> classItem) {
    final lang = ref.read(languageRiverpod);
    final question = lang.getTranslatedText({
      'en': 'Are you sure you want to remove class',
      'id': 'Yakin ingin menghapus kelas',
    });
    final fromSubject = lang.getTranslatedText({
      'en': 'from this subject?',
      'id': 'dari mata pelajaran ini?',
    });
    final className = Classroom.fromJson(classItem).name;
    return showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Remove Class',
        content: '$question $className $fromSubject',
        confirmColor: Colors.red,
      ),
    );
  }

  /// Checks if class is assigned
  @override
  bool isClassAssigned(String classId) {
    return assignedClasses0.any((classItem) => classItem['id'] == classId);
  }

  /// Checks if class is assigned (for mixin)
  @override
  bool checkIfClassAssigned(String classId) {
    return isClassAssigned(classId);
  }

  /// Gets primary color (for mixin)
  @override
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Handles class card tap (for mixin)
  @override
  void handleClassCardTap(Map<String, dynamic> classItem, bool isAssigned) {
    if (isAssigned) {
      removeClassFromSubject(classItem);
    } else {
      addClassToSubject(classItem);
    }
  }

  /// Reloads data after the wali kelas was changed via Frame D.
  @override
  void onWaliReassigned() {
    if (mounted) loadData();
  }

  /// Builds the body search bar — solid `SearchFilterBar` without a
  /// filter icon (the Status filter lives as a chip in the header
  /// bottom slot so it's always visible without an extra tap).
  @override
  Widget buildSearchBar() {
    return SearchFilterBar(
      controller: searchController,
      hintText: kSearchClasses.tr,
      transparentStyle: false,
      primaryColor: getPrimaryColor(),
      onChanged: (_) => setState(() {}),
    );
  }

  /// Opens the combined Filter & Urutkan sheet (Frame B). Changes are
  /// applied live via the callbacks; the sheet's own Terapkan button
  /// just closes it.
  void _openFilterSortSheet() {
    SubjectClassFilterSheet.show(
      context: context,
      initialFilter: selectedFilter,
      initialSort: selectedSort,
      primaryColor: getPrimaryColor(),
      onFilterChanged: (value) => setState(() => selectedFilter = value),
      onSortChanged: (value) => setState(() => selectedSort = value),
    );
  }

  /// Opens the Frame E multi-select add sheet. Replaces the legacy
  /// AlertDialog with the new bulk-attach UX backed by
  /// POST /subject/{id}/classes/bulk-attach.
  @override
  void showQuickAddClassDialog(
    List<dynamic> availableClasses,
    List<dynamic> assignedClasses0,
    dynamic subjectName,
  ) async {
    final unassignedClasses = availableClasses
        .where((classItem) => !isClassAssigned(classItem['id']))
        .whereType<Map<String, dynamic>>()
        .toList();

    if (unassignedClasses.isEmpty) {
      SnackBarUtils.showWarning(context, kSubAllClassesAdded.tr);
      return;
    }

    final changed = await SubjectBulkAddClassesSheet.show(
      context: context,
      subjectId: getSubjectId().toString(),
      subjectName: _subjectName(),
      unassignedClasses: unassignedClasses,
    );
    if (changed == true && mounted) {
      await loadData();
    }
  }

  /// Builds empty state for unassigned classes
  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: AppSpacing.sm),
          Text(
            kSubAllClassesAddedShort.tr,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClasses = getFilteredClasses(availableClasses);

    return buildMainScaffold(
      isLoading,
      filteredClasses,
      availableClasses,
      assignedClasses0,
      loadData,
      () => showQuickAddClassDialog(
        availableClasses,
        assignedClasses0,
        _subjectName(),
      ),
      widget.subject,
      onEdit: _openEditSubjectSheet,
      brandChips: buildBrandChips(
        currentFilter: selectedFilter,
        currentSort: selectedSort,
        onTap: _openFilterSortSheet,
      ),
    );
  }

  /// Opens the same `SubjectAddEditSheet` the list uses, pre-filled
  /// with the current subject. On save we reload local data so the
  /// header title (subject name) and class roster stay in sync.
  void _openEditSubjectSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubjectAddEditSheet(
        subject: widget.subject,
        availableMasterSubjects: const [],
        onSaved: () {
          if (mounted) {
            loadData();
          }
        },
      ),
    );
  }
}
