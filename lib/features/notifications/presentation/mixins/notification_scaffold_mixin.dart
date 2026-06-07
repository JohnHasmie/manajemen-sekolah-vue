import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/notifications/domain/models/notification_item.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_widget_builder_mixin.dart';

const _kNotErrorPrefix = {'en': 'Error', 'id': 'Kesalahan'};

/// Mixin for scaffold/layout and async value handling.
mixin NotificationScaffoldMixin on NotificationWidgetBuilderMixin {
  WidgetRef get ref;
  Color get primaryColor;
  @override
  BuildContext get context;

  // Methods to be implemented by the class using this mixin
  Future<void> loadData();
  void handleTap(NotificationItem notif);

  Widget buildHeaderSection(
    AsyncValue<List<NotificationItem>> asyncVal,
    LanguageProvider langProvider,
  ) {
    return asyncVal.when(
      data: (notifications) => buildHeader(
        context,
        langProvider,
        primaryColor,
        unreadCount(notifications),
        hasUnread(notifications),
      ),
      error: (_, __) =>
          buildHeader(context, langProvider, primaryColor, 0, false),
      loading: () => buildHeader(context, langProvider, primaryColor, 0, false),
    );
  }

  Widget buildContentSection(AsyncValue<List<NotificationItem>> asyncVal) {
    return asyncVal.when(
      data: (notifications) => RefreshIndicator(
        onRefresh: loadData,
        color: primaryColor,
        child: notifications.isEmpty
            ? buildEmptyState()
            : _buildNotificationList(notifications),
      ),
      loading: () => const SkeletonListLoading(itemCount: 8, infoTagCount: 1),
      error: (e, _) => Center(child: Text('${_kNotErrorPrefix.tr}: $e')),
    );
  }

  Widget _buildNotificationList(List<NotificationItem> notifications) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: notifications.length,
      itemBuilder: (ctx, index) {
        final notif = notifications[index];
        return GestureDetector(
          onTap: () {
            if (!isUnread(notif)) {
              markAsRead(notif.id);
            }
            handleTap(notif);
          },
          child: buildNotificationCard(notif),
        );
      },
    );
  }
}
