// Source-picker sheet for the three fixed Rekap Nilai columns
// (UTS, UAS, Keterampilan).
//
// Why it exists (Fix-EE)
// ----------------------
// The "Tambah Materi / Bab" 2-step sheet (`add_chapter_sheet.dart`)
// already lets teachers pull per-student scores from existing Buku
// Nilai assessments into a new bab column. The fixed UTS / UAS /
// Keterampilan columns had no equivalent — the only way to fill them
// was cell-by-cell manual input. This sheet exposes the same
// "ambil dari Nilai" flow for those three column headers, scoped to
// assessment types that semantically belong to each column:
//
//   • UTS column         → type ∈ {uts, pts}
//   • UAS column         → type ∈ {uas, pas}
//   • Keterampilan       → everything that isn't UTS/UAS, i.e.
//                          tugas / uh / kuis / praktek / portofolio
//                          / proyek / lainnya — since Indonesian
//                          schools record practical work under many
//                          labels and we let the teacher pick whichever
//                          one represents Keterampilan in their book.
//
// Single-step, no name editing — the column label is fixed.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Result returned by [showColumnSourcePickerSheet].
///
/// `null` from the future means the teacher dismissed the sheet — keep
/// the column as-is. A non-null result with `assessment == null` means
/// "Input Manual" (clear the column). A non-null `assessment` means
/// "pull scores from this assessment".
class ColumnSourcePickerResult {
  /// Picked assessment {title, type, date} — or `null` for manual.
  final Map<String, dynamic>? assessment;

  const ColumnSourcePickerResult({required this.assessment});
}

/// Opens the source-picker sheet for one of the three fixed columns.
///
/// [columnType] must be one of `'uts'`, `'uas'`, or `'skill_score'`.
/// [allAssessments] is the deduped pool the screen already keeps in
/// memory — same shape as `GradeRecapTableBuilder.deriveAvailableAssessments`
/// returns: `[{title, type, date}, …]`.
Future<ColumnSourcePickerResult?> showColumnSourcePickerSheet({
  required BuildContext context,
  required Color primaryColor,
  required String columnType,
  required List<Map<String, dynamic>> allAssessments,
}) {
  return showModalBottomSheet<ColumnSourcePickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => _ColumnSourcePickerSheet(
      primaryColor: primaryColor,
      columnType: columnType,
      allAssessments: allAssessments,
    ),
  );
}

class _ColumnSourcePickerSheet extends StatefulWidget {
  final Color primaryColor;
  final String columnType;
  final List<Map<String, dynamic>> allAssessments;

  const _ColumnSourcePickerSheet({
    required this.primaryColor,
    required this.columnType,
    required this.allAssessments,
  });

  @override
  State<_ColumnSourcePickerSheet> createState() =>
      _ColumnSourcePickerSheetState();
}

class _ColumnSourcePickerSheetState extends State<_ColumnSourcePickerSheet> {
  Map<String, dynamic>? _selected;
  bool _manual = true;

  /// Types that belong to each fixed column. Anything else falls through
  /// to "all non-UTS/UAS" for Keterampilan so practical assessments
  /// labelled with novel names (proyek, portofolio, …) are still
  /// reachable.
  static const Map<String, Set<String>> _typeMap = {
    'uts': {'uts', 'pts'},
    'uas': {'uas', 'pas'},
  };

  List<Map<String, dynamic>> get _eligible {
    if (widget.columnType == 'uts' || widget.columnType == 'uas') {
      final allowed = _typeMap[widget.columnType]!;
      return widget.allAssessments
          .where((a) => allowed.contains((a['type'] ?? '').toString()))
          .toList();
    }
    // Keterampilan / skill_score — everything except UTS/UAS aliases.
    const exclude = {'uts', 'pts', 'uas', 'pas'};
    return widget.allAssessments
        .where((a) => !exclude.contains((a['type'] ?? '').toString()))
        .toList();
  }

  String get _columnLabel {
    switch (widget.columnType) {
      case 'uts':
        return 'UTS';
      case 'uas':
        return 'UAS';
      case 'skill_score':
        return 'Keterampilan';
      default:
        return widget.columnType.toUpperCase();
    }
  }

  void _pick(Map<String, dynamic>? a) {
    setState(() {
      _selected = a;
      _manual = a == null;
    });
  }

  void _submit() {
    Navigator.of(
      context,
    ).pop(ColumnSourcePickerResult(assessment: _manual ? null : _selected));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final grouped = _groupByType(_eligible);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header.
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sumber Nilai $_columnLabel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pilih nilai yang sudah ada di Buku Nilai untuk '
                          'mengisi kolom $_columnLabel.',
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkResponse(
                    onTap: () => Navigator.of(context).pop(),
                    radius: 18,
                    child: Icon(
                      Icons.close_rounded,
                      color: ColorUtils.slate500,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ManualCard(
                        selected: _manual,
                        primaryColor: widget.primaryColor,
                        onTap: () => _pick(null),
                      ),
                      if (grouped.isEmpty) ...[
                        const SizedBox(height: 14),
                        _EmptyHint(columnLabel: _columnLabel),
                      ] else ...[
                        const SizedBox(height: 16),
                        Text(
                          'AMBIL DARI NILAI YANG SUDAH ADA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final entry in grouped.entries) ...[
                          Text(
                            _typeLabel(entry.key),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final a in entry.value)
                            _AssessmentTile(
                              assessment: a,
                              selected:
                                  !_manual &&
                                  _selected != null &&
                                  _selected!['title'] == a['title'] &&
                                  _selected!['date'] == a['date'] &&
                                  _selected!['type'] == a['type'],
                              primaryColor: widget.primaryColor,
                              onTap: () => _pick(a),
                            ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Terapkan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: widget.primaryColor.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Same ordering as `add_chapter_sheet.dart` for visual consistency
  /// — preferred order first, then any unknown types alphabetically.
  Map<String, List<Map<String, dynamic>>> _groupByType(
    List<Map<String, dynamic>> list,
  ) {
    final order = [
      'tugas',
      'uh',
      'kuis',
      'praktek',
      'portofolio',
      'proyek',
      'uts',
      'pts',
      'uas',
      'pas',
    ];
    final map = <String, List<Map<String, dynamic>>>{};
    for (final a in list) {
      final type = (a['type'] ?? 'lainnya').toString().toLowerCase();
      map.putIfAbsent(type, () => []).add(a);
    }
    final sortedKeys = <String>[
      ...order.where(map.containsKey),
      ...map.keys.where((k) => !order.contains(k)),
    ];
    return {for (final k in sortedKeys) k: map[k]!};
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'tugas':
        return 'Tugas';
      case 'uh':
        return 'Ulangan Harian';
      case 'kuis':
        return 'Kuis';
      case 'praktek':
        return 'Praktek';
      case 'portofolio':
        return 'Portofolio';
      case 'proyek':
        return 'Proyek';
      case 'uts':
      case 'pts':
        return 'UTS / PTS';
      case 'uas':
      case 'pas':
        return 'UAS / PAS';
      default:
        return type.toUpperCase();
    }
  }
}

class _ManualCard extends StatelessWidget {
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _ManualCard({
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? primaryColor.withValues(alpha: 0.08)
          : ColorUtils.slate50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primaryColor : ColorUtils.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? primaryColor.withValues(alpha: 0.15)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? primaryColor.withValues(alpha: 0.35)
                        : ColorUtils.slate200,
                  ),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: selected ? primaryColor : ColorUtils.slate600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Input Manual',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? primaryColor : ColorUtils.slate800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kosongkan kolom; isi nilai per siswa di tabel.',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssessmentTile extends StatelessWidget {
  final Map<String, dynamic> assessment;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _AssessmentTile({
    required this.assessment,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (assessment['title'] ?? '-').toString();
    final date = (assessment['date'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? primaryColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? primaryColor : ColorUtils.slate200,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? primaryColor : ColorUtils.slate800,
                        ),
                      ),
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: primaryColor,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String columnLabel;

  const _EmptyHint({required this.columnLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Text(
        'Belum ada nilai $columnLabel di Buku Nilai. '
        'Tambahkan dulu di halaman Nilai, atau pilih Input Manual.',
        style: TextStyle(fontSize: 12, color: ColorUtils.slate600, height: 1.4),
      ),
    );
  }
}
