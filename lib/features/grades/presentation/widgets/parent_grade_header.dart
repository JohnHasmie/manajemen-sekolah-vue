// Gradient header bar for the parent grade screen.
// Contains back button, title/subtitle, and a refresh popup menu action.
// Like a Vue `<AppHeader>` component that emits `back` and `refresh` events.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Gradient app-bar header for the parent grade screen.
///
/// Accepts a [gradient] so the parent can pass its role colour, and an
/// [onRefresh] callback — equivalent to a Vue `$emit('refresh')` call.
class ParentGradeHeader extends StatelessWidget {
  /// Background gradient derived from the parent role colour.
  final LinearGradient gradient;

  /// Primary role colour used for the drop shadow.
  final Color primaryColor;

  /// Called when the user taps "Refresh / Update Data" in the popup menu.
  final VoidCallback onRefresh;

  const ParentGradeHeader({
    super.key,
    required this.gradient,
    required this.primaryColor,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
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
              GestureDetector(
                onTap: () => AppNavigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.childAcademicGrades.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      AppLocalizations.monitorChildGrades.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'refresh') onRefresh();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 20,
                          color: ColorUtils.info600,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(AppLocalizations.updateData.tr),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
