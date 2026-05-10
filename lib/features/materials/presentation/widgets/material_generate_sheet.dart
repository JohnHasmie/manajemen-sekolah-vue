// "Generate Materi AI" bottom sheet — surfaces the checked bab/sub-bab
// items the teacher has queued for AI generation along with an estimated
// runtime, and a single primary action to kick the job off.
//
// Visual contract — Frame G of the Materi mockup:
//
//   ┌──────────────────────────────────────────────────────┐
//   │  ✦   GENERATE MATERI AI · IPA · 7A                   │
//   │      7 Item Belum AI                                  │
//   ├──────────────────────────────────────────────────────┤
//   │  ┌──────────────┬───────────────┐                    │
//   │  │      7       │    ~5 mnt     │                    │
//   │  │ AKAN DIGEN.  │  ESTIM. WAKTU │                    │
//   │  └──────────────┴───────────────┘                    │
//   │                                                       │
//   │  DAFTAR DIPILIH                                       │
//   │  ▢ Bab 1 — Tata Surya / Bulan & Pasang Surut    ~40s │
//   │  ▢ Bab 3 — Energi (3 sub-bab)                    ~2m │
//   │  …                                                    │
//   │  ──────────────────────────────────────────────────── │
//   │       ✦ Generate Sekarang                             │
//   └──────────────────────────────────────────────────────┘
//
// Time estimate: ~40s per item (chapter or sub-chapter). The chapter
// estimate is `subCount × 40s` if any sub-babs are bundled with it,
// otherwise a flat 40s.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';

class MaterialGenerateSheet extends StatelessWidget {
  final List<Map<String, dynamic>> checkedChapters;
  final List<Map<String, dynamic>> checkedSubChapters;

  /// Full chapter list — used to look up the parent bab title for
  /// each checked sub-chapter so item rows can render
  /// "Bab N — {bab title} / {sub title}".
  final List<dynamic> chapterMaterialList;

  final String subjectName;
  final String className;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onGenerate;

  const MaterialGenerateSheet({
    super.key,
    required this.checkedChapters,
    required this.checkedSubChapters,
    required this.chapterMaterialList,
    required this.subjectName,
    required this.className,
    required this.primaryColor,
    required this.languageProvider,
    required this.onGenerate,
  });

  static const _violet = Color(0xFF7C3AED);

  /// Helper to show this sheet as a modal bottom sheet.
  static void show({
    required BuildContext context,
    required List<Map<String, dynamic>> checkedChapters,
    required List<Map<String, dynamic>> checkedSubChapters,
    required List<dynamic> chapterMaterialList,
    required String subjectName,
    required String className,
    required Color primaryColor,
    required LanguageProvider languageProvider,
    required VoidCallback onGenerate,
  }) {
    final lp = languageProvider;
    final totalChecked = checkedChapters.length + checkedSubChapters.length;

    final kickerSubject = subjectName.trim().isNotEmpty
        ? subjectName.toUpperCase()
        : '-';
    final kickerClass = className.trim().isNotEmpty
        ? className.toUpperCase()
        : '-';

    AppBottomSheet.show(
      context: context,
      title: lp.getTranslatedText({
        'en': '$totalChecked Items Belum AI',
        'id': '$totalChecked Item Belum AI',
      }),
      subtitle: 'GENERATE MATERI AI · $kickerSubject · $kickerClass',
      icon: Icons.auto_awesome,
      primaryColor: primaryColor,
      content: MaterialGenerateSheet(
        checkedChapters: checkedChapters,
        checkedSubChapters: checkedSubChapters,
        chapterMaterialList: chapterMaterialList,
        subjectName: subjectName,
        className: className,
        primaryColor: primaryColor,
        languageProvider: languageProvider,
        onGenerate: onGenerate,
      ),
      footer: _MaterialGenerateFooter(
        totalChecked: totalChecked,
        languageProvider: lp,
        onGenerate: onGenerate,
      ),
    );
  }

  int get _totalChecked => checkedChapters.length + checkedSubChapters.length;

  // ── ETA helpers ─────────────────────────────────────────────
  // Tuned to match the mockup: a single sub-bab generates in ~40s,
  // a chapter rolls up its sub-babs (so a 3-sub-bab chapter shows
  // ~2m, a 1-sub-bab chapter shows ~40s, a chapter with no sub-babs
  // also shows ~40s for the bab itself).
  static const _secondsPerItem = 40;

  int _subCountForChapter(String chapterId) {
    return checkedSubChapters
        .where((s) => s['bab_id']?.toString() == chapterId)
        .length;
  }

  int _etaSecondsForChapter(Map<String, dynamic> chapter) {
    final subs = _subCountForChapter(chapter['id'].toString());
    final n = subs > 0 ? subs : 1;
    return n * _secondsPerItem;
  }

  int _etaSecondsForSubChapter() => _secondsPerItem;

  int _totalEtaSeconds() {
    var total = 0;
    for (final c in checkedChapters) {
      total += _etaSecondsForChapter(c);
    }
    total += checkedSubChapters.length * _secondsPerItem;
    // De-dupe: when both a chapter AND its sub-babs are checked, the
    // chapter loop already counted the sub-babs (subs > 0 branch).
    // Subtract the overlap.
    var overlap = 0;
    for (final c in checkedChapters) {
      overlap += _subCountForChapter(c['id'].toString()) * _secondsPerItem;
    }
    return total - overlap;
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '~${seconds}s';
    final mins = seconds / 60;
    if (mins < 1.5) return '~1m';
    if (mins == mins.roundToDouble()) {
      return '~${mins.toInt()}m';
    }
    return '~${mins.toStringAsFixed(1)}m';
  }

  String _formatEtaLong(int seconds) {
    if (seconds < 60) return '~$seconds dtk';
    final mins = (seconds / 60).round();
    return '~$mins mnt';
  }

  // ── Item label helpers ─────────────────────────────────────
  String? _chapterTitleById(String id) {
    for (final c in chapterMaterialList) {
      if (c is Map && c['id']?.toString() == id) {
        return c['judul_bab']?.toString();
      }
    }
    return null;
  }

  int? _chapterUrutanById(String id) {
    for (final c in chapterMaterialList) {
      if (c is Map && c['id']?.toString() == id) {
        final u = c['urutan'];
        return u is num ? u.toInt() : int.tryParse(u?.toString() ?? '');
      }
    }
    return null;
  }

  /// Builds the unified item list shown in DAFTAR DIPILIH. Each entry
  /// carries the display label and an ETA.
  List<({String label, int etaSeconds})> _buildItems() {
    final out = <({String label, int etaSeconds})>[];
    // Chapters that DON'T have any of their sub-babs in the checked
    // sub list — show the bab as a single roll-up entry.
    for (final c in checkedChapters) {
      final id = c['id'].toString();
      final urut = c['urutan']?.toString() ?? '?';
      final title = c['judul_bab']?.toString() ?? '-';
      final subCount = _subCountForChapter(id);
      final label = subCount > 0
          ? 'Bab $urut — $title ($subCount sub-bab)'
          : 'Bab $urut — $title';
      out.add((label: label, etaSeconds: _etaSecondsForChapter(c)));
    }
    // Sub-bab entries — only include those whose parent bab isn't
    // already in `checkedChapters` (otherwise the bab roll-up above
    // already covers them).
    final coveredChapterIds =
        checkedChapters.map((c) => c['id'].toString()).toSet();
    for (final s in checkedSubChapters) {
      final babId = s['bab_id']?.toString() ?? '';
      if (coveredChapterIds.contains(babId)) continue;
      final urut = _chapterUrutanById(babId)?.toString() ?? '?';
      final babTitle = _chapterTitleById(babId) ?? '-';
      final subTitle = s['judul_sub_bab']?.toString() ?? '-';
      final label = 'Bab $urut — $babTitle / $subTitle';
      out.add((label: label, etaSeconds: _etaSecondsForSubChapter()));
    }
    return out;
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_totalChecked == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: _emptyState(),
      );
    }

    final items = _buildItems();
    final totalEtaSeconds = _totalEtaSeconds();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _kpiCard(_totalChecked, totalEtaSeconds),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Text(
            'DAFTAR DIPILIH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: ColorUtils.slate500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            children: [
              for (final it in items) ...[
                _itemCard(it.label, _formatEta(it.etaSeconds)),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(int count, int totalSeconds) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _kpiCell(
                value: '$count',
                label: 'AKAN DIGENERATE',
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: ColorUtils.slate100,
            ),
            Expanded(
              child: _kpiCell(
                value: _formatEtaLong(totalSeconds),
                label: 'ESTIMASI WAKTU',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell({required String value, required String label}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _violet,
            height: 1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _itemCard(String label, String eta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 16,
              color: _violet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate800,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            eta,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate400,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 32, color: ColorUtils.slate400),
          const SizedBox(height: 8),
          Text(
            languageProvider.getTranslatedText({
              'en': 'No chapters selected yet',
              'id': 'Belum ada bab yang dipilih',
            }),
            style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            languageProvider.getTranslatedText({
              'en': 'Check chapters/sub-chapters first, then generate',
              'id': 'Centang bab/sub-bab terlebih dahulu',
            }),
            style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Sticky footer — single CTA "Generate Sekarang".
class _MaterialGenerateFooter extends StatelessWidget {
  final int totalChecked;
  final LanguageProvider languageProvider;
  final VoidCallback onGenerate;

  const _MaterialGenerateFooter({
    required this.totalChecked,
    required this.languageProvider,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final lp = languageProvider;
    final enabled = totalChecked > 0;
    const violet = MaterialGenerateSheet._violet;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
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
                    'en': 'Generate Now',
                    'id': 'Generate Sekarang',
                  })
                : lp.getTranslatedText({
                    'en': 'Select Materials First',
                    'id': 'Pilih Materi Dulu',
                  }),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: violet,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ColorUtils.slate200,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
