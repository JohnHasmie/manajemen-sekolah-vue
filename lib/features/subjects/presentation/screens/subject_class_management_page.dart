// Page for managing class assignments for a specific subject.
// Extracted from admin_subject_management_screen.dart to reduce
// file size. Uses mixins for decomposition.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/search_filter_bar.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart'
    as model_subject;
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_data_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_filter_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_actions_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_ui_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_ui_builder_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_add_edit_sheet.dart';

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
        SubjectClassDataMixin,
        SubjectClassFilterMixin,
        SubjectClassActionsMixin,
        SubjectClassUiMixin,
        SubjectClassUiBuilderMixin {
  @override
  late TextEditingController searchController;

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
    return showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Remove Class',
        content:
            '${ref.read(languageRiverpod).getTranslatedText({'en': 'Are you sure you want to remove class', 'id': 'Yakin ingin menghapus kelas'})} ${Classroom.fromJson(classItem).name} '
            '${ref.read(languageRiverpod).getTranslatedText({'en': 'from this subject?', 'id': 'dari mata pelajaran ini?'})}',
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

  /// Builds the body search bar — solid `SearchFilterBar` without a
  /// filter icon (the Status filter lives as a chip in the header
  /// bottom slot so it's always visible without an extra tap).
  @override
  Widget buildSearchBar() {
    return SearchFilterBar(
      controller: searchController,
      hintText: 'Cari kelas...',
      transparentStyle: false,
      primaryColor: getPrimaryColor(),
      onChanged: (_) => setState(() {}),
    );
  }

  /// Opens the Status picker sheet. Three mutually-exclusive options:
  /// Semua / Terdaftar / Belum Terdaftar.
  void _openStatusFilterSheet() {
    AppBottomSheet.show(
      context: context,
      title: 'Status Kelas',
      subtitle: 'Saring kelas berdasarkan status pendaftaran',
      icon: Icons.tune_rounded,
      primaryColor: getPrimaryColor(),
      content: _StatusFilterPicker(
        selected: selectedFilter,
        primaryColor: getPrimaryColor(),
        onSelect: (filter) {
          setState(() => selectedFilter = filter);
          AppNavigator.pop(context);
        },
      ),
    );
  }

  /// Shows quick add class dialog
  @override
  void showQuickAddClassDialog(
    List<dynamic> availableClasses,
    List<dynamic> assignedClasses0,
    dynamic subjectName,
  ) {
    final unassignedClasses = availableClasses
        .where((classItem) => !isClassAssigned(classItem['id']))
        .toList();

    if (unassignedClasses.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        'Semua kelas sudah ditambahkan ke '
        'mata pelajaran ini',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildDialogHeader(
                    getPrimaryColor(),
                    () => AppNavigator.pop(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pilih kelas yang ingin '
                          'ditambahkan ke '
                          '${_subjectName()}:',
                          style: TextStyle(
                            fontSize: 14,
                            color: ColorUtils.slate600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: unassignedClasses.isEmpty
                              ? buildEmptyState()
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: unassignedClasses.length,
                                  itemBuilder: (context, index) {
                                    final classItem = unassignedClasses[index];
                                    return buildClassListItem(
                                      classItem,
                                      getPrimaryColor(),
                                      () {
                                        AppNavigator.pop(context);
                                        addClassToSubject(classItem);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  buildDialogFooter(() => AppNavigator.pop(context), () {
                    AppNavigator.pop(context);
                    setState(() {});
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds empty state for unassigned classes
  Widget buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 48, color: Colors.green),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Semua kelas sudah ditambahkan',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
      headerFilterChips: buildStatusFilterChipStrip(
        currentFilter: selectedFilter,
        onTap: _openStatusFilterSheet,
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

/// Three-option mutually-exclusive Status filter list. Renders as
/// large tappable rows with a check icon on the currently-selected
/// row. Keeps the picker minimal so it feels like a lightweight chip
/// affordance rather than a full filter form.
class _StatusFilterPicker extends StatelessWidget {
  final String selected;
  final Color primaryColor;
  final ValueChanged<String> onSelect;

  const _StatusFilterPicker({
    required this.selected,
    required this.primaryColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const options = <(String, String, IconData)>[
      ('All', 'Semua', Icons.layers_outlined),
      ('Assigned', 'Terdaftar', Icons.check_circle_outline),
      ('Unassigned', 'Belum Terdaftar', Icons.radio_button_unchecked),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final opt in options)
          _StatusFilterRow(
            label: opt.$2,
            icon: opt.$3,
            isSelected: selected == opt.$1,
            primaryColor: primaryColor,
            onTap: () => onSelect(opt.$1),
          ),
      ],
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _StatusFilterRow({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? primaryColor : ColorUtils.slate200,
              width: isSelected ? 1.2 : 0.75,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? primaryColor : ColorUtils.slate500,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? primaryColor : ColorUtils.slate800,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
