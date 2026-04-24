// Controller for AdminScheduleManagementScreen — holds all
// data/logic that does NOT touch Flutter widgets.
//
// In Laravel terms, this is like a controller class that
// handles business logic while the screen (View) handles
// rendering. The screen owns state variables and calls
// setState after each method returns.
//
// Pattern: plain Dart class with a Riverpod Provider,
// matching how TeacherGradeController is wired but without
// AsyncNotifier since the screen manages its own loading
// state via setState.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/academic_period_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/cache_management_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/crud_operations_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/data_loading_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/excel_import_export_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/filter_options_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/formatting_filtering_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/grid_timetable_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/schedule_filtering_mixin.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

/// Riverpod provider — use `ref.read(
/// adminScheduleControllerProvider)` in the screen to get
/// the controller instance. Like a Laravel service
/// container binding: one instance per screen lifecycle.
final adminScheduleControllerProvider = Provider<AdminScheduleController>((
  ref,
) {
  return AdminScheduleController(ref);
});

/// Day-name translation table used by [AdminScheduleController.buildActiveFilterChips].
///
/// Keys are the lowercased Indonesian / English day names as they appear
/// in the API payload, values map to localized labels for both supported
/// languages. Kept private to this file — the only consumer is the chip
/// builder below.
const Map<String, Map<String, String>> _kDayTranslations = {
  'senin': {'en': 'Monday', 'id': 'Senin'},
  'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
  'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
  'kamis': {'en': 'Thursday', 'id': 'Kamis'},
  'jumat': {'en': 'Friday', 'id': 'Jumat'},
  "jum'at": {'en': 'Friday', 'id': 'Jumat'},
  'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
  'minggu': {'en': 'Sunday', 'id': 'Minggu'},
  'monday': {'en': 'Monday', 'id': 'Senin'},
  'tuesday': {'en': 'Tuesday', 'id': 'Selasa'},
  'wednesday': {'en': 'Wednesday', 'id': 'Rabu'},
  'thursday': {'en': 'Thursday', 'id': 'Kamis'},
  'friday': {'en': 'Friday', 'id': 'Jumat'},
  'saturday': {'en': 'Saturday', 'id': 'Sabtu'},
  'sunday': {'en': 'Sunday', 'id': 'Minggu'},
};

/// Controller that owns every data/logic method.
///
/// Think of this like a Laravel Controller class: it calls
/// Services and returns plain data. The screen (View) calls
/// setState with that data to re-render. No BuildContext
/// is stored — it is passed as a parameter only when a
/// method needs to show dialogs/snackbars.
///
/// This class uses mixins for logical grouping:
/// - CacheManagementMixin: cache key generation
/// - DataLoadingMixin: API data loading
/// - FilterOptionsMixin: filter options loading
/// - AcademicPeriodMixin: academic year/semester logic
/// - GridTimetableMixin: grid data generation
/// - CrudOperationsMixin: delete/update operations
/// - ExcelImportExportMixin: Excel import/export
/// - FormattingFilteringMixin: formatting utilities
/// - ScheduleFilteringMixin: filtering utilities
class AdminScheduleController
    with
        CacheManagementMixin,
        DataLoadingMixin,
        FilterOptionsMixin,
        AcademicPeriodMixin,
        GridTimetableMixin,
        CrudOperationsMixin,
        ExcelImportExportMixin,
        FormattingFilteringMixin,
        ScheduleFilteringMixin {
  /// Riverpod [Ref] — used to read other providers,
  /// e.g. language, academic year. Like Laravel's
  /// `app()->make()` but scoped to the current widget
  /// tree.
  @override
  final Ref ref;

  // Service dependencies injected via GetIt (like
  // Laravel service container).
  final ApiSubjectService _apiSubjectService = getIt<ApiSubjectService>();
  @override
  final ApiTeacherService apiTeacherService = getIt<ApiTeacherService>();
  final ApiService _apiService = ApiService();

  AdminScheduleController(this.ref);

  /// Returns the [ApiService] instance
  /// (needed by form dialogs in the screen).
  ApiService get apiService => _apiService;

  /// Returns the primary colour for the admin role.
  @override
  Color getPrimaryColor() => ColorUtils.getRoleColor('admin');

  /// Builds the list of [ActiveFilter] chips for the four filterable
  /// dimensions exposed by the admin schedule screen: day, class,
  /// semester (only when the user has overridden the current term),
  /// and lesson hour.
  ///
  /// Each chip carries its own targeted [onRemove] callback so the
  /// × on one chip only clears that filter — matching the Mapel /
  /// Kelas pattern from Phase 1.
  List<ActiveFilter> buildActiveFilterChips({
    required String? selectedDayId,
    required String? selectedClassId,
    required String? selectedFilterTerm,
    required String? selectedLessonHour,
    required String selectedTerm,
    required List<dynamic> availableDays,
    required List<dynamic> availableClasses,
    required List<dynamic> termList,
    required LanguageProvider languageProvider,
    required VoidCallback onClearDay,
    required VoidCallback onClearClass,
    required VoidCallback onClearSemester,
    required VoidCallback onClearLessonHour,
  }) {
    final chips = <ActiveFilter>[];

    if (selectedDayId != null) {
      final day = availableDays.firstWhere(
        (d) => d['id'].toString() == selectedDayId,
        orElse: () => <String, dynamic>{},
      );
      final raw = (day as Map).isNotEmpty
          ? (day['name'] ?? day['nama'] ?? '')
          : 'Day';
      final key = raw.toString().toLowerCase();
      final label = _kDayTranslations[key] != null
          ? languageProvider.getTranslatedText(_kDayTranslations[key]!)
          : raw.toString();
      chips.add(
        ActiveFilter(
          label:
              '${languageProvider.getTranslatedText(const {'en': 'Day', 'id': 'Hari'})}: $label',
          icon: Icons.today_outlined,
          onRemove: onClearDay,
        ),
      );
    }

    if (selectedClassId != null) {
      final cls = availableClasses.firstWhere(
        (c) => c['id'].toString() == selectedClassId,
        orElse: () => <String, dynamic>{},
      );
      final label = (cls as Map).isNotEmpty
          ? (cls['name'] ?? cls['nama'] ?? 'Class').toString()
          : 'Class';
      chips.add(
        ActiveFilter(
          label:
              '${languageProvider.getTranslatedText(const {'en': 'Class', 'id': 'Kelas'})}: $label',
          icon: Icons.school_outlined,
          onRemove: onClearClass,
        ),
      );
    }

    if (selectedFilterTerm != null && selectedFilterTerm != selectedTerm) {
      final semester = termList.firstWhere(
        (s) => s['id'].toString() == selectedFilterTerm,
        orElse: () => <String, dynamic>{},
      );
      var label = (semester as Map).isNotEmpty
          ? (semester['name'] ??
                    semester['nama'] ??
                    'Semester $selectedFilterTerm')
                .toString()
          : 'Semester $selectedFilterTerm';
      if (semester.isNotEmpty &&
          semester['academic_year'] != null &&
          semester['academic_year']['year'] != null) {
        label = '$label (${semester['academic_year']['year']})';
      }
      chips.add(
        ActiveFilter(
          label:
              '${languageProvider.getTranslatedText(const {'en': 'Semester', 'id': 'Semester'})}: $label',
          icon: Icons.event_outlined,
          onRemove: onClearSemester,
        ),
      );
    }

    if (selectedLessonHour != null) {
      chips.add(
        ActiveFilter(
          label: languageProvider.getTranslatedText({
            'en': 'Hour $selectedLessonHour',
            'id': 'Jam ke-$selectedLessonHour',
          }),
          icon: Icons.access_time_outlined,
          onRemove: onClearLessonHour,
        ),
      );
    }

    return chips;
  }
}
