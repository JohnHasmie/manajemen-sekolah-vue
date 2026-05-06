import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
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
  final String? filterTeacherId;
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
    this.filterTeacherId,
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

  /// Multi-select state. Empty when the sheet is in normal mode;
  /// populated (via long-press → tap to extend) when the user is
  /// bulk-deleting. Identifies sessions by the same composite key
  /// the backend's bulkDestroy filters on.
  final Set<String> _selectedKeys = {};
  bool _isBulkDeleting = false;

  bool get _selectionMode => _selectedKeys.isNotEmpty;

  /// Composite key matching the bulkDestroy filter shape — distinct
  /// per (subject, date, class, lesson hour) tuple. Sessions on the
  /// same date but different lesson hours stay separate.
  String _sessionKey(AttendanceSummaryItem s) =>
      '${s.subjectId}|${DateFormat('yyyy-MM-dd').format(s.date)}'
      '|${s.classId ?? ''}|${s.lessonHourId ?? ''}';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final data = await AttendanceService.getAttendanceSummary(
        teacherId: widget.filterTeacherId,
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
          if (widget.canEdit)
            _selectionMode ? _bulkDeleteBar() : _takeAttendanceButton(),
        ],
      ),
    );
  }

  Widget _bulkDeleteBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _isBulkDeleting ? null : _clearSelection,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Batal'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isBulkDeleting ? null : _deleteSelected,
                  icon: _isBulkDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_outline, size: 20),
                  label: Text(
                    'Hapus ${_selectedKeys.length} sesi',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.error600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
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
          final key = _sessionKey(s);
          return AttendanceSummaryCard(
            summary: s,
            primaryColor: widget.primaryColor,
            languageProvider: widget.languageProvider,
            isSelectionMode: _selectionMode,
            isSelected: _selectedKeys.contains(key),
            onTap: _selectionMode
                ? () => _toggleSelection(key)
                : () => _openDetail(s),
            onLongPress: widget.canEdit ? () => _toggleSelection(key) : null,
          );
        },
      ),
    );
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedKeys.clear);
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
          canEdit: widget.canEdit,
          filterTeacherId: widget.filterTeacherId,
        ),
      ),
    );
  }

  /// Deletes every currently-selected session. Confirmation flows
  /// through the shared [ConfirmationDialog] (gradient header +
  /// confirm/cancel buttons) so the visual matches the destructive
  /// flows on parent / admin pages. Each tuple goes through the
  /// same bulkDestroy endpoint as a single row; we run them
  /// sequentially so the snackbar reflects partial failure if any
  /// one row errors out.
  Future<void> _deleteSelected() async {
    if (_selectedKeys.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: 'Hapus presensi',
        content:
            'Yakin ingin menghapus ${_selectedKeys.length} sesi presensi? '
            'Tindakan ini tidak dapat dibatalkan.',
        confirmText: 'Hapus',
        confirmColor: ColorUtils.error600,
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _isBulkDeleting = true);

    final targets = _sessions
        .where((s) => _selectedKeys.contains(_sessionKey(s)))
        .toList();
    int ok = 0;
    int fail = 0;
    for (final s in targets) {
      try {
        await AttendanceService.deleteAttendanceSummary(
          teacherId: widget.teacherId,
          subjectId: s.subjectId,
          date: DateFormat('yyyy-MM-dd').format(s.date),
          classId: s.classId,
          lessonHourId: s.lessonHourId,
        );
        ok++;
      } catch (e) {
        AppLogger.error('attendance', 'bulk delete row failed: $e');
        fail++;
      }
    }

    if (!mounted) return;
    setState(() {
      _isBulkDeleting = false;
      _selectedKeys.clear();
    });
    if (fail == 0) {
      SnackBarUtils.showSuccess(context, '$ok sesi presensi dihapus.');
    } else {
      SnackBarUtils.showError(
        context,
        '$ok berhasil, $fail gagal dihapus. Coba ulang yang gagal.',
      );
    }
    _loadSessions();
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
