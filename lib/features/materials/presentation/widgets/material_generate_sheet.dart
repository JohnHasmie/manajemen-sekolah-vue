// Bottom sheet showing checked materials summary and "Generate" button.
//
// Extracted from teacher_material_screen.dart `_showGenerateSheet()`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';

/// Shows a summary of checked materials with a single
/// "Generate Kegiatan Kelas" action button.
class MaterialGenerateSheet extends StatelessWidget {
  final List<Map<String, dynamic>> checkedChapters;
  final List<Map<String, dynamic>> checkedSubChapters;
  final String subjectName;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onGenerate;

  const MaterialGenerateSheet({
    super.key,
    required this.checkedChapters,
    required this.checkedSubChapters,
    required this.subjectName,
    required this.primaryColor,
    required this.languageProvider,
    required this.onGenerate,
  });

  /// Helper to show this sheet as a modal bottom sheet.
  static void show({
    required BuildContext context,
    required List<Map<String, dynamic>> checkedChapters,
    required List<Map<String, dynamic>> checkedSubChapters,
    required String subjectName,
    required Color primaryColor,
    required LanguageProvider languageProvider,
    required VoidCallback onGenerate,
  }) {
    final lp = languageProvider;
    final totalChecked = checkedChapters.length + checkedSubChapters.length;

    AppBottomSheet.show(
      context: context,
      title: lp.getTranslatedText({
        'en': 'Generate Class Activity',
        'id': 'Generate Kegiatan Kelas',
      }),
      icon: Icons.auto_awesome,
      primaryColor: primaryColor,
      content: MaterialGenerateSheet(
        checkedChapters: checkedChapters,
        checkedSubChapters: checkedSubChapters,
        subjectName: subjectName,
        primaryColor: primaryColor,
        languageProvider: languageProvider,
        onGenerate: onGenerate,
      ),
      footer: _MaterialGenerateFooter(
        totalChecked: totalChecked,
        primaryColor: primaryColor,
        languageProvider: lp,
        onGenerate: onGenerate,
      ),
    );
  }

  int get _totalChecked => checkedChapters.length + checkedSubChapters.length;

  @override
  Widget build(BuildContext context) {
    final lp = languageProvider;
    final p = primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [_buildSummary(lp, p)],
    );
  }

  Widget _buildHeader(LanguageProvider lp, Color p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome, size: 18, color: p),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lp.getTranslatedText({
                    'en': 'Generate Class Activity',
                    'id': 'Generate Kegiatan Kelas',
                  }),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                  ),
                ),
                Text(
                  subjectName,
                  style: TextStyle(
                    fontSize: 12,
                    color: p,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(LanguageProvider lp, Color p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _totalChecked == 0
            ? _buildEmptySummary(lp)
            : _buildItemsSummary(lp),
      ),
    );
  }

  Widget _buildEmptySummary(LanguageProvider lp) {
    return Column(
      children: [
        Icon(Icons.info_outline, size: 32, color: ColorUtils.slate400),
        const SizedBox(height: 8),
        Text(
          lp.getTranslatedText({
            'en': 'No chapters selected yet',
            'id': 'Belum ada bab yang dipilih',
          }),
          style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          lp.getTranslatedText({
            'en':
                'Check chapters/sub-chapters first, '
                'then generate',
            'id': 'Centang bab/sub-bab terlebih dahulu',
          }),
          style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildItemsSummary(LanguageProvider lp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: ColorUtils.success600,
            ),
            const SizedBox(width: 6),
            Text(
              '$_totalChecked ${lp.getTranslatedText({'en': 'items ready to generate', 'id': 'materi siap di-generate'})}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...checkedChapters
            .take(3)
            .map((c) => _itemRow(Icons.folder_outlined, c['judul_bab'] ?? '-')),
        ...checkedSubChapters
            .take(3)
            .map(
              (s) => _itemRow(
                Icons.description_outlined,
                s['judul_sub_bab'] ?? '-',
              ),
            ),
        if (_totalChecked > 6)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+${_totalChecked - 6} ${lp.getTranslatedText({'en': 'more', 'id': 'lainnya'})}',
              style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
            ),
          ),
      ],
    );
  }

  Widget _itemRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: ColorUtils.slate400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: ColorUtils.slate600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom footer for material generate sheet with generate button.
class _MaterialGenerateFooter extends StatelessWidget {
  final int totalChecked;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onGenerate;

  const _MaterialGenerateFooter({
    required this.totalChecked,
    required this.primaryColor,
    required this.languageProvider,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final lp = languageProvider;
    final enabled = totalChecked > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: enabled
              ? () {
                  Navigator.pop(context);
                  onGenerate();
                }
              : null,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(
            enabled
                ? lp.getTranslatedText({
                    'en': 'Generate $totalChecked Items',
                    'id': 'Generate $totalChecked Materi',
                  })
                : lp.getTranslatedText({
                    'en': 'Select Materials First',
                    'id': 'Pilih Materi Dulu',
                  }),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ColorUtils.slate200,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
