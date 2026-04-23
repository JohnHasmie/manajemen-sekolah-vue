import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
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

    showDialog(
      context: context,
      builder: (context) => _buildActivityDetailDialog(
        activity,
        isAssignment,
        isSpecificTarget,
        languageProvider,
      ),
    );
  }

  Widget _buildActivityDetailDialog(
    Map<String, dynamic> activity,
    bool isAssignment,
    bool isSpecificTarget,
    LanguageProvider languageProvider,
  ) {
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailHeader(activity, isAssignment),
            _buildActivityDetailContent(
              activity,
              isAssignment,
              isSpecificTarget,
              languageProvider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityDetailContent(
    Map<String, dynamic> activity,
    bool isAssignment,
    bool isSpecificTarget,
    LanguageProvider languageProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicDetails(activity, isAssignment, isSpecificTarget),
          if (activity['deskripsi'] != null &&
              activity['deskripsi'].isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildDescriptionSection(activity),
          ],
          if (activity['judul_bab'] != null ||
              (activity['chapter'] is Map ? activity['chapter']['title'] : null) != null ||
              activity['judul_sub_bab'] != null ||
              (activity['subChapter'] is Map ? activity['subChapter']['title'] : null) != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildChapterSection(activity),
          ],
          const SizedBox(height: AppSpacing.xl),
          _buildCloseButton(languageProvider),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(Map<String, dynamic> activity, bool isAssignment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: getCardGradient(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderIcon(isAssignment),
          const SizedBox(width: 14),
          _buildHeaderText(activity),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(bool isAssignment) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Icon(
        isAssignment ? Icons.assignment : Icons.menu_book,
        size: 22,
        color: Colors.white,
      ),
    );
  }

  Widget _buildHeaderText(Map<String, dynamic> activity) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity['judul'] ?? 'Judul Kegiatan',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            '${activity['mata_pelajaran_nama'] ?? (activity['subject'] is Map ? activity['subject']['name'] : '') ?? ''} • '
            '${activity['kelas_nama'] ?? (activity['class'] is Map ? activity['class']['name'] : '') ?? ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicDetails(
    Map<String, dynamic> activity,
    bool isAssignment,
    bool isSpecificTarget,
  ) {
    return Column(
      children: [
        _buildTeacherDetailItem(activity),
        _buildDayDetailItem(activity),
        _buildDateDetailItem(activity),
        if (isAssignment) _buildDeadlineDetailItem(activity),
        _buildActivityTypeItem(isAssignment),
        _buildStudentTargetItem(isSpecificTarget),
      ],
    );
  }

  Widget _buildTeacherDetailItem(Map<String, dynamic> activity) {
    return AdminActivityDetailItem(
      icon: Icons.person,
      label: 'Guru Pengajar',
      value: activity['guru_nama'] ?? (activity['teacher'] is Map ? activity['teacher']['name'] : null) ?? 'Tidak Diketahui',
      primaryColor: getPrimaryColor(),
    );
  }

  Widget _buildDayDetailItem(Map<String, dynamic> activity) {
    return AdminActivityDetailItem(
      icon: Icons.calendar_today,
      label: 'Hari',
      value: activity['hari'] ?? '-',
      primaryColor: getPrimaryColor(),
    );
  }

  Widget _buildDateDetailItem(Map<String, dynamic> activity) {
    return AdminActivityDetailItem(
      icon: Icons.date_range,
      label: 'Tanggal',
      value: formatDate(activity['tanggal']),
      primaryColor: getPrimaryColor(),
    );
  }

  Widget _buildDeadlineDetailItem(Map<String, dynamic> activity) {
    return AdminActivityDetailItem(
      icon: Icons.access_time,
      label: 'Batas Waktu',
      value: formatDate(activity['batas_waktu']),
      primaryColor: getPrimaryColor(),
    );
  }

  Widget _buildActivityTypeItem(bool isAssignment) {
    return AdminActivityDetailItem(
      icon: Icons.category,
      label: 'Jenis Kegiatan',
      value: isAssignment ? 'Tugas' : 'Materi',
      primaryColor: getPrimaryColor(),
    );
  }

  Widget _buildStudentTargetItem(bool isSpecificTarget) {
    return AdminActivityDetailItem(
      icon: Icons.group,
      label: 'Target Siswa',
      value: isSpecificTarget ? 'Khusus Siswa' : 'Semua Siswa',
      primaryColor: getPrimaryColor(),
    );
  }

  Widget _buildDescriptionSection(Map<String, dynamic> activity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Text(
            activity['deskripsi'],
            style: TextStyle(
              fontSize: 14,
              color: ColorUtils.slate700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChapterSection(Map<String, dynamic> activity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Informasi Bab'),
        const SizedBox(height: AppSpacing.sm),
        if (activity['judul_bab'] != null ||
            (activity['chapter'] is Map ? activity['chapter']['title'] : null) != null)
          _buildMainChapterItem(activity),
        if (activity['judul_sub_bab'] != null ||
            (activity['subChapter'] is Map ? activity['subChapter']['title'] : null) != null)
          _buildSubChapterItem(activity),
        if (_hasAdditionalMaterial(activity))
          _buildAdditionalMaterialItems(activity),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ColorUtils.slate700,
      ),
    );
  }

  Widget _buildMainChapterItem(Map<String, dynamic> activity) {
    final chapterTitle = activity['judul_bab']
        ?? (activity['chapter'] is Map ? activity['chapter']['title'] : null)
        ?? '-';
    return AdminActivityDetailItem(
      icon: Icons.menu_book,
      label: 'Bab',
      value: chapterTitle,
      primaryColor: getPrimaryColor(),
    );
  }

  Widget _buildSubChapterItem(Map<String, dynamic> activity) {
    final subChapterTitle = activity['judul_sub_bab']
        ?? (activity['subChapter'] is Map ? activity['subChapter']['title'] : null)
        ?? '-';
    return AdminActivityDetailItem(
      icon: Icons.bookmark,
      label: 'Sub Bab (Utama)',
      value: subChapterTitle,
      primaryColor: getPrimaryColor(),
    );
  }

  bool _hasAdditionalMaterial(Map<String, dynamic> activity) {
    return activity['additional_material'] != null &&
        activity['additional_material'] is List &&
        (activity['additional_material'] as List).isNotEmpty;
  }

  Widget _buildAdditionalMaterialItems(Map<String, dynamic> activity) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xs),
        ...(activity['additional_material'] as List).map<Widget>((item) {
          return AdminActivityDetailItem(
            icon: Icons.bookmark_add,
            label: 'Sub Bab (Tambahan)',
            value: item['sub_chapter_title'] ?? 'Unknown',
            primaryColor: getPrimaryColor(),
          );
        }),
      ],
    );
  }

  Widget _buildCloseButton(LanguageProvider languageProvider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => AppNavigator.pop(context),
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
    );
  }
}
