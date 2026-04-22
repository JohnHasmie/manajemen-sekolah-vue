import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for header and search bar UI.
mixin HeaderSearchMixin on ConsumerState<ParentAnnouncementScreen> {
  TextEditingController get searchController;

  GlobalKey? get searchKey;

  Color getPrimaryColor();

  LinearGradient getCardGradient();

  Future<void> forceRefresh();

  Widget buildHeader(LanguageProvider languageProvider) {
    return TeacherPageHeader(
      title: languageProvider.getTranslatedText({
        'en': 'Announcements',
        'id': 'Pengumuman',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'View school announcements',
        'id': 'Lihat pengumuman sekolah',
      }),
      primaryColor: getPrimaryColor(),
      showSearchFilter: true,
      searchController: searchController,
      onSearchSubmitted: (_) => setState(() {}),
      searchHintText: languageProvider.getTranslatedText({
        'en': 'Search announcements...',
        'id': 'Cari pengumuman...',
      }),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'refresh') {
            forceRefresh();
          }
        },
        icon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
        ),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Update Data',
                    'id': 'Perbarui Data',
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
