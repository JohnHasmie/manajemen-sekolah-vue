import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_activity_detail_item.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';

/// Mixin providing UI helper methods and styling.
mixin ClassActivityUiMixin on ConsumerState<AdminClassActivityScreen> {
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
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

  void showActivityDetail(Map<String, dynamic> activity) {
    final languageProvider = ref.read(languageRiverpod);
    final isAssignment = activity['jenis'] == 'tugas';
    final isSpecificTarget = activity['target'] == 'khusus';
    final primaryColor = getPrimaryColor();

    final activityTitle = activity['judul'] ?? 'Judul Kegiatan';

    AppBottomSheet.show(
      context: context,
      title: activityTitle,
      subtitle: isAssignment ? 'Tugas' : 'Materi',
      icon: isAssignment ? Icons.assignment_rounded : Icons.menu_book_rounded,
      primaryColor: primaryColor,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      content: _AdminActivityDetailContent(
        activity: activity,
        isAssignment: isAssignment,
        isSpecificTarget: isSpecificTarget,
        primaryColor: primaryColor,
        languageProvider: languageProvider,
        formatDate: formatDate,
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: ColorUtils.slate300),
                ),
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Close',
                    'id': 'Tutup',
                  }),
                  style: TextStyle(
                    color: ColorUtils.slate700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminActivityDetailContent extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isAssignment;
  final bool isSpecificTarget;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final String Function(String?) formatDate;

  const _AdminActivityDetailContent({
    required this.activity,
    required this.isAssignment,
    required this.isSpecificTarget,
    required this.primaryColor,
    required this.languageProvider,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final description = (activity['deskripsi'] ?? activity['description'])?.toString();
    final hasDescription = description != null && description.trim().isNotEmpty;

    final chapterTitle = activity['judul_bab'] ??
        (activity['chapter'] is Map ? activity['chapter']['title'] : null);
    final subChapterTitle = activity['judul_sub_bab'] ??
        (activity['subChapter'] is Map ? activity['subChapter']['title'] : null);

    final hasChapter = chapterTitle != null || subChapterTitle != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminActivityDetailItem(
          icon: Icons.person_rounded,
          label: 'Guru Pengajar',
          value: activity['guru_nama'] ??
              (activity['teacher'] is Map ? activity['teacher']['name'] : null) ??
              'Tidak Diketahui',
          primaryColor: primaryColor,
        ),
        AdminActivityDetailItem(
          icon: Icons.calendar_today_rounded,
          label: 'Hari',
          value: activity['hari'] ?? '-',
          primaryColor: primaryColor,
        ),
        AdminActivityDetailItem(
          icon: Icons.date_range_rounded,
          label: 'Tanggal',
          value: formatDate(activity['tanggal']),
          primaryColor: primaryColor,
        ),
        if (isAssignment)
          AdminActivityDetailItem(
            icon: Icons.access_time_rounded,
            label: 'Batas Waktu',
            value: formatDate(activity['batas_waktu']),
            primaryColor: primaryColor,
          ),
        AdminActivityDetailItem(
          icon: Icons.category_rounded,
          label: 'Jenis Kegiatan',
          value: isAssignment ? 'Tugas' : 'Materi',
          primaryColor: primaryColor,
        ),
        AdminActivityDetailItem(
          icon: Icons.group_rounded,
          label: 'Target Siswa',
          value: isSpecificTarget ? 'Khusus Siswa' : 'Semua Siswa',
          primaryColor: primaryColor,
        ),
        if (hasDescription) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Deskripsi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: ColorUtils.slate700,
                height: 1.5,
              ),
            ),
          ),
        ],
        if (hasChapter) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Informasi Bab',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (chapterTitle != null)
            AdminActivityDetailItem(
              icon: Icons.menu_book_rounded,
              label: 'Bab',
              value: chapterTitle.toString(),
              primaryColor: primaryColor,
            ),
          if (subChapterTitle != null)
            AdminActivityDetailItem(
              icon: Icons.bookmark_rounded,
              label: 'Sub Bab (Utama)',
              value: subChapterTitle.toString(),
              primaryColor: primaryColor,
            ),
          if (activity['additional_material'] != null &&
              activity['additional_material'] is List &&
              (activity['additional_material'] as List).isNotEmpty)
            ...(activity['additional_material'] as List).map<Widget>((item) {
              return AdminActivityDetailItem(
                icon: Icons.bookmark_add_rounded,
                label: 'Sub Bab (Tambahan)',
                value: item['sub_chapter_title'] ?? 'Unknown',
                primaryColor: primaryColor,
              );
            }),
        ],
      ],
    );
  }
}
