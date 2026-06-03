// Per-student submission picker sheet — the "Catat Submit" surface
// for tugas / ujian / kuis activities.
//
// Mirrors the Presensi per-student status picker: an `AppDraggableSheet`
// hosting a header, search field, bulk action, and a scrollable list
// where each row exposes a 4-state status pill (Belum / Sudah / Telat /
// Izin). Save → POST /class-activity/{id}/submissions with the diff and
// pops `true` so the caller can refresh the detail screen.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';

const _statusSudah = 'submitted';
const _statusBelum = 'pending';
const _statusTelat = 'late';
const _statusIzin = 'excused';

const _statusLabels = <String, String>{
  _statusSudah: 'Sudah',
  _statusBelum: 'Belum',
  _statusTelat: 'Telat',
  _statusIzin: 'Izin',
};

const _statusOrder = [_statusBelum, _statusTelat, _statusSudah, _statusIzin];

/// Opens the submission picker sheet. Returns `true` on successful save
/// so the caller can re-fetch the activity detail.
///
/// When [activityType] resolves to a scored type (tugas/ujian/kuis),
/// each row exposes a 0-100 score input that flows into the Buku Nilai
/// pipeline on save (Phase 3 — see `syncSubmissionsToGrades`).
Future<bool?> showActivitySubmissionPickerSheet({
  required BuildContext context,
  required String activityId,
  required String activityTitle,
  String? activityType,
}) {
  return AppDraggableSheet.show<bool>(
    context: context,
    builder: (ctx, scrollController) => _ActivitySubmissionPickerSheet(
      activityId: activityId,
      activityTitle: activityTitle,
      activityType: activityType,
      scrollController: scrollController,
    ),
  );
}

class _ActivitySubmissionPickerSheet extends StatefulWidget {
  final String activityId;
  final String activityTitle;
  final String? activityType;
  final ScrollController scrollController;

  const _ActivitySubmissionPickerSheet({
    required this.activityId,
    required this.activityTitle,
    required this.activityType,
    required this.scrollController,
  });

  @override
  State<_ActivitySubmissionPickerSheet> createState() =>
      _ActivitySubmissionPickerSheetState();
}

class _ActivitySubmissionPickerSheetState
    extends State<_ActivitySubmissionPickerSheet> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// Source list — one row per student in the audience, with status.
  /// Mutated in place when the teacher taps a status pill.
  List<Map<String, dynamic>> _rows = const [];

  /// Active status filter chip. Null = "Semua". Drives both the visible
  /// rows in the list AND the context-aware bulk action label/behaviour.
  String? _statusFilter;

  /// True when the activity type produces a graded record (tugas, ujian,
  /// kuis). When true, each row shows a 0-100 score input that flows
  /// into the Buku Nilai pipeline on save.
  bool get _isScored {
    final t = (widget.activityType ?? '').toLowerCase();
    return t == 'tugas' ||
        t == 'assignment' ||
        t == 'ujian' ||
        t == 'exam' ||
        t == 'kuis' ||
        t == 'quiz';
  }

  /// Per-row score controllers, keyed by student_id. Created lazily so
  /// the controller lifecycle matches the row's lifetime.
  final Map<String, TextEditingController> _scoreCtrls = {};

  TextEditingController _scoreCtrlFor(Map<String, dynamic> r) {
    final id = (r['student_id'] ?? '').toString();
    return _scoreCtrls.putIfAbsent(id, () {
      final initial = r['score'];
      return TextEditingController(text: initial == null ? '' : '$initial');
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final c in _scoreCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await getIt<ApiClassActivityService>().getSubmissions(
        widget.activityId,
      );
      // Sort: Belum first, then Telat, then Sudah, then Izin so the
      // teacher's eye lands on actionable rows immediately. Within a
      // status group, preserve backend-provided ordering (typically
      // alphabetical by student name).
      final sorted = [...rows]
        ..sort((a, b) {
          final ai = _statusOrder.indexOf(
            (a['status'] ?? _statusBelum).toString(),
          );
          final bi = _statusOrder.indexOf(
            (b['status'] ?? _statusBelum).toString(),
          );
          if (ai != bi) return ai.compareTo(bi);
          return (a['student_name'] ?? '').toString().compareTo(
            (b['student_name'] ?? '').toString(),
          );
        });
      if (!mounted) return;
      setState(() {
        _rows = sorted;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat daftar siswa: $e';
      });
    }
  }

  void _setStatus(String studentId, String status) {
    setState(() {
      for (final r in _rows) {
        if (r['student_id'] == studentId) {
          r['status'] = status;
          break;
        }
      }
    });
  }

  /// Bulk action — flips every CURRENTLY VISIBLE row (after filter +
  /// search) to the given status. When no filter is active this acts
  /// like "tandai semua sudah" on the full list; with a filter active
  /// the teacher can mass-flip only the bucket they're looking at
  /// (e.g. mark all Belum as Izin in one tap).
  void _bulkSet(String status) {
    final visibleIds = _visibleRows
        .map((r) => r['student_id']?.toString() ?? '')
        .toSet();
    setState(() {
      for (final r in _rows) {
        if (visibleIds.contains(r['student_id']?.toString())) {
          r['status'] = status;
        }
      }
    });
  }

  Future<void> _editNote(Map<String, dynamic> r) async {
    final ctrl = TextEditingController(text: (r['note'] ?? '').toString());
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Catatan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (r['student_name'] ?? '-').toString(),
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Sakit, lupa bawa, izin pulang…',
                hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorUtils.brandCobalt,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved != null) {
      setState(() {
        r['note'] = saved.isEmpty ? null : saved;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final payload = _rows.map((r) {
        final id = (r['student_id'] ?? '').toString();
        final ctrl = _scoreCtrls[id];
        // Score is parsed from the row's controller (when scored type);
        // empty / non-numeric / out-of-range entries become null and the
        // backend skips grade-sync for that row. Range 0..100 is enforced
        // in the InputFormatter, but we double-check here.
        double? score;
        if (_isScored && ctrl != null) {
          final raw = ctrl.text.trim();
          if (raw.isNotEmpty) {
            final parsed = double.tryParse(raw.replaceAll(',', '.'));
            if (parsed != null && parsed >= 0 && parsed <= 100) {
              score = parsed;
            }
          }
        }
        return <String, dynamic>{
          'student_id': r['student_id'],
          'status': r['status'],
          if (r['note'] != null) 'note': r['note'],
          if (score != null) 'score': score,
        };
      }).toList();
      await getIt<ApiClassActivityService>().saveSubmissions(
        widget.activityId,
        payload,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      SnackBarUtils.showSuccess(
        context,
        _isScored
            ? 'Submit tersimpan · nilai disinkron ke Buku Nilai'
            : 'Submit tersimpan',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackBarUtils.showError(context, 'Gagal menyimpan: $e');
    }
  }

  List<Map<String, dynamic>> get _visibleRows {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filter = _statusFilter;
    return _rows.where((r) {
      if (filter != null &&
          (r['status'] ?? _statusBelum).toString() != filter) {
        return false;
      }
      if (q.isEmpty) return true;
      return (r['student_name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  /// Per-status counts derived from the full source list (not filtered).
  /// Drives the chip badge counts.
  Map<String, int> get _counts {
    final m = <String, int>{
      _statusSudah: 0,
      _statusBelum: 0,
      _statusTelat: 0,
      _statusIzin: 0,
    };
    for (final r in _rows) {
      final s = (r['status'] ?? _statusBelum).toString();
      m[s] = (m[s] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _handle(),
          _header(),
          if (!_loading && _error == null && _rows.isNotEmpty) _filterStrip(),
          if (!_loading && _error == null) _searchBar(),
          Expanded(child: _body()),
          if (!_loading && _error == null && _rows.isNotEmpty) _footer(),
        ],
      ),
    );
  }

  Widget _handle() => Container(
    margin: const EdgeInsets.only(top: 8),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: ColorUtils.slate300,
      borderRadius: BorderRadius.circular(999),
    ),
  );

  Widget _header() {
    final summary = _summary();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catat Submit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.activityTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_loading && _rows.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Aksi massal',
                  onSelected: _bulkSet,
                  itemBuilder: (ctx) {
                    // Header line — explains what "filter" means in this
                    // context. PopupMenu doesn't natively style this so
                    // we emit a disabled item.
                    final statusLabel =
                        _statusLabels[_statusFilter] ?? _statusFilter;
                    final scope = _statusFilter == null
                        ? 'semua siswa'
                        : 'siswa "$statusLabel"';
                    return [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Text(
                          'Ubah $scope:',
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: _statusSudah,
                        child: Text('Tandai sebagai Sudah'),
                      ),
                      const PopupMenuItem<String>(
                        value: _statusTelat,
                        child: Text('Tandai sebagai Telat'),
                      ),
                      const PopupMenuItem<String>(
                        value: _statusIzin,
                        child: Text('Tandai sebagai Izin'),
                      ),
                      const PopupMenuItem<String>(
                        value: _statusBelum,
                        child: Text('Reset ke Belum'),
                      ),
                    ];
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Aksi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.brandCobalt,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 16,
                          color: ColorUtils.brandCobalt,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (!_loading && _rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _summary() {
    int sudah = 0, belum = 0, telat = 0, izin = 0;
    for (final r in _rows) {
      switch ((r['status'] ?? _statusBelum).toString()) {
        case _statusSudah:
          sudah++;
          break;
        case _statusTelat:
          telat++;
          break;
        case _statusIzin:
          izin++;
          break;
        default:
          belum++;
      }
    }
    return 'Sudah $sudah · Belum $belum · Telat $telat · Izin $izin';
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Cari nama siswa…',
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: ColorUtils.slate400,
            size: 18,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ColorUtils.slate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ColorUtils.slate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ColorUtils.brandCobalt),
          ),
        ),
      ),
    );
  }

  /// Filter chip strip — Semua / Belum / Sudah / Telat / Izin with live
  /// counts. Tapping a chip narrows both the list AND the bulk action's
  /// scope (the popup label flips to "siswa Belum" etc).
  Widget _filterStrip() {
    final c = _counts;
    final chips = <Widget>[
      _filterChip(
        label: 'Semua',
        count: _rows.length,
        active: _statusFilter == null,
        onTap: () => setState(() => _statusFilter = null),
        color: ColorUtils.slate700,
      ),
      _filterChip(
        label: 'Belum',
        count: c[_statusBelum] ?? 0,
        active: _statusFilter == _statusBelum,
        onTap: () => setState(() => _statusFilter = _statusBelum),
        color: ColorUtils.slate700,
      ),
      _filterChip(
        label: 'Sudah',
        count: c[_statusSudah] ?? 0,
        active: _statusFilter == _statusSudah,
        onTap: () => setState(() => _statusFilter = _statusSudah),
        color: ColorUtils.success600,
      ),
      _filterChip(
        label: 'Telat',
        count: c[_statusTelat] ?? 0,
        active: _statusFilter == _statusTelat,
        onTap: () => setState(() => _statusFilter = _statusTelat),
        color: ColorUtils.warning600,
      ),
      _filterChip(
        label: 'Izin',
        count: c[_statusIzin] ?? 0,
        active: _statusFilter == _statusIzin,
        onTap: () => setState(() => _statusFilter = _statusIzin),
        color: ColorUtils.info600,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required bool active,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? color : ColorUtils.slate200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : ColorUtils.slate700,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.22)
                    : ColorUtils.slate100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : ColorUtils.slate700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: ColorUtils.error600, fontSize: 13),
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Tidak ada siswa pada audiens kegiatan ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          ),
        ),
      );
    }
    final visible = _visibleRows;
    if (visible.isEmpty) {
      // Filter or search produced no matches.
      final statusLabel = _statusLabels[_statusFilter] ?? _statusFilter;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _statusFilter != null
                ? 'Tidak ada siswa berstatus "$statusLabel".'
                : 'Tidak ada siswa cocok dengan pencarian.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: visible.length,
      itemBuilder: (_, i) => _row(visible[i]),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final name = (r['student_name'] ?? '-').toString();
    final status = (r['status'] ?? _statusBelum).toString();
    final note = (r['note'] ?? '').toString().trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: ColorUtils.slate700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
                // Note affordance — pencil if blank, sticky-note if set.
                // Tap → opens the note dialog. Long-press the row also
                // triggers the same flow (faster on tablets).
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => _editNote(r),
                  tooltip: note.isEmpty ? 'Beri catatan' : 'Edit catatan',
                  icon: Icon(
                    note.isEmpty
                        ? Icons.edit_note_rounded
                        : Icons.sticky_note_2_rounded,
                    size: 18,
                    color: note.isEmpty
                        ? ColorUtils.slate400
                        : ColorUtils.warning600,
                  ),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ColorUtils.slate600,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in _statusOrder)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _statusPill(
                              label: _statusLabels[s] ?? s,
                              selected: status == s,
                              color: _statusColor(s),
                              onTap: () =>
                                  _setStatus(r['student_id'].toString(), s),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_isScored) ...[const SizedBox(width: 8), _scoreField(r)],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact 0-100 numeric input. Visible only on tugas/ujian/kuis.
  /// On save, parsed values flow through saveSubmissions → backend
  /// `syncSubmissionsToGrades`, which lands them in the grades pipeline
  /// so they show up in Rekap Nilai automatically.
  Widget _scoreField(Map<String, dynamic> r) {
    return SizedBox(
      width: 64,
      height: 32,
      child: TextField(
        controller: _scoreCtrlFor(r),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: ColorUtils.slate900,
        ),
        decoration: InputDecoration(
          hintText: 'Nilai',
          hintStyle: TextStyle(
            fontSize: 11.5,
            color: ColorUtils.slate400,
            fontWeight: FontWeight.w700,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ColorUtils.slate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ColorUtils.slate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ColorUtils.brandCobalt),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case _statusSudah:
        return ColorUtils.success600;
      case _statusTelat:
        return ColorUtils.warning600;
      case _statusIzin:
        return ColorUtils.info600;
      case _statusBelum:
      default:
        return ColorUtils.slate500;
    }
  }

  Widget _statusPill({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : ColorUtils.slate200,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : ColorUtils.slate700,
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ColorUtils.slate200),
                    foregroundColor: ColorUtils.slate700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.brandCobalt,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
