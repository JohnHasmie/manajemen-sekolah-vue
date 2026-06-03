import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_row.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';

/// Mixin for parent Kegiatan Kelas activity-detail UI.
///
/// `showActivityDetail` was migrated from `showDialog(Dialog(...))` with a
/// hand-rolled gradient header to [AppBottomSheet.show] — the shared sheet
/// scaffold gives us the brand gradient header, drag handle, close X, and
/// safe-area handling for free. The Tutup footer button was dropped; the
/// header X is the dismissal affordance.
mixin ParentActivityUIBuilderMixin on ConsumerState<ParentClassActivityScreen> {
  void showActivityDetail(Map<String, dynamic> activity) {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = getPrimaryColor();
    final isAssignment = activity['jenis'] == 'tugas';

    final activityTitle =
        activity['title'] ??
        activity['judul'] ??
        AppLocalizations.activityTitle.tr;

    AppBottomSheet.show(
      context: context,
      title: activityTitle,
      subtitle: isAssignment
          ? languageProvider.getTranslatedText({
              'en': 'Assignment',
              'id': 'Tugas',
            })
          : languageProvider.getTranslatedText({
              'en': 'Material',
              'id': 'Materi',
            }),
      icon: isAssignment ? Icons.assignment_rounded : Icons.menu_book_rounded,
      primaryColor: primaryColor,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      content: _ActivityDetailContent(
        activity: activity,
        languageProvider: languageProvider,
        isAssignment: isAssignment,
        primaryColor: primaryColor,
        formatDate: formatDate,
      ),
    );
  }

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('wali');
  }

  /// Card gradient helper. Uses [ColorUtils.brandGradient] so any consumer
  /// that wires this in gets the brand-aligned two-stop azure rather than
  /// a single-color alpha fade.
  LinearGradient getCardGradient() {
    return ColorUtils.brandGradient('wali');
  }

  String formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  Widget buildActivityList();

  void onItemVisible(Map<String, dynamic> activity);
}

/// Sheet body for `showActivityDetail`. All the `ActivityDetailRow`
/// instances live here so the sheet builder closure stays terse and the
/// row composition reads top-to-bottom in one place.
class _ActivityDetailContent extends StatelessWidget {
  const _ActivityDetailContent({
    required this.activity,
    required this.languageProvider,
    required this.isAssignment,
    required this.primaryColor,
    required this.formatDate,
  });

  final Map<String, dynamic> activity;
  final LanguageProvider languageProvider;
  final bool isAssignment;
  final Color primaryColor;
  final String Function(String?) formatDate;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              (activity['teacher'] is Map
                  ? activity['teacher']['name']
                  : null) ??
              AppLocalizations.unknown.tr,
          primaryColor: primaryColor,
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
              (activity['subject'] is Map
                  ? activity['subject']['name']
                  : null) ??
              '-',
          primaryColor: primaryColor,
        ),
        ActivityDetailRow(
          icon: Icons.calendar_today_rounded,
          label: languageProvider.getTranslatedText({
            'en': 'Date',
            'id': 'Tanggal',
          }),
          value:
              '${activity['day'] ?? activity['hari'] ?? '-'} • '
              '${formatDate(activity['date'] ?? activity['tanggal'])}',
          primaryColor: primaryColor,
        ),
        if (isAssignment &&
            (activity['deadline'] ?? activity['batas_waktu']) != null)
          ActivityDetailRow(
            icon: Icons.access_time_rounded,
            label: AppLocalizations.deadline.tr,
            value: formatDate(activity['deadline'] ?? activity['batas_waktu']),
            primaryColor: primaryColor,
            iconColor: ColorUtils.error600,
          ),
        if (activity['deskripsi'] != null &&
            activity['deskripsi'].toString().isNotEmpty &&
            activity['deskripsi'] != 'null')
          ActivityDetailRow(
            icon: Icons.description_rounded,
            label: AppLocalizations.description.tr,
            value: activity['deskripsi'].toString(),
            primaryColor: primaryColor,
          ),
        if ((activity['judul_bab'] ??
                (activity['chapter'] is Map
                    ? activity['chapter']['title']
                    : null)) !=
            null)
          ActivityDetailRow(
            icon: Icons.auto_stories_rounded,
            label: languageProvider.getTranslatedText({
              'en': 'Chapter',
              'id': 'Materi',
            }),
            value: () {
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
              return '$bab${subBab != null ? '\n• $subBab' : ''}';
            }(),
            primaryColor: primaryColor,
          ),
        if (activity['additional_material'] != null &&
            activity['additional_material'] is List &&
            (activity['additional_material'] as List).isNotEmpty)
          ...(activity['additional_material'] as List).map<Widget>((item) {
            return ActivityDetailRow(
              icon: Icons.bookmark_add_rounded,
              label: AppLocalizations.additionalSubChapter.tr,
              value: item['sub_chapter_title'] ?? AppLocalizations.unknown.tr,
              primaryColor: primaryColor,
            );
          }),
      ],
    );
  }
}
