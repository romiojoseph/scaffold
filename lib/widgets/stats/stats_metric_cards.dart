import 'package:flutter/material.dart';
import '../../models/scan_stats.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../common/app_icon.dart';

Widget statsMetricCards({
  required ScanStats stats,
  required int totalTokens,
  required bool isLoadingTokenizer,
}) {
  return Row(
    children: [
      statsMetricCard(
        svgIcon: AppSvgIcon.filesFill,
        label: 'Total Files',
        value: FormatUtils.formatNumber(stats.totalFiles),
        color: AppColors.infoBase,
      ),
      const SizedBox(width: AppSpacing.md),
      statsMetricCard(
        svgIcon: AppSvgIcon.foldersFill,
        label: 'Total Directories',
        value: FormatUtils.formatNumber(stats.totalDirectories),
        color: AppColors.primaryBase,
      ),
      const SizedBox(width: AppSpacing.md),
      statsMetricCard(
        svgIcon: AppSvgIcon.code,
        label: 'Lines of Code',
        value: FormatUtils.formatNumber(stats.totalLines),
        color: AppColors.warningBase,
      ),
      const SizedBox(width: AppSpacing.md),
      statsMetricCard(
        svgIcon: AppSvgIcon.hardDrivesFill,
        label: 'Total Size',
        value: stats.formattedTotalSize,
        color: AppColors.successBase,
      ),
      const SizedBox(width: AppSpacing.md),
      statsMetricCard(
        svgIcon: AppSvgIcon.sparkleFill,
        label: 'Est. Tokens',
        value: isLoadingTokenizer
            ? '...'
            : FormatUtils.formatNumber(totalTokens),
        color: AppColors.primaryBase,
      ),
    ],
  );
}

Widget statsMetricCard({
  required AppSvgIcon svgIcon,
  required String label,
  required String value,
  required Color color,
}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: ShapeDecoration(
        color: AppColors.neutral13,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.neutral11),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AppIcon(svgIcon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption(color: AppColors.neutral6),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.heading6(color: AppColors.neutral0),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
