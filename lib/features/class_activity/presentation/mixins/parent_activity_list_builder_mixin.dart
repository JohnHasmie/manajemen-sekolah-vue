import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_empty_state.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_info_tag.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';

mixin ParentActivityListBuilderMixin
    on ConsumerState<ParentClassActivityScreen> {
  Widget buildActivityList() {
    final languageProvider = ref.read(languageRiverpod);
    final state = this as ParentClassActivityScreenState;

    if (state.selectedStudentId == null) {
      return ActivityEmptyState(
        message: AppLocalizations.selectChildToViewActivity.tr,
      );
    }

    if (state.isLoading) {
      return buildLoadingState();
    }

    if (state.activityList.isEmpty) {
      return ActivityEmptyState(
        message: AppLocalizations.noActivityForChild.tr,
      );
    }

    return ListView.builder(
      key: state.activityListKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.activityList.length,
      itemBuilder: (context, index) {
        final activity = state.activityList[index];
        final isAssignment = activity['jenis'] == 'tugas';
        final isSpecificTarget = activity['target'] == 'khusus';
        final isForThisStudent = activity['untuk_siswa_ini'] == true;
        final isRead =
            !state.hasFreshData ||
            activity['is_read'] == true ||
            activity['is_read'] == 1 ||
            activity['is_read'] == '1';

        final accentColor = isAssignment
            ? ColorUtils.warning600
            : ColorUtils.success600;

        return Builder(
          builder: (context) {
            onItemVisible(activity);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => showActivityDetail(activity),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(12),
                            ),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            isAssignment
                                ? Icons.assignment_outlined
                                : Icons.menu_book_outlined,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      activity['judul'] ??
                                          AppLocalizations.activityTitle.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: ColorUtils.slate900,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!isRead) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: ColorUtils.error600,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${activity['mata_pelajaran_nama'] ?? (activity['subject'] is Map ? activity['subject']['name'] : null) ?? '-'} • ${activity['kelas_nama'] ?? (activity['class'] is Map ? activity['class']['name'] : null) ?? '-'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorUtils.slate600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (activity['deskripsi'] != null &&
                                  activity['deskripsi'].toString().isNotEmpty &&
                                  activity['deskripsi'] != 'null') ...[
                                const SizedBox(height: 6),
                                Text(
                                  activity['deskripsi'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ColorUtils.slate500,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if ((activity['judul_bab'] ??
                                      (activity['chapter'] is Map
                                          ? activity['chapter']['title']
                                          : null)) !=
                                  null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.auto_stories_rounded,
                                      size: 12,
                                      color: ColorUtils.info600,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        () {
                                          final bab =
                                              activity['judul_bab'] ??
                                              (activity['chapter'] is Map
                                                  ? activity['chapter']['title']
                                                  : null) ??
                                              '';
                                          final subBab =
                                              activity['judul_sub_bab'] ??
                                              (activity['subChapter'] is Map
                                                  ? activity['subChapter']['title']
                                                  : null);
                                          return '$bab${subBab != null ? ' • $subBab' : ''}';
                                        }(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: ColorUtils.slate600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ActivityInfoTag(
                                    icon: isAssignment
                                        ? Icons.assignment_outlined
                                        : Icons.menu_book_outlined,
                                    label: isAssignment
                                        ? AppLocalizations.assignment.tr
                                        : AppLocalizations.material.tr,
                                    tagColor: accentColor,
                                  ),
                                  ActivityInfoTag(
                                    icon: Icons.calendar_today_outlined,
                                    label:
                                        '${activity['hari'] ?? '-'} • ${formatDate(activity['tanggal'])}',
                                  ),
                                  ActivityInfoTag(
                                    icon: isSpecificTarget
                                        ? Icons.person_outlined
                                        : Icons.group_outlined,
                                    label: isSpecificTarget
                                        ? languageProvider.getTranslatedText({
                                            'en': 'Specific',
                                            'id': 'Khusus',
                                          })
                                        : languageProvider.getTranslatedText({
                                            'en': 'All Students',
                                            'id': 'Semua',
                                          }),
                                    tagColor: isSpecificTarget
                                        ? ColorUtils.info600
                                        : ColorUtils.success600,
                                  ),
                                  if (isAssignment &&
                                      activity['batas_waktu'] != null)
                                    ActivityInfoTag(
                                      icon: Icons.access_time_rounded,
                                      label:
                                          '${languageProvider.getTranslatedText({'en': 'Due', 'id': 'Batas'})}: ${formatDate(activity['batas_waktu'])}',
                                      tagColor: ColorUtils.error600,
                                    ),
                                  if (isSpecificTarget && isForThisStudent)
                                    ActivityInfoTag(
                                      icon: Icons.star_outline_rounded,
                                      label: languageProvider
                                          .getTranslatedText({
                                            'en': 'For this child',
                                            'id': 'Untuk anak ini',
                                          }),
                                      tagColor: ColorUtils.corporateBlue600,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildLoadingState() {
    return SkeletonListLoading(
      itemCount: 6,
      infoTagCount: 3,
      baseColor: getPrimaryColor().withValues(alpha: 0.15),
      highlightColor: getPrimaryColor().withValues(alpha: 0.05),
    );
  }

  String formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  Color getPrimaryColor();

  void showActivityDetail(Map<String, dynamic> activity);

  void onItemVisible(Map<String, dynamic> activity);
}
