// Admin Sistem → Waktu Pembelajaran · Salin Dari Hari Lain (Frame E).
//
// Picks a source day (single-select) and copies all of its lesson-hour
// sessions to the target day in one backend round-trip via WP.5's
// `POST /lesson-hour-settings/copy` endpoint.
//
// When the target day already has sessions, we set `replace_existing=true`
// and warn the admin in an amber callout that the existing rows will be
// overwritten (rows tied to active teaching schedules are skipped by the
// backend and surfaced in the response's `blocked` list).
//
// Public API
// ----------
//   showLessonSessionCopySheet(
//     context,
//     targetDay: dayMap,
//     allDays: [...],
//     allSessionsByDay: {dayId: [sessions]},
//     targetHasExistingSessions: bool,
//   )
// Returns `true` when copy succeeded so the caller can refresh.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';

Future<bool?> showLessonSessionCopySheet(
  BuildContext context, {
  required dynamic targetDay,
  required List<dynamic> allDays,
  required Map<String, List<dynamic>> allSessionsByDay,
  required bool targetHasExistingSessions,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LessonSessionCopySheet(
      targetDay: targetDay,
      allDays: allDays,
      allSessionsByDay: allSessionsByDay,
      targetHasExistingSessions: targetHasExistingSessions,
    ),
  );
}

class _LessonSessionCopySheet extends StatefulWidget {
  const _LessonSessionCopySheet({
    required this.targetDay,
    required this.allDays,
    required this.allSessionsByDay,
    required this.targetHasExistingSessions,
  });

  final dynamic targetDay;
  final List<dynamic> allDays;
  final Map<String, List<dynamic>> allSessionsByDay;
  final bool targetHasExistingSessions;

  @override
  State<_LessonSessionCopySheet> createState() =>
      _LessonSessionCopySheetState();
}

class _LessonSessionCopySheetState extends State<_LessonSessionCopySheet> {
  String? _selectedSourceId;
  bool _isCopying = false;

  static const _palette = <({Color bg, Color fg})>[
    (bg: Color(0xFFEEF2FF), fg: Color(0xFF4F46E5)),
    (bg: Color(0xFFDCFCE7), fg: Color(0xFF16A34A)),
    (bg: Color(0xFFFFF7ED), fg: Color(0xFFEA580C)),
    (bg: Color(0xFFFEE2E2), fg: Color(0xFFDC2626)),
    (bg: Color(0xFFEDE9FE), fg: Color(0xFF7C3AED)),
    (bg: Color(0xFFCCFBF1), fg: Color(0xFF0D9488)),
    (bg: Color(0xFFEEF2FF), fg: Color(0xFF4F46E5)),
  ];

  String get _targetDayName =>
      dayNameToIndonesian(widget.targetDay['name']?.toString() ?? 'Hari');

  String _trim(String hms) => hms.length >= 5 ? hms.substring(0, 5) : hms;

  List<_SourceOption> _buildSourceOptions() {
    final targetId = widget.targetDay['id'].toString();
    final result = <_SourceOption>[];
    for (var i = 0; i < widget.allDays.length; i++) {
      final day = widget.allDays[i];
      final id = day['id'].toString();
      if (id == targetId) continue;
      final sessions = widget.allSessionsByDay[id] ?? const [];
      if (sessions.isEmpty) continue; // can't copy from an empty day
      final sorted = List<dynamic>.from(sessions)
        ..sort((a, b) {
          int n(dynamic v) =>
              v is int ? v : int.tryParse('${(v as Map)['hour_number']}') ?? 0;
          return n(a).compareTo(n(b));
        });
      final start = _trim(
        (sorted.first as Map)['start_time']?.toString() ?? '',
      );
      final end = _trim((sorted.last as Map)['end_time']?.toString() ?? '');
      result.add(
        _SourceOption(
          id: id,
          name: dayNameToIndonesian(day['name']?.toString() ?? 'Hari'),
          paletteIndex: i,
          sessionCount: sorted.length,
          range: '$start – $end',
        ),
      );
    }
    return result;
  }

  Future<void> _copy() async {
    if (_selectedSourceId == null || _isCopying) return;
    setState(() => _isCopying = true);
    try {
      final result = await getIt<ApiSettingsService>().copyLessonHoursToDay(
        fromDayId: _selectedSourceId!,
        toDayId: widget.targetDay['id'].toString(),
        replaceExisting: widget.targetHasExistingSessions,
      );
      if (!mounted) return;
      final copied = (result['copied_count'] ?? 0) as int;
      final blocked =
          (result['blocked'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];
      if (blocked.isEmpty) {
        SnackBarUtils.showSuccess(
          context,
          '$copied sesi berhasil disalin ke $_targetDayName.',
        );
      } else {
        SnackBarUtils.showInfo(
          context,
          '$copied sesi disalin · ${blocked.length} sesi target dilewati '
          '(terkait jadwal mengajar aktif).',
        );
      }
      AppNavigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCopying = false);
      SnackBarUtils.showError(
        context,
        'Gagal menyalin: ${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _buildSourceOptions();
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
            Flexible(child: _body(options)),
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
                child: const Icon(
                  Icons.content_copy_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Salin Jadwal Hari',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                        children: [
                          const TextSpan(text: 'Salin semua sesi ke '),
                          TextSpan(
                            text: _targetDayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
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

  Widget _body(List<_SourceOption> options) {
    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: ColorUtils.slate300, width: 1),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 28,
                color: ColorUtils.slate400,
              ),
              const SizedBox(height: 10),
              Text(
                'Belum ada hari sumber yang bisa disalin',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Atur dulu sesi pada hari lain, '
                'lalu Salin akan tersedia di sini.',
                style: TextStyle(
                  fontSize: 11.5,
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
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      children: [
        for (final opt in options) ...[
          _SourceTile(
            option: opt,
            palette: _palette[opt.paletteIndex % _palette.length],
            selected: _selectedSourceId == opt.id,
            onTap: () => setState(() => _selectedSourceId = opt.id),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.targetHasExistingSessions) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sesi $_targetDayName yang lama akan diganti dengan '
                    'salinan dari hari pilihan.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer() {
    final canSave = _selectedSourceId != null && !_isCopying;
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
                onPressed: _isCopying ? null : () => AppNavigator.pop(context),
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
                onPressed: canSave ? _copy : null,
                icon: _isCopying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                label: Text(
                  'Salin ke $_targetDayName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

class _SourceOption {
  const _SourceOption({
    required this.id,
    required this.name,
    required this.paletteIndex,
    required this.sessionCount,
    required this.range,
  });

  final String id;
  final String name;
  final int paletteIndex;
  final int sessionCount;
  final String range;
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.option,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final _SourceOption option;
  final ({Color bg, Color fg}) palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ColorUtils.brandDarkBlue.withValues(alpha: 0.04)
          : Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? ColorUtils.brandDarkBlue : ColorUtils.slate200,
              width: selected ? 1.5 : 0.75,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: palette.fg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${option.sessionCount} sesi · ${option.range}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? ColorUtils.brandDarkBlue : Colors.white,
                  border: Border.all(
                    color: selected
                        ? ColorUtils.brandDarkBlue
                        : ColorUtils.slate300,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
