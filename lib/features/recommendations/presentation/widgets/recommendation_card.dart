// Renders a single AI-generated learning recommendation card.
// Redesigned with status toggle button: "Tandai Diterapkan" / "Sudah Diterapkan",
// colored left accent bar, inline priority/type/status pills, sectioned content.
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_material_item.dart';

/// A card widget that displays a single learning recommendation.
/// Includes a status toggle button to mark as "Sudah Diterapkan".
class RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> rec;
  final Key? listKey;
  final bool isUpdatingStatus;
  final VoidCallback? onToggleStatus;

  const RecommendationCard({
    super.key,
    required this.rec,
    this.listKey,
    this.isUpdatingStatus = false,
    this.onToggleStatus,
  });

  /// Best-effort extraction of an authoring teacher's display name from
  /// the rec payload. Backend eager-loads `teacher:id,name` on the
  /// wali-kelas scope, so `rec['teacher']['name']` is the common shape;
  /// we also accept a flat `teacher_name` fallback for robustness.
  String? get _authorName {
    final teacher = rec['teacher'];
    if (teacher is Map) {
      final name = teacher['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    final flat = rec['teacher_name']?.toString();
    if (flat != null && flat.isNotEmpty) return flat;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final priority = rec['priority']?.toString().toLowerCase() ?? 'low';
    final type = rec['type']?.toString().toLowerCase() ?? 'other';
    final status = rec['status']?.toString().toLowerCase() ?? 'pending';
    final isCompleted = status == 'completed';

    final ({Color color, String label, IconData icon}) priorityInfo;
    if (priority == 'high') {
      priorityInfo = (
        color: ColorUtils.red500,
        label: 'Prioritas Tinggi',
        icon: Icons.priority_high_rounded,
      );
    } else if (priority == 'medium') {
      priorityInfo = (
        color: ColorUtils.amber500,
        label: 'Prioritas Sedang',
        icon: Icons.remove_rounded,
      );
    } else {
      priorityInfo = (
        color: ColorUtils.corporateBlue500,
        label: 'Prioritas Rendah',
        icon: Icons.arrow_downward_rounded,
      );
    }

    // Left accent color: green if completed, priority color otherwise
    final accentColor = isCompleted
        ? ColorUtils.emerald500
        : priorityInfo.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: isCompleted
              ? ColorUtils.emerald500.withValues(alpha: 0.2)
              : ColorUtils.slate100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: priority + type + status badges
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          icon: priorityInfo.icon,
                          label: priorityInfo.label,
                          color: priorityInfo.color,
                        ),
                        _Badge(
                          label: type.toUpperCase(),
                          color: ColorUtils.slate500,
                          filled: false,
                        ),
                        if (isCompleted)
                          _Badge(
                            icon: Icons.check_circle_rounded,
                            label: 'Sudah Diterapkan',
                            color: ColorUtils.emerald500,
                          ),
                      ],
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      key: listKey,
                      rec['title'] ?? 'Rekomendasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? ColorUtils.slate500
                            : ColorUtils.slate800,
                        letterSpacing: -0.3,
                        height: 1.3,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: ColorUtils.slate400,
                      ),
                    ),
                  ),

                  // Authoring teacher — shown when the backend eager-loads
                  // the `teacher` relation, which happens on the wali kelas
                  // scope so the homeroom teacher can see who authored
                  // each rec. The mengajar scope skips the eager load, so
                  // this row silently disappears and the card reads as
                  // before for the authoring teacher.
                  if (_authorName != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 13,
                            color: ColorUtils.slate400,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _authorName!,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: ColorUtils.slate500,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Description
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: HtmlWidget(
                      rec['description'] ?? '',
                      textStyle: TextStyle(
                        fontSize: 14,
                        color: isCompleted
                            ? ColorUtils.slate400
                            : ColorUtils.slate600,
                        height: 1.5,
                      ),
                    ),
                  ),

                  // AI Reasoning block
                  if (!isCompleted &&
                      rec['ai_reasoning'] != null &&
                      (rec['ai_reasoning'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ColorUtils.slate50,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                          border: Border.all(color: ColorUtils.slate100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.psychology_rounded,
                                  color: ColorUtils.violet500,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Analisis AI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ColorUtils.violet500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rec['ai_reasoning'] ?? '',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: ColorUtils.slate600,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Materials
                  if (!isCompleted &&
                      rec['materials'] != null &&
                      (rec['materials'] as List).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 13,
                            color: ColorUtils.slate400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Materi & Aktivitas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...(rec['materials'] as List).map(
                      (mat) => RecommendationMaterialItem(matItem: mat),
                    ),
                  ],

                  // Status toggle button
                  if (onToggleStatus != null) _buildStatusButton(isCompleted),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUpdatingStatus ? null : onToggleStatus,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: isCompleted
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ColorUtils.emerald500,
                        ColorUtils.emerald500.withValues(alpha: 0.85),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ColorUtils.corporateBlue500,
                        ColorUtils.corporateBlue500.withValues(alpha: 0.85),
                      ],
                    ),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color:
                      (isCompleted
                              ? ColorUtils.emerald500
                              : ColorUtils.corporateBlue500)
                          .withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isUpdatingStatus)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                const SizedBox(width: 7),
                Text(
                  isUpdatingStatus
                      ? 'Memperbarui...'
                      : isCompleted
                      ? 'Sudah Diterapkan'
                      : 'Tandai Sudah Diterapkan',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact badge/pill widget.
class _Badge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final bool filled;

  const _Badge({
    this.icon,
    required this.label,
    required this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
