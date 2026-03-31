// Notification list screen shared across all roles (admin, guru, wali).
//
// Like `pages/common/notifications.vue` - a shared notification inbox page
// used by all user roles. Fetches notifications from the API, supports
// mark-as-read, delete (swipe-to-dismiss), and navigation to related screens.
//
// In Laravel terms, this consumes the NotificationController endpoints.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_billing_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Notification list screen - shared across admin, teacher (guru), and parent (wali) roles.
///
/// This is a [StatefulWidget] - like a Vue page component with its own local state
/// (`data() { return { notifications: [], isLoading: true } }`).
///
/// Takes a [role] prop to determine color theming and which screens to navigate
/// to when a notification is tapped (e.g., parent sees billing, teacher sees activities).
class NotificationListScreen extends ConsumerStatefulWidget {
  final String role; // 'guru', 'admin', 'wali'

  const NotificationListScreen({super.key, required this.role});

  @override
  ConsumerState<NotificationListScreen> createState() => _NotificationListScreenState();
}

/// The mutable state for [NotificationListScreen].
///
/// Key state variables (like Vue `data()` properties):
/// - [_notifications] - the list of notification objects from the API
/// - [_isLoading] - controls skeleton loading display
///
/// setState() is like Vue's reactivity - triggers a re-render when data changes.
class _NotificationListScreenState extends ConsumerState<NotificationListScreen> {

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.role);
  }

  /// Like Vue's `mounted()` - fetches notifications when screen first appears.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications(widget.role);
    });
  }

  Future<void> _loadData() async {
    await ref.read(notificationProvider.notifier).fetchNotifications(widget.role);
  }

  Future<void> _markAsRead(String id) async {
    await ref.read(notificationProvider.notifier).markAsRead(id);
  }

  Future<void> _deleteNotification(String id) async {
    await ref.read(notificationProvider.notifier).deleteNotification(id);
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationProvider.notifier).markAllRead();
  }

  bool _isUnread(dynamic n) {
    if (n is! Map<String, dynamic>) return true;
    if (n['is_read'] is bool) return !(n['is_read'] as bool);
    if (n['is_read'] is int) return n['is_read'] != 1;
    return true;
  }

  int _unreadCount(List<dynamic> notifications) =>
      notifications.where(_isUnread).length;

  bool _hasUnread(List<dynamic> notifications) =>
      notifications.any(_isUnread);

  Color _getColor(String type) {
    switch (type) {
      case 'bill':
      case 'tagihan':
        return ColorUtils.success600;
      case 'announcement':
      case 'pengumuman':
        return ColorUtils.corporateBlue600;
      case 'class_activity':
      case 'activity':
        return ColorUtils.warning600;
      case 'reminder_teaching':
        return ColorUtils.violet700;
      case 'grade':
      case 'nilai':
      case 'exam_score':
        return const Color(0xFF0D9488);
      default:
        return ColorUtils.slate500;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'bill':
      case 'tagihan':
        return Icons.receipt_long_rounded;
      case 'announcement':
      case 'pengumuman':
        return Icons.campaign_rounded;
      case 'class_activity':
      case 'activity':
        return Icons.assignment_rounded;
      case 'reminder_teaching':
        return Icons.class_rounded;
      case 'grade':
      case 'nilai':
      case 'exam_score':
        return Icons.grade_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  /// Navigates to the appropriate screen based on notification type and user role.
  /// Like a Vue method with switch/case that calls `router.push()` to different routes.
  /// For example, a 'bill' notification for a parent navigates to ParentBillingScreen.
  void _handleTap(Map<String, dynamic> notif) {
    final type = notif['type'];

    if (widget.role == 'wali' || widget.role == 'parent') {
      if (type == 'bill') {
        AppNavigator.push(context, ParentBillingScreen());
        return;
      } else if (type == 'class_activity') {
        AppNavigator.push(context, ParentClassActivityScreen());
        return;
      }
    } else if (widget.role == 'guru' || widget.role == 'teacher') {
      if (type == 'class_activity') {
        AppNavigator.push(context, ClassActivityScreen());
        return;
      }
    }

    if (type == 'announcement' || type == 'pengumuman') {
      AppNavigator.push(context, AnnouncementScreen());
    } else if (type == 'grade' || type == 'nilai' || type == 'exam_score') {
      _showDetailDialog(notif);
    }
  }

  void _showDetailDialog(Map<String, dynamic> notif) {
    final color = _getColor(notif['type'] ?? 'general');
    final icon = _getIcon(notif['type'] ?? 'general');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient header (Pattern #10)
            Container(
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif['title'] ?? AppLocalizations.information.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(notif['created_at']),
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
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                notif['body'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: ColorUtils.slate700,
                  height: 1.6,
                ),
              ),
            ),
            // Footer
            Container(
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppLocalizations.close.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return AppLocalizations.justNow.tr;
      if (diff.inMinutes < 60) return '${diff.inMinutes} ${AppLocalizations.minutesAgo.tr}';
      if (diff.inHours < 24) return '${diff.inHours} ${AppLocalizations.hoursAgo.tr}';
      if (diff.inDays < 7) return '${diff.inDays} ${AppLocalizations.daysAgo.tr}';
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  /// Main build method - like Vue's `<template>`.
  /// Uses the global `languageProvider` singleton for language changes -
  /// similar to Vue's `computed` property that depends on a Vuex/Pinia store.
  /// Shows skeleton loading, empty state, or the notification list with pull-to-refresh.
  @override
  Widget build(BuildContext context) {
    final notificationAsyncValue = ref.watch(notificationProvider);
    final primaryColor = _getPrimaryColor();

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          notificationAsyncValue.when(
            data: (notifications) => _buildHeader(
              context,
              languageProvider,
              primaryColor,
              _unreadCount(notifications),
              _hasUnread(notifications),
            ),
            error: (_, __) => _buildHeader(
              context,
              languageProvider,
              primaryColor,
              0,
              false,
            ),
            loading: () => _buildHeader(
              context,
              languageProvider,
              primaryColor,
              0,
              false,
            ),
          ),
          Expanded(
            child: notificationAsyncValue.when(
              data: (notifications) => RefreshIndicator(
                onRefresh: _loadData,
                color: primaryColor,
                child: notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) =>
                            _buildNotificationCard(notifications[index]),
                      ),
              ),
              loading: () => SkeletonListLoading(itemCount: 8, infoTagCount: 1),
              error: (e, _) => Center(
                child: Text('${AppLocalizations.error.tr}: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    LanguageProvider languageProvider,
    Color primaryColor,
    int unread,
    bool hasUnread,
  ) {
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
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => AppNavigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Notifications',
                        'id': 'Notifikasi',
                      }),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (unread > 0) ...[
                      SizedBox(height: 2),
                      Text(
                        '$unread ${languageProvider.getTranslatedText({'en': 'unread', 'id': 'belum dibaca'})}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Action: Mark all read
              if (hasUnread)
                IconButton(
                  onPressed: _markAllRead,
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
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

  Widget _buildEmptyState() {
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
              SizedBox(height: AppSpacing.lg),
              Text(
                AppLocalizations.noNotifications.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                AppLocalizations.allNotificationsWillAppear.tr,
                style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final isRead = !_isUnread(notif);
    final type = notif['type'] ?? 'general';
    final color = isRead ? ColorUtils.slate400 : _getColor(type);

    return Dismissible(
      key: Key(notif['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: ColorUtils.error600,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: AppSpacing.xs),
            Text(
              AppLocalizations.delete.tr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _deleteNotification(notif['id'].toString()),
      child: GestureDetector(
        onTap: () {
          if (!isRead) _markAsRead(notif['id'].toString());
          _handleTap(notif);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar for unread
                  if (!isRead)
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                  // Content
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
                          // Icon container
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(_getIcon(type), color: color, size: 22),
                          ),
                          SizedBox(width: AppSpacing.md),
                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif['title'] ?? '-',
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
                                SizedBox(height: AppSpacing.xs),
                                Text(
                                  notif['body'] ?? '-',
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
                                    _buildInfoTag(
                                      Icons.access_time_rounded,
                                      _formatDate(notif['created_at']),
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

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ColorUtils.slate500),
          SizedBox(width: AppSpacing.xs),
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
