// RPP (lesson plan) list card — premium design with status accent,
// subject icon, metadata row, and contextual action menu.
// Tap card to view detail. Edit/delete via popup menu.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';

/// Premium RPP card for the flat list view.
///
/// Tap the card to open detail. Edit/delete via trailing popup menu.
class LessonPlanCard extends StatelessWidget {
  final Map<String, dynamic> lessonPlan;
  final Color primaryColor;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const LessonPlanCard({
    super.key,
    required this.lessonPlan,
    required this.primaryColor,
    required this.statusColor,
    required this.statusLabel,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final model = LessonPlan.fromJson(lessonPlan);
    final hasClass = (model.className ?? '').isNotEmpty;
    final hasSubject = (model.subjectName ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onView,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Row(
            children: [
              // Left status accent strip
              Container(width: 4, height: 80, color: statusColor),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      // Subject icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          size: 20,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title + metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              model.title.isNotEmpty
                                  ? model.title
                                  : 'Tanpa Judul',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ColorUtils.slate800,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Subject + Class row
                            Row(
                              children: [
                                if (hasSubject) ...[
                                  Icon(
                                    Icons.menu_book_rounded,
                                    size: 11,
                                    color: ColorUtils.slate400,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      model.subjectName!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: ColorUtils.slate500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                if (hasSubject && hasClass)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Text(
                                      '·',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ColorUtils.slate300,
                                      ),
                                    ),
                                  ),
                                if (hasClass) ...[
                                  Icon(
                                    Icons.class_rounded,
                                    size: 11,
                                    color: ColorUtils.slate400,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    model.className!,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: ColorUtils.slate500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Date + status badge row
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 10,
                                  color: ColorUtils.slate400,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  model.createdAtDate,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ColorUtils.slate400,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.08),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(6),
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Action menu
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') onDelete();
                        },
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: ColorUtils.slate400,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            height: 40,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: ColorUtils.slate500,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: ColorUtils.slate700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            height: 40,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: ColorUtils.red500,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Hapus',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: ColorUtils.red500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
