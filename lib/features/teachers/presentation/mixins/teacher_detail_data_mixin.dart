import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/teacher_detail_screen.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Mixin for data loading operations in TeacherDetailScreen.
mixin TeacherDetailDataMixin on ConsumerState<TeacherDetailScreen> {
  final ApiTeacherService apiTeacherService = getIt<ApiTeacherService>();
  final ApiSubjectService apiSubjectService = getIt<ApiSubjectService>();

  Map<String, dynamic>? get teacherDetail;
  set teacherDetail(Map<String, dynamic>? value);

  List<dynamic> get subjects;
  set subjects(List<dynamic> value);

  bool get isLoading;
  set isLoading(bool value);

  String? get errorMessage;
  set errorMessage(String? value);

  Map<String, dynamic> get widgetTeacher;

  /// Loads full teacher details by ID, including subjects and classes.
  Future<void> loadTeacherDetail() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      String? academicYearId;
      if (mounted) {
        try {
          final academicYearProvider = ref.read(academicYearRiverpod);
          academicYearId = academicYearProvider.selectedAcademicYear?['id']
              ?.toString();
        } catch (e) {
          // provider might not be available or other error
        }
      }

      // Backend returns everything including subjects and classes
      final teacherDetail = await apiTeacherService.getTeacherById(
        widgetTeacher['id'],
        academicYearId: academicYearId,
      );

      // Fetch all subjects for mapping
      final subjectsData = await apiSubjectService.getSubject();

      setState(() {
        this.teacherDetail = teacherDetail;
        subjects = subjectsData;
        isLoading = false;
      });
    } catch (e) {
      AppLogger.error('teacher', e);
      setState(() {
        isLoading = false;
        errorMessage = ErrorUtils.getFriendlyMessage(e);
      });
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal memuat detail guru: '
        '${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }
}
