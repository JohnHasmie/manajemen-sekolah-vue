import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Gradient header for the admin finance hub.
///
/// Mirrors the shared [TeacherPageHeader]/[AdminCrudScaffold] aesthetic used
/// by the other admin screens (Mapel, Kelas, Jadwal): rounded back chevron,
/// 20px bold title, muted subtitle, trailing action pill. The visual language
/// is deliberately identical so swiping between admin screens doesn't jar.
class FinanceHeader extends StatelessWidget {
  const FinanceHeader({
    required this.languageProvider,
    required this.primaryColor,
    required this.onRefresh,
    super.key,
  });

  final dynamic languageProvider;
  final Color primaryColor;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.82)],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIconChip(
            icon: Icons.arrow_back,
            onTap: () => AppNavigator.pop(context),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Financial Management',
                    'id': 'Manajemen Keuangan',
                  }),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Manage payments & bills',
                    'id': 'Kelola pembayaran & tagihan',
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildActionMenu(),
        ],
      ),
    );
  }

  Widget _buildIconChip({required IconData icon, required VoidCallback onTap}) {
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

  Widget _buildActionMenu() {
    return PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      onSelected: (value) {
        if (value == 'refresh') onRefresh();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 20, color: ColorUtils.info600),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Refresh data',
                  'id': 'Update Data',
                }),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
