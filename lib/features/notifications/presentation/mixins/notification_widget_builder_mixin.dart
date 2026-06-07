import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/notifications/domain/models/notification_item.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_type_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_read_state_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/date_formatting_mixin.dart';

const kNotNotificationsEmpty = {
  'en': 'No notifications',
  'id': 'Tidak ada notifikasi',
};
const kNotNotificationsEmptyHint = {
  'en': 'New notifications will appear here',
  'id': 'Notifikasi baru akan muncul di sini',
};

/// Mixin for building header, empty state, and card widgets.
mixin NotificationWidgetBuilderMixin
    on NotificationTypeMixin, NotificationReadStateMixin, DateFormattingMixin {
  BuildContext get context;
  String get role;

  // These methods are provided by NotificationActionsMixin
  Future<void> markAsRead(String id);
  Future<void> deleteNotification(String id);
  Future<void> markAllRead();

  Widget buildHeader(
    BuildContext ctx,
    LanguageProvider languageProvider,
    Color primaryColor,
    int unread,
    bool hasUnread,
  ) {
    final unreadWord = languageProvider.getTranslatedText({
      'en': 'unread',
      'id': 'belum dibaca',
    });
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(ctx).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => AppNavigator.pop(ctx),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Notifications',
                        'id': 'Notifikasi',
                      }),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$unread $unreadWord',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasUnread)
                IconButton(
                  onPressed: markAllRead,
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Icon(
                      Icons.done_all_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  tooltip: languageProvider.getTranslatedText({
                    'en': 'Mark all as read',
                    'id': 'Tandai semua dibaca',
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_off_rounded,
                  size: 38,
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                kNotNotificationsEmpty.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                kNotNotificationsEmptyHint.tr,
                style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildNotificationCard(NotificationItem notif) {
    final isRead = !isUnread(notif);
    final type = notif.type ?? 'general';
    final color = isRead ? ColorUtils.slate400 : getColor(type);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: ColorUtils.error600,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => deleteNotification(notif.id),
      child: GestureDetector(
        onTap: () {
          if (!isRead) markAsRead(notif.id);
          // Note: handleTap called in main build
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(
              color: isRead
                  ? ColorUtils.slate200
                  : color.withValues(alpha: 0.35),
              width: isRead ? 1.0 : 1.5,
            ),
            boxShadow: ColorUtils.corporateShadow(
              elevation: isRead ? 0.5 : 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isRead)
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isRead ? 14 : 12,
                        14,
                        14,
                        14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(12),
                              ),
                              border: Border.all(
                                color: color.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(getIcon(type), color: color, size: 22),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif.title ?? '-',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isRead
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                          color: isRead
                                              ? ColorUtils.slate600
                                              : ColorUtils.slate900,
                                        ),
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  notif.body ?? '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isRead
                                        ? ColorUtils.slate400
                                        : ColorUtils.slate600,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    buildInfoTag(
                                      Icons.access_time_rounded,
                                      formatDate(notif.createdAt),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildInfoTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ColorUtils.slate500),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: ColorUtils.slate600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
