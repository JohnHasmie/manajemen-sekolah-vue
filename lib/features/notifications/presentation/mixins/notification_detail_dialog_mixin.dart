import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_type_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/date_formatting_mixin.dart';

/// Mixin for showing notification detail dialog.
mixin NotificationDetailDialogMixin
    on NotificationTypeMixin, DateFormattingMixin {
  BuildContext get context;

  /// Shows notification detail in a brand [AppBottomSheet] (gradient header
  /// coloured by notification type + scrollable body + Samsung-safe footer).
  void showDetailDialog(Map<String, dynamic> notif) {
    final color = getColor(notif['type'] ?? 'general');
    final icon = getIcon(notif['type'] ?? 'general');

    AppBottomSheet.show<void>(
      context: context,
      title: notif['title'] ?? 'Informasi',
      subtitle: formatDate(notif['created_at']),
      icon: icon,
      primaryColor: color,
      content: Text(
        notif['body'] ?? '',
        style: TextStyle(fontSize: 14, color: ColorUtils.slate700, height: 1.6),
      ),
      footer: BottomSheetFooter(
        primaryLabel: AppLocalizations.close.tr,
        secondaryLabel: 'Batal',
        primaryColor: color,
        onPrimary: () => AppNavigator.pop(context),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}
