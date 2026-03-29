// DashboardAppBar — the pinned top app bar for all dashboard roles.
// Displays school name, language switcher, notification badge, and account button.
// Like a Vue layout component (<AppHeader>) that accepts callbacks for modal actions.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A `SliverAppBar` for the dashboard that shows the school name,
/// a language-selector icon, a notification bell with optional badge,
/// and a profile/account icon.
///
/// All interactive actions are provided by the parent via callbacks so this
/// widget stays stateless (like a "dumb" Vue presentational component).
class DashboardAppBar extends StatelessWidget {
  /// The school name shown as the main title. Falls back to [AppLocalizations.appTitle].
  final String? schoolName;

  /// Role-specific primary color used for the logo container.
  final Color primaryColor;

  /// Number of unread announcements — drives the notification badge.
  final int? unreadAnnouncements;

  /// GlobalKey placed on the profile IconButton (used by the onboarding tour).
  final GlobalKey? profileHeaderKey;

  /// Called when the language icon is tapped.
  final VoidCallback onLanguageTap;

  /// Called when the notification bell is tapped.
  final VoidCallback onNotificationTap;

  /// Called when the account/profile icon is tapped.
  final VoidCallback onAccountTap;

  const DashboardAppBar({
    super.key,
    this.schoolName,
    required this.primaryColor,
    this.unreadAnnouncements,
    this.profileHeaderKey,
    required this.onLanguageTap,
    required this.onNotificationTap,
    required this.onAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 50,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: ColorUtils.slate200, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Logo — role-coloured square with school icon
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.school, color: Colors.white, size: 18),
                ),
                SizedBox(width: AppSpacing.md),

                // Title — single line, truncated if too long
                Expanded(
                  child: Text(
                    schoolName ?? AppLocalizations.appTitle.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Language switcher icon
                IconButton(
                  icon: Icon(
                    Icons.language,
                    size: 20,
                    color: ColorUtils.slate600,
                  ),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 18,
                  onPressed: onLanguageTap,
                ),

                // Notification bell with unread badge
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: ColorUtils.slate600,
                      ),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      splashRadius: 18,
                      onPressed: onNotificationTap,
                    ),
                    if (unreadAnnouncements != null && unreadAnnouncements! > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: ColorUtils.error600,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            unreadAnnouncements! > 9
                                ? '9+'
                                : unreadAnnouncements.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),

                // Profile / account icon
                IconButton(
                  key: profileHeaderKey,
                  icon: Icon(
                    Icons.account_circle,
                    size: 20,
                    color: ColorUtils.slate600,
                  ),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 18,
                  onPressed: onAccountTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
