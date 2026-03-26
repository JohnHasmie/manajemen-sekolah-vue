// Attendance detail screen for a specific subject on a specific date.
// Like `pages/teacher/AttendanceDetail.vue` in a Vue app.
//
// This is a StatefulWidget (equivalent to a Vue component with local reactive
// state via `data() { return {...} }`).  It loads a list of students and their
// attendance status, allows the teacher to change each status via a dropdown,
// and submits updates to the backend API.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Attendance detail page where a teacher can view and update each student's
/// attendance status (hadir/terlambat/izin/sakit/alpha) for a given subject
/// and date.
///
/// This is a StatefulWidget -- the Flutter equivalent of a Vue component that
/// has mutable local state. The widget itself is immutable (like Vue `props`),
/// while the State class holds the mutable data (like Vue `data()`).
///
/// Props (passed via constructor, immutable -- like Vue `props`):
/// - [teacher] -- the logged-in teacher's data map
/// - [subjectId] / [subjectName] -- which subject this attendance is for
/// - [date] -- the date of the attendance record
class AbsensiDetailPage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final String subjectId;
  final String subjectName;
  final DateTime date;

  const AbsensiDetailPage({
    super.key,
    required this.teacher,
    required this.subjectId,
    required this.subjectName,
    required this.date,
  });

  @override
  State<AbsensiDetailPage> createState() => _AbsensiDetailPageState();
}

/// The mutable State for [AbsensiDetailPage].
///
/// This is like a Vue page component with its own local state
/// (`data() { return {...} }`).  Key state variables:
/// - [_absensiData] -- raw attendance records from the API
/// - [_studentList] / [_filteredStudentList] -- all students and the search-filtered subset
/// - [_absensiStatus] -- a Map<studentId, status> tracking each student's attendance choice
/// - [_isLoading] / [_isSubmitting] -- loading flags (like Vue `data.loading`)
/// - [_searchController] -- TextEditingController, similar to a Vue `v-model` on an input
///
/// `setState()` is like Vue's reactivity system -- when you call it, Flutter
/// re-renders the widget tree, just like Vue re-renders when a reactive
/// property changes.
class _AbsensiDetailPageState extends State<AbsensiDetailPage> {
  List<dynamic> _absensiData = [];
  List<Student> _studentList = [];
  List<Student> _filteredStudentList = [];
  final Map<String, String> _absensiStatus = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  final TextEditingController _searchController = TextEditingController();

  /// Called once when the widget is inserted into the tree.
  /// Like Vue's `mounted()` lifecycle hook -- the place to kick off
  /// initial data loading and set up listeners.
  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterSiswa);
  }

  /// Called when the widget is removed from the tree.
  /// Like Vue's `beforeUnmount()` -- clean up controllers to avoid memory leaks.
  /// In Laravel terms, think of it as a destructor that releases resources.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filters the student list based on the search query (name or NIS).
  /// Like a Vue `computed` property that filters an array, or a Laravel
  /// Collection `->filter()` call. Called automatically via the search
  /// controller listener set up in [initState].
  void _filterSiswa() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudentList = List.from(_studentList);
      } else {
        _filteredStudentList = _studentList
            .where(
              (siswa) =>
                  siswa.name.toLowerCase().contains(query) ||
                  siswa.studentNumber.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  /// Loads student list and existing attendance data in parallel.
  /// Like calling `Promise.all([getStudents(), getAbsensi()])` in Vue/JS,
  /// or in Laravel: running two async queries concurrently.
  /// Uses `Future.wait` for parallel API calls (same as `Promise.all`).
  Future<void> _loadData() async {
    try {
      // Load siswa dan absensi data
      final [studentData, absensiData] = await Future.wait([
        getIt<ApiStudentService>().getStudent(),
        ApiService.getAttendance(
          teacherId: widget.teacher['id'],
          subjectId: widget.subjectId,
          date: DateFormat('yyyy-MM-dd').format(widget.date),
        ),
      ]);

      setState(() {
        _studentList = studentData.map((s) => Student.fromJson(s)).toList();
        _filteredStudentList = List.from(_studentList);
        _absensiData = absensiData;

        // Map status absensi
        for (var absen in _absensiData) {
          _absensiStatus[absen['siswa_id']] = absen['status'];
        }

        // Set default untuk siswa yang belum ada data
        for (var student in _studentList) {
          _absensiStatus[student.id] ??= 'hadir';
        }

        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('attendance', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
            SnackBarUtils.showError(context, 'Gagal memuat data: ${ErrorUtils.getFriendlyMessage(e)}');
    }
  }

  /// Builds a single student card with a dropdown to select attendance status.
  /// Like a Vue `<StudentAttendanceRow>` component rendered inside a `v-for`.
  /// Each dropdown change calls `setState()` which triggers a re-render
  /// (equivalent to Vue reactivity updating the DOM).
  Widget _buildStudentItem(Student student) {
    final status = _absensiStatus[student.id] ?? 'hadir';
    final Color statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAvatarColor(student.name),
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('NIS: ${student.studentNumber}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: DropdownButton<String>(
            value: status,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: 'hadir',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Hadir'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'terlambat',
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.purple, size: 16),
                    SizedBox(width: 4),
                    Text('Terlambat'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'izin',
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    SizedBox(width: 4),
                    Text('Izin'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'sakit',
                child: Row(
                  children: [
                    Icon(
                      Icons.medical_services,
                      color: Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text('Sakit'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'alpha',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text('Alpha'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _absensiStatus[student.id] = value!;
              });
            },
          ),
        ),
      ),
    );
  }

  /// Submits attendance updates for all students to the backend API.
  /// Like a Vue `methods.submitForm()` that calls `axios.post()` in a loop.
  /// In Laravel terms, this is like calling `AttendanceController@store`
  /// for each student. Shows success/error snackbar (like Vue `this.$toast`).
  Future<void> _updateAbsensi() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      int successCount = 0;

      for (var student in _studentList) {
        final status = _absensiStatus[student.id] ?? 'hadir';

        await ApiService.createAttendance({
          'siswa_id': student.id,
          'guru_id': widget.teacher['id'],
          'mata_pelajaran_id': widget.subjectId,
          'tanggal': DateFormat('yyyy-MM-dd').format(widget.date),
          'status': status,
          'keterangan': '',
        });

        successCount++;
      }

      if (mounted) {
                SnackBarUtils.showSuccess(context, 'Berhasil update $successCount absensi');
        AppNavigator.pop(context);
      }
    } catch (e) {
      AppLogger.error('attendance', e);
      if (mounted) {
                SnackBarUtils.showError(context, 'Gagal update absensi: ${ErrorUtils.getFriendlyMessage(e)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Helper functions
  Color _getStatusColor(String status) {
    switch (status) {
      case 'izin':
        return Colors.blue;
      case 'sakit':
        return Colors.orange;
      case 'alpha':
        return Colors.red;
      case 'terlambat':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  Color _getAvatarColor(String nama) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    final index = nama.isNotEmpty ? nama.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }

  /// The main build method -- called every time `setState()` is invoked.
  /// Like Vue's `render()` function or the `<template>` block that re-renders
  /// whenever reactive data changes. Composes the full page layout:
  /// header info, search bar, student list, and submit button.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Absensi - ${widget.subjectName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.subjectName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat(
                          'EEEE, dd MMMM yyyy',
                          'id_ID',
                        ).format(widget.date),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Cari siswa...',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Student Count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Siswa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '${_filteredStudentList.length} siswa',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Student List
                Expanded(
                  child: _filteredStudentList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada siswa ditemukan',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredStudentList.length,
                          itemBuilder: (context, index) =>
                              _buildStudentItem(_filteredStudentList[index]),
                        ),
                ),
                // Update Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _updateAbsensi,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.update),
                    label: Text(
                      _isSubmitting ? 'Mengupdate...' : 'Update Absensi',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
