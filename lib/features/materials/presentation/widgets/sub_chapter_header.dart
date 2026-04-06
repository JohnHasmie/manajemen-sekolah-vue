// Header widget for the sub-chapter detail page.
// Works both as a full-screen page header and a sheet header.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class SubChapterHeader extends StatelessWidget {
  final Map<String, dynamic> chapter;
  final Map<String, dynamic> subChapter;
  final Color primaryColor;
  final LinearGradient cardGradient;
  final LanguageProvider languageProvider;
  const SubChapterHeader({
    super.key,
    required this.chapter,
    required this.subChapter,
    required this.primaryColor,
    required this.cardGradient,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    // Detect if opened as a sheet (no status bar padding needed)
    final isSheet = ModalRoute.of(context) == null || ModalRoute.of(context)!.isFirst == false;
    final topPadding = isSheet ? 0.0 : MediaQuery.of(context).padding.top + 8;

    return Container(
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: isSheet ? const BorderRadius.vertical(top: Radius.circular(20)) : null,
      ),
      child: Column(children: [
        // Drag handle (only in sheet mode)
        if (isSheet)
          Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: EdgeInsets.only(top: isSheet ? 12 : topPadding, left: 16, right: 8, bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top row: back/close + chapter info + done + AI
            Row(children: [
              GestureDetector(
                onTap: () => AppNavigator.pop(context),
                child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: Icon(isSheet ? Icons.close : Icons.arrow_back, color: Colors.white, size: 18)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bab ${chapter['urutan']} · Sub ${subChapter['urutan']}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 2),
                Text(subChapter['judul_sub_bab'] ?? 'Sub Bab', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
            ]),
            const SizedBox(height: 10),
            // Chapter name banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.folder_outlined, color: Colors.white.withValues(alpha: 0.8), size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(chapter['judul_bab'] ?? 'Bab', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
