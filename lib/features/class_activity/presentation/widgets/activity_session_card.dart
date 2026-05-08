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
    final timeStr = (activity['time'] ?? activity['jam'] ?? '')
        .toString()
        .trim();
    final studentCount = activity['student_count'] ?? activity['jumlah_siswa'];

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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _typeIcon(spec),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isHomeroomView && teacherName.isNotEmpty)
                        _teacherRow(teacherName),
                      Text(
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
                      const SizedBox(height: 6),
                      _scopeRow(className, subjectName, spec),
                      const SizedBox(height: 6),
                      _metaRow(
                        type: type,
                        spec: spec,
                        dateStr: dateStr,
                        timeStr: timeStr,
                        studentCount: studentCount,
                      ),
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

  Widget _scopeRow(String className, String subjectName, _TypeSpec spec) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _ScopePill(
          label: className,
          icon: Icons.school_rounded,
          bg: ColorUtils.info600.withValues(alpha: 0.10),
          fg: ColorUtils.info600,
        ),
        _ScopePill(
          label: subjectName,
          icon: Icons.menu_book_rounded,
          bg: ColorUtils.violet700.withValues(alpha: 0.10),
          fg: ColorUtils.violet700,
        ),
      ],
    );
  }

  Widget _metaRow({
    required String type,
    required _TypeSpec spec,
    required String dateStr,
    required String timeStr,
    required dynamic studentCount,
  }) {
    final parts = <Widget>[];

    final formatted = _formatDate(dateStr);
    if (formatted.isNotEmpty) {
      parts.add(_metaLabel(Icons.calendar_today_rounded, formatted));
    }
    if (timeStr.isNotEmpty) {
      parts.add(_metaLabel(Icons.schedule_rounded, timeStr));
    }
    parts.add(_metaPill(label: spec.label, bg: spec.tint, fg: spec.fg));
    if (studentCount is num && studentCount > 0) {
      parts.add(
        _metaPill(
          label: '$studentCount siswa',
          bg: ColorUtils.slate100,
          fg: ColorUtils.slate600,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts,
    );
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

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Hari ini';
    }
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      return 'Kemarin';
    }
    return DateFormat('d MMM', 'id_ID').format(dt);
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
