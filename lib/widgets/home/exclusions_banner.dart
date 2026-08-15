import 'package:flutter/material.dart';
import '../../models/exclusions_config.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';

Widget scanExclusionsBanner(BuildContext context, ExclusionsConfig config) {
  final show = config.gitignoreOnly ||
      (config.enabled && config.patterns.isNotEmpty);
  if (!show) return const SizedBox.shrink();

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    color: AppColors.neutral13,
    child: Row(
      children: [
        const AppIcon(
          AppSvgIcon.funnel,
          size: 14,
          color: AppColors.neutral6,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          config.gitignoreOnly ? 'Mode: ' : 'Excluding: ',
          style: AppTypography.caption(color: AppColors.neutral6),
        ),
        Expanded(
          child: Text(
            config.gitignoreOnly
                ? '.gitignore + manual patterns'
                : config.patterns.join(', '),
            style: AppTypography.caption(
              color: config.gitignoreOnly
                  ? AppColors.primaryBase
                  : AppColors.neutral5,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}