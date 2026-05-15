// Frame D live conflict preview — admin Jadwal add/edit form.
//
// Sits just above the Simpan footer in [ScheduleFormDialog]. Re-probes
// `GET /teaching-schedule/conflicts` whenever the relevant form fields
// settle (300 ms debounce) and renders a red preview block when the
// chosen (teacher, class, semester, academic_year, days, lesson_hour)
// tuple collides with another row.
//
// The widget is fully reactive — callers just rebuild it with the
// current form state on every setState, and didUpdateWidget detects
// arg changes + schedules a probe. There's no need to wire callbacks
// into the form mixin.
//
// When [excludeScheduleId] is non-empty (edit mode) the row being
// edited is filtered out so the user doesn't see "Bentrok dengan
// dirinya sendiri".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';

/// Renders a red conflict preview card when the current form values
/// would create a teacher- or class-collision in any of the selected
/// days. Renders [SizedBox.shrink] until the user has picked the
/// minimum required fields.
class LiveConflictPreviewCard extends StatefulWidget {
  final String teacherId;
  final String classId;
  final String semesterId;
  final String academicYearId;
  final List<String> daysIds;
  final String lessonHourId;

  /// Optional id of the schedule currently being edited. When set the
  /// probe response is filtered to exclude that id so the edit flow
  /// doesn't flag the row against itself.
  final String? excludeScheduleId;

  /// Optional callback invoked whenever the conflict count changes.
  /// Used by the parent form to enable / disable the Simpan button.
  final ValueChanged<int>? onConflictCountChanged;

  /// Debounce window before firing the probe. Defaults to 350 ms —
  /// long enough that picking 3 fields in quick succession only fires
  /// one network call, short enough to feel responsive.
  final Duration debounce;

  const LiveConflictPreviewCard({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.semesterId,
    required this.academicYearId,
    required this.daysIds,
    required this.lessonHourId,
    this.excludeScheduleId,
    this.onConflictCountChanged,
    this.debounce = const Duration(milliseconds: 350),
  });

  @override
  State<LiveConflictPreviewCard> createState() =>
      _LiveConflictPreviewCardState();
}

class _LiveConflictPreviewCardState extends State<LiveConflictPreviewCard> {
  /// Latest fetched list of conflicting schedule maps. Empty list
  /// renders as "no conflicts" (widget collapses to SizedBox.shrink).
  List<dynamic> _conflicts = const [];

  Timer? _debounce;
  bool _probing = false;

  /// Bumped every time we kick off a probe; the response handler
  /// checks this to swallow late callbacks (debounce-then-fire-again
  /// patterns can produce out-of-order results otherwise).
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(LiveConflictPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_argsChanged(oldWidget)) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool _argsChanged(LiveConflictPreviewCard old) {
    if (old.teacherId != widget.teacherId) return true;
    if (old.classId != widget.classId) return true;
    if (old.semesterId != widget.semesterId) return true;
    if (old.academicYearId != widget.academicYearId) return true;
    if (old.lessonHourId != widget.lessonHourId) return true;
    if (old.excludeScheduleId != widget.excludeScheduleId) return true;
    if (old.daysIds.length != widget.daysIds.length) return true;
    for (var i = 0; i < widget.daysIds.length; i++) {
      if (old.daysIds[i] != widget.daysIds[i]) return true;
    }
    return false;
  }

  bool get _argsComplete =>
      widget.teacherId.isNotEmpty &&
      widget.classId.isNotEmpty &&
      widget.semesterId.isNotEmpty &&
      widget.academicYearId.isNotEmpty &&
      widget.daysIds.isNotEmpty &&
      widget.lessonHourId.isNotEmpty;

  void _schedule() {
    _debounce?.cancel();
    if (!_argsComplete) {
      // Clear stale conflicts the moment the form is incomplete so the
      // preview doesn't show a phantom error.
      if (_conflicts.isNotEmpty) {
        setState(() => _conflicts = const []);
        widget.onConflictCountChanged?.call(0);
      }
      return;
    }
    _debounce = Timer(widget.debounce, _runProbe);
  }

  Future<void> _runProbe() async {
    final myGeneration = ++_generation;
    setState(() => _probing = true);
    try {
      final raw = await getIt<ApiScheduleService>().getConflictingSchedules(
        daysIds: widget.daysIds,
        classId: widget.classId,
        teacherId: widget.teacherId,
        semesterId: widget.semesterId,
        academicYearId: widget.academicYearId,
        lessonHourId: widget.lessonHourId,
        excludeScheduleId: widget.excludeScheduleId,
      );
      if (!mounted || myGeneration != _generation) return;
      setState(() {
        _conflicts = raw;
        _probing = false;
      });
      widget.onConflictCountChanged?.call(raw.length);
    } catch (e) {
      AppLogger.error('schedule_form', 'Live conflict probe failed: $e');
      if (!mounted || myGeneration != _generation) return;
      setState(() => _probing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_argsComplete) return const SizedBox.shrink();
    if (_probing && _conflicts.isEmpty) {
      return _ProbingHint();
    }
    if (_conflicts.isEmpty) {
      return _ClearHint();
    }
    return _ConflictPreview(conflicts: _conflicts);
  }
}

// ─────────────────────────────────────────────────────────────────────
// States
// ─────────────────────────────────────────────────────────────────────

class _ProbingHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ColorUtils.slate400,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Memeriksa bentrok…',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ColorUtils.success600.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColorUtils.success600.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: ColorUtils.success600,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Slot bebas — tidak ada bentrok.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.success600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictPreview extends StatelessWidget {
  final List<dynamic> conflicts;

  const _ConflictPreview({required this.conflicts});

  String _describe(Map<String, dynamic> c) {
    final subject = (c['subject']?['name'] ??
            c['subject_name'] ??
            c['mata_pelajaran_nama'] ??
            'Sesi lain')
        .toString();
    final className = (c['class']?['name'] ??
            c['class_name'] ??
            c['kelas_nama'] ??
            '')
        .toString();
    final teacher = (c['teacher']?['name'] ??
            c['teacher_name'] ??
            c['guru_nama'] ??
            '')
        .toString();
    final pieces = <String>[
      subject,
      if (className.isNotEmpty) className,
      if (teacher.isNotEmpty) teacher,
    ];
    return pieces.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: ColorUtils.error600.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColorUtils.error600.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: ColorUtils.error600,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Pratinjau bentrok',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.errorDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              conflicts.length == 1
                  ? 'Slot yang dipilih bentrok dengan 1 sesi:'
                  : 'Slot yang dipilih bentrok dengan ${conflicts.length} sesi:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorUtils.errorDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            for (final c in conflicts.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: TextStyle(color: ColorUtils.error600)),
                    Expanded(
                      child: Text(
                        c is Map
                            ? _describe(Map<String, dynamic>.from(c))
                            : c.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.errorDark,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (conflicts.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+ ${conflicts.length - 3} sesi lain.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.errorDark.withValues(alpha: 0.85),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Pilih jam atau hari lain untuk menghindari bentrok. '
              'Anda tetap bisa simpan dan tangani lewat dialog konfirmasi.',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: ColorUtils.errorDark.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
