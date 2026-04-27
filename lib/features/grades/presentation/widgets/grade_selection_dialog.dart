import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

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
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final selected = <dynamic>[];
      return StatefulBuilder(
        builder: (ctx, setSS) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          // SafeArea(top: false) keeps the footer above the Samsung /
          // iPhone home indicator so the "Gunakan Rata-rata" button is
          // never cropped by system nav.
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                BottomSheetHeader(
                  title: type == 'bab'
                      ? 'Pilih Nilai Harian/UH'
                      : 'Pilih Nilai ${type.toUpperCase()}',
                  subtitle: 'Pilih untuk dirata-ratakan',
                  icon: Icons.checklist_rounded,
                  primaryColor: p,
                ),
                // List
                Expanded(
                  child: options.isEmpty
                      ? Center(
                          child: Text(
                            AppLocalizations.noGradeDataFound.tr,
                            style: TextStyle(color: ColorUtils.slate400),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: options.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: ColorUtils.slate100),
                          itemBuilder: (_, i) {
                            final g = options[i];
                            final score = (g['score'] ?? g['nilai'] ?? '0')
                                .toString();
                            final title =
                                g['assessment']?['title'] ??
                                g['title'] ??
                                g['judul'] ??
                                'Nilai';
                            final date =
                                (g['assessment']?['date'] ??
                                        g['date'] ??
                                        g['tanggal'] ??
                                        '')
                                    .toString();
                            final dFmt = date.length >= 10
                                ? '${date.substring(8, 10)}/${date.substring(5, 7)}/${date.substring(0, 4)}'
                                : date;
                            final isSelected = selected.contains(g);
                            final scoreVal = double.tryParse(score) ?? 0;

                            return GestureDetector(
                              onTap: () => setSS(() {
                                if (isSelected) {
                                  selected.remove(g);
                                } else {
                                  selected.add(g);
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 4,
                                ),
                                color: isSelected
                                    ? p.withValues(alpha: 0.05)
                                    : Colors.transparent,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? p
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? p
                                              : ColorUtils.slate300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: ColorUtils.slate800,
                                            ),
                                          ),
                                          Text(
                                            dFmt,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: ColorUtils.slate400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      score,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: scoreVal >= 80
                                            ? ColorUtils.success600
                                            : (scoreVal >= 60
                                                  ? ColorUtils.warning600
                                                  : ColorUtils.error600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Footer
                BottomSheetFooter(
                  primaryLabel: selected.isEmpty
                      ? 'Gunakan Rata-rata'
                      : 'Gunakan Rata-rata (${selected.length})',
                  secondaryLabel: 'Batal',
                  primaryColor: p,
                  primaryEnabled: selected.isNotEmpty,
                  onPrimary: () {
                    double sum = 0;
                    for (final item in selected) {
                      sum +=
                          double.tryParse(
                            (item['score'] ?? item['nilai'] ?? '0').toString(),
                          ) ??
                          0;
                    }
                    onAverageSelected(sum / selected.length);
                    Navigator.pop(ctx);
                  },
                  onSecondary: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
