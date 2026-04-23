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
}
