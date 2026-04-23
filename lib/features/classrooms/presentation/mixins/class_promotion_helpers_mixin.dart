import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/classrooms/presentation/screens/class_promotion_wizard.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_student_selection_sheet.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_create_class_dialog.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';

/// Mixin for helper methods and navigation in ClassPromotionWizard.
mixin ClassPromotionHelpersMixin on ConsumerState<ClassPromotionWizard> {
  // State field getters
  int get currentStep;
  set currentStep(int v);

  List<dynamic> get classes;
  List<dynamic> get academicYears;
  List<dynamic> get students;
  List<dynamic> get targetClasses;
  List<dynamic> get teachers;
  List<String> get availableGradeLevels;

  String? get selectedSourceClassId;
  String? get selectedTargetYearId;
  String? get selectedTargetClassId;

  Set<String> get selectedStudentIds;

  bool get isLoading;
  set isLoading(bool v);

  PageController get pageController;
  Future<void> loadTargetClasses(String yearId);
  Future<void> loadStudents(String classId);

  Color getPrimaryColor() => ColorUtils.getRoleColor('admin');

  LinearGradient getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [getPrimaryColor(), getPrimaryColor().withValues(alpha: 0.85)],
    );
  }

  /// Check if a student is already promoted to the target year.
  bool isAlreadyPromoted(dynamic student) {
    if (selectedTargetYearId == null) return false;

    final List classes = student['classes'] ?? [];
    for (final cls in classes) {
      if (cls['pivot'] != null) {
        final yearId = cls['pivot']['academic_year_id']?.toString();
        if (yearId == selectedTargetYearId) {
          return true;
        }
      }
      if (cls['academic_year_id']?.toString() == selectedTargetYearId) {
        return true;
      }
    }
    return false;
  }

  /// Predict the target academic year based on source class.
  void predictTargetYear() {
    if (selectedSourceClassId == null || academicYears.isEmpty) return;

    final sourceClass = classes.firstWhere(
      (c) => c['id'].toString() == selectedSourceClassId,
      orElse: () => null,
    );

    if (sourceClass != null) {
      String? sourceYearId = sourceClass['academic_year_id']?.toString();
      if (sourceYearId == null && sourceClass['academic_year'] != null) {
        sourceYearId = sourceClass['academic_year']['id']?.toString();
      }

      if (sourceYearId != null) {
        final currentIndex = academicYears.indexWhere(
          (y) => y['id'].toString() == sourceYearId,
        );

        if (currentIndex != -1 && currentIndex < academicYears.length - 1) {
          final currentYearData = academicYears[currentIndex];
          final String currentYearName =
              currentYearData['year']?.toString() ?? '';
          final startYearStr = currentYearName.split('/').first;
          final startYear = int.tryParse(startYearStr);

          String? nextYearId;

          if (startYear != null) {
            final nextStartYearPattern = (startYear + 1).toString();
            final nextYearObj = academicYears.firstWhere(
              (y) => (y['year']?.toString() ?? '').startsWith(
                nextStartYearPattern,
              ),
              orElse: () => null,
            );
            if (nextYearObj != null) {
              nextYearId = nextYearObj['id'].toString();
            }
          }

          nextYearId ??= academicYears[currentIndex + 1]['id'].toString();

          setState(() {
            // Will be set via state, not here
          });
          loadTargetClasses(nextYearId);
        }
      }
    }
  }

  /// Navigate to a specific step.
  void goToStep(int step) {
    setState(() => currentStep = step);
    pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Show student selection bottom sheet.
  void showStudentSelectionDialog(LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PromotionStudentSelectionSheet(
        students: students,
        selectedStudentIds: selectedStudentIds,
        isAlreadyPromoted: isAlreadyPromoted,
        primaryColor: getPrimaryColor(),
        cardGradient: getCardGradient(),
        languageProvider: languageProvider,
        onSelectionChanged: () => setState(() {}),
      ),
    );
  }

  /// Show create class dialog.
  void showCreateClassDialog() {
    final languageProvider = ref.read(languageRiverpod);
    showDialog(
      context: context,
      builder: (context) => PromotionCreateClassDialog(
        availableGradeLevels: availableGradeLevels,
        teachers: teachers,
        selectedTargetYearId: selectedTargetYearId,
        primaryColor: getPrimaryColor(),
        cardGradient: getCardGradient(),
        languageProvider: languageProvider,
        onClassCreated: () {
          if (selectedTargetYearId != null) {
            loadTargetClasses(selectedTargetYearId!);
          }
        },
      ),
    );
  }

  /// Handle step continue/next action.
  void onStepContinue() async {
    final languageProvider = ref.read(languageRiverpod);
    if (currentStep == 0) {
      if (selectedSourceClassId == null) return;
      if (students.isEmpty) await loadStudents(selectedSourceClassId!);
      goToStep(1);
    } else if (currentStep == 1) {
      if (selectedStudentIds.isEmpty) return;

      if (selectedSourceClassId != null && academicYears.isNotEmpty) {
        final sourceClass = classes.firstWhere(
          (c) => c['id'].toString() == selectedSourceClassId,
          orElse: () => null,
        );
        if (sourceClass != null) {
          String? sourceYearId = sourceClass['academic_year_id']?.toString();
          if (sourceYearId == null && sourceClass['academic_year'] != null) {
            sourceYearId = sourceClass['academic_year']['id']?.toString();
          }
          if (sourceYearId != null) {
            final currentIndex = academicYears.indexWhere(
              (y) => y['id'].toString() == sourceYearId,
            );
            if (currentIndex != -1 && currentIndex < academicYears.length - 1) {
              final currentYearData = academicYears[currentIndex];
              final String currentYearName =
                  currentYearData['year']?.toString() ?? '';
              final startYearStr = currentYearName.split('/').first;
              final startYear = int.tryParse(startYearStr);

              if (startYear != null) {
                final nextYearNameStart = (startYear + 1).toString();
                final nextYear = academicYears.firstWhere(
                  (y) => (y['year']?.toString() ?? '').startsWith(
                    nextYearNameStart,
                  ),
                  orElse: () => null,
                );
                if (nextYear != null) {
                  setState(() {
                    // Will be set via state
                  });
                  await loadTargetClasses(nextYear['id'].toString());
                }
              }
            }
          }
        }
      }

      goToStep(2);
    } else if (currentStep == 2) {
      if (selectedTargetYearId == null) return;
      if (selectedTargetClassId == null) {
        SnackBarUtils.showWarning(
          context,
          languageProvider.getTranslatedText({
            'en': 'Please select or create a target class',
            'id': 'Silakan pilih atau buat kelas tujuan',
          }),
        );
        return;
      }
      goToStep(3);
    } else if (currentStep == 3) {
      submitPromotion();
    }
  }

  /// Submit the promotion request to the API.
  Future<void> submitPromotion() async {
    final languageProvider = ref.read(languageRiverpod);
    isLoading = true;
    try {
      final data = {
        'source_class_id': selectedSourceClassId,
        'target_class_id': selectedTargetClassId,
        'student_ids': selectedStudentIds.toList(),
        'academic_year_id': selectedTargetYearId,
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
      if (mounted) isLoading = false;
    }
  }
}
