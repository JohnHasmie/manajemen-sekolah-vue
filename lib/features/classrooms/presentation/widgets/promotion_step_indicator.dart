// Step indicator component for the class promotion wizard.
//
// Like a Vue `<StepIndicator>` component used in a multi-step form wizard.
// Shows numbered circles connected by lines, with completed/active/pending states.
// Similar to a Vuetify `<v-stepper>` or a Bootstrap stepper component.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A horizontal step indicator that shows progress through a multi-step wizard.
///
/// This is a [StatelessWidget] - it receives all data via props (constructor params),
/// just like a Vue component that only uses `props` with no local `data()`.
///
/// Props (constructor parameters):
/// - [currentStep] - the 0-based index of the active step
/// - [totalSteps] - total number of steps in the wizard
/// - [steps] - list of step label strings
/// - [primaryColor] - the theme color for active/completed steps
class PromotionStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> steps;
  final Color primaryColor;

  const PromotionStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.steps,
    required this.primaryColor,
  });

  /// Renders the step indicator with circles, connecting lines, and labels.
  /// Uses `List.generate` to build the UI dynamically - like Vue's `v-for` directive.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: List.generate(totalSteps * 2 - 1, (i) {
              if (i.isEven) {
                final stepIndex = i ~/ 2;
                final isActive = stepIndex <= currentStep;
                final isCurrent = stepIndex == currentStep;
                final isCompleted = stepIndex < currentStep;

                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive ? primaryColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? primaryColor : ColorUtils.slate300,
                      width: 2,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          )
                        : Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : ColorUtils.slate500,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                  ),
                );
              } else {
                final lineIndex = i ~/ 2;
                final isActive = lineIndex < currentStep;
                return Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive ? primaryColor : ColorUtils.slate200,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                );
              }
            }),
          ),
          const SizedBox(height: 10),
          // Labels
          Row(
            children: List.generate(totalSteps, (index) {
              final isCurrent = index == currentStep;
              final isActive = index <= currentStep;

              return Expanded(
                child: Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 11,
                    color: isCurrent
                        ? primaryColor
                        : isActive
                        ? ColorUtils.slate700
                        : ColorUtils.slate400,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
