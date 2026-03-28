import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';

void main() {
  group('Attendance.fromJson', () {
    test('parses normal response with English fields', () {
      final json = {
        'id': 'a1',
        'student_id': 's1',
        'date': '2026-03-25T08:00:00',
        'status': 'present',
        'is_read': true,
        'subject_name': 'Matematika',
        'subject_id': 'sub1',
        'lesson_hour_id': 'hour1',
        'class_id': 'c1',
      };

      final attendance = Attendance.fromJson(json);

      expect(attendance.id, 'a1');
      expect(attendance.studentId, 's1');
      expect(attendance.date, DateTime(2026, 3, 25, 8));
      expect(attendance.status, 'present');
      expect(attendance.isRead, true);
      expect(attendance.subjectName, 'Matematika');
      expect(attendance.subjectId, 'sub1');
      expect(attendance.lessonHourId, 'hour1');
      expect(attendance.classId, 'c1');
    });

    test('handles Indonesian aliases (id_siswa, tanggal, mata_pelajaran_id)', () {
      final json = {
        'id': 'a2',
        'id_siswa': 's2',
        'tanggal': '2026-03-26',
        'status': 'sick',
        'isRead': false,
        'mata_pelajaran_nama': 'Bahasa Indonesia',
        'id_mata_pelajaran': 'sub2',
        'id_jam_pelajaran': 'hour2',
        'kelas_id': 'c2',
      };

      final attendance = Attendance.fromJson(json);

      expect(attendance.studentId, 's2');
      expect(attendance.date, DateTime(2026, 3, 26));
      expect(attendance.status, 'sick');
      expect(attendance.isRead, false);
      expect(attendance.subjectName, 'Bahasa Indonesia');
      expect(attendance.subjectId, 'sub2');
      expect(attendance.lessonHourId, 'hour2');
      expect(attendance.classId, 'c2');
    });
  });

  group('Attendance.toJson', () {
    test('produces correct snake_case keys (English)', () {
      final date = DateTime(2026, 3, 25);
      final attendance = Attendance(
        id: 'a1',
        studentId: 's1',
        date: date,
        status: 'present',
        isRead: true,
        subjectName: 'Matematika',
        subjectId: 'sub1',
        lessonHourId: 'hour1',
        classId: 'c1',
      );

      final json = attendance.toJson();

      expect(json['id'], 'a1');
      expect(json['student_id'], 's1');
      expect(json['date'], date.toIso8601String());
      expect(json['status'], 'present');
      expect(json['is_read'], true);
      expect(json['subject_name'], 'Matematika');
      expect(json['subject_id'], 'sub1');
      expect(json['lesson_hour_id'], 'hour1');
      expect(json['class_id'], 'c1');
    });
  });

  group('Attendance round-trip', () {
    test('toJson then fromJson preserves all fields', () {
      final original = Attendance(
        id: 'a-rt',
        studentId: 's-rt',
        date: DateTime(2026, 3, 28),
        status: 'excused',
        lessonHourId: 'hour-rt',
        classId: 'c-rt',
      );

      final json = original.toJson();
      final restored = Attendance.fromJson(json);

      expect(restored, original);
    });
  });
}
