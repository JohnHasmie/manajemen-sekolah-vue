// Data model for one attendance summary row displayed in the Results tab.
// Like a Laravel Eloquent model or a TypeScript interface -- a plain data
// class with no Flutter dependency. Moved out of teacher_attendance_screen.dart
// so it can be shared between the screen and extracted card widgets.
import 'package:intl/intl.dart';

/// Holds computed attendance counts for a subject on a specific date.
///
/// [key] is a unique string used as a Map key / cache key -- like a composite
/// primary key in a database (subject + date + class + lesson hour).
class AttendanceSummaryItem {
  final String subjectId;
  final String subjectName;
  final DateTime date;
  final int totalStudent;
  final int present;
  final int absent;
  final String? classId;
  final String? className;
  final String? lessonHourId;
  final String? lessonHourName;

  AttendanceSummaryItem({
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.totalStudent,
    required this.present,
    required this.absent,
    this.classId,
    this.className,
    this.lessonHourId,
    this.lessonHourName,
  });

  String get key =>
      '$subjectId-${DateFormat('yyyy-MM-dd').format(date)}-$classId-$lessonHourId';
}
