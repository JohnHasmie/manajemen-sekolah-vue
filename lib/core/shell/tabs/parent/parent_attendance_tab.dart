// Parent "Attendance" tab root — Phase 3.
//
// Per `P1_BottomNav_Spec.md` § 2.3 — wali's Kehadiran tab is conceptually
// "single screen". `ParentAttendanceScreen` requires `parent` and
// `studentId` constructor params. The tab handles the load-students
// flow itself:
//
//   - 0 children linked  → empty state
//   - 1+ children        → embed `ParentAttendanceScreen` directly,
//                          defaulting to the first child. The screen's
//                          `ChildSelectorChipRow` lets the parent
//                          switch between siblings in-place — no
//                          intermediate "pilih anak" step.
//
// This auto-pick behaviour matches the user's Phase-3 brief: tapping
// the Kehadiran tab should land the parent on the actual attendance
// view, not a picker. Dashboard quick-actions / FCM notifications
// route through `ShellNav.goTo(ShellTab.attendance)` which lands here.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';

class ParentAttendanceTab extends ConsumerStatefulWidget {
  const ParentAttendanceTab({super.key});

  @override
  ConsumerState<ParentAttendanceTab> createState() =>
      _ParentAttendanceTabState();
}

class _ParentAttendanceTabState extends ConsumerState<ParentAttendanceTab> {
  bool _loading = true;
  String? _error;
  List<dynamic> _students = const [];
  Map<String, dynamic> _parentData = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = PreferencesService();
      final raw = prefs.getString('user');
      final userData = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final email = (userData['email'] ?? '').toString();
      if (email.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Email akun tidak ditemukan.';
          });
        }
        return;
      }
      final students = await ApiStudentService().getStudent(
        guardianEmail: email,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _students = students;
        _parentData = userData;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat data anak: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return _ErrorOrEmpty(
        title: 'Tidak dapat memuat',
        subtitle: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    }
    if (_students.isEmpty) {
      return const _ErrorOrEmpty(
        title: 'Belum ada anak terdaftar',
        subtitle:
            'Akun ini belum tertaut dengan siswa manapun. Hubungi admin '
            'sekolah untuk menautkan.',
      );
    }

    // Always embed the actual attendance screen — the chip row in
    // the screen handles in-place switching between siblings.
    final firstStudentId = _students.first['id']?.toString() ?? '';
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    return ParentAttendanceScreen(
      parent: _parentData,
      studentId: firstStudentId,
      academicYearId: academicYearId,
    );
  }
}

class _ErrorOrEmpty extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _ErrorOrEmpty({
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 56,
                color: ColorUtils.slate400,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: ColorUtils.slate500,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba lagi'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
