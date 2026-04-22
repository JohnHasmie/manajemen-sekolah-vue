import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_row.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';

mixin ParentActivityUIBuilderMixin on ConsumerState<ParentClassActivityScreen> {
  void showActivityDetail(Map<String, dynamic> activity) {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = getPrimaryColor();
    final isAssignment = activity['jenis'] == 'tugas';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.75)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Icon(
                      isAssignment
                          ? Icons.assignment_rounded
                          : Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAssignment
                              ? languageProvider.getTranslatedText({
                                  'en': 'Assignment',
                                  'id': 'Tugas',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'Material',
                                  'id': 'Materi',
                                }),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          activity['title'] ??
                              activity['judul'] ??
                              AppLocalizations.activityTitle.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ActivityDetailRow(
                      icon: Icons.person_rounded,
                      label: languageProvider.getTranslatedText({
                        'en': 'Teacher',
                        'id': 'Guru Pengajar',
                      }),
                      value:
                          activity['teacher_name'] ??
                          activity['guru_nama'] ??
                          (activity['teacher'] is Map ? activity['teacher']['name'] : null) ??
                          AppLocalizations.unknown.tr,
                      primaryColor: getPrimaryColor(),
                    ),
                    ActivityDetailRow(
                      icon: Icons.menu_book_rounded,
                      label: languageProvider.getTranslatedText({
                        'en': 'Subject',
                        'id': 'Mata Pelajaran',
                      }),
                      value:
                          activity['subject_name'] ??
                          activity['mata_pelajaran_nama'] ??
                          (activity['subject'] is Map ? activity['subject']['name'] : null) ??
                          '-',
                      primaryColor: getPrimaryColor(),
                    ),
                    ActivityDetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: languageProvider.getTranslatedText({
                        'en': 'Date',
                        'id': 'Tanggal',
                      }),
                      value:
                          '${activity['day'] ?? activity['hari'] ?? '-'} • ${formatDate(activity['date'] ?? activity['tanggal'])}',
                      primaryColor: getPrimaryColor(),
                    ),
                    if (isAssignment &&
                        (activity['deadline'] ?? activity['batas_waktu']) !=
                            null)
                      ActivityDetailRow(
                        icon: Icons.access_time_rounded,
                        label: AppLocalizations.deadline.tr,
                        value: formatDate(
                          activity['deadline'] ?? activity['batas_waktu'],
                        ),
                        primaryColor: getPrimaryColor(),
                        iconColor: ColorUtils.error600,
                      ),
                    if (activity['deskripsi'] != null &&
                        activity['deskripsi'].toString().isNotEmpty &&
                        activity['deskripsi'] != 'null')
                      ActivityDetailRow(
                        icon: Icons.description_rounded,
                        label: AppLocalizations.description.tr,
                        value: activity['deskripsi'].toString(),
                        primaryColor: getPrimaryColor(),
                      ),
                    if ((activity['judul_bab'] ?? (activity['chapter'] is Map ? activity['chapter']['title'] : null)) != null)
                      ActivityDetailRow(
                        icon: Icons.auto_stories_rounded,
                        label: languageProvider.getTranslatedText({
                          'en': 'Chapter',
                          'id': 'Materi',
                        }),
                        value: () {
                          final bab = activity['judul_bab'] ?? (activity['chapter'] is Map ? activity['chapter']['title'] : null) ?? '';
                          final subBab = activity['judul_sub_bab'] ?? (activity['subChapter'] is Map ? activity['subChapter']['title'] : null);
                          return '$bab${subBab != null ? '\n• $subBab' : ''}';
                        }(),
                        primaryColor: getPrimaryColor(),
                      ),
                    if (activity['additional_material'] != null &&
                        activity['additional_material'] is List &&
                        (activity['additional_material'] as List).isNotEmpty)
                      ...(activity['additional_material'] as List).map<Widget>((
                        item,
                      ) {
                        return ActivityDetailRow(
                          icon: Icons.bookmark_add_rounded,
                          label: AppLocalizations.additionalSubChapter.tr,
                          value:
                              item['sub_chapter_title'] ??
                              AppLocalizations.unknown.tr,
                          primaryColor: getPrimaryColor(),
                        );
                      }),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: ColorUtils.slate100)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => AppNavigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: ColorUtils.slate300),
                    foregroundColor: ColorUtils.slate700,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.close.tr,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('wali');
  }

  LinearGradient getCardGradient() {
    final primaryColor = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  String formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  Widget buildActivityList();

  void onItemVisible(Map<String, dynamic> activity);
}
