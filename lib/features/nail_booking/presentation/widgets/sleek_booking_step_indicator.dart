import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SleekBookingStepIndicator extends StatelessWidget {
  final int currentStep;
  final List<Map<String, dynamic>> steps;

  const SleekBookingStepIndicator({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCompleted = index < currentStep;
          final isActive = index == currentStep;
          final step = steps[index];
          final String title = step['title'] as String;
          final IconData icon = step['icon'] as IconData;

          return Expanded(
            child: Row(
              children: [
                // Connecting line before item (except step 0)
                if (index > 0)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: (isCompleted || isActive)
                            ? const LinearGradient(
                                colors: [AppColors.primary, Color(0xFFFF80AB)],
                              )
                            : null,
                        color: (isCompleted || isActive)
                            ? null
                            : const Color(0xFFF0E5E7),
                      ),
                    ),
                  ),

                // Step Item (Circle + Title)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: isActive ? 34 : 28,
                      height: isActive ? 34 : 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Colors.white
                            : (isCompleted
                                  ? AppColors.primary
                                  : const Color(0xFFFAF5F6)),
                        border: Border.all(
                          color: (isActive || isCompleted)
                              ? AppColors.primary
                              : const Color(0xFFE5D5D9),
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
                            : Icon(
                                icon,
                                size: isActive ? 15 : 13,
                                color: isActive
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                              ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: isActive ? 11 : 10,
                        fontWeight: (isActive || isCompleted)
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isActive
                            ? AppColors.primaryDark
                            : (isCompleted
                                  ? AppColors.primary
                                  : Colors.grey.shade500),
                        letterSpacing: -0.2,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Connecting line after item (except last step)
                if (index < steps.length - 1)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: isCompleted
                            ? const LinearGradient(
                                colors: [AppColors.primary, Color(0xFFFF80AB)],
                              )
                            : null,
                        color: isCompleted ? null : const Color(0xFFF0E5E7),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
