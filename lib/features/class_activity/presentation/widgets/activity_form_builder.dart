import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_student_selector.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_material_selector.dart';

/// Helper class for building form sections
class ActivityFormBuilder {
  static Widget buildSectionLabel({
    required IconData icon,
    required String label,
    required Color color,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  static Widget buildDateCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? value,
    String? placeholder,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value ?? placeholder ?? '-',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: value != null
                          ? ColorUtils.slate800
                          : ColorUtils.slate400,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ColorUtils.slate400,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ColorUtils.slate300,
              ),
          ],
        ),
      ),
    );
  }

  static Widget buildTitleField({
    required TextEditingController controller,
    required Color accentColor,
    required bool isAssignment,
    required bool useMaterialTitle,
    required String? selectedChapterId,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: isAssignment ? 'Judul tugas...' : 'Judul materi...',
        hintStyle: TextStyle(
          color: ColorUtils.slate400,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        suffixIcon: useMaterialTitle && selectedChapterId != null
            ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: ColorUtils.slate400,
                ),
              )
            : null,
      ),
      readOnly: useMaterialTitle && selectedChapterId != null,
      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
    );
  }

  static Widget buildDescriptionField({
    required TextEditingController controller,
    required Color accentColor,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Tambahkan catatan atau instruksi...',
        hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
        filled: true,
        fillColor: ColorUtils.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        alignLabelWithHint: true,
      ),
      maxLines: 3,
      minLines: 2,
    );
  }

  static Widget buildMaterialSelectionSection({
    required Color accentColor,
    required bool useMaterialTitle,
    required List<dynamic> chapters,
    required bool isLoadingChapters,
    required String? selectedChapterId,
    required List<dynamic> subChapters,
    required List<String> selectedSubChapterIds,
    required String Function(dynamic) getChapterName,
    required String Function(dynamic) getSubChapterName,
    required Function(String) onChapterSelected,
    required Function(String, bool) onSubChapterToggled,
    required LanguageProvider languageProvider,
    required VoidCallback onViewAllPressed,
  }) {
    if (!useMaterialTitle) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        buildSectionLabel(
          icon: Icons.menu_book_rounded,
          label: 'Bab Materi',
          color: accentColor,
        ),
        const SizedBox(height: 8),
        ActivityChapterSelector(
          chapters: chapters,
          isLoading: isLoadingChapters,
          selectedChapterId: selectedChapterId,
          onChapterSelected: onChapterSelected,
          getChapterName: getChapterName,
        ),
        if (selectedChapterId != null && subChapters.isNotEmpty) ...[
          const SizedBox(height: 14),
          buildSectionLabel(
            icon: Icons.article_outlined,
            label: 'Sub Bab',
            color: accentColor,
            trailing: subChapters.length > 7
                ? GestureDetector(
                    onTap: onViewAllPressed,
                    child: Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          ActivitySubChapterSelector(
            subChapters: subChapters,
            selectedSubChapterIds: selectedSubChapterIds,
            onSubChapterToggled: onSubChapterToggled,
            getSubChapterName: getSubChapterName,
          ),
        ],
      ],
    );
  }

  static Widget buildStudentSelectorSection({
    required List<dynamic> studentList,
    required List<String> selectedStudents,
    required bool isLoading,
    required String initialTarget,
    required String? selectedClassId,
    required LanguageProvider languageProvider,
    required VoidCallback onRefresh,
    required Function(String, bool) onToggleStudent,
  }) {
    if (initialTarget != 'khusus' || selectedClassId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: ColorUtils.slate200, height: 1),
        ),
        AddActivityStudentSelector(
          studentList: studentList,
          selectedStudents: selectedStudents,
          isLoading: isLoading,
          initialTarget: initialTarget,
          onRefresh: onRefresh,
          onToggleStudent: onToggleStudent,
          languageProvider: languageProvider,
        ),
      ],
    );
  }

  static String formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String formatDateTime(DateTime d) {
    return '${formatDate(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
