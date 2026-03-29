// Gradient app-bar for the grade recap wizard.
// Like a Vue <GradeRecapAppBar> component — purely presentational, all
// actions (back, save, refresh, export) flow through callbacks.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Pattern #7 gradient header used across all three wizard steps.
///
/// Shows a back button, dynamic subtitle (step-aware), an optional save
/// button (step 2 only), and a popup menu for refresh / export.
/// Like a Laravel Blade `@include('partials.header')` partial — it receives
/// all data as constructor params and emits actions via callbacks.
class GradeRecapAppBar extends StatelessWidget {
  // ── Step & identity ────────────────────────────────────────────────────────

  /// 0 = class list, 1 = subject list, 2 = recap table.
  final int currentStep;

  /// Primary brand colour derived from teacher role.
  final Color primaryColor;

  // ── Subtitle strings (step-dependent) ─────────────────────────────────────

  /// Shown as subtitle on step 0 (e.g. "Select Class").
  final String selectClassLabel;

  /// Name of the selected class — shown on step 1.
  final String selectedClassName;

  /// Name of the selected subject — shown on step 2.
  final String selectedSubjectName;

  // ── Title string ───────────────────────────────────────────────────────────

  /// Main title text (e.g. "Grade Recap" / "Rekap Nilai").
  final String title;

  // ── Action button labels ───────────────────────────────────────────────────

  /// Label for the "Update Data" popup menu item.
  final String updateDataLabel;

  // ── GlobalKeys (for tour highlighting) ────────────────────────────────────

  /// Placed on the save icon so the onboarding tour can highlight it.
  final GlobalKey saveKey;

  /// Placed on the popup-menu icon so the onboarding tour can highlight it.
  final GlobalKey exportKey;

  // ── State ──────────────────────────────────────────────────────────────────

  /// Whether a save operation is in progress (shows spinner instead of icon).
  final bool isSaving;

  // ── Callbacks ─────────────────────────────────────────────────────────────

  /// Called when the user taps the back button.
  final VoidCallback onBack;

  /// Called when the user taps the save icon (step 2 only).
  final VoidCallback onSave;

  /// Called when the user selects "refresh" from the popup menu.
  final VoidCallback onRefresh;

  /// Called when the user selects "export Excel" from the popup menu.
  final VoidCallback onExportExcel;

  const GradeRecapAppBar({
    super.key,
    required this.currentStep,
    required this.primaryColor,
    required this.title,
    required this.selectClassLabel,
    required this.selectedClassName,
    required this.selectedSubjectName,
    required this.updateDataLabel,
    required this.saveKey,
    required this.exportKey,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
    required this.onRefresh,
    required this.onExportExcel,
  });

  // ── Derived helpers ────────────────────────────────────────────────────────

  String get _subtitle {
    if (currentStep == 0) return selectClassLabel;
    if (currentStep == 1) return selectedClassName;
    return selectedSubjectName;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Title + dynamic subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _subtitle,
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

          // Save button — only visible on step 2
          if (currentStep == 2)
            GestureDetector(
              key: saveKey,
              onTap: isSaving ? null : onSave,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isSaving
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white, size: 20),
              ),
            ),

          // Overflow menu (refresh + optional export)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') onRefresh();
              if (value == 'export_excel') onExportExcel();
            },
            icon: Container(
              key: currentStep == 2 ? exportKey : null,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
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
                    Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                    const SizedBox(width: AppSpacing.sm),
                    Text(updateDataLabel),
                  ],
                ),
              ),
              if (currentStep == 2)
                PopupMenuItem<String>(
                  value: 'export_excel',
                  child: Row(
                    children: [
                      const Icon(Icons.table_view, size: 20, color: Colors.green),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Export Excel'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
