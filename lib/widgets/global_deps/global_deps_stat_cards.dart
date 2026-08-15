import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../common/app_icon.dart';

Widget globalDepsStatCards({
  required int projectCount,
  required int totalPackages,
  required int divergentCount,
  required int totalOutdatedUsages,
  required int vulnerableCount,
}) {
  return Row(
    children: [
      globalDepsStatCard(
        svgIcon: AppSvgIcon.foldersFill,
        label: 'Projects Tracked',
        value: FormatUtils.formatNumber(projectCount),
        color: AppColors.primaryBase,
      ),
      const SizedBox(width: AppSpacing.md),
      globalDepsStatCard(
        svgIcon: AppSvgIcon.packageDuotone,
        label: 'Distinct Packages',
        value: FormatUtils.formatNumber(totalPackages),
        color: AppColors.infoBase,
      ),
      const SizedBox(width: AppSpacing.md),
      globalDepsStatCard(
        svgIcon: AppSvgIcon.magnifyingGlass,
        label: 'Version Mismatches',
        value: FormatUtils.formatNumber(divergentCount),
        color: divergentCount > 0 ? AppColors.warningBase : AppColors.neutral6,
      ),
      const SizedBox(width: AppSpacing.md),
      globalDepsStatCard(
        svgIcon: AppSvgIcon.arrowUpFill,
        label: 'Outdated Usages',
        value: FormatUtils.formatNumber(totalOutdatedUsages),
        color: totalOutdatedUsages > 0
            ? AppColors.warningBase
            : AppColors.neutral6,
      ),
      const SizedBox(width: AppSpacing.md),
      globalDepsStatCard(
        svgIcon: AppSvgIcon.trashFill,
        label: 'Vulnerabilities',
        value: FormatUtils.formatNumber(vulnerableCount),
        color: vulnerableCount > 0 ? AppColors.dangerBase : AppColors.neutral6,
      ),
    ],
  );
}

Widget globalDepsStatCard({
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
          side: const BorderSide(color: AppColors.neutral11),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AppIcon(svgIcon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption(color: AppColors.neutral6),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.heading6(
                    color: AppColors.neutral4,
                    fontWeight: FontWeight.w500,
                  ),
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
