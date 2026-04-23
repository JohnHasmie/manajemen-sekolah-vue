import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/school_level_settings_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/time_settings_screen.dart';

// ignore: implementation_depends_on_exported_member
class _MenuItem {
  final GlobalKey key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// Mixin for UI building and rendering.
/// Handles main layout, header, menu items, and cards.
mixin UIMixin {
  /// Abstract state and context access required from implementing class
  void setState(VoidCallback fn);
  BuildContext get context;
  WidgetRef get ref;

  /// Abstract field access required from implementing class
  GlobalKey get generalSettingsKey;
  GlobalKey get timeSettingsKey;

  /// Build the main scaffold with header and menu.
  Widget buildMainScaffold() {
    final lang = ref.watch(languageRiverpod);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildGradientHeader(lang),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _buildBodyContent(lang),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the gradient header with back button and title.
  Widget _buildGradientHeader(LanguageProvider lang) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _buildHeaderTitle(lang)),
        ],
      ),
    );
  }

  /// Build the back button.
  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => AppNavigator.pop(context),
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
  }

  /// Build the header title section.
  Widget _buildHeaderTitle(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.getTranslatedText(AppLocalizations.schoolSettings),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Kelola pengaturan sekolah',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  /// Build the body content with menu cards.
  Widget _buildBodyContent(LanguageProvider lang) {
    final menuItems = _buildMenuItems(lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(lang),
        const SizedBox(height: 16),
        _buildMenuGrid(menuItems),
      ],
    );
  }

  /// Build the section header with icon and title.
  Widget _buildSectionHeader(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: ColorUtils.corporateBlue600,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            lang.getTranslatedText(AppLocalizations.settingsMenu),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the grid of menu items.
  Widget _buildMenuGrid(List<_MenuItem> menuItems) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) => _buildMenuCard(menuItems[index]),
    );
  }

  /// Build a single menu card.
  Widget _buildMenuCard(_MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: item.key,
        onTap: item.onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardIconRow(item),
              const Spacer(),
              _buildCardTitle(item),
              const SizedBox(height: 3),
              _buildCardSubtitle(item),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the icon row for a menu card.
  Widget _buildCardIconRow(_MenuItem item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: item.color.withValues(alpha: 0.2)),
          ),
          child: Icon(item.icon, color: item.color, size: 24),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: ColorUtils.slate100,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            color: ColorUtils.slate500,
            size: 18,
          ),
        ),
      ],
    );
  }

  /// Build the title text for a menu card.
  Widget _buildCardTitle(_MenuItem item) {
    return Text(
      item.title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ColorUtils.slate900,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build the subtitle text for a menu card.
  Widget _buildCardSubtitle(_MenuItem item) {
    return Text(
      item.subtitle,
      style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build the list of menu items with navigation.
  List<_MenuItem> _buildMenuItems(LanguageProvider lang) {
    return [
      _MenuItem(
        key: generalSettingsKey,
        title: AppLocalizations.generalSettings.tr,
        subtitle: 'Jenjang & informasi sekolah',
        icon: Icons.school_rounded,
        color: ColorUtils.getColorForIndex(0),
        onTap: () =>
            AppNavigator.push(context, const SchoolLevelSettingsScreen()),
      ),
      _MenuItem(
        key: timeSettingsKey,
        title: AppLocalizations.timeSettings.tr,
        subtitle: 'Jadwal & waktu pembelajaran',
        icon: Icons.access_time_rounded,
        color: ColorUtils.getColorForIndex(2),
        onTap: () => AppNavigator.push(context, const TimeSettingsScreen()),
      ),
    ];
  }
}
