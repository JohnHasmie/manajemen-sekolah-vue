import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Mixin for AppBar and header builders in SettingsScreen.
mixin SettingsScreenAppBarMixin {
  // Abstract properties
  Color get primaryColor;
  WidgetRef get ref;
  Future<void> forceRefresh();

  /// Builds SliverAppBar with gradient and profile.
  SliverAppBar buildSliverAppBar(
    String name,
    String email,
    String role,
    String avatarLetter,
    VoidCallback onEdit,
  ) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
      title: _buildAppBarTitle(),
      actions: _buildAppBarActions(onEdit),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildAppBarBackground(name, email, role, avatarLetter),
      ),
    );
  }

  /// Builds the title for app bar.
  Widget _buildAppBarTitle() {
    return Text(
      ref.watch(languageRiverpod).getTranslatedText({
        'en': 'User Profile',
        'id': 'Profil Pengguna',
      }),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
    );
  }

  /// Builds the actions for app bar.
  List<Widget> _buildAppBarActions(VoidCallback onEdit) {
    return [
      IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
        ),
        onPressed: onEdit,
        tooltip: 'Edit Profil',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (value) {
          if (value == 'refresh') {
            forceRefresh();
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                const SizedBox(width: AppSpacing.sm),
                const Text('Perbarui Data'),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(width: AppSpacing.sm),
    ];
  }

  /// Builds the background for app bar.
  Widget _buildAppBarBackground(
    String name,
    String email,
    String role,
    String avatarLetter,
  ) {
    return Container(
      // HH.12 — replaced the legacy single-color alpha-fade gradient
      // with the proper brand two-stop gradient via
      // [ColorUtils.brandGradient]. The visual result is now
      // role-aware (admin navy / teacher cobalt / parent azure) and
      // matches every other migrated hero in the app.
      decoration: BoxDecoration(gradient: ColorUtils.brandGradient(role)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
          child: Row(
            children: [
              _buildAvatarContainer(avatarLetter),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _buildProfileHeader(name, email, role)),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds avatar container with initials.
  Widget _buildAvatarContainer(String avatarLetter) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          avatarLetter,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Builds profile header text and role badge.
  Widget _buildProfileHeader(String name, String email, String role) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isNotEmpty ? name : 'Pengguna',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          email,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildRoleBadge(role),
      ],
    );
  }

  /// Builds role badge widget.
  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        role,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
