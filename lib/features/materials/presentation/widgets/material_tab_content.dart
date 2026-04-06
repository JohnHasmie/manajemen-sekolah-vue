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
              iconColor: ColorUtils.info600,
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
            const SizedBox(height: AppSpacing.md),
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
                                borderRadius: const BorderRadius.all(Radius.circular(7)),
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
            const SizedBox(height: AppSpacing.md),
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



        // ── Manual Content from backend ──────────────────────────────────
        if (contentList.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.slate200,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Icon(
                  Icons.attach_file_rounded,
                  color: ColorUtils.slate600,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Lampiran (Manual)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...contentList.asMap().entries.map((entry) {
            final index = entry.key;
            final content = entry.value;
            final cardColor = ColorUtils.getColorForIndex(index);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: [
                  BoxShadow(color: ColorUtils.slate200.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onTap: () {
                    // Tap attachment detail placeholder
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: cardColor.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Center(
                            child: Icon(Icons.description_rounded, color: cardColor, size: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                content['judul_konten'] ?? content['title'] ?? 'Lampiran',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ColorUtils.slate800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((content['isi_konten'] ?? content['description'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  content['isi_konten'] ?? content['description'] ?? '',
                                  style: TextStyle(color: ColorUtils.slate500, fontSize: 12, height: 1.4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, color: ColorUtils.slate400, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
