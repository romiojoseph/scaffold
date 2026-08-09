import 'package:flutter/material.dart';
import 'package:scaffold/theme/app_spacing.dart';
import 'package:scaffold/theme/app_typography.dart';
import '../../theme/app_colors.dart';
import 'app_icon.dart';

class AppToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String subtitle;
  final Color? activeColor;

  const AppToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onChanged == null;
    final Color effectiveActiveColor = activeColor ?? AppColors.primaryBase;

    return InkWell(
      onTap: isDisabled ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: ShapeDecoration(
          color: AppColors.neutral12,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.neutral10, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      fontWeight: FontWeight.w500,
                      color: isDisabled
                          ? AppColors.neutral7
                          : (value ? AppColors.neutral3 : AppColors.neutral6),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTypography.caption(
                      fontWeight: FontWeight.w400,
                      color: isDisabled
                          ? AppColors.neutral7
                          : (value ? AppColors.neutral5 : AppColors.neutral7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppIcon(
              value ? AppSvgIcon.toggleRight : AppSvgIcon.toggleLeft,
              size: 32,
              color: isDisabled
                  ? AppColors.neutral10
                  : (value ? effectiveActiveColor : AppColors.neutral8),
            ),
          ],
        ),
      ),
    );
  }
}
