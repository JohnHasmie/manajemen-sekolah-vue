import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_type_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/date_formatting_mixin.dart';

/// Mixin for showing notification detail dialog.
mixin NotificationDetailDialogMixin
    on NotificationTypeMixin, DateFormattingMixin {
  BuildContext get context;

  void showDetailDialog(Map<String, dynamic> notif) {
    final color = getColor(notif['type'] ?? 'general');
    final icon = getIcon(notif['type'] ?? 'general');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader(color, icon, notif),
            _buildDialogBody(notif),
            _buildDialogFooter(color, ctx),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(
    Color color,
    IconData icon,
    Map<String, dynamic> notif,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.8)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif['title'] ?? 'Informasi',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDate(notif['created_at']),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogBody(Map<String, dynamic> notif) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        notif['body'] ?? '',
        style: TextStyle(fontSize: 14, color: ColorUtils.slate700, height: 1.6),
      ),
    );
  }

  Widget _buildDialogFooter(Color color, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => AppNavigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              elevation: 0,
            ),
            child: Text(
              AppLocalizations.close.tr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
