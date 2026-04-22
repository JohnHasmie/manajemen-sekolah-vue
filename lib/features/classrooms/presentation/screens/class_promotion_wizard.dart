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
import 'package:manajemensekolah/features/classrooms/presentation/widgets/class_promotion_step1_source.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/class_promotion_step2_students.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/class_promotion_step3_target.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/class_promotion_step4_summary.dart';
import 'package:manajemensekolah/features/classrooms/presentation/mixins/class_promotion_data_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/mixins/class_promotion_helpers_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/mixins/class_promotion_ui_mixin.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';

/// Multi-step wizard for promoting students to the next class/academic year.
///
/// Like a Vuetify `<v-stepper>` component with 4 steps.
/// This is a [ConsumerStatefulWidget] with step navigation, student selection, and
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
/// - [_selectedStudentIds] - Set of student IDs selected for promotion
class _ClassPromotionWizardState extends ConsumerState<ClassPromotionWizard>
    with
        ClassPromotionDataMixin,
        ClassPromotionHelpersMixin,
        ClassPromotionUIMixin {
  int _currentStep = 0;
  bool _isLoading = false;
  List<dynamic> _classes = [];
  List<dynamic> _academicYears = [];
  List<dynamic> _students = [];
  List<dynamic> _targetClasses = [];
  List<dynamic> _teachers = [];
  final List<String> _availableGradeLevels = [];
  String? _schoolJenjang;
  String? _selectedSourceClassId;
  String? _selectedTargetYearId;
  String? _selectedTargetClassId;
  final Set<String> _selectedStudentIds = {};
  final PageController _pageController = PageController();

  // ========== Mixin implementation getters/setters ==========

  @override
  int get currentStep => _currentStep;
  @override
  set currentStep(int v) => _currentStep = v;

  @override
  List<dynamic> get classes => _classes;
  @override
  set classes(List<dynamic> v) => _classes = v;

  @override
  List<dynamic> get academicYears => _academicYears;
  @override
  set academicYears(List<dynamic> v) => _academicYears = v;

  @override
  List<dynamic> get students => _students;
  @override
  set students(List<dynamic> v) => _students = v;

  @override
  List<dynamic> get targetClasses => _targetClasses;
  @override
  set targetClasses(List<dynamic> v) => _targetClasses = v;

  @override
  List<dynamic> get teachers => _teachers;
  @override
  set teachers(List<dynamic> v) => _teachers = v;

  @override
  List<String> get availableGradeLevels => _availableGradeLevels;

  @override
  String? get schoolJenjang => _schoolJenjang;
  @override
  set schoolJenjang(String? v) => _schoolJenjang = v;

  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool v) => setState(() => _isLoading = v);

  @override
  String? get selectedSourceClassId => _selectedSourceClassId;
  @override
  String? get selectedTargetYearId => _selectedTargetYearId;
  @override
  String? get selectedTargetClassId => _selectedTargetClassId;

  @override
  Set<String> get selectedStudentIds => _selectedStudentIds;

  @override
  PageController get pageController => _pageController;

  @override
  void generateGradeLevels() {
    _availableGradeLevels.clear();
    int start = 1, end = 12;
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

  @override
  void initState() {
    super.initState();
    loadInitialData();
    fetchTeachers();
    loadSchoolSettings();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  VoidCallback get onStepCancel {
    return () {
      if (currentStep > 0) {
        goToStep(currentStep - 1);
      } else {
        AppNavigator.pop(context);
      }
    };
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
              buildGradientHeader(languageProvider, steps),
              PromotionStepIndicator(
                currentStep: _currentStep,
                totalSteps: steps.length,
                steps: steps,
                primaryColor: getPrimaryColor(),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    buildStepContainer(
                      ClassPromotionStep1Source(
                        classes: _classes,
                        selectedSourceClassId: _selectedSourceClassId,
                        studentCount: _students.length,
                        primaryColor: getPrimaryColor(),
                        languageProvider: languageProvider,
                        onClassSelected: (val) =>
                            setState(() => _selectedSourceClassId = val),
                        onClassLoadRequested: () {
                          if (_selectedSourceClassId != null) {
                            loadStudents(_selectedSourceClassId!);
                            _selectedTargetYearId = null;
                            predictTargetYear();
                          }
                        },
                      ),
                    ),
                    buildStepContainer(
                      ClassPromotionStep2Students(
                        students: _students,
                        selectedStudentIds: _selectedStudentIds,
                        primaryColor: getPrimaryColor(),
                        languageProvider: languageProvider,
                        isAlreadyPromoted: isAlreadyPromoted,
                        onSelectEligible: () {
                          setState(() {
                            _selectedStudentIds.clear();
                            for (final s in _students) {
                              if (!isAlreadyPromoted(s)) {
                                _selectedStudentIds.add(s['id'].toString());
                              }
                            }
                          });
                        },
                        onSelectManually: () =>
                            showStudentSelectionDialog(languageProvider),
                      ),
                    ),
                    buildStepContainer(
                      ClassPromotionStep3Target(
                        academicYears: _academicYears,
                        targetClasses: _targetClasses,
                        selectedTargetYearId: _selectedTargetYearId,
                        selectedTargetClassId: _selectedTargetClassId,
                        primaryColor: getPrimaryColor(),
                        languageProvider: languageProvider,
                        onYearChanged: (val) {
                          setState(() {
                            _selectedTargetYearId = val;
                            _selectedTargetClassId = null;
                          });
                          if (val != null) loadTargetClasses(val);
                        },
                        onClassChanged: (val) =>
                            setState(() => _selectedTargetClassId = val),
                        onCreateClassPressed: showCreateClassDialog,
                      ),
                    ),
                    buildStepContainer(
                      ClassPromotionStep4Summary(
                        classes: _classes,
                        targetClasses: _targetClasses,
                        academicYears: _academicYears,
                        students: _students,
                        selectedStudentIds: _selectedStudentIds,
                        selectedSourceClassId: _selectedSourceClassId,
                        selectedTargetClassId: _selectedTargetClassId,
                        selectedTargetYearId: _selectedTargetYearId,
                        primaryColor: getPrimaryColor(),
                        languageProvider: languageProvider,
                      ),
                    ),
                  ],
                ),
              ),
              buildBottomControls(languageProvider),
            ],
          ),
          buildLoadingOverlay(),
        ],
      ),
    );
  }
}
