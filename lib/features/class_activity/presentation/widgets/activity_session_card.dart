// Per-activity card for the brand-migrated Kegiatan Kelas list
// (mockup Frame 0 in `_design/teacher_class_activity_mockup.html`).
//
// Each card represents ONE activity (not a class+subject aggregate).
// The class and subject are surfaced as separate brand-coloured pills
// so the eye lands on scope before time/type. Tipe icon comes from
// Material rounded glyphs.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ActivitySessionCard extends StatelessWidget {
  /// Per-activity payload — must contain at minimum `title`, `type`,
  /// `class_name`, `subject_name`. Date / time / counts are optional.
  final Map<String, dynamic> activity;

  /// Wali-kelas mode surfaces the recording teacher's name as a small
  /// row above the title so the homeroom teacher can see who logged
  /// the activity.
  final bool isHomeroomView;

  final VoidCallback onTap;

  const ActivitySessionCard({
    super.key,
    required this.activity,
    required this.onTap,
    this.isHomeroomView = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = (activity['title'] ?? activity['judul'] ?? '-').toString();
    final type = (activity['type'] ?? activity['tipe'] ?? 'aktivitas')
        .toString()
        .toLowerCase();
    final className = (activity['class_name'] ?? activity['kelas_nama'] ?? '-')
        .toString();
    final subjectName =
        (activity['subject_name'] ?? activity['mata_pelajaran_nama'] ?? '-')
            .toString();
    final teacherName =
        (activity['teacher_name'] ?? activity['guru_nama'] ?? '')
            .toString()
            .trim();
    final dateStr = (activity['date'] ?? activity['tanggal'] ?? '').toString();
    // Try multiple field shapes for the time — backend may surface it
    // as `time`, `jam`, or fold it into `created_at`.
    final timeStr = _resolveTime(activity);
    final studentCount = _readInt(activity['student_count']);
    final submissionCount = _readInt(activity['submission_count']);

    final spec = _typeSpec(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _typeIcon(spec),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isHomeroomView && teacherName.isNotEmpty)
                        _teacherRow(teacherName),
                      // Row 1 — title, with type pill on the right.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: ColorUtils.slate900,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _typePill(spec),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Row 2 — class + subject scope pills (always inline).
                      _scopeRow(className, subjectName),
                      // Row 3 — meta. Today: clock+time. Older: calendar+
                      // date. Tugas/Ujian also get a "X/Y submit" badge.
                      if (dateStr.isNotEmpty ||
                          timeStr.isNotEmpty ||
                          (studentCount ?? 0) > 0) ...[
                        const SizedBox(height: 5),
                        _metaRow(
                          dateStr: dateStr,
                          timeStr: timeStr,
                          type: type,
                          studentCount: studentCount,
                          submissionCount: submissionCount,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeIcon(_TypeSpec spec) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: spec.tint,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Icon(spec.icon, size: 19, color: spec.fg),
    );
  }

  /// Class + subject as inline pills sized to their text content. Uses
  /// Row + Flexible so a long subject name truncates with ellipsis
  /// instead of wrapping the second pill onto a new line.
  Widget _scopeRow(String className, String subjectName) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: _ScopePill(
            label: className,
            icon: Icons.school_rounded,
            bg: ColorUtils.info600.withValues(alpha: 0.10),
            fg: ColorUtils.info600,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          flex: 2,
          child: _ScopePill(
            label: subjectName,
            icon: Icons.menu_book_rounded,
            bg: ColorUtils.violet700.withValues(alpha: 0.10),
            fg: ColorUtils.violet700,
          ),
        ),
      ],
    );
  }

  /// Inline meta row matching the mockup:
  ///   • Today's cards   → clock + `HH.mm`
  ///   • Older / future  → calendar + `EEE, d MMM`
  ///   • Tugas / Ujian   → trailing "X/Y submit" badge
  /// Time-only on today's cards keeps the date implicit (the section
  /// head already says "Hari ini") and saves a row.
  Widget _metaRow({
    required String dateStr,
    required String timeStr,
    required String type,
    required int? studentCount,
    required int? submissionCount,
  }) {
    final parts = <Widget>[];
    final isToday = _isToday(dateStr);

    // Primary token — time on today's cards, date everywhere else.
    if (isToday && timeStr.isNotEmpty) {
      parts.add(_metaLabel(Icons.schedule_rounded, timeStr));
    } else if (dateStr.isNotEmpty) {
      final formatted = _formatDateLong(dateStr);
      if (formatted.isNotEmpty) {
        parts.add(_metaLabel(Icons.calendar_today_rounded, formatted));
      }
    } else if (timeStr.isNotEmpty) {
      parts.add(_metaLabel(Icons.schedule_rounded, timeStr));
    }

    // Submission badge for tugas / ujian (X/Y submit). Hidden for
    // aktivitas / catatan since those types don't track submissions.
    if (_tracksSubmissions(type) && (studentCount ?? 0) > 0) {
      if (parts.isNotEmpty) parts.add(_metaSeparator());
      parts.add(
        _metaPill(
          label: '${submissionCount ?? 0}/$studentCount submit',
          bg: ColorUtils.success600.withValues(alpha: 0.10),
          fg: ColorUtils.success600,
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }

  bool _tracksSubmissions(String type) {
    return type == 'tugas' ||
        type == 'assignment' ||
        type == 'ujian' ||
        type == 'exam' ||
        type == 'kuis' ||
        type == 'quiz';
  }

  bool _isToday(String raw) {
    if (raw.isEmpty) return false;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  Widget _metaSeparator() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Text(
      '·',
      style: TextStyle(color: ColorUtils.slate300, fontSize: 11),
    ),
  );

  /// Type-tag pill rendered to the right of the title row. Replaces
  /// the previous full-width type pill that dominated the card.
  Widget _typePill(_TypeSpec spec) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: spec.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        spec.label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: spec.fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Resolve a time label from the most common backend field shapes.
  String _resolveTime(Map<String, dynamic> a) {
    final raw = (a['time'] ?? a['jam'] ?? a['start_time'] ?? '')
        .toString()
        .trim();
    if (raw.isNotEmpty) return _trimTime(raw);
    final created = (a['created_at'] ?? a['createdAt'] ?? '').toString();
    if (created.isNotEmpty) {
      final dt = DateTime.tryParse(created);
      if (dt != null) {
        return DateFormat('HH.mm').format(dt.toLocal());
      }
    }
    return '';
  }

  String _trimTime(String s) {
    if (s.length >= 5) return s.substring(0, 5).replaceAll(':', '.');
    return s.replaceAll(':', '.');
  }

  /// Tolerant int parser — counts may arrive as int, num, or string
  /// depending on the backend serializer. Returns null when missing
  /// so the caller can decide whether to render the badge.
  int? _readInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Widget _metaLabel(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: ColorUtils.slate400),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _metaPill({
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _teacherRow(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 11, color: ColorUtils.slate400),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 10,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// `EEE, d MMM` (e.g. "Senin, 5 Mei") for older / future cards. The
  /// section head already says "Hari ini" / "Sebelumnya", so we don't
  /// need to relabel today/yesterday inline.
  String _formatDateLong(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return DateFormat('EEE, d MMM', 'id_ID').format(dt);
  }

  /// Type → icon + tint + label spec. Matches the four type tiles in
  /// the add-activity sheet (mockup Frame B).
  _TypeSpec _typeSpec(String type) {
    switch (type) {
      case 'tugas':
      case 'assignment':
        return _TypeSpec(
          icon: Icons.assignment_turned_in_rounded,
          tint: const Color(0xFFDBEAFE),
          fg: ColorUtils.info600,
          label: 'Tugas',
        );
      case 'ujian':
      case 'exam':
      case 'kuis':
      case 'quiz':
        return _TypeSpec(
          icon: Icons.science_rounded,
          tint: const Color(0xFFFEF3C7),
          fg: ColorUtils.warning600,
          label: 'Ujian',
        );
      case 'catatan':
      case 'note':
        return _TypeSpec(
          icon: Icons.sticky_note_2_rounded,
          tint: ColorUtils.slate100,
          fg: ColorUtils.slate600,
          label: 'Catatan',
        );
      case 'aktivitas':
      case 'activity':
      default:
        return _TypeSpec(
          icon: Icons.groups_2_rounded,
          tint: const Color(0xFFEDE9FE),
          fg: ColorUtils.violet700,
          label: 'Aktivitas',
        );
    }
  }
}

class _TypeSpec {
  final IconData icon;
  final Color tint;
  final Color fg;
  final String label;
  const _TypeSpec({
    required this.icon,
    required this.tint,
    required this.fg,
    required this.label,
  });
}

class _ScopePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  const _ScopePill({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
