// Bottom sheet for picking a subject in recommendations. Extracted from recommendation_class_screen.dart.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A bottom sheet that presents a list of subjects for the teacher to pick from.
///
/// Used in the AI recommendation flow: after selecting a class, the teacher
/// picks which subject to generate recommendations for.
///
/// Like a small modal component in Vue -- receives props, emits a selection
/// back to the caller via [AppNavigator.pop] with the chosen subject map.
class SubjectPickerSheet extends StatelessWidget {
  final List<Map<String, String>> subjects;
  final String className;
  final Color primaryColor;

  const SubjectPickerSheet({
    super.key,
    required this.subjects,
    required this.className,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Pilih Mata Pelajaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Generate rekomendasi AI untuk $className',
            style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...subjects.map(
            (subject) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => AppNavigator.pop(context, subject),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: ColorUtils.slate200, width: 1),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Icon(
                            Icons.menu_book_outlined,
                            size: 18,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            subject['name'] ?? 'Mata Pelajaran',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ),
                        Icon(Icons.auto_awesome, size: 18, color: primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
