import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_data_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_add_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_filter_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_shared_mixin.dart';

/// Facade mixin that combines all attendance dialog functionality.
/// This maintains backward compatibility while delegating to specialized
/// mixins.
///
/// The dialog handling is split into three focused mixins:
/// - AttendanceDialogAddMixin: Add attendance flow
/// - AttendanceDialogFilterMixin: Filter dialog flow
/// - AttendanceDialogSharedMixin: Shared UI components
mixin AttendanceDialogMixin
    on
        ConsumerState<AttendancePage>,
        AttendanceDataMixin,
        AttendanceDialogAddMixin,
        AttendanceDialogFilterMixin,
        AttendanceDialogSharedMixin {
  // This mixin is now a facade that combines the functionality
  // of the three specialized mixins below. All methods have been
  // moved to the appropriate specialized mixin.
}
