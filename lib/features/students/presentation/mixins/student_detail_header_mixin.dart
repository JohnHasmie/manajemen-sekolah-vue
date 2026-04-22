import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Builds the top header bar for student detail screen.
mixin StudentDetailHeaderMixin {
  /// Gets primary color for UI elements.
  Color getPrimaryColor();

  /// Builds gradient header with back, refresh, edit buttons.
  Widget buildHeader(
    BuildContext context,
    LanguageProvider languageProvider,
    String nameStr, {
    VoidCallback? onRefresh,
    VoidCallback? onEdit,
  }) {
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
          colors: [getPrimaryColor(), getPrimaryColor().withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildHeaderButton(
            onTap: () => AppNavigator.pop(context),
            icon: Icons.arrow_back_rounded,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Student Detail',
                    'id': 'Detail Siswa',
                  }),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nameStr.isNotEmpty
                      ? nameStr
                      : languageProvider.getTranslatedText({
                          'en': 'Complete student information',
                          'id': 'Informasi lengkap siswa',
                        }),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildHeaderButton(onTap: onRefresh, icon: Icons.refresh_rounded),
          if (onEdit != null) ...[
            const SizedBox(width: AppSpacing.sm),
            _buildHeaderButton(onTap: onEdit, icon: Icons.edit_rounded),
          ],
        ],
      ),
    );
  }

  /// Builds individual header button.
  Widget _buildHeaderButton({
    required VoidCallback? onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
