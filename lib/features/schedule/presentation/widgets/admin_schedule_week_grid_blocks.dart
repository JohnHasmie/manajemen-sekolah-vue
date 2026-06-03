// Session-block leaf widgets for the admin week-grid view.
//
// Extracted verbatim from `admin_schedule_week_grid_view.dart` during the
// Phase-2 readability split. Stack-mode mini-cards, the overflow pill, the
// drag feedback card, and the dotted childWhenDragging outline. Kept as a
// `part` file so they can reference the library-private `_BlockPalette`.
part of 'admin_schedule_week_grid_view.dart';

/// One row inside a stack-mode block. Renders a compact mini-card with
/// the subject + class abbreviated to fit a ~12dp row.
class _StackMiniCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final _BlockPalette palette;
  final VoidCallback? onTap;

  const _StackMiniCard({
    required this.schedule,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subject =
        (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'] ?? '—')
            .toString();
    final className = (schedule['class_name'] ?? schedule['kelas_nama'] ?? '')
        .toString();
    final isConflict = schedule.hasScheduleConflict;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(3),
          border: Border(left: BorderSide(color: palette.border, width: 2)),
        ),
        child: Row(
          children: [
            if (isConflict) ...[
              Icon(Icons.warning_amber_rounded, size: 8, color: palette.fg),
              const SizedBox(width: 2),
            ],
            Expanded(
              child: Text(
                className.isEmpty ? subject : '$className · $subject',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: palette.fg,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "+ N lagi" pill rendered as the last row of a stack-mode block when
/// there are more sessions than visible mini-card slots.
class _StackOverflowPill extends StatelessWidget {
  final int count;

  const _StackOverflowPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        '+ $count lagi',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: ColorUtils.slate600,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Tilted card the user's finger carries while dragging a session.
/// Wider + shadowed than the in-grid block so it reads as "lifted".
class _DragFeedbackCard extends StatelessWidget {
  final _BlockPalette palette;
  final String subjectName;
  final String className;
  final String teacherName;

  const _DragFeedbackCard({
    required this.palette,
    required this.subjectName,
    required this.className,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.04, // ~-2.3° tilt
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 140,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.slate900.withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subjectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: palette.fg,
                  height: 1.1,
                ),
              ),
              if (className.isNotEmpty || teacherName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      className,
                      if (teacherName.isNotEmpty) teacherName,
                    ].where((e) => e.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                    ),
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                '↓ lepas di slot lain',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin dashed-style outline shown where the block USED to sit while
/// it's being dragged. Flutter doesn't have native dashed borders, so
/// we use a translucent cobalt outline as a near-equivalent.
class DottedOutline extends StatelessWidget {
  final Widget child;

  const DottedOutline({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: ColorUtils.brandCobalt.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}
