import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../common/app_icon.dart';

Widget depsStatCards({
  required int manifestsCount,
  required int totalDeps,
  required int upToDateDeps,
  required int outdatedDeps,
  required int vulnerableDeps,
}) {
  return Row(
    children: [
      depsStatCard(
        svgIcon: AppSvgIcon.fileCodeFill,
        label: 'Manifests',
        value: FormatUtils.formatNumber(manifestsCount),
        color: AppColors.primaryBase,
        tooltip:
            'Total package manifest files detected in the project (package.json, pubspec.yaml, go.mod, Cargo.toml, requirements.txt)',
      ),
      const SizedBox(width: AppSpacing.md),
      depsStatCard(
        svgIcon: AppSvgIcon.foldersFill,
        label: 'Total Dependencies',
        value: FormatUtils.formatNumber(totalDeps),
        color: AppColors.infoBase,
        tooltip:
            'Total number of dependencies declared across all discovered manifest files',
      ),
      const SizedBox(width: AppSpacing.md),
      depsStatCard(
        svgIcon: AppSvgIcon.checkCircleFill,
        label: 'Up to Date',
        value: FormatUtils.formatNumber(upToDateDeps),
        color: AppColors.successBase,
        tooltip:
            'Number of packages matching the latest available version in their registry',
      ),
      const SizedBox(width: AppSpacing.md),
      depsStatCard(
        svgIcon: AppSvgIcon.shieldWarningFill,
        label: 'Outdated Packages',
        value: FormatUtils.formatNumber(outdatedDeps),
        color: outdatedDeps > 0 ? AppColors.warningBase : AppColors.neutral6,
        tooltip:
            'Number of packages that have newer version releases available in their package registry',
      ),
      const SizedBox(width: AppSpacing.md),
      depsStatCard(
        svgIcon: AppSvgIcon.radioactiveFill,
        label: 'Vulnerabilities',
        value: FormatUtils.formatNumber(vulnerableDeps),
        color: vulnerableDeps > 0 ? AppColors.dangerBase : AppColors.neutral6,
        tooltip:
            'Number of packages with known security advisories or vulnerabilities (CVEs)',
      ),
    ],
  );
}

Widget depsStatCard({
  required AppSvgIcon svgIcon,
  required String label,
  required String value,
  required Color color,
  required String tooltip,
}) {
  return Expanded(
    child: Tooltip(
      message: tooltip,
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
    ),
  );
}
