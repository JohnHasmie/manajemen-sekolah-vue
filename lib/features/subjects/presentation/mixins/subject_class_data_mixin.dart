// Data loading and management for subject class assignments
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/subjects/presentation/screens/subject_class_management_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

mixin SubjectClassDataMixin on ConsumerState<SubjectClassManagementPage> {
  final ApiService apiService = ApiService();
  late List<dynamic> availableClasses;
  late List<dynamic> assignedClasses0;
  late bool isLoading;

  @override
  void initState() {
    super.initState();
    availableClasses = [];
    assignedClasses0 = [];
    isLoading = true;
    loadData();
  }

  /// Loads all available classes and classes assigned to subject.
  /// Filters both queries by the currently-selected academic year on
  /// the dashboard so admin sees only data for the year they're
  /// browsing.
  Future<void> loadData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final ayId = getCurrentAcademicYearId();
      final ayQuery = ayId == null ? '' : '?academic_year_id=$ayId';
      final assignedQueryPrefix = ayId == null ? '?' : '$ayQuery&';

      // Load all available classes scoped to the current AY
      final allClassesResponse = await apiService.get('/class$ayQuery');

      // Load classes already assigned to this subject for this AY
      final assignedClassesRaw = await apiService.get(
        '${ApiEndpoints.classBySubject}'
        '${assignedQueryPrefix}subject_id=${getSubjectId().toString()}',
      );

      // Handle Map format (pagination) or direct List
      final assignedClasses = _parseResponse(assignedClassesRaw);

      // Handle both Map (pagination) and List formats
      final allClasses = _parseResponse(allClassesResponse);

      setState(() {
        availableClasses = allClasses;
        assignedClasses0 = assignedClasses;
        isLoading = false;
      });

      if (allClasses.isNotEmpty) {
        AppLogger.debug('subject', 'First class data: ${allClasses[0]}');
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: $error');
      }
    }
  }

  /// Adds a class to the subject
  Future<void> addClassToSubject(Map<String, dynamic> classItem) async {
    try {
      await getIt<ApiSubjectService>().attachClass(
        getSubjectId().toString(),
        classItem['id'].toString(),
      );

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'Kelas ${Classroom.fromJson(classItem).name} berhasil ditambahkan',
        );
      }

      loadData();
    } catch (error) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: $error');
      }
    }
  }

  /// Removes a class from the subject with confirmation
  Future<void> removeClassFromSubject(Map<String, dynamic> classItem) async {
    final confirmed = await showRemoveConfirmation(classItem);

    if (confirmed == true) {
      try {
        await getIt<ApiSubjectService>().detachClass(
          getSubjectId().toString(),
          classItem['id'].toString(),
        );

        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            'Kelas ${Classroom.fromJson(classItem).name} berhasil dihapus',
          );
        }

        loadData();
      } catch (error) {
        if (mounted) {
          SnackBarUtils.showError(context, 'Error: $error');
        }
      }
    }
  }

  /// Parses API response to `List<dynamic>`
  List<dynamic> _parseResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response['data'] ?? [];
    } else if (response is List) {
      return response;
    }
    return [];
  }

  /// Shows confirmation dialog before removing class
  Future<bool?> showRemoveConfirmation(Map<String, dynamic> classItem);

  /// Gets subject ID from widget
  dynamic getSubjectId();

  /// Returns the dashboard-selected academic year id, or null if no
  /// year has been picked yet. Provided by the
  /// `AdminAcademicYearReloadMixin` on the host State.
  String? getCurrentAcademicYearId();
}
