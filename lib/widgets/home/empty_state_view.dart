import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';

Widget homeErrorState(BuildContext context, String message) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppIcon(
          AppSvgIcon.xBold,
          color: AppColors.dangerBase,
          size: 48,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Error scanning directory',
          style: AppTypography.heading6(
            color: AppColors.dangerBase,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          style: AppTypography.body(color: AppColors.neutral6),
        ),
      ],
    ),
  );
}

Widget homeEmptyState(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppIcon(
          AppSvgIcon.folderOpen,
          color: AppColors.neutral8,
          size: 64,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Select a directory path above and click "Scan Directory"',
          style: AppTypography.body(color: AppColors.neutral6),
        ),
      ],
    ),
  );
}