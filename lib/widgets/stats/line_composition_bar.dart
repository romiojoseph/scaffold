import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';

Widget lineCompositionBar({
  required int totalCode,
  required int totalComments,
  required int totalBlanks,
  required int totalAllLines,
}) {
  if (totalAllLines <= 0) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ShapeDecoration(
        color: AppColors.neutral13,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.neutral11),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Line Composition',
                style: AppTypography.heading6(
                  color: AppColors.neutral5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                'Total: ${FormatUtils.formatNumber(totalAllLines)} lines',
                style: AppTypography.caption(color: AppColors.neutral6),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (totalCode > 0)
                    Expanded(
                      flex: totalCode,
                      child: Container(color: AppColors.successBase),
                    ),
                  if (totalComments > 0)
                    Expanded(
                      flex: totalComments,
                      child: Container(color: AppColors.infoBase),
                    ),
                  if (totalBlanks > 0)
                    Expanded(
                      flex: totalBlanks,
                      child: Container(color: AppColors.neutral7),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              statsLegendItem(
                color: AppColors.successBase,
                label: 'Code Lines',
                value: FormatUtils.formatNumber(totalCode),
                percentage: totalAllLines > 0
                    ? (totalCode / totalAllLines * 100).toStringAsFixed(1)
                    : '0',
              ),
              statsLegendItem(
                color: AppColors.infoBase,
                label: 'Comments',
                value: FormatUtils.formatNumber(totalComments),
                percentage: totalAllLines > 0
                    ? (totalComments / totalAllLines * 100).toStringAsFixed(1)
                    : '0',
              ),
              statsLegendItem(
                color: AppColors.neutral7,
                label: 'Blank Lines',
                value: FormatUtils.formatNumber(totalBlanks),
                percentage: totalAllLines > 0
                    ? (totalBlanks / totalAllLines * 100).toStringAsFixed(1)
                    : '0',
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget statsLegendItem({
  required Color color,
  required String label,
  required String value,
  required String percentage,
}) {
  return Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(
        '$label: ',
        style: AppTypography.caption(color: AppColors.neutral5),
      ),
      Text(
        '$value ($percentage%)',
        style: AppTypography.caption(
          color: AppColors.neutral0,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}