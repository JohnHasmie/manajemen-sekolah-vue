// Overview views (card + list) for the material screen when no subject
// is selected yet. Shows summary cards per class+subject.
//
// Extracted from teacher_material_screen.dart `_buildOverview()`,
// `_buildCardView()`, `_buildListView()`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/mixins/card_view_builder_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/mixins/list_view_builder_mixin.dart';

/// Displays material overview summary: card or list view.
class MaterialOverviewView extends StatelessWidget {
  final List<dynamic> overviewSummary;
  final bool isLoading;
  final bool isListView;
  final bool isHomeroomView;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final Future<void> Function() onRefresh;
  final void Function(
    String classId,
    String className,
    String subjectId,
    String subjectName,
  )
  onOpenChapter;

  final String searchText;

  const MaterialOverviewView({
    super.key,
    required this.overviewSummary,
    required this.isLoading,
    required this.isListView,
    this.isHomeroomView = false,
    required this.primaryColor,
    required this.languageProvider,
    required this.onRefresh,
    required this.onOpenChapter,
    this.searchText = '',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
        showActions: false,
      );
    }
    if (overviewSummary.isEmpty) {
      final isSearching = searchText.isNotEmpty;
      return EmptyState(
        title: languageProvider.getTranslatedText(isSearching
            ? {'en': 'No Results', 'id': 'Tidak Ditemukan'}
            : {'en': 'No Materials', 'id': 'Tidak Ada Materi'}),
        subtitle: languageProvider.getTranslatedText(isSearching
            ? {
                'en': 'No results for "$searchText"',
                'id': 'Tidak ditemukan untuk "$searchText"',
              }
            : {
                'en': 'No teaching materials found',
                'id': 'Tidak ada materi mengajar',
              }),
        icon: isSearching ? Icons.search : Icons.menu_book,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: primaryColor,
      child: isListView
          ? _ListView(
              summary: overviewSummary,
              primaryColor: primaryColor,
              lp: languageProvider,
              isHomeroomView: isHomeroomView,
              onOpenChapter: onOpenChapter,
            )
          : _CardView(
              summary: overviewSummary,
              primaryColor: primaryColor,
              lp: languageProvider,
              isHomeroomView: isHomeroomView,
              onOpenChapter: onOpenChapter,
            ),
    );
  }
}

// ── Card view ──

class _CardView extends StatelessWidget with CardViewBuilderMixin {
  @override
  final List<dynamic> summary;
  @override
  final Color primaryColor;
  @override
  final LanguageProvider lp;
  @override
  final bool isHomeroomView;
  @override
  final void Function(String, String, String, String) onOpenChapter;

  const _CardView({
    required this.summary,
    required this.primaryColor,
    required this.lp,
    this.isHomeroomView = false,
    required this.onOpenChapter,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: summary.length,
      itemBuilder: (context, index) => buildCard(context, summary[index]),
    );
  }
}

// ── List view (grouped by subject) ──

class _ListView extends StatelessWidget with ListViewBuilderMixin {
  @override
  final List<dynamic> summary;
  @override
  final Color primaryColor;
  final LanguageProvider lp;
  @override
  final bool isHomeroomView;
  @override
  final void Function(String, String, String, String) onOpenChapter;

  const _ListView({
    required this.summary,
    required this.primaryColor,
    required this.lp,
    this.isHomeroomView = false,
    required this.onOpenChapter,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<dynamic>> bySubject = {};
    for (final g in summary) {
      final sn = g['subject_name']?.toString() ?? '-';
      bySubject.putIfAbsent(sn, () => []).add(g);
    }
    final p = primaryColor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: bySubject.entries.map((entry) {
        final subjectName = entry.key;
        final items = entry.value;
        final totalChapters = items.first['total_chapters'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSubjectHeader(subjectName, totalChapters, items.length, p),
              const SizedBox(height: 10),
              ...items.map((g) => buildClassRow(g, subjectName, p)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
