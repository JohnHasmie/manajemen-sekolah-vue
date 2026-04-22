// Admin subject (mata pelajaran) management screen
// - full CRUD for subjects with search, filters, and
// pagination.
//
// Refactored to use mixin-based state
// decomposition for maintainability.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/mixins/subject_actions_mixin.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/mixins/subject_data_mixin.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/mixins/subject_filter_mixin.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/mixins/subject_tour_mixin.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/mixins/subject_ui_builder_mixin.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Admin subject management screen with full CRUD,
/// search, filters, and Excel import/export.
class AdminSubjectManagementScreen extends ConsumerStatefulWidget {
  const AdminSubjectManagementScreen({super.key});

  @override
  AdminSubjectManagementScreenState createState() =>
      AdminSubjectManagementScreenState();
}

/// Mutable state for [AdminSubjectManagementScreen].
///
/// Composed of mixins for logical grouping:
/// - [SubjectDataMixin] - loading, pagination, sync
/// - [SubjectFilterMixin] - filtering, search
/// - [SubjectActionsMixin] - CRUD operations
/// - [SubjectUIBuilderMixin] - header and list UI
/// - [SubjectTourMixin] - guided tour
class AdminSubjectManagementScreenState
    extends ConsumerState<AdminSubjectManagementScreen>
    with
        SubjectDataMixin,
        SubjectFilterMixin,
        SubjectActionsMixin,
        SubjectUIBuilderMixin,
        SubjectTourMixin {
  // State fields for UI
  bool _isLoading = true;
  String _errorMessage = '';

  // Tour Keys
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  @override
  GlobalKey get menuKey => _menuKey;

  @override
  GlobalKey get searchKey => _searchKey;

  @override
  GlobalKey get filterKey => _filterKey;

  @override
  GlobalKey get fabKey => _fabKey;

  @override
  bool get isLoading => _isLoading;

  @override
  String get errorMessage => _errorMessage;

  @override
  set isLoading(bool value) {
    _isLoading = value;
  }

  @override
  set errorMessage(String value) {
    _errorMessage = value;
  }

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    searchController = TextEditingController();
    initializeDataLoading();
  }

  @override
  void dispose() {
    disposeDataLoading();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    if (isLoading) {
      return Scaffold(
        backgroundColor: ColorUtils.lightGray,
        body: Column(
          children: [
            buildHeader(context, languageProvider),
            const Expanded(
              child: SkeletonListLoading(itemCount: 6, infoTagCount: 2),
            ),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return ErrorScreen(errorMessage: errorMessage, onRetry: loadSubjects);
    }

    final filteredSubjects = getFilteredSubjects(
      subjectList,
      searchController.text,
    );

    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          buildHeader(context, languageProvider),
          Expanded(
            child: filteredSubjects.isEmpty
                ? EmptyState(
                    title: languageProvider.getTranslatedText({
                      'en': 'No subjects',
                      'id': 'Tidak ada mata pelajaran',
                    }),
                    subtitle: searchController.text.isEmpty && !hasActiveFilter
                        ? languageProvider.getTranslatedText({
                            'en': 'Tap + to add a subject',
                            'id':
                                'Tap + untuk menambah '
                                'mata pelajaran',
                          })
                        : languageProvider.getTranslatedText({
                            'en':
                                'No search results '
                                'found',
                            'id':
                                'Tidak ditemukan hasil '
                                'pencarian',
                          }),
                    icon: Icons.school_outlined,
                  )
                : buildListView(filteredSubjects),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: fabKey,
        onPressed: showAddEditDialog,
        backgroundColor: ColorUtils.primary, // Adjust to match controller
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }
}
