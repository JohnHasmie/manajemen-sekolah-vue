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
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/enhanced_search_bar.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart'
    as model_subject;
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_data_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_filter_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_actions_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_ui_mixin.dart';
import 'package:manajemensekolah/features/subjects/presentation/mixins/subject_class_ui_builder_mixin.dart';

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
  dynamic getSubjectId() =>
      model_subject.Subject.fromJson(widget.subject).id;

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

  /// Builds search bar widget
  @override
  Widget buildSearchBar() {
    final translatedOptions = _getTranslatedFilterOptions();

    return EnhancedSearchBar(
      controller: searchController,
      hintText: 'Cari classItem...',
      onChanged: (value) {
        setState(() {});
      },
      filterOptions: translatedOptions,
      selectedFilter:
          translatedOptions[selectedFilter == 'All'
              ? 0
              : selectedFilter == 'Assigned'
              ? 1
              : 2],
      onFilterChanged: (filter) {
        final index = translatedOptions.indexOf(filter);
        setState(() {
          selectedFilter = index == 0
              ? 'All'
              : index == 1
              ? 'Assigned'
              : 'Unassigned';
        });
      },
      showFilter: true,
    );
  }

  /// Gets translated filter options
  List<String> _getTranslatedFilterOptions() {
    final lang = ref.read(languageRiverpod);
    return [
      lang.getTranslatedText({'en': 'All', 'id': 'Semua'}),
      lang.getTranslatedText({'en': 'Assigned', 'id': 'Terdaftar'}),
      lang.getTranslatedText({'en': 'Unassigned', 'id': 'Belum Terdaftar'}),
    ];
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
    );
  }
}
