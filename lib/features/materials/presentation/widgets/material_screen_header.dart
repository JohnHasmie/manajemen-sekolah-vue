// Gradient header bar for TeacherMaterialScreen.
// Extracted from TeacherMaterialScreenState._buildHeader() to keep the screen
// file lean. Like a Vue <MaterialHeader /> sub-component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Top gradient header for the material browser screen.
///
/// In Vue terms this is a dumb/presentational component — it receives all data
/// and callbacks as props (constructor params) and never calls setState itself.
///
/// [gradient]          — the gradient to paint behind the header.
/// [primaryColor]      — accent colour used for the shadow.
/// [languageProvider]  — drives translated title text.
/// [onGenerateTap]     — called when the ✨ generate button is tapped.
/// [onRefreshTap]      — called when "Refresh" is selected from the overflow menu.
class MaterialScreenHeader extends StatelessWidget {
  final LinearGradient gradient;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onGenerateTap;
  final VoidCallback onRefreshTap;

  const MaterialScreenHeader({
    super.key,
    required this.gradient,
    required this.primaryColor,
    required this.languageProvider,
    required this.onGenerateTap,
    required this.onRefreshTap,
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
                      languageProvider.getTranslatedText({
                        'en': 'Learning Materials',
                        'id': 'Materi Pembelajaran',
                      }),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      AppLocalizations.selectAndOrganizeMaterials.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onGenerateTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'refresh') {
                    onRefreshTap();
                  }
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
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
