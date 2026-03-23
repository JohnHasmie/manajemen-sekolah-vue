/// data_dummy.dart - Static seed/mock data for development and testing.
/// Like Laravel's `DatabaseSeeder` or factory definitions (`database/seeders/`, `database/factories/`).
/// In Vue terms, this is like a mock data file you'd use with `json-server` or in Vuex for prototyping.
library;

import 'package:manajemensekolah/core/models/activity.dart';
import 'package:manajemensekolah/core/models/announcement.dart';
import 'package:manajemensekolah/core/models/attendance.dart';
import 'package:manajemensekolah/core/models/classroom.dart';
import 'package:manajemensekolah/core/models/grade.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/models/teacher.dart';
import 'package:manajemensekolah/core/models/user.dart';

/// Provides hardcoded sample data for all major models.
/// Like Laravel's `DatabaseSeeder` - populates the app with realistic test data
/// for development, UI prototyping, and offline testing.
///
/// Each static list contains pre-built model instances:
/// - [users]: Sample accounts for each role (admin, teacher, staff, parent).
/// - [students]: Sample students with class assignments and guardian info.
/// - [grades]: Sample grades linking students to subjects and scores.
/// - [attendances]: Sample attendance records from recent days.
/// - [activities]: Sample upcoming school activities/events.
/// - [announcements]: Sample announcements in different categories.
/// - [inventory]: Sample school inventory items (as raw maps).
/// - [classrooms]: Sample classrooms with homeroom teachers.
/// - [teachers]: Sample teacher list.
class DataDummy {
  static List<User> users = [
    User(id: '1', name: 'Admin Sekolah', email: 'admin@sekolah.com', password: 'admin123', role: 'admin'),
    User(id: '2', name: 'Budi Santoso', email: 'budi@sekolah.com', password: 'guru123', role: 'guru', classroom: '7A'),
    User(id: '3', name: 'Sari Dewi', email: 'sari@sekolah.com', password: 'guru123', role: 'guru', classroom: '8B'),
    User(id: '4', name: 'Staff TU', email: 'staff@sekolah.com', password: 'staff123', role: 'staff'),
    User(id: '5', name: 'Wali Ahmad', email: 'wali1@email.com', password: 'wali123', role: 'wali'),
    User(id: '6', name: 'Wali Siti', email: 'wali2@email.com', password: 'wali123', role: 'wali'),
  ];

  static List<Student> students = [
    Student(id: '1', name: 'Ahmad Rizki', className: '7A', studentNumber: '001', address: 'Jl. Merdeka 1', guardianName: 'Wali Ahmad', phoneNumber: '081234567890'),
    Student(id: '2', name: 'Siti Nurhaliza', className: '7A', studentNumber: '002', address: 'Jl. Sudirman 2', guardianName: 'Wali Siti', phoneNumber: '081234567891'),
    Student(id: '3', name: 'Budi Permana', className: '7B', studentNumber: '003', address: 'Jl. Gatot Subroto 3', guardianName: 'Wali Budi', phoneNumber: '081234567892'),
    Student(id: '4', name: 'Dewi Sartika', className: '8A', studentNumber: '004', address: 'Jl. Diponegoro 4', guardianName: 'Wali Dewi', phoneNumber: '081234567893'),
    Student(id: '5', name: 'Andi Wijaya', className: '8B', studentNumber: '005', address: 'Jl. Ahmad Yani 5', guardianName: 'Wali Andi', phoneNumber: '081234567894'),
  ];

  static List<Grade> grades = [
    Grade(studentId: '1', subject: 'Matematika', score: 85.0, semester: 'Ganjil'),
    Grade(studentId: '1', subject: 'Bahasa Indonesia', score: 88.0, semester: 'Ganjil'),
    Grade(studentId: '1', subject: 'IPA', score: 82.0, semester: 'Ganjil'),
    Grade(studentId: '2', subject: 'Matematika', score: 78.0, semester: 'Ganjil'),
    Grade(studentId: '2', subject: 'Bahasa Indonesia', score: 85.0, semester: 'Ganjil'),
    Grade(studentId: '2', subject: 'IPA', score: 80.0, semester: 'Ganjil'),
  ];

  static List<Attendance> attendances = [
    Attendance(studentId: '1', date: DateTime.now().subtract(Duration(days: 1)), status: 'hadir'),
    Attendance(studentId: '1', date: DateTime.now().subtract(Duration(days: 2)), status: 'hadir'),
    Attendance(studentId: '1', date: DateTime.now().subtract(Duration(days: 3)), status: 'sakit'),
    Attendance(studentId: '2', date: DateTime.now().subtract(Duration(days: 1)), status: 'hadir'),
    Attendance(studentId: '2', date: DateTime.now().subtract(Duration(days: 2)), status: 'izin'),
  ];

  static List<Activity> activities = [
    Activity(
      id: '1',
      name: 'Upacara Bendera',
      description: 'Upacara bendera rutin setiap hari Senin',
      date: DateTime.now().add(Duration(days: 1)),
      location: 'Lapangan Sekolah',
    ),
    Activity(
      id: '2',
      name: 'Ujian Tengah Semester',
      description: 'Pelaksanaan ujian tengah semester untuk semua kelas',
      date: DateTime.now().add(Duration(days: 7)),
      location: 'Ruang Kelas',
    ),
    Activity(
      id: '3',
      name: 'Lomba Sains',
      description: 'Lomba sains antar kelas tingkat SMP',
      date: DateTime.now().add(Duration(days: 14)),
      location: 'Lab IPA',
    ),
  ];

  static List<Announcement> announcements = [
    Announcement(
      id: '1',
      title: 'Libur Semester',
      content: 'Libur semester akan dimulai tanggal 15 Desember 2024',
      date: DateTime.now(),
      category: 'Akademik',
    ),
    Announcement(
      id: '2',
      title: 'Pembayaran SPP',
      content: 'Batas waktu pembayaran SPP bulan ini adalah tanggal 10',
      date: DateTime.now().subtract(Duration(days: 1)),
      category: 'Keuangan',
    ),
  ];

  static List<Map<String, dynamic>> inventory = [
    {'nama': 'Meja Siswa', 'jumlah': 150, 'kondisi': 'Baik'},
    {'nama': 'Kursi Siswa', 'jumlah': 150, 'kondisi': 'Baik'},
    {'nama': 'Papan Tulis', 'jumlah': 12, 'kondisi': 'Baik'},
    {'nama': 'Proyektor', 'jumlah': 5, 'kondisi': 'Rusak Ringan'},
    {'nama': 'Komputer', 'jumlah': 20, 'kondisi': 'Baik'},
    {'nama': 'Printer', 'jumlah': 3, 'kondisi': 'Baik'},
  ];

  static List<Classroom> classrooms = [
    Classroom(id: '1', name: '7A', homeroomTeacher: 'Budi Santoso', studentCount: 25),
    Classroom(id: '2', name: '7B', homeroomTeacher: 'Sari Dewi', studentCount: 23),
    Classroom(id: '3', name: '8A', homeroomTeacher: 'Ahmad Fauzi', studentCount: 28),
    Classroom(id: '4', name: '8B', homeroomTeacher: 'Dewi Sartika', studentCount: 26),
    Classroom(id: '5', name: '9A', homeroomTeacher: 'Rudi Hartono', studentCount: 30),
    Classroom(id: '6', name: '9B', homeroomTeacher: 'Siti Rahayu', studentCount: 27),
  ];

  static List<Teacher> teachers = [
    Teacher(id: '1', name: 'Budi Santoso'),
    Teacher(id: '2', name: 'Sari Dewi'),
    Teacher(id: '3', name: 'Ahmad Fauzi'),
    Teacher(id: '4', name: 'Dewi Sartika'),
    Teacher(id: '5', name: 'Rudi Hartono'),
    Teacher(id: '6', name: 'Siti Rahayu'),
  ];
}
