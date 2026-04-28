// Header + search-bar slot for the parent announcements screen.
//
// Originally this rendered the bespoke `TeacherPageHeader` with the
// search input baked in. Phase 3 migrates the surface to the
// canonical `BrandPageHeader` (role 'wali'), with the search input
// hosted in the header's `bottomSlot` so the gradient hero is the
// single source of truth for "what screen am I on" + "search this".
//
// The mixin still owns the search controller wiring (so the screen
// stays a thin shell) but the visual treatment is now Phase-3
// brand-aligned and matches every other parent deep-tab screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_realtime_pill.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for the parent-announcements gradient header + search slot.
mixin HeaderSearchMixin on ConsumerState<ParentAnnouncementScreen> {
  TextEditingController get searchController;

  GlobalKey? get searchKey;

  Color getPrimaryColor();

  LinearGradient getCardGradient();

  Future<void> forceRefresh();

  Widget buildHeader(LanguageProvider languageProvider) {
    return BrandPageHeader(
      role: 'wali',
      subtitle: languageProvider.getTranslatedText({
        'en': 'Academic',
        'id': 'Akademik',
      }),
      title: languageProvider.getTranslatedText({
        'en': 'Announcements',
        'id': 'Pengumuman',
      }),
      realtimeIndicator: BrandRealtimePill(
        isFresh: true,
        lastSync: DateTime.now(),
      ),
      bottomSlot: _SearchField(
        controller: searchController,
        searchKey: searchKey,
        hintText: languageProvider.getTranslatedText({
          'en': 'Search announcements…',
          'id': 'Cari pengumuman…',
        }),
        onSubmitted: (_) => setState(() {}),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}

/// White rounded search field designed to sit inside a brand
/// gradient hero. Mirrors the mockup `Parent_Phase3_Pengumuman_Mockup`
/// search box styling.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey? searchKey;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const _SearchField({
    required this.controller,
    required this.hintText,
    this.searchKey,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: searchKey,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: ColorUtils.slate900,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: ColorUtils.slate400,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: ColorUtils.slate400,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
