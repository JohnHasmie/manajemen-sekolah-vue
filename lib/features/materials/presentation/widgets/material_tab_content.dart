// Scrollable content for the Materi tab of the sub-chapter detail page.
// Renders AI-generated sections (ringkasan, poin utama, cara mengajar),
// an AI info badge, and any manually-entered content items from the backend.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/section_card.dart';

/// Tab body for AI and manual material content.
///
/// Like a Vue presentational component: all data comes in as props and
/// side-effects go out through callbacks — no direct state mutation here.
/// [parsedContent] is the decoded `material_content` JSON map (may be null),
/// [aiGeneratedData] is the full AI response map (may be null),
/// [contentList] is the list of manual backend content items,
/// [stripHtml] is a pure utility function injected from the parent,
/// [onRegenerateTap] fires when "Regenerate" or the AI badge is tapped.
class MaterialTabContent extends StatelessWidget {
  final Map<String, dynamic>? parsedContent;
  final Map<String, dynamic>? aiGeneratedData;
  final List<dynamic> contentList;
  final Color primaryColor;

  /// Strips HTML tags from a string — injected so this widget stays stateless.
  final String Function(String) stripHtml;

  /// Called when the user taps "Regenerate" or the AI info badge CTA.
  final VoidCallback onRegenerateTap;

  const MaterialTabContent({
    super.key,
    required this.parsedContent,
    required this.aiGeneratedData,
    required this.contentList,
    required this.primaryColor,
    required this.stripHtml,
    required this.onRegenerateTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // ── AI Materi Section ────────────────────────────────────────────
        if (parsedContent != null) ...[
          // Ringkasan
          if (parsedContent!['ringkasan'] != null)
            SectionCard(
              icon: Icons.summarize_rounded,
              iconColor: ColorUtils.violet500,
              title: 'Ringkasan',
              child: Text(
                parsedContent!['ringkasan'] ?? '',
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ),

          // Poin Utama
          if (parsedContent!['poin_utama'] is List) ...[
            SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.lightbulb_rounded,
              iconColor: ColorUtils.amber500,
              title: 'Poin Utama',
              child: Column(
                children: (parsedContent!['poin_utama'] as List)
                    .asMap()
                    .entries
                    .map((entry) {
                      final isLast =
                          entry.key ==
                          (parsedContent!['poin_utama'] as List).length - 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: ColorUtils.amber500.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: TextStyle(
                                    color: ColorUtils.amber500,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value.toString(),
                                style: TextStyle(
                                  color: ColorUtils.slate700,
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ],

          // Cara Mengajar
          if (parsedContent!['cara_mengajar'] != null) ...[
            SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.school_rounded,
              iconColor: primaryColor,
              title: 'Cara Mengajar',
              child: Text(
                parsedContent!['cara_mengajar'] ?? '',
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ] else if (aiGeneratedData != null) ...[
          // Fallback: raw material_content as plain text
          SectionCard(
            icon: Icons.auto_awesome,
            iconColor: Colors.orange,
            title: 'Materi AI',
            child: Text(
              stripHtml(aiGeneratedData!['material_content']?.toString() ?? ''),
              style: TextStyle(
                color: ColorUtils.slate700,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ],

        // ── AI Info Badge ────────────────────────────────────────────────
        if (aiGeneratedData != null) ...[
          SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: primaryColor.withValues(alpha: 0.6),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Dibuat oleh AI  •  ${aiGeneratedData!['ai_model_used'] ?? 'Claude'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onRegenerateTap,
                  child: Text(
                    'Regenerate',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Manual Content from backend ──────────────────────────────────
        if (contentList.isNotEmpty) ...[
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.slate200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.article_rounded,
                  color: ColorUtils.slate600,
                  size: 16,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Konten Manual',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate800,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          ...contentList.asMap().entries.map((entry) {
            final index = entry.key;
            final content = entry.value;
            final cardColor = ColorUtils.getColorForIndex(index);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: cardColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content['judul_konten'] ??
                                content['title'] ??
                                'Judul Konten',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            content['isi_konten'] ??
                                content['description'] ??
                                '',
                            style: TextStyle(
                              color: ColorUtils.slate600,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
