// Empty-state placeholder shown when a tab has no data yet.
// Displays an icon, title, subtitle, and a "Generate AI" action button
// that routes to the AI result screen via the [onGenerateTap] callback.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Centred empty-state card shown inside quiz and reference tabs.
///
/// Analogous to a Vue `<EmptyState>` component: receives display text as
/// props and emits a single [onGenerateTap] event for the CTA button.
/// The [primaryColor] comes from the parent so the button stays on-brand.
class EmptyTabState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color primaryColor;

  /// Called when the user taps "Generate AI".
  final VoidCallback onGenerateTap;

  const EmptyTabState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.onGenerateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: ColorUtils.slate400),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate700,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
            ),
            SizedBox(height: AppSpacing.xl),
            GestureDetector(
              onTap: onGenerateTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Generate AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
