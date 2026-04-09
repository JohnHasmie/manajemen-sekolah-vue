import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Bottom sheet for chapter column configuration — name + bulk auto-fill.
void showBulkSelectionDialog({
  required BuildContext context,
  required String type,
  int? chapterIndex,
  required List<dynamic> rawGrades,
  required List<dynamic> allAvailableChapters,
  required void Function(List<Map<String, dynamic>> selectedAssessments) onApplyBulkGrades,
  required void Function(Map<String, dynamic> chapterData) onChapterNameChanged,
}) {
  final p = ColorUtils.getRoleColor('guru');
  final titleController = TextEditingController();

  // Get unique assessments for bulk filling
  final assessmentMap = <String, Map<String, dynamic>>{};
  for (final g in rawGrades) {
    final typeStr = (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';
    bool match = false;
    if (type == 'bab') {
      match = ['uh', 'tugas', 'praktek', 'formatif', 'sumatif'].contains(typeStr);
    } else if (type == 'uts') {
      match = typeStr == 'uts' || typeStr == 'pts';
    } else if (type == 'uas') {
      match = typeStr == 'uas' || typeStr == 'pas';
    } else {
      match = typeStr == type.toLowerCase();
    }
    if (match) {
      final title = g['assessment']?['title'] ?? g['title'] ?? g['judul'] ?? 'Nilai';
      final date = g['assessment']?['date'] ?? g['date'] ?? g['tanggal'] ?? '';
      final key = '$title|$date';
      if (!assessmentMap.containsKey(key)) {
        assessmentMap[key] = {'title': title, 'date': date};
      }
    }
  }
  final assessments = assessmentMap.values.toList();

  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) {
      final selected = <Map<String, dynamic>>[];
      int tabIndex = 0;

      return StatefulBuilder(builder: (ctx, setSS) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p, p.withValues(alpha: 0.85)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  type == 'bab' ? 'Pengaturan Bab ${(chapterIndex ?? 0) + 1}' : 'Pengaturan ${type.toUpperCase()}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                )),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ]),
          ),

          // Tab switcher (only for bab)
          if (type == 'bab')
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                _TabChip(label: 'Nama Materi', active: tabIndex == 0, color: p, onTap: () => setSS(() => tabIndex = 0)),
                const SizedBox(width: 8),
                _TabChip(label: 'Isi Otomatis', active: tabIndex == 1, color: p, onTap: () => setSS(() => tabIndex = 1)),
              ]),
            ),

          // Content
          Expanded(child: (type != 'bab' || tabIndex == 1)
              // Tab: Auto-fill from assessments
              ? _buildAutoFillTab(assessments, selected, p, setSS)
              // Tab: Material name
              : _buildMaterialTab(titleController, allAvailableChapters, p, ctx, onChapterNameChanged),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: ColorUtils.slate200))),
            child: SafeArea(top: false, child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: ColorUtils.slate300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(AppLocalizations.cancel.tr, style: TextStyle(color: ColorUtils.slate600, fontWeight: FontWeight.w600)),
              )),
              if ((type != 'bab' || tabIndex == 1) && selected.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () { onApplyBulkGrades(selected); Navigator.pop(ctx); },
                  style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('Terapkan (${selected.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                )),
              ],
            ])),
          ),
        ]),
      ));
    },
  );
}

Widget _buildAutoFillTab(List<Map<String, dynamic>> assessments, List<Map<String, dynamic>> selected, Color p, StateSetter setSS) {
  if (assessments.isEmpty) {
    return Center(child: Text('Tidak ada riwayat nilai', style: TextStyle(color: ColorUtils.slate400)));
  }
  return ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    itemCount: assessments.length,
    separatorBuilder: (_, __) => Divider(height: 1, color: ColorUtils.slate100),
    itemBuilder: (_, i) {
      final a = assessments[i];
      final isSelected = selected.contains(a);
      final date = (a['date'] ?? '').toString();
      final dFmt = date.length >= 10 ? '${date.substring(8, 10)}/${date.substring(5, 7)}' : date;

      return GestureDetector(
        onTap: () => setSS(() { if (isSelected) { selected.remove(a); } else { selected.add(a); } }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: isSelected ? p.withValues(alpha: 0.05) : Colors.transparent,
          child: Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: isSelected ? p : Colors.transparent, borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isSelected ? p : ColorUtils.slate300, width: 1.5)),
              child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['title']?.toString() ?? 'Nilai', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate800)),
              if (dFmt.isNotEmpty) Text(dFmt, style: TextStyle(fontSize: 11, color: ColorUtils.slate400)),
            ])),
          ]),
        ),
      );
    },
  );
}

Widget _buildMaterialTab(TextEditingController controller, List<dynamic> chapters, Color p, BuildContext ctx, void Function(Map<String, dynamic>) onChanged) {
  return Column(children: [
    // Manual input
    Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Ketik nama materi...',
          hintStyle: TextStyle(fontSize: 12, color: ColorUtils.slate400),
          filled: true, fillColor: ColorUtils.slate50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: IconButton(
            icon: Icon(Icons.check, color: p, size: 20),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onChanged({'judul_bab': controller.text, 'judul': controller.text, 'title': controller.text});
                Navigator.pop(ctx);
              }
            },
          ),
        ),
        onSubmitted: (val) {
          if (val.isNotEmpty) {
            onChanged({'judul_bab': val, 'judul': val, 'title': val});
            Navigator.pop(ctx);
          }
        },
      ),
    ),
    Divider(height: 1, color: ColorUtils.slate100),
    // Chapter list
    Expanded(child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chapters.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: ColorUtils.slate50),
      itemBuilder: (_, i) {
        final c = chapters[i];
        final title = c['judul_bab'] ?? c['judul'] ?? c['title'] ?? 'Bab';
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(title.toString(), style: TextStyle(fontSize: 13, color: ColorUtils.slate800)),
          trailing: Icon(Icons.chevron_right_rounded, size: 16, color: ColorUtils.slate300),
          onTap: () { onChanged(Map<String, dynamic>.from(c)); Navigator.pop(ctx); },
        );
      },
    )),
  ]);
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color.withValues(alpha: 0.3) : ColorUtils.slate200),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? color : ColorUtils.slate500)),
      ),
    );
  }
}
