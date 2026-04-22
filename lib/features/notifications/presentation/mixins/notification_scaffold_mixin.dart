import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_widget_builder_mixin.dart';

/// Mixin for scaffold/layout and async value handling.
mixin NotificationScaffoldMixin on NotificationWidgetBuilderMixin {
  late WidgetRef ref;
  late Color primaryColor;
  @override
  late BuildContext context;

  // Methods to be implemented by the class using this mixin
  Future<void> loadData();
  void handleTap(Map<String, dynamic> notif);

  Widget buildHeaderSection(
    AsyncValue<dynamic> asyncVal,
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

  Widget buildContentSection(AsyncValue<dynamic> asyncVal) {
    return asyncVal.when(
      data: (notifications) => RefreshIndicator(
        onRefresh: loadData,
        color: primaryColor,
        child: notifications.isEmpty
            ? buildEmptyState()
            : _buildNotificationList(notifications),
      ),
      loading: () => const SkeletonListLoading(itemCount: 8, infoTagCount: 1),
      error: (e, _) => Center(child: Text('Kesalahan: $e')),
    );
  }

  Widget _buildNotificationList(List<dynamic> notifications) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: notifications.length,
      itemBuilder: (ctx, index) {
        final notif = notifications[index];
        return GestureDetector(
          onTap: () {
            if (!isUnread(notif)) {
              markAsRead(notif['id'].toString());
            }
            handleTap(notif);
          },
          child: buildNotificationCard(notif),
        );
      },
    );
  }
}
