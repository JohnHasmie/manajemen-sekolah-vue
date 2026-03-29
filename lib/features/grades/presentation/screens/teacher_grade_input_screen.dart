// Grade input screen for teachers — class/subject selection wizard.
// Like `pages/teacher/GradeBook.vue` in a Vue app.
//
// This is the first part of a multi-step screen: Step 0 (select class) ->
// Step 1 (select subject) -> Step 2 (navigates to GradeBookPage).
// In Laravel terms, this is the entry point for GradeController.
//
// Contains:
// - [GradePage] -- the class/subject selection wizard (Steps 0-1)
//
// Related files (extracted from this file):
// - grade_book_screen.dart -- GradeBookPage (grade table with inline editing)
// - grade_input_form.dart -- GradeInputForm (individual grade edit dialog)
// - grade_input_form_new.dart -- GradeInputFormNew (bulk grade input form)
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

import 'package:manajemensekolah/features/grades/presentation/controllers/teacher_grade_controller.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/teacher_grade_state.dart';

/// The class/subject selection screen (Steps 0-1) before entering the grade book.
class GradePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;

  const GradePage({super.key, required this.teacher});

  @override
  GradePageState createState() => GradePageState();
}

class GradePageState extends ConsumerState<GradePage> {
  // Logic migrated to TeacherGradeController
  
  TeacherGradeParams get _controllerParams => 
    TeacherGradeParams(teacher: widget.teacher);

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.8)],
    );
  }

  // Filtering & Search
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final gradeState = ref.read(teacherGradeProvider(_controllerParams)).value;
    if (gradeState != null && gradeState.currentStep != 0) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(teacherGradeProvider(_controllerParams).notifier).loadMoreClasses();
    }
  }

  void _handleSearch() {
    ref.read(teacherGradeProvider(_controllerParams).notifier)
      .updateSearch(_searchController.text);
  }

  // ==================== BUILDERS ====================

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStep0ClassList(
    LanguageProvider languageProvider,
    TeacherGradeState state,
  ) {
    final searchTerm = _searchController.text.toLowerCase();
    final filtered = state.classList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '').toString().toLowerCase();
      final level = (item['grade_level'] ?? item['tingkat'] ?? '').toString().toLowerCase();
      return name.contains(searchTerm) || level.contains(searchTerm);
    }).toList();

    if (state.isLoading) {
      return SkeletonListLoading(padding: EdgeInsets.only(top: 8, bottom: 80));
    }

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.class_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Classes Found',
          'id': 'Tidak Ada Kelas',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'Try adjusting your search filters',
          'id': 'Coba sesuaikan filter pencarian anda',
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(teacherGradeProvider(_controllerParams).notifier).updateSearch(_searchController.text);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(top: 8, bottom: 80),
        itemCount: filtered.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_getPrimaryColor()),
              ),
            );
          }
          final classData = filtered[index];
          final isHomeroom = classData['is_homeroom'] == true;
          final accentColor = isHomeroom ? ColorUtils.primary : _getPrimaryColor();
          final isToday = state.todaySchedules.any(
            (s) => (s['class_id'] ?? s['kelas_id'] ?? '').toString() == classData['id'].toString(),
          );
          final gradeLevel = classData['grade_level'] ?? classData['tingkat'];
          final homeroomTeacher = classData['homeroom_teacher_name'];

          return Container(
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _searchController.clear();
                  ref.read(teacherGradeProvider(_controllerParams).notifier).selectClass(classData);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ColorUtils.slate200, width: 1),
                    boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                        ),
                        child: Icon(
                          isHomeroom ? Icons.home_work_outlined : Icons.class_outlined,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              classData['nama'] ?? classData['name'] ?? '-',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate900,
                              ),
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (gradeLevel != null && gradeLevel.toString().isNotEmpty)
                                  _buildInfoTag(Icons.school_outlined, gradeLevel.toString()),
                                if (isHomeroom) _buildInfoTag(Icons.home_outlined, 'Wali Kelas'),
                                if (homeroomTeacher != null)
                                  _buildInfoTag(Icons.person_outlined, homeroomTeacher.toString()),
                                if (isToday)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.success600.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: ColorUtils.success600.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.today, size: 11, color: ColorUtils.success600),
                                        SizedBox(width: 3),
                                        Text(
                                          'Today',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.success600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: ColorUtils.slate400, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep1SubjectList(
    LanguageProvider languageProvider,
    TeacherGradeState state,
  ) {
    if (state.isLoading) {
      return SkeletonListLoading(padding: EdgeInsets.only(top: 8, bottom: 80));
    }

    final searchTerm = _searchController.text.toLowerCase();
    final filtered = state.subjectList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '').toString().toLowerCase();
      final code = (item['kode'] ?? item['code'] ?? '').toString().toLowerCase();
      return name.contains(searchTerm) || code.contains(searchTerm);
    }).toList();

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Subjects Found',
          'id': 'Tidak Ada Mata Pelajaran',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'No subjects found for this class',
          'id': 'Tidak ada mata pelajaran para kelas ini',
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(teacherGradeProvider(_controllerParams).notifier).loadSubjects(useCache: false);
      },
      child: ListView.builder(
        padding: EdgeInsets.only(top: 8, bottom: 80),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final subject = filtered[index];
          final subjectCode = subject['kode'] ?? subject['code'];
          final canEdit = subject['can_edit'] != false;
          final isToday = state.todaySchedules.any(
            (s) =>
                (s['class_id'] ?? s['kelas_id'] ?? '').toString() == state.selectedClass!['id'].toString() &&
                (s['subject_id'] ?? s['mata_pelajaran_id'] ?? '').toString() == subject['id'].toString(),
          );
          final accentColor = ColorUtils.warning600;

          return Container(
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ref.read(teacherGradeProvider(_controllerParams).notifier).selectSubject(subject);
                  ref.read(teacherGradeProvider(_controllerParams).notifier).setStep(2);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ColorUtils.slate200, width: 1),
                    boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                        ),
                        child: Icon(Icons.book_outlined, color: accentColor, size: 24),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject['nama'] ?? subject['name'] ?? '-',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate900,
                              ),
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (subjectCode != null && subjectCode.toString().isNotEmpty)
                                  _buildInfoTag(Icons.tag, subjectCode.toString()),
                                if (isToday)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.success600.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: ColorUtils.success600.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.today, size: 11, color: ColorUtils.success600),
                                        SizedBox(width: 3),
                                        Text(
                                          'Today',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.success600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (!canEdit)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.warning600.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: ColorUtils.warning600.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock_outline, size: 11, color: ColorUtils.warning600),
                                        SizedBox(width: 3),
                                        Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Read Only',
                                            'id': 'Hanya Lihat',
                                          }),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.warning600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: ColorUtils.slate400, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _handleWillPop(TeacherGradeState state) async {
    if (state.currentStep > 0) {
      if (state.currentStep == 1) {
        _searchController.clear();
      }
      ref.read(teacherGradeProvider(_controllerParams).notifier).setStep(state.currentStep - 1);
      return false;
    }
    return true;
  }

  Widget _buildHeader(
    BuildContext context,
    LanguageProvider languageProvider,
    TeacherGradeState state,
  ) {
    String title = '';
    String subtitle = '';

    if (state.currentStep == 0) {
      title = languageProvider.getTranslatedText({
        'en': 'Input Grades',
        'id': 'Input Nilai',
      });
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select Class',
        'id': 'Pilih Kelas',
      });
    } else if (state.currentStep == 1) {
      title = state.selectedClass?['nama'] ?? state.selectedClass?['name'] ?? 'Class';
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select Subject',
        'id': 'Pilih Mata Pelajaran',
      });
    } else {
      return SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final shouldPop = await _handleWillPop(state);
                  if (shouldPop && context.mounted) AppNavigator.pop(context);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xxl),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: state.currentStep == 0
                          ? languageProvider.getTranslatedText({
                              'en': 'Search class...',
                              'id': 'Cari kelas...',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Search subject...',
                              'id': 'Cari mata pelajaran...',
                            }),
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: Icon(Icons.search, color: _getPrimaryColor()),
                    onPressed: _handleSearch,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final gradeState = ref.watch(teacherGradeProvider(_controllerParams));

    return gradeState.when(
      data: (state) => _buildContent(context, languageProvider, state),
      loading: () => Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Center(child: CircularProgressIndicator(color: _getPrimaryColor())),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LanguageProvider languageProvider,
    TeacherGradeState state,
  ) {
    if (state.currentStep == 2) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldPop = await _handleWillPop(state);
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: GradeBookPage(
          teacher: widget.teacher,
          subject: state.selectedSubject!,
          classData: state.selectedClass!,
          onBack: () {
            ref.read(teacherGradeProvider(_controllerParams).notifier).setStep(1);
          },
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleWillPop(state);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            _buildHeader(context, languageProvider, state),
            Expanded(
              child: state.currentStep == 0
                  ? _buildStep0ClassList(languageProvider, state)
                  : _buildStep1SubjectList(languageProvider, state),
            ),
          ],
        ),
      ),
    );
  }
}
