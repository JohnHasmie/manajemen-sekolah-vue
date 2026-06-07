// Admin Sistem → Waktu Pembelajaran · Day session sheet (Frame B + B-2).
//
// Rebuilt from scratch in WP.8 to match the redesigned mockup
// (`_design/admin_waktu_pembelajaran_redesign.html`, Frame B/B2/D).
//
// Behavior contract
// -----------------
// 1. **Tap a row → open Edit sheet.** The per-row pencil/trash icons
//    were dropped. Single-row edit lives on Frame C (the same sheet
//    that handles Tambah), which detects "dirty" state and only
//    enables Simpan when the user actually changed something.
// 2. **Long-press a row → enter bulk-select mode.** The header swaps
//    to a "N sesi dipilih" navy header, each row grows a checkbox on
//    the left, and the footer becomes a BulkActionBar with `Hapus`.
//    Hapus opens a confirmation dialog and calls the WP.5 bulk
//    endpoint `/lesson-hour-settings/bulk-delete`.
// 3. **Empty day** renders a centered `EmptyState`-style placeholder
//    with dual CTA (Salin Hari + Tambah Jam) so admin can bootstrap a
//    day without typing every row.
//
// The sheet owns its own local copy of `_sessions` so deletes/adds
// can update in place without round-tripping the entire screen state.
// On every successful mutation we also call [onSave] so the hub can
// recompute its KPI strip.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/lesson_session_edit_sheet.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/lesson_session_copy_sheet.dart';

class DaySessionManagementSheet extends StatefulWidget {
  /// The day record (`{ id, name }`) we're managing sessions for.
  final dynamic day;

  /// Initial sessions for the day. The sheet keeps an internal mutable
  /// copy so deletes/adds reflect immediately without waiting for the
  /// parent to reload.
  final List<dynamic> sessions;

  /// All sessions grouped by day_id — passed through to the Salin sheet
  /// so the source-day picker can show counts/ranges.
  final Map<String, List<dynamic>> allSessionsByDay;

  /// All available days (Senin → Minggu). Powers the Salin source list.
  final List<dynamic> allDays;

  /// Called after any successful mutation so the parent hub can
  /// refresh its KPI strip and day-row sub-lines.
  final VoidCallback onSave;

  const DaySessionManagementSheet({
    super.key,
    required this.day,
    required this.sessions,
    required this.allSessionsByDay,
    required this.allDays,
    required this.onSave,
  });

  @override
  State<DaySessionManagementSheet> createState() =>
      _DaySessionManagementSheetState();
}

class _DaySessionManagementSheetState extends State<DaySessionManagementSheet> {
  late List<dynamic> _sessions;
  bool _bulkMode = false;
  final Set<String> _selectedIds = <String>{};
  bool _isBulkDeleting = false;

  @override
  void initState() {
    super.initState();
    _sessions = List<dynamic>.from(widget.sessions)..sort(_byHourNumber);
  }

  int _byHourNumber(dynamic a, dynamic b) {
    int n(dynamic v) =>
        v is int ? v : int.tryParse((v as Map)['hour_number'].toString()) ?? 0;
    return n(a).compareTo(n(b));
  }

  String get _dayName =>
      dayNameToIndonesian(widget.day['name']?.toString() ?? 'Hari');
  String get _dayId => widget.day['id'].toString();

  String _trim(String hms) => hms.length >= 5 ? hms.substring(0, 5) : hms;

  // ── Mode transitions ─────────────────────────────────────────────

  void _enterBulk(String firstId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _bulkMode = true;
      _selectedIds
        ..clear()
        ..add(firstId);
    });
  }

  void _exitBulk() {
    setState(() {
      _bulkMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      // Exit bulk mode when user deselects everything.
      if (_selectedIds.isEmpty) _bulkMode = false;
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_sessions.map((s) => (s as Map)['id'].toString()));
    });
  }

  // ── Mutations ────────────────────────────────────────────────────

  Future<void> _openEditSheet({Map<String, dynamic>? session}) async {
    final saved = await showLessonSessionEditSheet(
      context,
      day: widget.day,
      session: session,
      existingSessions: _sessions,
      nextHourNumberHint: session == null ? _nextHourNumber() : null,
    );
    if (saved == true) {
      await _refreshSessions();
    }
  }

  int _nextHourNumber() {
    if (_sessions.isEmpty) return 1;
    final last = _sessions.last as Map;
    final n = last['hour_number'];
    final asInt = n is int ? n : int.tryParse('$n') ?? _sessions.length;
    return asInt + 1;
  }

  Future<void> _openCopySheet() async {
    final didCopy = await showLessonSessionCopySheet(
      context,
      targetDay: widget.day,
      allDays: widget.allDays,
      allSessionsByDay: widget.allSessionsByDay,
      targetHasExistingSessions: _sessions.isNotEmpty,
    );
    if (didCopy == true) {
      await _refreshSessions();
    }
  }

  Future<void> _refreshSessions() async {
    try {
      final all = await getIt<ApiSettingsService>().getLessonHourSettings();
      final mine =
          all.where((s) => (s as Map)['day_id'].toString() == _dayId).toList()
            ..sort(_byHourNumber);
      if (!mounted) return;
      setState(() {
        _sessions = mine;
        _bulkMode = false;
        _selectedIds.clear();
      });
      widget.onSave();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal memuat ulang sesi: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  Future<void> _confirmAndBulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final selectedRows = _sessions
        .where((s) => _selectedIds.contains((s as Map)['id'].toString()))
        .toList();

    // ConfirmationDialog accepts a plain `content` string; embed the
    // per-row preview as a short multi-line list so admin sees exactly
    // which jam will go.
    final preview = selectedRows
        .take(5)
        .map(
          (r) =>
              '• Jam ke-${(r as Map)['hour_number']} · '
              '${_trim(r['start_time']?.toString() ?? '')} – '
              '${_trim(r['end_time']?.toString() ?? '')}',
        )
        .join('\n');
    final overflow = selectedRows.length > 5
        ? '\n+ ${selectedRows.length - 5} sesi lainnya'
        : '';
    final message =
        '${_selectedIds.length} jam pelajaran yang dipilih akan dihapus '
        'dari Jadwal $_dayName. Penomoran sesi berikutnya akan bergeser '
        'otomatis.\n\n$preview$overflow';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isBulkDeleting,
      builder: (_) => ConfirmationDialog(
        title: kSetDeleteSessions.tr.replaceAll('{count}', '${_selectedIds.length}'),
        content: message,
        confirmText: 'Hapus ${_selectedIds.length} sesi',
        confirmColor: const Color(0xFFDC2626),
      ),
    );

    if (confirmed != true) return;
    setState(() => _isBulkDeleting = true);
    try {
      final result = await getIt<ApiSettingsService>().bulkDeleteLessonHours(
        _selectedIds.toList(growable: false),
      );
      if (!mounted) return;
      final deleted = (result['deleted_count'] ?? 0) as int;
      final blocked =
          (result['blocked'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];
      if (blocked.isEmpty) {
        SnackBarUtils.showSuccess(context, '$deleted sesi berhasil dihapus.');
      } else {
        SnackBarUtils.showInfo(
          context,
          '$deleted sesi dihapus · ${blocked.length} dilewati '
          '(terkait jadwal mengajar aktif).',
        );
      }
      await _refreshSessions();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal menghapus sesi: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => _isBulkDeleting = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
            Flexible(child: _sessions.isEmpty ? _emptyBody() : _sessionList()),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final isBulk = _bulkMode;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBulk
              ? [const Color(0xFF0F172A), ColorUtils.brandDarkBlue]
              : [ColorUtils.brandDarkBlue, const Color(0xFF1F4A8F)],
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
                  isBulk ? Icons.check_box_outlined : Icons.schedule_rounded,
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
                    Text(
                      isBulk
                          ? '${_selectedIds.length} sesi dipilih'
                          : 'Jadwal $_dayName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBulk
                          ? 'Ketuk lagi untuk batal pilih'
                          : _sessions.isEmpty
                          ? 'Belum diatur'
                          : '${_sessions.length} jam · '
                                'ketuk untuk edit, tahan untuk pilih',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.80),
                      ),
                    ),
                  ],
                ),
              ),
              if (isBulk) ...[
                Material(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    onTap: _selectAll,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        'Pilih semua',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
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

  Widget _sessionList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      shrinkWrap: true,
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index] as Map<String, dynamic>;
        final id = session['id'].toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SessionRow(
            session: session,
            bulkMode: _bulkMode,
            selected: _selectedIds.contains(id),
            onTap: () {
              if (_bulkMode) {
                _toggleSelected(id);
              } else {
                _openEditSheet(session: session);
              }
            },
            onLongPress: () {
              if (!_bulkMode) {
                _enterBulk(id);
              } else {
                _toggleSelected(id);
              }
            },
          ),
        );
      },
    );
  }

  Widget _emptyBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(
            color: ColorUtils.slate300,
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.schedule_rounded,
                size: 22,
                color: ColorUtils.slate500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Belum ada sesi pelajaran',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tambahkan jam pelajaran satu per satu, atau salin dari hari '
              'lain yang sudah diatur untuk menghemat waktu.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ColorUtils.slate500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    if (_bulkMode) return _bulkFooter();
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
              child: OutlinedButton.icon(
                onPressed: _openCopySheet,
                icon: Icon(
                  Icons.content_copy_rounded,
                  size: 16,
                  color: ColorUtils.brandDarkBlue,
                ),
                label: Text(
                  'Salin',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.brandDarkBlue,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: ColorUtils.brandDarkBlue.withValues(alpha: 0.40),
                    width: 1.5,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
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
                onPressed: _openEditSheet,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Tambah Jam Pelajaran',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.brandDarkBlue,
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

  Widget _bulkFooter() {
    final count = _selectedIds.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$count',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.brandDarkBlue,
                    ),
                  ),
                  TextSpan(
                    text: ' sesi dipilih',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: _isBulkDeleting ? null : _exitBulk,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: ColorUtils.slate300, width: 1.5),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(
                'Batal',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isBulkDeleting || count == 0
                  ? null
                  : _confirmAndBulkDelete,
              icon: _isBulkDeleting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
              label: const Text(
                'Hapus',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                disabledBackgroundColor: const Color(0xFFFCA5A5),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.bulkMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Map<String, dynamic> session;
  final bool bulkMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String _trim(String hms) => hms.length >= 5 ? hms.substring(0, 5) : hms;

  int _durationMinutes(String start, String end) {
    int? parse(String hms) {
      final parts = hms.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return h * 60 + m;
    }

    final s = parse(start);
    final e = parse(end);
    if (s == null || e == null) return 0;
    return e - s;
  }

  @override
  Widget build(BuildContext context) {
    final hourNum = session['hour_number'];
    final start = session['start_time']?.toString() ?? '';
    final end = session['end_time']?.toString() ?? '';
    final startTrim = _trim(start);
    final endTrim = _trim(end);
    final mins = _durationMinutes(start, end);

    final selectedBg = selected
        ? ColorUtils.brandDarkBlue.withValues(alpha: 0.05)
        : Colors.white;
    final selectedBorder = selected
        ? ColorUtils.brandDarkBlue.withValues(alpha: 0.40)
        : ColorUtils.slate200;

    return Material(
      color: selectedBg,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selectedBorder,
              width: selected ? 1 : 0.75,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              if (bulkMode) ...[
                _Checkbox(checked: selected),
                const SizedBox(width: 10),
              ],
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ColorUtils.brandDarkBlue.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$hourNum',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.brandDarkBlue,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Jam ke-$hourNum',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text(
                          '$startTrim – $endTrim',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: ColorUtils.brandCobalt.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          child: Text(
                            mins > 0 ? '$mins mnt' : '—',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: ColorUtils.brandCobalt,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!bulkMode)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ColorUtils.slate300,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? ColorUtils.brandDarkBlue : Colors.white,
        border: Border.all(
          color: checked ? ColorUtils.brandDarkBlue : ColorUtils.slate300,
          width: 2,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      alignment: Alignment.center,
      child: checked
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}
