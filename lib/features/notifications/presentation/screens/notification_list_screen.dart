// Notification list screen shared across all roles (admin, guru, wali).
//
// Like `pages/common/notifications.vue` - a shared notification inbox page
// used by all user roles. Fetches notifications from the API, supports
// mark-as-read, delete (swipe-to-dismiss), and navigation to related screens.
//
// In Laravel terms, this consumes the NotificationController endpoints.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_actions_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_detail_dialog_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_navigation_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_read_state_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_scaffold_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_type_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/notification_widget_builder_mixin.dart';
import 'package:manajemensekolah/features/notifications/presentation/mixins/date_formatting_mixin.dart';

/// Notification list screen - shared across admin, teacher (guru), and
/// parent (wali) roles.
///
/// This is a [ConsumerStatefulWidget] - like a Vue page component with its
/// own local state (`data() { return { notifications: [], isLoading:
/// true } }`).
///
/// Takes a [role] prop to determine color theming and which screens to
/// navigate to when a notification is tapped (e.g., parent sees billing,
/// teacher sees activities).
class NotificationListScreen extends ConsumerStatefulWidget {
  final String role; // 'guru', 'admin', 'wali'

  const NotificationListScreen({super.key, required this.role});

  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

/// The mutable state for [NotificationListScreen].
///
/// Key state variables (like Vue `data()` properties):
/// - Notifications fetched from ref.watch(notificationProvider)
/// - Delegates styling, navigation, and state checks to mixins
///
/// setState() is like Vue's reactivity - triggers a re-render when data
/// changes.
class _NotificationListScreenState extends ConsumerState<NotificationListScreen>
    with
        NotificationActionsMixin,
        NotificationTypeMixin,
        NotificationReadStateMixin,
        DateFormattingMixin,
        NotificationDetailDialogMixin,
        NotificationNavigationMixin,
        NotificationWidgetBuilderMixin,
        NotificationScaffoldMixin {
  // Mixin getters — ConsumerState already provides ref and context.
  @override
  String get role => widget.role;

  @override
  Color get primaryColor => ColorUtils.getRoleColor(widget.role);

  LanguageProvider get languageProvider => ref.watch(languageRiverpod);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications(widget.role);
    });
  }

  @override
  Widget build(BuildContext context) {

    final notificationAsyncValue = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          buildHeaderSection(notificationAsyncValue, languageProvider),
          Expanded(child: buildContentSection(notificationAsyncValue)),
        ],
      ),
    );
  }
}
