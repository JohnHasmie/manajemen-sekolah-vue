// Parent "Attendance" tab root.
//
// Per `P1_BottomNav_Spec.md` § 2.3 — wali's Kehadiran tab is conceptually
// "single screen", but `ParentAttendanceScreen` requires `parent` and
// `studentId` constructor params. So this tab handles the load-students
// flow itself:
//
//   - 0 children linked  → empty state
//   - 1 child            → embed `ParentAttendanceScreen` directly
//   - 2+ children        → render a child picker; tap pushes the screen
//
// Mirrors the existing `ParentMenuItemsMixin._handleParentPresenceTap`
// flow so the multi-anak UX stays familiar.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
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
      final students =
          await ApiStudentService().getStudent(guardianEmail: email);
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
    if (_students.length == 1) {
      // Single child — embed the actual attendance screen directly so
      // the tab is the feature, not a launcher.
      final studentId = _students.first['id']?.toString() ?? '';
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      return ParentAttendanceScreen(
        parent: _parentData,
        studentId: studentId,
        academicYearId: academicYearId,
      );
    }
    // Multi-anak — render a child picker.
    return _ChildPicker(
      students: _students,
      parentData: _parentData,
    );
  }
}

class _ChildPicker extends ConsumerWidget {
  final List<dynamic> students;
  final Map<String, dynamic> parentData;

  const _ChildPicker({required this.students, required this.parentData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ColorUtils.getRoleColor('wali');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ShellTabHeader(
            title: 'Kehadiran',
            subtitle: 'Pilih anak untuk melihat kehadiran',
            accentColor: accent,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              itemCount: students.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final s = Map<String, dynamic>.from(students[i] as Map);
                final name = (s['name'] ?? s['nama'] ?? 'Anak').toString();
                final classLabel =
                    (s['class_name'] ?? s['kelas_nama'] ?? '-').toString();
                return Material(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  child: InkWell(
                    borderRadius:
                        const BorderRadius.all(Radius.circular(14)),
                    onTap: () {
                      final academicYearId = ref
                          .read(academicYearRiverpod)
                          .selectedAcademicYear?['id']
                          ?.toString();
                      AppNavigator.push(
                        context,
                        ParentAttendanceScreen(
                          parent: parentData,
                          studentId: s['id']?.toString() ?? '',
                          academicYearId: academicYearId,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(14)),
                        border: Border.all(color: ColorUtils.slate200),
                        boxShadow: ColorUtils.corporateShadow(elevation: 0.8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                accent.withValues(alpha: 0.12),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Kelas: $classLabel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ColorUtils.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: ColorUtils.slate400,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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

