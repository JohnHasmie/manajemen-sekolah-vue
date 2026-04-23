import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin for header UI building.
mixin HeaderMixin {
  Map<String, dynamic> get classData;
  Map<String, String> get teacher;
  BuildContext get context;

  Future<void> forceRefresh();

  Widget buildHeader() {
    final primaryColor = getPrimaryColor();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      decoration: _buildHeaderDecoration(primaryColor),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: AppSpacing.lg),
          _buildTitleColumn(),
          _buildMenuButton(),
        ],
      ),
    );
  }

  BoxDecoration _buildHeaderDecoration(Color primaryColor) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
      ),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

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

  Widget _buildTitleColumn() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            classData['name'] ?? classData['nama'] ?? 'Daftar Siswa',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pilih siswa untuk melihat rekomendasi belajar',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) {
        if (value == 'refresh') forceRefresh();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
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
  }

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor(teacher['role'] ?? 'guru');
  }
}
