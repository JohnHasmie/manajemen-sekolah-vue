// Renders a single AI-generated learning recommendation card.
// Like a reusable Vue component: <RecommendationCard :rec="rec" />.
// Displays priority badge, type badge, HTML description, AI reasoning, and materials.
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_material_item.dart';

/// A card widget that displays a single learning recommendation.
///
/// Renders priority/type badges, an HTML description block, an AI reasoning
/// section, and a list of [RecommendationMaterialItem] rows.
///
/// Pass [listKey] only for the first card so the tutorial coach mark can
/// attach its spotlight to the recommendation list (like a Vue `ref` on the
/// first element).
class RecommendationCard extends StatelessWidget {
  /// The recommendation data map from the API.
  final Map<String, dynamic> rec;

  /// Optional GlobalKey attached to the title text of the first card.
  /// Used by the onboarding tour to highlight the recommendation list.
  final Key? listKey;

  const RecommendationCard({super.key, required this.rec, this.listKey});

  @override
  Widget build(BuildContext context) {
    final priority = rec['priority']?.toString().toLowerCase() ?? 'low';
    final type = rec['type']?.toString().toLowerCase() ?? 'other';

    // Map priority string → colour (like a computed property in Vue).
    Color priorityColor;
    if (priority == 'high') {
      priorityColor = Colors.red;
    } else if (priority == 'medium') {
      priorityColor = Colors.orange;
    } else {
      priorityColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        boxShadow: ColorUtils.corporateShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header: priority badge + type badge ──────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Priority badge (HIGH / MEDIUM / LOW)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Type badge (e.g. EXERCISE / VIDEO / READING)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate100,
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: ColorUtils.slate600,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(Icons.more_horiz, color: ColorUtils.slate300),
              ],
            ),
          ),

          // ── Title ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              // listKey is attached here so the tour can spotlight the list.
              key: listKey,
              rec['title'] ?? 'Rekomendasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate800,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // ── Description (HTML rendered via flutter_widget_from_html) ──────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REKOMENDASI:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate400,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                HtmlWidget(
                  rec['description'] ?? '',
                  textStyle: TextStyle(
                    fontSize: 15,
                    color: ColorUtils.slate700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // ── AI Reasoning block ────────────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ColorUtils.primary.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(
                color: ColorUtils.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: ColorUtils.primary,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'BERDASARKAN ANALISIS AI:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: ColorUtils.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  rec['ai_reasoning'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate700,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // ── Materials & Activities list ───────────────────────────────────
          if (rec['materials'] != null &&
              (rec['materials'] as List).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: 12,
              ),
              child: Text(
                'MATERI & AKTIVITAS:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: ColorUtils.slate400,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            // Map each material entry to a RecommendationMaterialItem widget.
            ...(rec['materials'] as List).map(
              (mat) => RecommendationMaterialItem(matItem: mat),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
