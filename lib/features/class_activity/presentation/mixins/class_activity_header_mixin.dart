import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';

/// Mixin providing header building methods for admin class activity screen.
mixin ClassActivityHeaderMixin on ConsumerState<AdminClassActivityScreen> {
  Widget buildHeader(LanguageProvider lp) => Container(
    width: double.infinity,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      bottom: 16,
    ),
    decoration: BoxDecoration(
      gradient: getCardGradient(),
      boxShadow: [
        BoxShadow(
          color: getPrimaryColor().withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildHeaderTop(lp),
        const SizedBox(height: AppSpacing.lg),
        buildSearchBar(lp),
      ],
    ),
  );

  Widget buildHeaderTop(LanguageProvider lp) => Row(
    children: [
      _buildBackButton(),
      const SizedBox(width: AppSpacing.md),
      _buildHeaderTitles(lp),
      buildMenuButton(),
    ],
  );

  Widget _buildBackButton() => GestureDetector(
    onTap: showTeacherList
        ? () => AppNavigator.pop(context)
        : (showSubjectList ? backToTeacherList : backToSubjectList),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
    ),
  );

  Widget _buildHeaderTitles(LanguageProvider lp) => Expanded(
    child: Column(
      key: infoKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          getTitleText(lp),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          getSubtitleText(lp),
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    ),
  );

  String getTitleText(LanguageProvider lp) => lp.getTranslatedText(
    showTeacherList
        ? {'en': 'Class Activities', 'id': 'Kegiatan Kelas'}
        : showSubjectList
        ? {
            'en': 'Subjects - $selectedTeacherName',
            'id': 'Mata Pelajaran - $selectedTeacherName',
          }
        : {
            'en': 'Activities - $selectedSubjectName',
            'id': 'Kegiatan - $selectedSubjectName',
          },
  );

  String getSubtitleText(LanguageProvider lp) => lp.getTranslatedText(
    showTeacherList
        ? {
            'en': 'View all teacher activities',
            'id': 'Lihat semua kegiatan guru',
          }
        : showSubjectList
        ? {
            'en': 'Select subject to view activities',
            'id': 'Pilih mata pelajaran untuk melihat kegiatan',
          }
        : {
            'en': 'Viewing activities for $selectedSubjectName',
            'id': 'Melihat kegiatan untuk $selectedSubjectName',
          },
  );

  Widget buildMenuButton() => PopupMenuButton<String>(
    onSelected: (v) => v == 'refresh' ? forceRefresh() : null,
    icon: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
    ),
    itemBuilder: (_) => [
      PopupMenuItem<String>(
        value: 'refresh',
        child: Row(
          children: [
            Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
            const SizedBox(width: AppSpacing.sm),
            Text(AppLocalizations.updateData.tr),
          ],
        ),
      ),
    ],
  );

  Widget buildSearchBar(LanguageProvider lp) => Container(
    key: searchKey,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            style: TextStyle(color: ColorUtils.slate800),
            decoration: InputDecoration(
              hintText: getSearchHint(lp),
              hintStyle: TextStyle(color: ColorUtils.slate400),
              prefixIcon: Icon(Icons.search, color: ColorUtils.slate400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onSubmitted: (_) => setState(() {}),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 4),
          child: IconButton(
            icon: Icon(Icons.search, color: getPrimaryColor()),
            onPressed: () => setState(() {}),
          ),
        ),
      ],
    ),
  );

  String getSearchHint(LanguageProvider lp) => lp.getTranslatedText(
    showTeacherList
        ? {'en': 'Search teachers...', 'id': 'Cari guru...'}
        : showSubjectList
        ? {'en': 'Search subjects...', 'id': 'Cari mata pelajaran...'}
        : {'en': 'Search activities...', 'id': 'Cari kegiatan...'},
  );

  // Abstract getters/setters from state
  bool get showTeacherList;
  bool get showSubjectList;
  String? get selectedTeacherName;
  String? get selectedSubjectName;
  GlobalKey get infoKey;
  GlobalKey get searchKey;
  TextEditingController get searchController;
  Color getPrimaryColor();
  LinearGradient getCardGradient();
  void backToTeacherList();
  void backToSubjectList();
  Future<void> forceRefresh();
}
