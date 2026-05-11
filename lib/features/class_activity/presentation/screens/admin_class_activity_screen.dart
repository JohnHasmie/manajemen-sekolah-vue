// Admin class activity monitoring screen.
//
// Like `pages/admin/class-activities.vue` - allows admins to view class
// activities (assignments, homework, exams) created by teachers. Uses a
// drill-down navigation: Teacher list -> Subject list -> Activity list.
//
// In Laravel terms, this consumes ClassActivityController with teacher/
// subject filtering.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/class_activity_data_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/class_activity_header_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/class_activity_navigation_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/class_activity_ui_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_class_activity_cards.dart';

/// Admin screen to monitor class activities per teacher/subject.
///
/// This is a [StatefulWidget] with drill-down navigation:
/// 1. Shows teacher list -> 2. Shows subjects for that teacher
/// -> 3. Shows activities. Like a Vue page with nested views
/// controlled by local state flags.
class AdminClassActivityScreen extends ConsumerStatefulWidget {
  const AdminClassActivityScreen({super.key});

  @override
  AdminClassActivityScreenState createState() =>
      AdminClassActivityScreenState();
}

/// Mutable state for [AdminClassActivityScreen].
///
/// Key state (like Vue `data()`):
/// - [_showTeacherList] / [_showSubjectList] - flags controlling which
///   drill-down view is shown
/// - [_teacherList] / [_subjectList] / [_activityList] - data lists
/// - [_selectedTeacherId] / [_selectedSubjectId] - current selections
///
/// Uses cache-first pattern with [LocalCacheService] for instant
/// display. setState() triggers re-render, like Vue's reactivity.
class AdminClassActivityScreenState
    extends ConsumerState<AdminClassActivityScreen>
    with
        ClassActivityDataMixin,
        ClassActivityHeaderMixin,
        ClassActivityNavigationMixin,
        ClassActivityUiMixin {
  // Data state
  List<dynamic> _teacherList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _activityList = [];
  bool _isLoading = true;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  bool _showTeacherList = true;
  bool _showSubjectList = false;
  String? _errorMessage;

  // UI state
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _infoKey = GlobalKey();
  bool _isTourShowing = false;

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  // ───── Mixin Getters/Setters ─────────────────────────────────────
  @override
  List<dynamic> get teacherList => _teacherList;
  @override
  set teacherList(List<dynamic> v) => _teacherList = v;
  @override
  List<dynamic> get subjectList => _subjectList;
  @override
  set subjectList(List<dynamic> v) => _subjectList = v;
  @override
  List<dynamic> get activityList => _activityList;
  @override
  set activityList(List<dynamic> v) => _activityList = v;
  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool v) => _isLoading = v;
  @override
  String? get selectedTeacherId => _selectedTeacherId;
  @override
  set selectedTeacherId(String? v) => _selectedTeacherId = v;
  @override
  String? get selectedTeacherName => _selectedTeacherName;
  @override
  set selectedTeacherName(String? v) => _selectedTeacherName = v;
  @override
  String? get selectedSubjectId => _selectedSubjectId;
  @override
  set selectedSubjectId(String? v) => _selectedSubjectId = v;
  @override
  String? get selectedSubjectName => _selectedSubjectName;
  @override
  set selectedSubjectName(String? v) => _selectedSubjectName = v;
  @override
  bool get showTeacherList => _showTeacherList;
  @override
  set showTeacherList(bool v) => _showTeacherList = v;
  @override
  bool get showSubjectList => _showSubjectList;
  @override
  set showSubjectList(bool v) => _showSubjectList = v;
  @override
  String? get errorMessage => _errorMessage;
  @override
  set errorMessage(String? v) => _errorMessage = v;
  @override
  TextEditingController get searchController => _searchController;
  @override
  bool get isTourShowing => _isTourShowing;
  @override
  set isTourShowing(bool v) => _isTourShowing = v;
  @override
  GlobalKey get infoKey => _infoKey;
  @override
  GlobalKey get searchKey => _searchKey;

  /// Like Vue's `mounted()` - loads the initial teacher list.
  @override
  void initState() {
    super.initState();
    loadTeachers();
  }

  /// Like Vue's `beforeUnmount()` - cleans up controllers.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    final filteredItems = _showTeacherList
        ? getFilteredTeachers()
        : (_showSubjectList ? getFilteredSubjects() : getFilteredActivities());

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [buildHeader(languageProvider), _buildContent(filteredItems)],
      ),
    );
  }

  Widget _buildErrorScreen() => ErrorScreen(
    errorMessage: _errorMessage!,
    onRetry: _showTeacherList
        ? loadTeachers
        : (_showSubjectList
              ? () => loadSubjectsByTeacher(
                  _selectedTeacherId!,
                  _selectedTeacherName!,
                )
              : () => loadActivitiesBySubject(
                  _selectedSubjectId!,
                  _selectedSubjectName!,
                )),
  );

  Widget _buildContent(List<dynamic> filteredItems) => Expanded(
    child: _isLoading
        ? SkeletonListLoading(
            itemCount: 8,
            infoTagCount: _showTeacherList ? 1 : 2,
            showActions: false,
          )
        : filteredItems.isEmpty
        ? _buildEmptyState()
        : _buildListView(filteredItems),
  );

  Widget _buildEmptyState() {
    final lp = ref.watch(languageRiverpod);
    return EmptyState(
      title: _getEmptyTitle(lp),
      subtitle: _getEmptySubtitle(lp),
      icon: _getEmptyIcon(),
    );
  }

  String _getEmptyTitle(LanguageProvider lp) => lp.getTranslatedText(
    _showTeacherList
        ? {'en': 'No teachers', 'id': 'Tidak ada guru'}
        : _showSubjectList
        ? {'en': 'No subjects', 'id': 'Tidak ada mata pelajaran'}
        : {'en': 'No activities', 'id': 'Tidak ada kegiatan'},
  );

  String _getEmptySubtitle(LanguageProvider lp) {
    if (_searchController.text.isNotEmpty) {
      return lp.getTranslatedText({
        'en': 'No search results found',
        'id': 'Tidak ditemukan hasil pencarian',
      });
    }
    if (_showTeacherList) {
      return lp.getTranslatedText({
        'en': 'No teacher data available',
        'id': 'Data guru tidak tersedia',
      });
    }
    if (_showSubjectList) {
      return lp.getTranslatedText({
        'en': 'Teacher $_selectedTeacherName has no subjects',
        'id': 'Guru $_selectedTeacherName tidak memiliki mata pelajaran',
      });
    }
    return lp.getTranslatedText({
      'en': 'Subject $_selectedSubjectName has no class activities',
      'id':
          'Mata pelajaran $_selectedSubjectName belum memiliki '
          'kegiatan kelas',
    });
  }

  IconData _getEmptyIcon() => _showTeacherList
      ? Icons.people_outline
      : _showSubjectList
      ? Icons.menu_book
      : Icons.event_note;

  Widget _buildListView(List<dynamic> items) => ListView.builder(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    itemCount: items.length,
    itemBuilder: (_, i) {
      final item = items[i];
      if (_showTeacherList) {
        return AdminClassActivityCardBuilders.buildTeacherCard(
          item,
          i,
          () => loadSubjectsByTeacher(
            item['id'].toString(),
            item['name']?.toString() ?? '',
          ),
        );
      } else if (_showSubjectList) {
        return AdminClassActivityCardBuilders.buildSubjectCard(
          item,
          i,
          () => loadActivitiesBySubject(
            item['id'].toString(),
            item['name']?.toString() ?? '',
          ),
        );
      }
      return AdminClassActivityCardBuilders.buildActivityCard(
        item,
        () => showActivityDetail(item),
      );
    },
  );
}
