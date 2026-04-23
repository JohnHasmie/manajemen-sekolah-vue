import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/classrooms/presentation/screens/class_promotion_wizard.dart';
import 'package:manajemensekolah/features/settings/data/academic_service.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin for data loading operations in ClassPromotionWizard.
/// Handles loading classes, students, academic years, teachers, and school settings.
mixin ClassPromotionDataMixin on ConsumerState<ClassPromotionWizard> {
  // Data getters/setters
  List<dynamic> get classes;
  set classes(List<dynamic> v);

  List<dynamic> get academicYears;
  set academicYears(List<dynamic> v);

  List<dynamic> get students;
  set students(List<dynamic> v);

  List<dynamic> get targetClasses;
  set targetClasses(List<dynamic> v);

  List<dynamic> get teachers;
  set teachers(List<dynamic> v);

  List<String> get availableGradeLevels;

  String? get schoolJenjang;
  set schoolJenjang(String? v);

  bool get isLoading;
  set isLoading(bool v);

  String? get selectedSourceClassId;
  String? get selectedTargetYearId;

  void generateGradeLevels();

  /// Loads classes and academic years for the wizard dropdowns.
  /// Like calling `GET /api/classes` and `GET /api/academic-years` in Vue's `mounted()`.
  Future<void> loadInitialData() async {
    isLoading = true;
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
        classes = classesData;
        academicYears = yearsData;
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
      isLoading = false;
    }
  }

  /// Loads students for a given source class.
  Future<void> loadStudents(String classId) async {
    isLoading = true;
    try {
      final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final studentsData = await getIt<ApiClassService>().getStudentsByClassId(
        classId,
        academicYearId: ayId,
      );
      setState(() {
        students = studentsData;
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
      isLoading = false;
    }
  }

  /// Loads target classes for a given academic year.
  Future<void> loadTargetClasses(String yearId) async {
    isLoading = true;
    try {
      final response = await getIt<ApiClassService>().getClassPaginated(
        limit: 1000,
        academicYearId: yearId,
      );

      setState(() {
        if (response['data'] != null && response['data'] is List) {
          targetClasses = response['data'];
        } else {
          targetClasses = [];
        }
      });
    } catch (e) {
      AppLogger.error('classroom', e);
      setState(() => targetClasses = []);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    } finally {
      isLoading = false;
    }
  }

  /// Fetches teachers from the API.
  Future<void> fetchTeachers() async {
    try {
      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        limit: 1000,
      );
      if (!mounted) return;
      setState(() {
        teachers = response['data'] ?? [];
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

  /// Loads school settings to determine available grade levels.
  Future<void> loadSchoolSettings() async {
    try {
      final settings = await getIt<ApiSettingsService>().getSchoolSettings();
      if (!mounted) return;
      setState(() {
        schoolJenjang = settings['jenjang'];
        generateGradeLevels();
      });
    } catch (e) {
      AppLogger.error('classroom', e);
      setState(generateGradeLevels);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }
}
