// Class promotion wizard - multi-step form for promoting students to next grade.
//
// Like `pages/admin/class-promotion.vue` - a step-by-step wizard that allows
// admins to promote students from one class to another across academic years.
// Steps: 1) Select source class -> 2) Select students -> 3) Configure target -> 4) Confirm.
//
// In Laravel terms, this calls `POST /api/classes/promote` with selected student IDs
// and target class/year configuration.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_step_indicator.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_stat_row.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_dropdown.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_info_row.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_section_header.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_grade_level_dropdown.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_homeroom_teacher_dropdown.dart';
import 'package:manajemensekolah/features/settings/data/academic_service.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Multi-step wizard for promoting students to the next class/academic year.
///
/// Like a Vuetify `<v-stepper>` component with 4 steps.
/// This is a [StatefulWidget] with step navigation, student selection, and
/// target class configuration state.
class ClassPromotionWizard extends ConsumerStatefulWidget {
  const ClassPromotionWizard({super.key});

  @override
  ConsumerState<ClassPromotionWizard> createState() =>
      _ClassPromotionWizardState();
}

/// Mutable state for [ClassPromotionWizard].
///
/// Key state (like Vue `data()`):
/// - [_currentStep] - active wizard step (0-based), controls which view is shown
/// - [_classes] / [_academicYears] / [_students] - data lists from API
/// - [_selectedSourceClassId] / [_selectedTargetYearId] / [_selectedTargetClassId] - user selections
/// - [_selectedStudentIds] - Set of student IDs selected for promotion (like Vue `v-model` on checkboxes)
class _ClassPromotionWizardState extends ConsumerState<ClassPromotionWizard> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Data
  List<dynamic> _classes = [];
  List<dynamic> _academicYears = [];
  List<dynamic> _students = [];
  List<dynamic> _targetClasses = [];
  List<dynamic> _teachers = [];
  final List<String> _availableGradeLevels = [];
  String? _schoolJenjang;

  // Selections
  String? _selectedSourceClassId;
  String? _selectedTargetYearId;
  String? _selectedTargetClassId;
  Set<String> _selectedStudentIds = {};

  Color _getPrimaryColor() => ColorUtils.getRoleColor('admin');

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.85)],
    );
  }

  /// Like Vue's `mounted()` - loads classes, academic years, teachers, and school settings.
  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _fetchTeachers();
    _loadSchoolSettings();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Loads classes and academic years for the wizard dropdowns.
  /// Like calling `GET /api/classes` and `GET /api/academic-years` in Vue's `mounted()`.
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final yearsData = await getIt<ApiAcademicServices>().getAcademicYears();

      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYear = academicYearProvider.selectedAcademicYear;

      List<dynamic> classesData = [];
      if (selectedYear != null) {
        final response = await getIt<ApiClassService>().getClassPaginated(
          limit: 1000,
          academicYearId: selectedYear['id'].toString(),
        );
        classesData = response['data'] ?? [];
      } else {
        final activeYear = await getIt<ApiAcademicServices>()
            .getActiveAcademicYear();
        if (activeYear != null) {
          final response = await getIt<ApiClassService>().getClassPaginated(
            limit: 1000,
            academicYearId: activeYear['id'].toString(),
          );
          classesData = response['data'] ?? [];
        } else {
          classesData = await getIt<ApiClassService>().getClass();
        }
      }

      setState(() {
        _classes = classesData;
        _academicYears = yearsData;
      });
    } catch (e) {
      AppLogger.error('classroom', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToLoadInitialData.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudents(String classId) async {
    setState(() => _isLoading = true);
    try {
      final students = await getIt<ApiClassService>().getStudentsByClassId(
        classId,
      );
      setState(() {
        _students = students;
        _selectedStudentIds = students.map((s) => s['id'].toString()).toSet();
      });
    } catch (e) {
      AppLogger.error('classroom', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTargetClasses(String yearId) async {
    setState(() => _isLoading = true);
    try {
      final response = await getIt<ApiClassService>().getClassPaginated(
        limit: 1000,
        academicYearId: yearId,
      );

      setState(() {
        if (response['data'] != null && response['data'] is List) {
          _targetClasses = response['data'];
        } else {
          _targetClasses = [];
        }
      });
    } catch (e) {
      AppLogger.error('classroom', e);
      setState(() => _targetClasses = []);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTeachers() async {
    try {
      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        limit: 1000,
      );
      if (!mounted) return;
      setState(() {
        _teachers = response['data'] ?? [];
      });
    } catch (e) {
      AppLogger.error('classroom', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  void _predictTargetYear() {
    if (_selectedSourceClassId == null || _academicYears.isEmpty) return;

    final sourceClass = _classes.firstWhere(
      (c) => c['id'].toString() == _selectedSourceClassId,
      orElse: () => null,
    );

    if (sourceClass != null) {
      String? sourceYearId = sourceClass['academic_year_id']?.toString();
      if (sourceYearId == null && sourceClass['academic_year'] != null) {
        sourceYearId = sourceClass['academic_year']['id']?.toString();
      }

      if (sourceYearId != null) {
        final currentIndex = _academicYears.indexWhere(
          (y) => y['id'].toString() == sourceYearId,
        );

        if (currentIndex != -1 && currentIndex < _academicYears.length - 1) {
          final currentYearData = _academicYears[currentIndex];
          final String currentYearName =
              currentYearData['year']?.toString() ?? '';
          final startYearStr = currentYearName.split('/').first;
          final startYear = int.tryParse(startYearStr);

          String? nextYearId;

          if (startYear != null) {
            final nextStartYearPattern = (startYear + 1).toString();
            final nextYearObj = _academicYears.firstWhere(
              (y) => (y['year']?.toString() ?? '').startsWith(
                nextStartYearPattern,
              ),
              orElse: () => null,
            );
            if (nextYearObj != null) {
              nextYearId = nextYearObj['id'].toString();
            }
          }

          nextYearId ??= _academicYears[currentIndex + 1]['id'].toString();

          setState(() {
            _selectedTargetYearId = nextYearId;
          });
          _loadTargetClasses(nextYearId);
        }
      }
    }
  }

  bool _isAlreadyPromoted(dynamic student) {
    if (_selectedTargetYearId == null) return false;

    final List classes = student['classes'] ?? [];
    for (var cls in classes) {
      if (cls['pivot'] != null) {
        final yearId = cls['pivot']['academic_year_id']?.toString();
        if (yearId == _selectedTargetYearId) {
          return true;
        }
      }
      if (cls['academic_year_id']?.toString() == _selectedTargetYearId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadSchoolSettings() async {
    try {
      final settings = await getIt<ApiSettingsService>().getSchoolSettings();
      if (!mounted) return;
      setState(() {
        _schoolJenjang = settings['jenjang'];
        _generateGradeLevels();
      });
    } catch (e) {
      AppLogger.error('classroom', e);
      setState(_generateGradeLevels);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  void _generateGradeLevels() {
    _availableGradeLevels.clear();
    int start = 1;
    int end = 12;

    if (_schoolJenjang != null) {
      final jenjang = _schoolJenjang!.toUpperCase();
      if (jenjang == 'SD') {
        start = 1;
        end = 6;
      } else if (jenjang == 'SMP') {
        start = 7;
        end = 9;
      } else if (jenjang == 'SMA' || jenjang == 'SMK') {
        start = 10;
        end = 12;
      }
    }

    for (int i = start; i <= end; i++) {
      _availableGradeLevels.add(i.toString());
    }
  }

  final PageController _pageController = PageController();

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }


  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final steps = [
      languageProvider.getTranslatedText({'en': 'Source', 'id': 'Asal'}),
      languageProvider.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
      languageProvider.getTranslatedText({'en': 'Target', 'id': 'Tujuan'}),
      languageProvider.getTranslatedText({'en': 'Summary', 'id': 'Ringkasan'}),
    ];

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Stack(
        children: [
          Column(
            children: [
              // --- Gradient Header (Pattern #7) ---
              Container(
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
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_currentStep > 0) {
                          _onStepCancel();
                        } else {
                          AppNavigator.pop(context);
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Promote Class',
                              'id': 'Naik Kelas',
                            }),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            languageProvider.getTranslatedText({
                              'en':
                                  'Step ${_currentStep + 1} of ${steps.length}: ${steps[_currentStep]}',
                              'id':
                                  'Langkah ${_currentStep + 1} dari ${steps.length}: ${steps[_currentStep]}',
                            }),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- Step Indicator ---
              PromotionStepIndicator(
                currentStep: _currentStep,
                totalSteps: steps.length,
                steps: steps,
                primaryColor: _getPrimaryColor(),
              ),

              // --- Step Content ---
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    _buildStepContainer(_buildSourceStep(languageProvider)),
                    _buildStepContainer(_buildStudentsStep(languageProvider)),
                    _buildStepContainer(_buildTargetStep(languageProvider)),
                    _buildStepContainer(_buildSummaryStep(languageProvider)),
                  ],
                ),
              ),

              // --- Bottom Controls ---
              _buildBottomControls(languageProvider),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getPrimaryColor().withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getPrimaryColor(),
                    ),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContainer(Widget child) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }

  Widget _buildBottomControls(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _onStepCancel,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: ColorUtils.slate700,
                  ),
                  label: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Back',
                      'id': 'Kembali',
                    }),
                    style: TextStyle(
                      color: ColorUtils.slate700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: ColorUtils.slate300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _onStepContinue,
                icon: Icon(
                  _currentStep == 3
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  _currentStep == 3
                      ? languageProvider.getTranslatedText({
                          'en': 'Finish',
                          'id': 'Selesai',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Continue',
                          'id': 'Lanjut',
                        }),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == 3
                      ? ColorUtils.success600
                      : _getPrimaryColor(),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: _getPrimaryColor().withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================
  // STEP 1: SOURCE CLASS
  // ==============================
  Widget _buildSourceStep(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionSectionHeader(
          icon: Icons.school_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Select Source Class',
            'id': 'Pilih Kelas Asal',
          }),
          primaryColor: _getPrimaryColor(),
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Source Class',
                  'id': 'Kelas Asal',
                }),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate600,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSourceClassId,
                    isExpanded: true,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: ColorUtils.slate500,
                    ),
                    hint: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Select a class',
                        'id': 'Pilih kelas',
                      }),
                      style: TextStyle(
                        color: ColorUtils.slate400,
                        fontSize: 14,
                      ),
                    ),
                    items: _classes.map<DropdownMenuItem<String>>((c) {
                      return DropdownMenuItem(
                        value: c['id'].toString(),
                        child: Text(
                          c['name'] ?? 'Unknown',
                          style: TextStyle(
                            color: ColorUtils.slate800,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSourceClassId = val;
                      });
                      if (val != null) {
                        _loadStudents(val);
                        _selectedTargetYearId = null;
                        _predictTargetYear();
                      }
                    },
                  ),
                ),
              ),
              if (_selectedSourceClassId != null) ...[
                SizedBox(height: AppSpacing.lg),
                Container(
                  padding: EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _getPrimaryColor().withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _getPrimaryColor().withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getPrimaryColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: _getPrimaryColor(),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en':
                                '${_students.length} students found in this class',
                            'id':
                                '${_students.length} siswa ditemukan di kelas ini',
                          }),
                          style: TextStyle(
                            fontSize: 13,
                            color: _getPrimaryColor(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ==============================
  // STEP 2: STUDENTS
  // ==============================
  Widget _buildStudentsStep(LanguageProvider languageProvider) {
    final eligibleStudents = _students
        .where((s) => !_isAlreadyPromoted(s))
        .length;
    final alreadyPromotedCount = _students.length - eligibleStudents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionSectionHeader(
          icon: Icons.people_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Student Selection',
            'id': 'Pilih Siswa',
          }),
          primaryColor: _getPrimaryColor(),
        ),
        SizedBox(height: AppSpacing.xs),

        // Stats card
        Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            children: [
              PromotionStatRow(
                icon: Icons.groups_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Total Students',
                  'id': 'Total Siswa',
                }),
                value: _students.length.toString(),
                color: _getPrimaryColor(),
              ),
              SizedBox(height: AppSpacing.sm),
              PromotionStatRow(
                icon: Icons.check_circle_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Eligible for Promotion',
                  'id': 'Bisa Naik Kelas',
                }),
                value: eligibleStudents.toString(),
                color: ColorUtils.success600,
              ),
              if (alreadyPromotedCount > 0) ...[
                SizedBox(height: AppSpacing.sm),
                PromotionStatRow(
                  icon: Icons.warning_rounded,
                  label: languageProvider.getTranslatedText({
                    'en': 'Already Promoted',
                    'id': 'Sudah Naik Kelas',
                  }),
                  value: alreadyPromotedCount.toString(),
                  color: ColorUtils.warning600,
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(
                  Icons.select_all_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Eligible',
                    'id': 'Pilih Semua',
                  }),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _getPrimaryColor(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  setState(() {
                    _selectedStudentIds.clear();
                    for (var s in _students) {
                      if (!_isAlreadyPromoted(s)) {
                        _selectedStudentIds.add(s['id'].toString());
                      }
                    }
                  });
                  SnackBarUtils.showSuccess(
                    context,
                    languageProvider.getTranslatedText({
                      'en': 'All eligible students selected',
                      'id': 'Semua siswa yang memenuhi syarat dipilih',
                    }),
                  );
                },
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(
                  Icons.checklist_rounded,
                  size: 18,
                  color: _getPrimaryColor(),
                ),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Manually',
                    'id': 'Pilih Siswa',
                  }),
                  style: TextStyle(
                    color: _getPrimaryColor(),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: _getPrimaryColor()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showStudentSelectionDialog(languageProvider),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xl),

        // Selected count badge
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _selectedStudentIds.isNotEmpty
                ? ColorUtils.success600.withValues(alpha: 0.08)
                : ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedStudentIds.isNotEmpty
                  ? ColorUtils.success600.withValues(alpha: 0.25)
                  : ColorUtils.slate200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedStudentIds.isNotEmpty
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 20,
                color: _selectedStudentIds.isNotEmpty
                    ? ColorUtils.success600
                    : ColorUtils.slate500,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Selected: ${_selectedStudentIds.length} students',
                  'id': 'Terpilih: ${_selectedStudentIds.length} siswa',
                }),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _selectedStudentIds.isNotEmpty
                      ? ColorUtils.success600
                      : ColorUtils.slate700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================
  // STEP 3: TARGET
  // ==============================
  Widget _buildTargetStep(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionSectionHeader(
          icon: Icons.school_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Target Configuration',
            'id': 'Konfigurasi Tujuan',
          }),
          primaryColor: _getPrimaryColor(),
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            children: [
              PromotionDropdown(
                label: languageProvider.getTranslatedText({
                  'en': 'Target Academic Year',
                  'id': 'Tahun Ajaran Tujuan',
                }),
                value: _selectedTargetYearId,
                items: _academicYears.map<DropdownMenuItem<String>>((y) {
                  return DropdownMenuItem(
                    value: y['id'].toString(),
                    child: Text(
                      y['year'] ?? 'Unknown',
                      style: TextStyle(
                        color: ColorUtils.slate800,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTargetYearId = val;
                    _selectedTargetClassId = null;
                  });
                  if (val != null) _loadTargetClasses(val);
                },
                icon: Icons.calendar_today_rounded,
                primaryColor: _getPrimaryColor(),
              ),
              SizedBox(height: AppSpacing.lg),
              PromotionDropdown(
                label: languageProvider.getTranslatedText({
                  'en': 'Target Class',
                  'id': 'Kelas Tujuan',
                }),
                value: _selectedTargetClassId,
                items: _targetClasses.isEmpty
                    ? []
                    : _targetClasses.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text(
                            c['name'] ?? 'Unknown',
                            style: TextStyle(
                              color: ColorUtils.slate800,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }).toList(),
                onChanged: (val) =>
                    setState(() => _selectedTargetClassId = val),
                hint: _targetClasses.isEmpty
                    ? languageProvider.getTranslatedText({
                        'en': 'No classes found',
                        'id': 'Tidak ada kelas',
                      })
                    : null,
                icon: Icons.class_rounded,
                primaryColor: _getPrimaryColor(),
              ),
              SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: _getPrimaryColor(),
                  ),
                  label: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Create New Class',
                      'id': 'Buat Kelas Baru',
                    }),
                    style: TextStyle(
                      color: _getPrimaryColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: _getPrimaryColor()),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _showCreateClassDialog,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================
  // STEP 4: SUMMARY
  // ==============================
  Widget _buildSummaryStep(LanguageProvider languageProvider) {
    final sourceClass = _classes.firstWhere(
      (c) => c['id'].toString() == _selectedSourceClassId,
      orElse: () => {'name': 'Unknown'},
    );
    final targetClass = _targetClasses.firstWhere(
      (c) => c['id'].toString() == _selectedTargetClassId,
      orElse: () => {'name': 'Unknown'},
    );
    final targetYear = _academicYears.firstWhere(
      (y) => y['id'].toString() == _selectedTargetYearId,
      orElse: () => {'year': 'Unknown'},
    );

    final selectedStudentsList = _students
        .where((s) => _selectedStudentIds.contains(s['id'].toString()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionSectionHeader(
          icon: Icons.summarize_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Promotion Summary',
            'id': 'Ringkasan Kenaikan',
          }),
          primaryColor: _getPrimaryColor(),
        ),
        SizedBox(height: AppSpacing.xs),

        // Summary info card
        Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            children: [
              PromotionInfoRow(
                icon: Icons.school_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Source Class',
                  'id': 'Kelas Asal',
                }),
                value: sourceClass['name'] ?? '-',
                primaryColor: _getPrimaryColor(),
              ),
              PromotionInfoRow(
                icon: Icons.arrow_forward_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Target Class',
                  'id': 'Kelas Tujuan',
                }),
                value: targetClass['name'] ?? '-',
                primaryColor: _getPrimaryColor(),
              ),
              PromotionInfoRow(
                icon: Icons.calendar_today_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Target Academic Year',
                  'id': 'Tahun Ajaran Tujuan',
                }),
                value: targetYear['year'] ?? '-',
                primaryColor: _getPrimaryColor(),
              ),
              PromotionInfoRow(
                icon: Icons.people_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Students to Promote',
                  'id': 'Siswa yang Dinaikkan',
                }),
                value: '${selectedStudentsList.length} siswa',
                primaryColor: _getPrimaryColor(),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),

        // Student list
        PromotionSectionHeader(
          icon: Icons.list_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Selected Students (${selectedStudentsList.length})',
            'id': 'Siswa Terpilih (${selectedStudentsList.length})',
          }),
          primaryColor: _getPrimaryColor(),
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          constraints: BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.all(AppSpacing.md),
            itemCount: selectedStudentsList.length,
            separatorBuilder: (ctx, i) =>
                Divider(height: 1, color: ColorUtils.slate100),
            itemBuilder: (context, index) {
              final student = selectedStudentsList[index];
              final nameStr = student['name'] ?? '-';
              final nameHash = nameStr.codeUnits.fold(0, (sum, c) => sum + c);
              final avatarColor = ColorUtils.getColorForIndex(nameHash);

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: avatarColor.withValues(alpha: 0.15),
                      child: Text(
                        nameStr.isNotEmpty ? nameStr[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: avatarColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${index + 1}. $nameStr',
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==============================
  // STUDENT SELECTION DIALOG
  // ==============================
  void _showStudentSelectionDialog(LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Gradient header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 16, 12, 16),
                  decoration: BoxDecoration(
                    gradient: _getCardGradient(),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.checklist_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Select Students',
                                    'id': 'Pilih Siswa',
                                  }),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_selectedStudentIds.length}/${_students.length} dipilih',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => AppNavigator.pop(context),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Student list
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final id = student['id'].toString();
                      final isPromoted = _isAlreadyPromoted(student);
                      final isSelected = _selectedStudentIds.contains(id);
                      final nameStr = student['name'] ?? 'Unknown';
                      final nameHash = nameStr.codeUnits.fold(
                        0,
                        (sum, c) => sum + c,
                      );
                      final avatarColor = ColorUtils.getColorForIndex(nameHash);

                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isPromoted
                              ? ColorUtils.slate50
                              : isSelected
                              ? _getPrimaryColor().withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? _getPrimaryColor().withValues(alpha: 0.3)
                                : ColorUtils.slate200,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: isPromoted
                                ? null
                                : () {
                                    setDialogState(() {
                                      if (isSelected) {
                                        _selectedStudentIds.remove(id);
                                      } else {
                                        _selectedStudentIds.add(id);
                                      }
                                    });
                                    setState(() {});
                                  },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isPromoted
                                        ? ColorUtils.slate200
                                        : avatarColor.withValues(alpha: 0.15),
                                    child: Text(
                                      nameStr.isNotEmpty
                                          ? nameStr[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isPromoted
                                            ? ColorUtils.slate400
                                            : avatarColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nameStr,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isPromoted
                                                ? ColorUtils.slate400
                                                : ColorUtils.slate900,
                                            fontWeight: FontWeight.w600,
                                            decoration: isPromoted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        if (isPromoted)
                                          Text(
                                            languageProvider.getTranslatedText({
                                              'en': 'Already Promoted',
                                              'id': 'Sudah Naik Kelas',
                                            }),
                                            style: TextStyle(
                                              color: ColorUtils.warning600,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (!isPromoted)
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _getPrimaryColor()
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? _getPrimaryColor()
                                              : ColorUtils.slate300,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Footer
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.slate900.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => AppNavigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Done',
                            'id': 'Selesai',
                          }),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==============================
  // STEP NAVIGATION
  // ==============================
  void _onStepContinue() async {
    final languageProvider = ref.read(languageRiverpod);
    if (_currentStep == 0) {
      if (_selectedSourceClassId == null) return;
      if (_students.isEmpty) await _loadStudents(_selectedSourceClassId!);
      _goToStep(1);
    } else if (_currentStep == 1) {
      if (_selectedStudentIds.isEmpty) return;

      if (_selectedSourceClassId != null && _academicYears.isNotEmpty) {
        final sourceClass = _classes.firstWhere(
          (c) => c['id'].toString() == _selectedSourceClassId,
          orElse: () => null,
        );
        if (sourceClass != null) {
          String? sourceYearId = sourceClass['academic_year_id']?.toString();
          if (sourceYearId == null && sourceClass['academic_year'] != null) {
            sourceYearId = sourceClass['academic_year']['id']?.toString();
          }
          if (sourceYearId != null) {
            final currentIndex = _academicYears.indexWhere(
              (y) => y['id'].toString() == sourceYearId,
            );
            if (currentIndex != -1 &&
                currentIndex < _academicYears.length - 1) {
              final currentYearData = _academicYears[currentIndex];
              final String currentYearName =
                  currentYearData['year']?.toString() ?? '';
              final startYearStr = currentYearName.split('/').first;
              final startYear = int.tryParse(startYearStr);

              if (startYear != null) {
                final nextYearNameStart = (startYear + 1).toString();
                final nextYear = _academicYears.firstWhere(
                  (y) => (y['year']?.toString() ?? '').startsWith(
                    nextYearNameStart,
                  ),
                  orElse: () => null,
                );
                if (nextYear != null) {
                  setState(() {
                    _selectedTargetYearId = nextYear['id'].toString();
                  });
                  await _loadTargetClasses(_selectedTargetYearId!);
                }
              }
            }
          }
        }
      }

      _goToStep(2);
    } else if (_currentStep == 2) {
      if (_selectedTargetYearId == null) return;
      if (_selectedTargetClassId == null) {
        SnackBarUtils.showWarning(
          context,
          languageProvider.getTranslatedText({
            'en': 'Please select or create a target class',
            'id': 'Silakan pilih atau buat kelas tujuan',
          }),
        );
        return;
      }
      _goToStep(3);
    } else if (_currentStep == 3) {
      _submitPromotion();
    }
  }

  Future<void> _submitPromotion() async {
    final languageProvider = ref.read(languageRiverpod);
    setState(() => _isLoading = true);
    try {
      final data = {
        'source_class_id': _selectedSourceClassId,
        'target_class_id': _selectedTargetClassId,
        'student_ids': _selectedStudentIds.toList(),
        'academic_year_id': _selectedTargetYearId,
      };

      await getIt<ApiClassService>().promoteStudents(data);

      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'Promotion successful',
          'id': 'Kenaikan kelas berhasil',
        }),
      );
      AppNavigator.pop(context, true);
    } catch (e) {
      AppLogger.error('classroom', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToProcess.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      AppNavigator.pop(context);
    }
  }

  // ==============================
  // CREATE CLASS DIALOG
  // ==============================
  void _showCreateClassDialog() {
    final languageProvider = ref.read(languageRiverpod);
    final nameController = TextEditingController();
    String? selectedGradeLevel;
    String? selectedHomeroomTeacherId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gradient header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(gradient: _getCardGradient()),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Create New Class',
                                  'id': 'Buat Kelas Baru',
                                }),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Add a new target class',
                                  'id': 'Tambah kelas tujuan baru',
                                }),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form body
                  Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDialogTextField(
                          controller: nameController,
                          label: languageProvider.getTranslatedText({
                            'en': 'Class Name',
                            'id': 'Nama Kelas',
                          }),
                          icon: Icons.school_rounded,
                        ),
                        SizedBox(height: AppSpacing.md),
                        PromotionGradeLevelDropdown(
                          value: selectedGradeLevel,
                          onChanged: (val) {
                            setDialogState(() {
                              selectedGradeLevel = val;
                            });
                          },
                          languageProvider: languageProvider,
                          availableGradeLevels: _availableGradeLevels,
                          primaryColor: _getPrimaryColor(),
                        ),
                        SizedBox(height: AppSpacing.md),
                        PromotionHomeroomTeacherDropdown(
                          value: selectedHomeroomTeacherId,
                          onChanged: (val) {
                            setDialogState(() {
                              selectedHomeroomTeacherId = val;
                            });
                          },
                          languageProvider: languageProvider,
                          teachers: _teachers,
                          primaryColor: _getPrimaryColor(),
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Cancel',
                                'id': 'Batal',
                              }),
                              style: TextStyle(
                                color: ColorUtils.slate700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isEmpty ||
                                  selectedGradeLevel == null) {
                                SnackBarUtils.showWarning(
                                  context,
                                  'Please fill required fields',
                                );
                                return;
                              }

                              try {
                                final data = {
                                  'name': nameController.text.trim(),
                                  'grade_level': int.parse(selectedGradeLevel!),
                                  'homeroom_teacher_id':
                                      selectedHomeroomTeacherId,
                                  'academic_year_id': _selectedTargetYearId,
                                };
                                await getIt<ApiClassService>().addClass(data);
                                if (!mounted) return;
                                // ignore: use_build_context_synchronously
                                AppNavigator.pop(context);
                                if (_selectedTargetYearId != null) {
                                  _loadTargetClasses(_selectedTargetYearId!);
                                }
                                SnackBarUtils.showSuccess(
                                  // ignore: use_build_context_synchronously
                                  context,
                                  'Class Created',
                                );
                              } catch (e) {
                                AppLogger.error('classroom', e);
                                if (mounted) {
                                  SnackBarUtils.showError(
                                    // ignore: use_build_context_synchronously
                                    context,
                                    '${AppLocalizations.failedToSave.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 13),
                              elevation: 2,
                              shadowColor: _getPrimaryColor().withValues(
                                alpha: 0.4,
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Create',
                                'id': 'Buat',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: ColorUtils.slate800, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate600, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

}
