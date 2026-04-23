import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_summary_item.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_summary_card.dart';

/// Bottom-sheet listing attendance sessions for
/// a given class + subject combination.
class AttendanceDetailSheet extends StatefulWidget {
  final String teacherId;
  final String teacherNama;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final List<dynamic> lessonHours;
  final List<dynamic> classList;
  final Color primaryColor;
  final bool canEdit;
  final LanguageProvider languageProvider;

  const AttendanceDetailSheet({
    super.key,
    required this.teacherId,
    required this.teacherNama,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.lessonHours,
    required this.classList,
    required this.primaryColor,
    required this.languageProvider,
    this.canEdit = true,
  });

  @override
  State<AttendanceDetailSheet> createState() => _AttendanceDetailSheetState();
}

class _AttendanceDetailSheetState extends State<AttendanceDetailSheet> {
  List<AttendanceSummaryItem> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final data = await AttendanceService.getAttendanceSummary(
        teacherId: widget.teacherId,
        classId: widget.classId,
        subjectId: widget.subjectId,
      );
      if (!mounted) return;
      final sessions =
          data
              .map(
                (record) => AttendanceSummaryItem(
                  subjectId: (record['subject_id'] ?? '').toString(),
                  subjectName: record['subject_name'] ?? widget.subjectName,
                  date:
                      AppDateUtils.parseApiDate(
                        record['date']?.toString() ?? '',
                      ) ??
                      DateTime.now(),
                  totalStudent:
                      int.tryParse(
                        record['total_students']?.toString() ?? '0',
                      ) ??
                      0,
                  present:
                      int.tryParse(record['present']?.toString() ?? '0') ?? 0,
                  absent:
                      int.tryParse(record['absent']?.toString() ?? '0') ?? 0,
                  classId: (record['class_id'] ?? '').toString(),
                  className: record['class_name'] ?? widget.className,
                  lessonHourId: (record['lesson_hour_id'] ?? '').toString(),
                  lessonHourName: record['lesson_hour_name'] ?? '',
                ),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading sessions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _header(),
          Expanded(child: _sessionList()),
          if (widget.canEdit) _takeAttendanceButton(),
        ],
      ),
    );
  }

  Widget _header() {
    final p = widget.primaryColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p, p.withValues(alpha: 0.85)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
            child: Row(
              children: [
                _iconBox(),
                const SizedBox(width: 12),
                Expanded(child: _titleColumn()),
                _closeButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.fact_check_outlined,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _titleColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kelas: ${widget.className}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          widget.subjectName,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _closeButton() {
    return IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _sessionList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sessions.isEmpty) {
      return Center(
        child: Text(
          'No attendance records',
          style: TextStyle(color: ColorUtils.slate400),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSessions,
      color: widget.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final s = _sessions[index];
          return AttendanceSummaryCard(
            summary: s,
            primaryColor: widget.primaryColor,
            languageProvider: widget.languageProvider,
            onTap: () => _openDetail(s),
            onDelete: widget.canEdit ? () => _deleteSession(s) : () {},
          );
        },
      ),
    );
  }

  void _openDetail(AttendanceSummaryItem s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherAttendanceDetailPage(
          subjectId: s.subjectId,
          subjectName: s.subjectName,
          date: s.date,
          classId: s.classId ?? '',
          className: s.className ?? '',
          teacher: {'id': widget.teacherId, 'nama': widget.teacherNama},
          lessonHourId: s.lessonHourId,
          lessonHourName: s.lessonHourName,
        ),
      ),
    );
  }

  Future<void> _deleteSession(AttendanceSummaryItem s) async {
    try {
      await AttendanceService.deleteAttendanceSummary(
        teacherId: widget.teacherId,
        subjectId: s.subjectId,
        date: DateFormat('yyyy-MM-dd').format(s.date),
        classId: s.classId,
        lessonHourId: s.lessonHourId,
      );
      _loadSessions();
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Widget _takeAttendanceButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _openEmbeddedInput,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Ambil Presensi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  void _openEmbeddedInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (ctx, sc) => AttendancePage(
          teacher: {'id': widget.teacherId, 'nama': widget.teacherNama},
          initialDate: DateTime.now(),
          initialSubjectId: widget.subjectId,
          initialSubjectName: widget.subjectName,
          initialclassId: widget.classId,
          initialClassName: widget.className,
          initialTabIndex: 1,
          embedded: true,
          scrollController: sc,
        ),
      ),
    ).then((_) => _loadSessions());
  }
}
