import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Floating action button for sub-chapter detail screen.
/// Adapts based on active tab (Materi, Kuis, Referensi).
class SubChapterFAB extends StatelessWidget {
  final int currentTabIndex;
  final bool isRegeneratingMateri;
  final bool isAddingQuiz;
  final bool isRegeneratingRef;
  final bool isLoading;
  final bool isPollingAi;
  final List<Map<String, dynamic>> quizzes;
  final List<Map<String, dynamic>> references;
  final Color primaryColor;
  final VoidCallback onRegenerateMaterial;
  final VoidCallback onAddQuiz;
  final VoidCallback onGenerateMaterial;
  final VoidCallback onRegenerateReferences;
  final BuildContext context;

  const SubChapterFAB({
    super.key,
    required this.currentTabIndex,
    required this.isRegeneratingMateri,
    required this.isAddingQuiz,
    required this.isRegeneratingRef,
    required this.isLoading,
    required this.isPollingAi,
    required this.quizzes,
    required this.references,
    required this.primaryColor,
    required this.onRegenerateMaterial,
    required this.onAddQuiz,
    required this.onGenerateMaterial,
    required this.onRegenerateReferences,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || isPollingAi) {
      return const SizedBox.shrink();
    }

    switch (currentTabIndex) {
      case 0: // Materi
        return FloatingActionButton.extended(
          onPressed: isRegeneratingMateri ? null : onRegenerateMaterial,
          backgroundColor: isRegeneratingMateri
              ? ColorUtils.slate400
              : primaryColor,
          elevation: 4,
          icon: isRegeneratingMateri
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
          label: Text(
            isRegeneratingMateri ? kMatProcessing.tr : kMatReplaceMaterial.tr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        );

      case 1: // Kuis
        final canRegenQuiz = quizzes.isNotEmpty;
        const quizMax = 10;

        if (!canRegenQuiz && quizzes.isNotEmpty) {
          return FloatingActionButton.extended(
            onPressed: () => SnackBarUtils.showInfo(
              this.context,
              kMatQuizLimitReached.tr,
            ),
            backgroundColor: ColorUtils.slate400,
            elevation: 2,
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
            label: Text(
              kMatLimitReached.tr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          );
        }

        return FloatingActionButton.extended(
          onPressed: isAddingQuiz
              ? null
              : (quizzes.isEmpty ? onGenerateMaterial : onAddQuiz),
          backgroundColor: isAddingQuiz ? ColorUtils.slate400 : primaryColor,
          elevation: 4,
          icon: isAddingQuiz
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          label: Text(
            isAddingQuiz ? kMatProcessing.tr : kMatAddQuiz.tr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        );

      case 2: // Referensi
        final canRegenRef = references.isNotEmpty;
        const refMax = 5;

        if (!canRegenRef && references.isNotEmpty) {
          return FloatingActionButton.extended(
            onPressed: () => SnackBarUtils.showInfo(
              this.context,
              kMatReferenceLimitReached.tr,
            ),
            backgroundColor: ColorUtils.slate400,
            elevation: 2,
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
            label: Text(
              kMatLimitReached.tr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          );
        }

        return FloatingActionButton.extended(
          onPressed: isRegeneratingRef
              ? null
              : (references.isNotEmpty
                    ? onRegenerateReferences
                    : onGenerateMaterial),
          backgroundColor: isRegeneratingRef
              ? ColorUtils.slate400
              : primaryColor,
          elevation: 4,
          icon: isRegeneratingRef
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
          label: Text(
            isRegeneratingRef ? kMatProcessing.tr : kMatReplaceReferences.tr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
