import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Dialog for bulk grade selection and chapter name configuration.
/// Extracted from `_showBulkSelectionDialog` in `teacher_grade_recap_screen.dart`.
///
/// [type] - column type: 'bab', 'uts', 'uas', etc.
/// [chapterIndex] - index of the chapter if [type] == 'bab'.
/// [rawGrades] - full list of raw grade records for history selection.
/// [allAvailableChapters] - list of reference chapters for material selection.
/// [onApplyBulkGrades] - callback when user selects assessments to average across all students.
/// [onChapterNameChanged] - callback when user sets a manual material name or selects from list.
void showBulkSelectionDialog({
  required BuildContext context,
  required String type,
  int? chapterIndex,
  required List<dynamic> rawGrades,
  required List<dynamic> allAvailableChapters,
  required void Function(List<Map<String, dynamic>> selectedAssessments) onApplyBulkGrades,
  required void Function(Map<String, dynamic> chapterData) onChapterNameChanged,
}) {
  // 1. Get unique assessments for bulk filling
  final assessmentMap = <String, Map<String, dynamic>>{};
  for (var g in rawGrades) {
    final typeStr = (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';

    // Filter by requested type (harian types for bab, or specific uts/uas map)
    bool match = false;
    if (type == 'bab') {
      match = [
        'uh',
        'tugas',
        'praktek',
        'formatif',
        'sumatif',
      ].contains(typeStr);
    } else if (type == 'uts') {
      match = typeStr == 'uts' || typeStr == 'pts';
    } else if (type == 'uas') {
      match = typeStr == 'uas' || typeStr == 'pas';
    } else {
      match = typeStr == type.toLowerCase();
    }

    if (match) {
      final title =
          g['assessment']?['title'] ?? g['title'] ?? g['judul'] ?? 'Nilai';
      final date =
          g['assessment']?['date'] ?? g['date'] ?? g['tanggal'] ?? '';
      final key = '$title|$date';
      if (!assessmentMap.containsKey(key)) {
        assessmentMap[key] = {'title': title, 'date': date};
      }
    }
  }
  final assessments = assessmentMap.values.toList();

  showDialog(
    context: context,
    builder: (context) {
      final List<Map<String, dynamic>> selectedBulk = [];

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return DefaultTabController(
            length: type == 'bab' ? 2 : 1,
            child: AlertDialog(
              title: Text(
                type == 'bab'
                    ? 'Pengaturan Kolom Bab ${chapterIndex! + 1}'
                    : 'Pengaturan Kolom ${type.toUpperCase()}',
              ),
              contentPadding: EdgeInsets.zero,
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: ColorUtils.primary,
                      unselectedLabelColor: ColorUtils.slate500,
                      indicatorColor: ColorUtils.primary,
                      tabs: [
                        if (type == 'bab') Tab(text: 'Nama Materi'),
                        Tab(text: 'Isi Otomatis'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Material Selection (Only for Bab)
                          if (type == 'bab')
                            Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Nama Materi Manual',
                                      hintText: 'Ketik nama materi di sini...',
                                      border: OutlineInputBorder(),
                                      suffixIcon: Icon(Icons.edit),
                                    ),
                                    onSubmitted: (val) {
                                      if (val.isNotEmpty) {
                                        onChapterNameChanged({
                                          'judul_bab': val,
                                          'judul': val,
                                          'title': val,
                                        });
                                        AppNavigator.pop(context);
                                      }
                                    },
                                  ),
                                ),
                                Divider(),
                                Expanded(
                                  child: ListView.builder(
                                    padding: EdgeInsets.all(8.0),
                                    itemCount: allAvailableChapters.length,
                                    itemBuilder: (context, i) {
                                      final c = allAvailableChapters[i];
                                      final title = c['judul_bab'] ??
                                          c['judul'] ??
                                          c['title'] ??
                                          'Bab';
                                      return ListTile(
                                        title: Text(title),
                                        onTap: () {
                                          onChapterNameChanged(c);
                                          AppNavigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          // Tab: Bulk Fill from History (Multi-select)
                          Column(
                            children: [
                              if (assessments.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Pilih satu atau lebih nilai untuk dirata-ratakan ke seluruh murid.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ColorUtils.slate500,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: assessments.isEmpty
                                    ? Center(
                                        child: Text(
                                          'Tidak ada riwayat nilai.',
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                        itemCount: assessments.length,
                                        itemBuilder: (context, i) {
                                          final a = assessments[i];
                                          final isSelected =
                                              selectedBulk.contains(a);
                                          return CheckboxListTile(
                                            title: Text(a['title']),
                                            subtitle: Text(a['date']),
                                            value: isSelected,
                                            activeColor: ColorUtils.primary,
                                            onChanged: (val) {
                                              setDialogState(() {
                                                if (val == true) {
                                                  selectedBulk.add(a);
                                                } else {
                                                  selectedBulk.remove(a);
                                                }
                                              });
                                            },
                                          );
                                        },
                                      ),
                              ),
                              if (selectedBulk.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ColorUtils.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        onApplyBulkGrades(selectedBulk);
                                        AppNavigator.pop(context);
                                      },
                                      child: Text(
                                        'Gunakan Rata-rata (${selectedBulk.length})',
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => AppNavigator.pop(context),
                  child: Text(AppLocalizations.cancel.tr),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
