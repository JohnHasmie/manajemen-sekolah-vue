// ClassActivityHeader — the gradient app-bar for the class-activity screen.
//
// Extracted from `ClassActivityScreenState._buildHeader`.
// Think of this like a Vue `<ClassActivityHeader :step="currentStep" />`
// component. It renders the gradient bar, back button, overflow menu, and
// (when on Step 2) the tab-switcher widget passed in as [tabSwitcherWidget].

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// The gradient top-header bar for the teacher class-activity screen.
///
/// Props (constructor params — like Vue props):
/// - [currentStep]        — wizard step (0=classes, 1=subjects, 2=activities)
/// - [selectedClassName]  — name of the selected class (shown in subtitle)
/// - [selectedSubjectName]— name of the selected subject (shown in subtitle for step 2)
/// - [primaryColor]       — theme colour for the gradient
/// - [languageProvider]   — translation helper (read-only)
/// - [onBackPressed]      — called when the back/arrow button is tapped
/// - [onRefreshPressed]   — called when "Refresh Data" is chosen from the menu
/// - [tabSwitcherWidget]  — optional pre-built tab switcher, shown only on step 2
class ClassActivityHeader extends StatelessWidget {
  final int currentStep;
  final String? selectedClassName;
  final String? selectedSubjectName;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  /// Fired when the user taps the back arrow.
  /// The parent is responsible for the wizard-step logic.
  final VoidCallback onBackPressed;

  /// Fired when the user picks "Refresh Data" from the overflow menu.
  final VoidCallback onRefreshPressed;

  /// The pre-built `_buildTabSwitcher(...)` widget from the parent.
  /// Passed in rather than built here so the [TabController] and [GlobalKey]
  /// stay in the parent's State — same pattern as passing `slot` content in Vue.
  final Widget? tabSwitcherWidget;

  const ClassActivityHeader({
    super.key,
    required this.currentStep,
    required this.primaryColor,
    required this.languageProvider,
    required this.onBackPressed,
    required this.onRefreshPressed,
    this.selectedClassName,
    this.selectedSubjectName,
    this.tabSwitcherWidget,
  });

  // ---------------------------------------------------------------------------
  // Helper: derive subtitle text from current wizard step.
  // ---------------------------------------------------------------------------
  String _buildSubtitle() {
    if (currentStep == 0) {
      return languageProvider.getTranslatedText({
        'en': 'Select a class to manage activities',
        'id': 'Pilih kelas untuk mengelola kegiatan',
      });
    } else if (currentStep == 1) {
      return selectedClassName ?? '-';
    } else {
      return '${selectedClassName ?? '-'} • ${selectedSubjectName ?? '-'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = languageProvider.getTranslatedText({
      'en': 'Class Activity',
      'id': 'Kegiatan Kelas',
    });
    final subtitle = _buildSubtitle();

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
          // ── Top row: back button | title+subtitle | overflow menu ─────
          Row(
            children: [
              // Back / wizard-step navigation button
              GestureDetector(
                onTap: onBackPressed,
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

              // Title + subtitle column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Overflow / kebab menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'refresh') {
                    onRefreshPressed();
                  }
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
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
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Update Data',
                            'id': 'Perbarui Data',
                          }),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'help',
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Help'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Tab switcher: only visible on Step 2 ─────────────────────
          // The widget is built by the parent so the TabController key stays
          // in the State. Same idea as a Vue named `<slot name="tabs">`.
          if (currentStep == 2 && tabSwitcherWidget != null) ...[
            const SizedBox(height: AppSpacing.lg),
            tabSwitcherWidget!,
          ],
        ],
      ),
    );
  }
}
