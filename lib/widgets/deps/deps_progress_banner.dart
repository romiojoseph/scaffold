import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

Widget depsProgressBanner({
  required String message,
  required int checkedCount,
  required int totalToCheck,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    decoration: ShapeDecoration(
      color: AppColors.primaryBase.withValues(alpha: 0.1),
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.primaryBase.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBase),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            message,
            style: AppTypography.body(
              color: AppColors.primaryBase,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryBase.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$checkedCount / $totalToCheck',
            style: AppTypography.caption(
              color: AppColors.neutral4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}