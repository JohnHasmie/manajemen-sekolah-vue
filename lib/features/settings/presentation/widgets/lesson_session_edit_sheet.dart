// Admin Sistem → Waktu Pembelajaran · Edit/Add session sheet (Frame C).
//
// Rebuilt from scratch in WP.9 to replace the old `session_add_edit_mixin`
// flow. The new sheet is a regular `AppBottomSheet`-styled widget with:
//
//   * Admin navy gradient header (pencil icon for edit, plus icon for add).
//   * Three field rows (BrandTextFormField-styled): Jam Ke- (stepper),
//     Mulai (showTimePicker), Selesai (showTimePicker). All three sit
//     inside slate-50 framed containers with an icon-box on the left and
//     uppercase 10.5 pt label + 15 pt bold value on the right.
//   * Auto-computed Durasi pill below the time row.
//   * Inline overlap warning when the chosen range collides with another
//     session on the same day.
//   * `BottomSheetFooter` Batal + Simpan, where **Simpan is disabled
//     until at least one field is dirty** (i.e. the user actually
//     changed something from the initial values).
//
// Public API
// ----------
//   showLessonSessionEditSheet(
//     context,
//     day: dayMap,
//     session: existingSessionMap, // null → Tambah mode
//     existingSessions: [...],     // for overlap check
//     nextHourNumberHint: 4,       // for Tambah mode default
//   )
// Returns `true` when the user saved successfully so the caller can
// reload its session list; `null` / `false` otherwise.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';

/// Opens the Edit/Add session sheet as a modal bottom sheet.
///
/// Returns `true` when the user saves successfully (caller should
/// refresh its list). Returns `null` / `false` when dismissed.
Future<bool?> showLessonSessionEditSheet(
  BuildContext context, {
  required dynamic day,
  Map<String, dynamic>? session,
  required List<dynamic> existingSessions,
  int? nextHourNumberHint,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LessonSessionEditSheet(
      day: day,
      session: session,
      existingSessions: existingSessions,
      nextHourNumberHint: nextHourNumberHint,
    ),
  );
}

class _LessonSessionEditSheet extends StatefulWidget {
  const _LessonSessionEditSheet({
    required this.day,
    required this.session,
    required this.existingSessions,
    required this.nextHourNumberHint,
  });

  final dynamic day;
  final Map<String, dynamic>? session;
  final List<dynamic> existingSessions;
  final int? nextHourNumberHint;

  @override
  State<_LessonSessionEditSheet> createState() =>
      _LessonSessionEditSheetState();
}

class _LessonSessionEditSheetState extends State<_LessonSessionEditSheet> {
  late int _initialHour;
  late TimeOfDay _initialStart;
  late TimeOfDay _initialEnd;

  late int _hour;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _isSaving = false;

  bool get _isEdit => widget.session != null;
  String get _dayName =>
      dayNameToIndonesian(widget.day['name']?.toString() ?? 'Hari');
  String get _dayId => widget.day['id'].toString();

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.session!;
      _initialHour = _readInt(s['hour_number']) ?? 1;
      _initialStart =
          _readTime(s['start_time']?.toString() ?? '') ??
          const TimeOfDay(hour: 7, minute: 0);
      _initialEnd =
          _readTime(s['end_time']?.toString() ?? '') ??
          const TimeOfDay(hour: 7, minute: 45);
    } else {
      _initialHour = widget.nextHourNumberHint ?? 1;
      _initialStart = _suggestedStartTime();
      _initialEnd = TimeOfDay(
        hour: (_initialStart.hour * 60 + _initialStart.minute + 45) ~/ 60 % 24,
        minute: (_initialStart.hour * 60 + _initialStart.minute + 45) % 60,
      );
    }
    _hour = _initialHour;
    _start = _initialStart;
    _end = _initialEnd;
  }

  /// Pick a sensible default start time for Tambah mode — the end of
  /// the latest existing session (so the new row stacks naturally), or
  /// 07:00 when the day is empty.
  TimeOfDay _suggestedStartTime() {
    if (widget.existingSessions.isEmpty) {
      return const TimeOfDay(hour: 7, minute: 0);
    }
    final last = widget.existingSessions.last as Map;
    final t = _readTime(last['end_time']?.toString() ?? '');
    return t ?? const TimeOfDay(hour: 7, minute: 0);
  }

  int? _readInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}');
  }

  TimeOfDay? _readTime(String hms) {
    if (hms.isEmpty) return null;
    final parts = hms.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  int get _durationMinutes => _minutes(_end) - _minutes(_start);

  /// True when the user changed any field from the values we loaded into.
  bool get _isDirty {
    if (_hour != _initialHour) return true;
    if (_start != _initialStart) return true;
    if (_end != _initialEnd) return true;
    return false;
  }

  /// Overlap detection — true when the chosen range crosses any OTHER
  /// session on the same day (the row being edited is excluded). Also
  /// guards against start ≥ end which is structurally invalid.
  ({bool overlap, bool invalid}) get _validation {
    final startMin = _minutes(_start);
    final endMin = _minutes(_end);
    if (endMin <= startMin) return (overlap: false, invalid: true);
    for (final raw in widget.existingSessions) {
      final s = raw as Map;
      if (_isEdit && s['id'] == widget.session!['id']) continue;
      final oStart = _readTime(s['start_time']?.toString() ?? '');
      final oEnd = _readTime(s['end_time']?.toString() ?? '');
      if (oStart == null || oEnd == null) continue;
      final overlap = startMin < _minutes(oEnd) && endMin > _minutes(oStart);
      if (overlap) return (overlap: true, invalid: false);
    }
    return (overlap: false, invalid: false);
  }

  bool get _canSave => _isDirty && !_validation.invalid && !_validation.overlap;

  // ── Pickers / steppers ──────────────────────────────────────────

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) {
        // Force 24-hour format so the value matches our HH:MM display.
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (isStart) {
        _start = picked;
        // If the user pushes start past end, auto-bump end to +45 minutes
        // so the form stays valid by default.
        if (_minutes(_start) >= _minutes(_end)) {
          final m = _minutes(_start) + 45;
          _end = TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60);
        }
      } else {
        _end = picked;
      }
    });
  }

  void _stepHour(int delta) {
    final next = (_hour + delta).clamp(1, 99);
    if (next == _hour) return;
    HapticFeedback.selectionClick();
    setState(() => _hour = next);
  }

  // ── Save ────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);
    String fmt(TimeOfDay t) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    try {
      if (_isEdit) {
        await getIt<ApiSettingsService>().updateLessonSession(
          id: widget.session!['id'].toString(),
          startTime: fmt(_start),
          endTime: fmt(_end),
          hourNumber: _hour,
        );
      } else {
        await getIt<ApiSettingsService>().createLessonSession(
          dayId: _dayId,
          hourNumber: _hour,
          startTime: fmt(_start),
          endTime: fmt(_end),
        );
      }
      if (!mounted) return;
      AppNavigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      SnackBarUtils.showError(
        context,
        'Gagal menyimpan sesi: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final v = _validation;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _hourField(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _timeField(
                            label: kSetStart.tr,
                            value: _start,
                            dirty: _start != _initialStart,
                            onTap: () => _pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _timeField(
                            label: kSetEnd.tr,
                            value: _end,
                            dirty: _end != _initialEnd,
                            onTap: () => _pickTime(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _durationCard(),
                    if (v.invalid) ...[
                      const SizedBox(height: 8),
                      _warningCard(
                        text: 'Waktu selesai harus setelah waktu mulai.',
                        tone: _WarningTone.danger,
                      ),
                    ] else if (v.overlap) ...[
                      const SizedBox(height: 8),
                      _warningCard(
                        text:
                            'Sesi ini tumpang tindih dengan jam lain '
                            'di hari yang sama.',
                        tone: _WarningTone.danger,
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      _warningCard(
                        text:
                            'Sesi tidak boleh tumpang tindih dengan jam '
                            'pelajaran lain pada hari yang sama.',
                        tone: _WarningTone.info,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorUtils.brandDarkBlue, const Color(0xFF1F4A8F)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.brandDarkBlue.withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _isEdit
                                ? 'Edit Sesi · $_dayName'
                                : 'Tambah Sesi · $_dayName',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isDirty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.20),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Dot(color: Color(0xFFF59E0B)),
                                SizedBox(width: 4),
                                Text(
                                  'BELUM DISIMPAN',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF59E0B),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Atur urutan jam & rentang waktu pelajaran',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.80),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.all(Radius.circular(999)),
                child: InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hourField() {
    final dirty = _hour != _initialHour;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dirty ? const Color(0xFFFEFCE8) : ColorUtils.slate50,
        border: Border.all(
          color: dirty
              ? const Color(0xFFF59E0B).withValues(alpha: 0.50)
              : ColorUtils.slate200,
          width: 1.5,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: dirty
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                  : ColorUtils.brandDarkBlue.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.tag_rounded,
              size: 16,
              color: dirty ? const Color(0xFFB45309) : ColorUtils.brandDarkBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'JAM KE-',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$_hour',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: () => _stepHour(-1),
            enabled: _hour > 1,
          ),
          const SizedBox(width: 6),
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: () => _stepHour(1),
            enabled: _hour < 99,
          ),
        ],
      ),
    );
  }

  Widget _timeField({
    required String label,
    required TimeOfDay value,
    required bool dirty,
    required VoidCallback onTap,
  }) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final display = '$hh:$mm';
    return Material(
      color: dirty ? const Color(0xFFFEFCE8) : ColorUtils.slate50,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(
              color: dirty
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.50)
                  : ColorUtils.slate200,
              width: 1.5,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: dirty
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                      : ColorUtils.brandDarkBlue.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: dirty
                      ? const Color(0xFFB45309)
                      : ColorUtils.brandDarkBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      display,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationCard() {
    final mins = _durationMinutes;
    final initialMins = _minutes(_initialEnd) - _minutes(_initialStart);
    final delta = mins - initialMins;
    final showDelta = _isEdit && delta != 0 && mins > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.brandDarkBlue.withValues(alpha: 0.06),
        border: Border.all(
          color: ColorUtils.brandDarkBlue.withValues(alpha: 0.15),
          width: 1,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: ColorUtils.brandDarkBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.brandDarkBlue,
                ),
                children: [
                  const TextSpan(text: 'Durasi sesi: '),
                  TextSpan(
                    text: mins > 0 ? '$mins menit' : '—',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (showDelta) ...[
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: '${delta > 0 ? '↑ +' : '↓ '}${delta.abs()} mnt',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: delta > 0
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningCard({required String text, required _WarningTone tone}) {
    Color bg, border, fg;
    IconData icon;
    switch (tone) {
      case _WarningTone.info:
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFFDE68A);
        fg = const Color(0xFFB45309);
        icon = Icons.info_outline_rounded;
        break;
      case _WarningTone.danger:
        bg = const Color(0xFFFEE2E2);
        border = const Color(0xFFFECACA);
        fg = const Color(0xFFB91C1C);
        icon = Icons.error_outline_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final canSave = _canSave && !_isSaving;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate100, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => AppNavigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: ColorUtils.slate300, width: 1.5),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: canSave ? _save : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.save_outlined,
                        size: 18,
                        color: canSave ? Colors.white : ColorUtils.slate500,
                      ),
                label: Text(
                  'Simpan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: canSave ? Colors.white : ColorUtils.slate500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.brandDarkBlue,
                  disabledBackgroundColor: ColorUtils.slate200,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _WarningTone { info, danger }

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? ColorUtils.brandDarkBlue.withValues(alpha: 0.10)
          : ColorUtils.slate100,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? ColorUtils.brandDarkBlue : ColorUtils.slate400,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
