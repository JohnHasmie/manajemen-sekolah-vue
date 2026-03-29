// Renders a single material/activity row inside a RecommendationCard.
// Like a reusable Vue component: <RecommendationMaterialItem :mat="mat" />.
// Displays a type icon, title, and HTML content for one learning material.
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A single material/activity row used inside [RecommendationCard].
///
/// Accepts a raw [matItem] from the API. If the item is not a
/// [Map<String, dynamic>] it renders as an empty box (defensive guard,
/// like an `v-if` check in Vue).
class RecommendationMaterialItem extends StatelessWidget {
  /// The raw material map from the API (type, title, content).
  final dynamic matItem;

  const RecommendationMaterialItem({super.key, required this.matItem});

  @override
  Widget build(BuildContext context) {
    // Guard: skip non-map entries — same logic as the original _buildMaterialItem.
    if (matItem is! Map<String, dynamic>) return const SizedBox.shrink();
    final mat = matItem as Map<String, dynamic>;

    // Choose icon and colour based on material type (like a computed in Vue).
    IconData iconData;
    Color iconColor;
    final type = mat['type']?.toString().toLowerCase() ?? 'other';

    if (type == 'video') {
      iconData = Icons.play_circle_filled_rounded;
      iconColor = Colors.red.shade600;
    } else if (type == 'exercise') {
      iconData = Icons.task_alt_rounded;
      iconColor = Colors.orange.shade700;
    } else if (type == 'reading') {
      iconData = Icons.auto_stories_rounded;
      iconColor = Colors.blue.shade700;
    } else {
      iconData = Icons.extension_rounded;
      iconColor = ColorUtils.slate400;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Title + HTML content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mat['title'] ?? 'Materi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                HtmlWidget(
                  mat['content'] ?? '',
                  textStyle: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
