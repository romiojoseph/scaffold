import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_button.dart';
import '../common/app_icon.dart';

Widget statsCopyBar({
  required bool isCopied,
  required VoidCallback onCopyPressed,
  required int languageCount,
}) {
  return Row(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Language Breakdown',
                style: AppTypography.heading6(
                  color: AppColors.neutral5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: isCopied ? 'Copied' : 'Copy Markdown Table',
                svgIcon: isCopied
                    ? AppSvgIcon.checkBold
                    : AppSvgIcon.copy,
                variant: AppButtonVariant.text,
                size: AppButtonSize.small,
                foregroundColor: isCopied
                    ? AppColors.successBase
                    : AppColors.primaryBase,
                onPressed: onCopyPressed,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Token counts are estimated using the included tokenizer configuration. Actual token counts may vary depending on the target LLM's model configuration.",
            style: AppTypography.caption(color: AppColors.neutral7),
          ),
        ],
      ),
      const Spacer(),
      Text(
        '$languageCount Languages Detected',
        style: AppTypography.caption(color: AppColors.neutral6),
      ),
    ],
  );
}