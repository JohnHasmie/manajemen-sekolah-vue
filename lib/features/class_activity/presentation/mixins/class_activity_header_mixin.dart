import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';

/// Mixin providing header building methods for admin class activity screen.
mixin ClassActivityHeaderMixin on ConsumerState<AdminClassActivityScreen> {
  /// Builds the gradient hero — now goes through the shared
  /// `BrandPageHeader` so the admin role gets the same compact
  /// centered-title + bottomSlot search idiom as every other tab.
  /// The drill-down back button still walks the in-screen state
  /// (teachers → subjects → activities) before falling through to
  /// `AppNavigator.pop`.
  Widget buildHeader(LanguageProvider lp) {
    return BrandPageHeader(
      key: infoKey,
      role: 'admin',
      subtitle: _getKickerText(lp),
      title: getTitleText(lp),
      onBackPressed: _handleBack,
      showBackButton: true,
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.refresh_rounded,
          onTap: forceRefresh,
        ),
      ],
      bottomSlot: _buildSearchField(lp),
    );
  }

  /// Walks the drill-down state. From teachers list, pops the screen.
  /// From subjects list, returns to teachers. From activities, returns
  /// to subjects.
  void _handleBack() {
    if (showTeacherList) {
      AppNavigator.pop(context);
    } else if (showSubjectList) {
      backToTeacherList();
    } else {
      backToSubjectList();
    }
  }

  /// Compact white search field that lives in
  /// `BrandPageHeader.bottomSlot`. Mirrors the v3 search-bar pattern
  /// `admin_grade_overview_screen` uses.
  Widget _buildSearchField(LanguageProvider lp) {
    return Container(
      key: searchKey,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: ColorUtils.slate400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              style: TextStyle(
                color: ColorUtils.slate800,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: getSearchHint(lp),
                hintStyle: TextStyle(
                  color: ColorUtils.slate400,
                  fontSize: 12.5,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  /// Kicker shown ABOVE the centered title in the BrandPageHeader.
  /// Switches between the role kicker and the drill-down breadcrumb
  /// so the admin always knows which level of the hierarchy they're
  /// viewing.
  String _getKickerText(LanguageProvider lp) {
    if (showTeacherList) {
      return lp.getTranslatedText({
        'en': 'ACADEMIC · ACTIVITIES',
        'id': 'AKADEMIK · KEGIATAN',
      });
    }
    if (showSubjectList) {
      return (selectedTeacherName ?? '').toUpperCase();
    }
    return (selectedSubjectName ?? '').toUpperCase();
  }

  String getTitleText(LanguageProvider lp) => lp.getTranslatedText(
    showTeacherList
        ? {'en': 'Class Activities', 'id': 'Kegiatan Kelas'}
        : showSubjectList
        ? {'en': 'Subjects', 'id': 'Mata Pelajaran'}
        : {'en': 'Activities', 'id': 'Kegiatan'},
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
