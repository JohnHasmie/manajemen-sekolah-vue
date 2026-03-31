// Header bar for the AI material result screen.
// Displays gradient background, back button, title, and optional regenerate button.
// Like a Vue component `<MaterialAiHeader />` receiving props for state and emitting events.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Gradient header shown at the top of [MaterialAiResultScreen].
///
/// Renders:
/// - Back button (pops the route)
/// - Title + subtitle ("AI Generated Materi" + material title)
/// - Regenerate button (shown only when data is loaded and not loading)
///
/// Constructor params replace all `widget.*` and `_state` references,
/// keeping this widget purely presentational (like a dumb Vue component).
class MaterialAiHeader extends StatelessWidget {
  /// The material title shown as a subtitle in the header.
  final String title;

  /// Gradient applied to the header background.
  final LinearGradient gradient;

  /// Primary accent colour (tint for shadow and spinner).
  final Color primaryColor;

  /// True while the initial AI load is still in progress.
  final bool isLoading;

  /// True while a re-generation request is running.
  final bool isRegenerating;

  /// True once AI data has been loaded at least once.
  final bool hasData;

  /// Called when the user taps the regenerate icon.
  /// Parent is responsible for showing the bottom-sheet options.
  final VoidCallback onRegenOptions;

  const MaterialAiHeader({
    super.key,
    required this.title,
    required this.gradient,
    required this.primaryColor,
    required this.isLoading,
    required this.isRegenerating,
    required this.hasData,
    required this.onRegenOptions,
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button — like Vue's `@click="$router.back()"`
          GestureDetector(
            onTap: () => AppNavigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Title column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Generated Materi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
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
          const SizedBox(width: AppSpacing.sm),
          // Regenerate button — only shown once data is available
          if (!isLoading && hasData)
            GestureDetector(
              onTap: isRegenerating ? null : onRegenOptions,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: isRegenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
