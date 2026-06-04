import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_form_dialog.dart';

/// Mixin for form state management, filtering, and submission logic.
/// Handles cascading dropdowns (teacher -> subject, day -> lesson hour)
/// and fetching occupied slots.
mixin ScheduleFormMixin on ConsumerState<ScheduleFormDialog> {
  // Abstract getters/setters for form state (implemented by the main state class)
  String get selectedTeacher;
  set selectedTeacher(String value);

  String get selectedSubject;
  set selectedSubject(String value);

  String get selectedClass;
  set selectedClass(String value);

  List<String> get selectedDayIds;
  set selectedDayIds(List<String> value);

  String get selectedTerm;
  set selectedTerm(String value);

  String get selectedAcademicYear;
  set selectedAcademicYear(String value);

  String get selectedLessonHour;
  set selectedLessonHour(String value);

  List<dynamic> get filteredSubjectList;
  set filteredSubjectList(List<dynamic> value);

  List<dynamic> get availableLessonHourList;
  set availableLessonHourList(List<dynamic> value);

  List<dynamic> get occupiedSlots;
  set occupiedSlots(List<dynamic> value);

  bool get isLoadingSubjects;
  set isLoadingSubjects(bool value);

  bool get isLoadingLessonHour;
  set isLoadingLessonHour(bool value);

  // Abstract properties for widget data
  dynamic get schedule;
  List<dynamic> get subjectList;
  List<dynamic> get lessonHourList;
  List<dynamic> get classList;
  ApiTeacherService get apiTeacherService;

  Future<void> loadSettings() async {
    try {
      await getIt<ApiSettingsService>().getLessonHourSettings();
      if (mounted) {
        if (availableLessonHourList.isNotEmpty && selectedDayIds.isNotEmpty) {
          filterAvailableJamPelajaran();
        }
      }
    } catch (e) {
      AppLogger.error('schedule_form', 'Error loading settings: $e');
    }
  }

  Future<void> fetchOccupiedSlots() async {
    if (selectedClass.isEmpty ||
        selectedDayIds.isEmpty ||
        selectedTerm.isEmpty) {
      return;
    }

    try {
      final response = await getIt<ApiScheduleService>().getSchedulesPaginated(
        classId: selectedClass,
        dayId: selectedDayIds.first,
        semesterId: selectedTerm,
        academicYearId: selectedAcademicYear,
        limit: 100,
      );

      final occupied = response['data'] is List ? response['data'] : [];

      if (!mounted) return;
      setState(() {
        occupiedSlots = occupied;

        if (schedule != null && schedule['id'] != null) {
          // String-compare so the row being edited is reliably excluded
          // from its own occupied set — raw `==` on a mixed int/String id
          // would miss the match and wrongly flag the editee's slot as
          // "(Terisi)".
          final editingId = schedule['id'].toString();
          occupiedSlots.removeWhere((s) => s['id']?.toString() == editingId);
        }
      });

      AppLogger.debug(
        'schedule_form',
        'Occupied slots count: ${occupiedSlots.length}',
      );
    } catch (e) {
      AppLogger.error('schedule_form', 'Error fetching occupied slots: $e');
    }
  }

  Future<void> filterSubjectsByTeacher(String teacherId) async {
    try {
      setState(() => isLoadingSubjects = true);

      final teacherSubjects = await apiTeacherService.getSubjectByTeacher(
        teacherId,
      );

      if (!mounted) return;

      // Build the set of subject ids this teacher teaches, normalising to
      // String and tolerating the `subject_id` / `mata_pelajaran_id` key
      // aliases the API uses in some payload shapes. Raw `==` on mixed
      // int/String ids (the /teacher/{id}/subjects and /subject endpoints
      // can disagree on id type) silently matches nothing, so the picked
      // teacher's "Mata Pelajaran" dropdown comes out wrong. String-compare
      // against the same id set keeps the dropdown limited to exactly the
      // teacher's own subjects, mirroring the mobile behaviour.
      final teacherSubjectIds = teacherSubjects
          .map(
            (ts) =>
                (ts['id'] ?? ts['subject_id'] ?? ts['mata_pelajaran_id'])
                    ?.toString(),
          )
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      final filtered = subjectList.where((subject) {
        final sId =
            (subject['id'] ??
                    subject['subject_id'] ??
                    subject['mata_pelajaran_id'])
                ?.toString();
        return sId != null && teacherSubjectIds.contains(sId);
      }).toList();

      setState(() {
        filteredSubjectList = filtered;
        isLoadingSubjects = false;

        if (selectedSubject.isNotEmpty) {
          final currentSubjectExists = filtered.any(
            (subject) => subject['id'] == selectedSubject,
          );
          if (!currentSubjectExists) {
            selectedSubject = '';
          }
        }
        AppLogger.debug(
          'schedule_form',
          'Available lesson hours: ${availableLessonHourList.length}',
        );
      });
    } catch (e) {
      AppLogger.error('schedule_form', 'Error filtering subjects: $e');
      if (!mounted) return;
      setState(() {
        filteredSubjectList = subjectList;
        isLoadingSubjects = false;
      });
      _showErrorSnackBar('Failed to load teacher subjects');
    }
  }

  void filterAvailableJamPelajaran() {
    setState(() => isLoadingLessonHour = true);

    try {
      if (selectedDayIds.isEmpty) {
        setState(() {
          availableLessonHourList = lessonHourList;
          isLoadingLessonHour = false;
        });
        return;
      }

      final selectedDayId = selectedDayIds.first;

      final filtered = lessonHourList.where((jam) {
        final jamDayId =
            jam['day_id']?.toString() ?? jam['hari_id']?.toString();
        return jamDayId == selectedDayId;
      }).toList();

      filtered.sort((a, b) {
        final hA = int.tryParse(a['hour_number'].toString()) ?? 0;
        final hB = int.tryParse(b['hour_number'].toString()) ?? 0;
        return hA.compareTo(hB);
      });

      setState(() {
        availableLessonHourList = filtered;
        isLoadingLessonHour = false;

        if (selectedLessonHour.isNotEmpty) {
          final exists = filtered.any(
            (jam) => jam['id'].toString() == selectedLessonHour,
          );
          if (!exists) {
            selectedLessonHour = '';
          }
        }
      });
      fetchOccupiedSlots();
    } catch (e) {
      AppLogger.error('schedule_form', 'Error filtering lesson hours: $e');
      setState(() {
        availableLessonHourList = lessonHourList;
        isLoadingLessonHour = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': message,
          'id': message.replaceAll(
            'Failed to load teacher subjects',
            AppLocalizations.failedToLoadTeacherSubjects.tr,
          ),
        }),
      );
    }
  }
}
