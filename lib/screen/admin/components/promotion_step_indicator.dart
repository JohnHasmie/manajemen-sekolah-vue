import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

class PromotionStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> steps;

  const PromotionStepIndicator({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
    required this.steps,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps, (index) {
              // Line connector
              if (index > 0) {
                return Expanded(
                  child: Container(
                    height: 2,
                    color: index <= currentStep
                        ? ColorUtils.getRoleColor('admin')
                        : Colors.grey.shade300,
                  ),
                );
              }
              return SizedBox.shrink();
            }),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(totalSteps, (index) {
              final isActive = index <= currentStep;
              final isCurrent = index == currentStep;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive
                            ? ColorUtils.getRoleColor('admin')
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? ColorUtils.getRoleColor('admin')
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrent
                            ? ColorUtils.getRoleColor('admin')
                            : Colors.grey.shade600,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
