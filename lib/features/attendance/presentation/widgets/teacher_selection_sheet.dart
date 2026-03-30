// Extracted teacher-selection bottom sheet for admin attendance report.
//
// Like a Vue modal component that receives a teacher list as a prop and
// emits an onTeacherSelected event when the user picks a teacher.
// Owns no async logic -- the parent passes in the already-loaded list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A modal bottom sheet that lets an admin pick a teacher from [teacherList].
///
/// Like a Vue `<TeacherPickerModal>` component:
/// - [teacherList]   – props: the already-loaded teacher data (`List<dynamic>`)
/// - [primaryColor]  – props: brand colour passed down from the parent
/// - [onSelected]    – emit: fires with the chosen teacher map so the parent
///                     can navigate to AttendancePage
///
/// Call [TeacherSelectionSheet.show] from the parent instead of constructing
/// the widget directly -- it wraps [showModalBottomSheet] for you.
class TeacherSelectionSheet extends ConsumerWidget {
  const TeacherSelectionSheet({
    super.key,
    required this.teacherList,
    required this.primaryColor,
    required this.onSelected,
  });

  final List<dynamic> teacherList;
  final Color primaryColor;

  /// Called with the selected teacher map when the user taps a row.
  /// The parent is responsible for navigating away after this fires.
  final void Function(Map<String, dynamic> teacher) onSelected;

  /// Convenience factory: shows this sheet as a modal bottom sheet.
  ///
  /// Like calling `this.$emit('show-modal')` in Vue – the caller doesn't need
  /// to know the internal sheet geometry details.
  static void show({
    required BuildContext context,
    required List<dynamic> teacherList,
    required Color primaryColor,
    required void Function(Map<String, dynamic> teacher) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TeacherSelectionSheet(
        teacherList: teacherList,
        primaryColor: primaryColor,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read translations once -- like accessing `this.$t(...)` in Vue.
    final languageProvider = ref.read(languageRiverpod);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Header bar ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Teacher',
                    'id': 'Pilih Guru',
                  }),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => AppNavigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Teacher list ─────────────────────────────────────────────────
          // Like a v-for loop rendering one <TeacherCard> per teacher.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: teacherList.length,
              itemBuilder: (context, index) {
                final teacher =
                    teacherList[index] as Map<String, dynamic>? ?? {};
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        (teacher['name'] as String? ?? 'G')[0].toUpperCase(),
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                    title: Text(
                      teacher['name'] as String? ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(teacher['nuptk'] as String? ?? 'N/A'),
                    onTap: () {
                      // Close the sheet first, then let the parent navigate.
                      // Like Vue's $emit('selected', teacher) before $emit('close').
                      AppNavigator.pop(context);
                      onSelected(teacher);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
