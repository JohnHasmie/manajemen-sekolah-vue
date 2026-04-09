import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Bottom sheet for selecting grade items and computing their average.
void showGradeSelectionDialog({
  required BuildContext context,
  required List<dynamic> rawGrades,
  required String studentClassId,
  required String type,
  int? chapterIndex,
  required void Function(double average) onAverageSelected,
}) {
  final p = ColorUtils.getRoleColor('guru');

  final studentGrades = rawGrades.where((g) {
    final gId = (g['student_class_id'] ?? g['siswa_kelas_id'])?.toString();
    return gId == studentClassId;
  }).toList();

  List<dynamic> options = [];
  if (type == 'bab') {
    options = studentGrades.where((g) {
      final t = (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';
      return ['uh', 'tugas', 'praktek', 'formatif', 'sumatif'].contains(t);
    }).toList();
  } else {
    options = studentGrades.where((g) {
      final t = (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';
      if (type.toLowerCase() == 'uts') return t == 'uts' || t == 'pts';
      if (type.toLowerCase() == 'uas') return t == 'uas' || t == 'pas';
      return t == type.toLowerCase();
    }).toList();
  }

  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) {
      final selected = <dynamic>[];
      return StatefulBuilder(builder: (ctx, setSS) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p, p.withValues(alpha: 0.85)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.checklist_rounded, color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(type == 'bab' ? 'Pilih Nilai Harian/UH' : 'Pilih Nilai ${type.toUpperCase()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Pilih untuk dirata-ratakan', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ])),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ]),
          ),
          // List
          Expanded(child: options.isEmpty
            ? Center(child: Text(AppLocalizations.noGradeDataFound.tr, style: TextStyle(color: ColorUtils.slate400)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: options.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: ColorUtils.slate100),
                itemBuilder: (_, i) {
                  final g = options[i];
                  final score = (g['score'] ?? g['nilai'] ?? '0').toString();
                  final title = g['assessment']?['title'] ?? g['title'] ?? g['judul'] ?? 'Nilai';
                  final date = (g['assessment']?['date'] ?? g['date'] ?? g['tanggal'] ?? '').toString();
                  final dFmt = date.length >= 10 ? '${date.substring(8, 10)}/${date.substring(5, 7)}/${date.substring(0, 4)}' : date;
                  final isSelected = selected.contains(g);
                  final scoreVal = double.tryParse(score) ?? 0;

                  return GestureDetector(
                    onTap: () => setSS(() { if (isSelected) selected.remove(g); else selected.add(g); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      color: isSelected ? p.withValues(alpha: 0.05) : Colors.transparent,
                      child: Row(children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? p : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? p : ColorUtils.slate300, width: 1.5),
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate800)),
                          Text(dFmt, style: TextStyle(fontSize: 11, color: ColorUtils.slate400)),
                        ])),
                        Text(score, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scoreVal >= 80 ? ColorUtils.success600 : (scoreVal >= 60 ? ColorUtils.warning600 : ColorUtils.error600))),
                      ]),
                    ),
                  );
                },
              ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [BoxShadow(color: ColorUtils.slate900.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))]),
            child: SafeArea(top: false, child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: ColorUtils.slate300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Batal', style: TextStyle(color: ColorUtils.slate600, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: selected.isEmpty ? null : () {
                  double sum = 0;
                  for (final item in selected) { sum += double.tryParse((item['score'] ?? item['nilai'] ?? '0').toString()) ?? 0; }
                  onAverageSelected(sum / selected.length);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, elevation: 0, disabledBackgroundColor: ColorUtils.slate200, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(selected.isEmpty ? 'Gunakan Rata-rata' : 'Gunakan Rata-rata (${selected.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              )),
            ])),
          ),
        ]),
      ));
    },
  );
}
