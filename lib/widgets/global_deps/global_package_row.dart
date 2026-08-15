import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/dependency_info.dart';
import '../../services/global_dependency_service.dart';
import '../../services/icon_mapping_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';

Widget globalPackageRow({
  required GlobalPackageGroup pkg,
  required bool isEven,
  required bool isExpanded,
  required VoidCallback onToggle,
  required void Function(String text, String message) onCopy,
  required void Function(String url) onOpenUrl,
  required String Function(Ecosystem ecosystem, String packageName, bool isDev)
  generateUpgradeCommand,
}) {
  final ecoIconSvg = IconMappingConfig.instance
      .getIconForExtension(pkg.ecosystem.defaultExtension);

  return Container(
    decoration: BoxDecoration(
      color: isEven
          ? AppColors.neutral12.withValues(alpha: 0.35)
          : AppColors.neutral11.withValues(alpha: 0.15),
      border: const Border(
        bottom: BorderSide(color: AppColors.neutral11, width: 0.5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Summary Row
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Tooltip(
                  message: isExpanded
                      ? 'Click to collapse project breakdown'
                      : 'Click to expand cross-project version breakdown',
                  child: AppIcon(
                    isExpanded
                        ? AppSvgIcon.caretDownBold
                        : AppSvgIcon.caretRightBold,
                    size: 16,
                    color: AppColors.primaryBase,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Package Name + Ecosystem Tag + CVE Tag
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Package: ${pkg.name}',
                        child: Text(
                          pkg.name,
                          style: AppTypography.body(
                            color: AppColors.neutral4,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Tooltip(
                        message: '${pkg.ecosystem.label} ecosystem',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBase.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/mapping/$ecoIconSvg',
                                width: 12,
                                height: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                pkg.ecosystem.label,
                                style: AppTypography.tagline(
                                  color: AppColors.primaryBase,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (pkg.hasVulnerabilities) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Tooltip(
                          message:
                              'Security Advisory (${pkg.vulnerabilityIds.length} CVEs reported)',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.dangerBase.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppIcon(
                                  AppSvgIcon.radioactiveFill,
                                  size: 10,
                                  color: AppColors.dangerBase,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'CVE',
                                  style: AppTypography.tagline(
                                    color: AppColors.dangerBase,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Used in projects count
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Tooltip(
                        message:
                            'This package is declared across ${pkg.projectCount} separate project manifests',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryBase.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pkg.projectCount} ${pkg.projectCount == 1 ? 'project' : 'projects'}',
                            style: AppTypography.caption(
                              color: AppColors.primaryBase,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Version Discrepancies & Outdated Status
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      if (pkg.hasVersionDivergence)
                        Tooltip(
                          message:
                              'Version divergence detected! Different projects use differing versions of this package',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(right: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.warningBase.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Version Mismatch',
                              style: AppTypography.caption(
                                color: AppColors.warningBase,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      if (pkg.outdatedUsagesCount > 0)
                        Tooltip(
                          message:
                              '${pkg.outdatedUsagesCount} project usages are behind the latest version',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.warningBase.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${pkg.outdatedUsagesCount} need update',
                              style: AppTypography.caption(
                                color: AppColors.warningBase,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      else if (!pkg.hasVersionDivergence &&
                          pkg.latestVersion != null)
                        Tooltip(
                          message:
                              'All project usages match the latest registry version',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.successBase.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'All up to date',
                              style: AppTypography.caption(
                                color: AppColors.successBase,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Latest Version
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: pkg.latestVersion != null
                        ? 'Latest registry release: v${pkg.latestVersion}'
                        : 'Latest registry version not yet checked',
                    child: Text(
                      pkg.latestVersion != null
                          ? 'v${pkg.latestVersion}'
                          : 'Checking...',
                      style: AppTypography.caption(
                        color: pkg.latestVersion != null
                            ? AppColors.neutral4
                            : AppColors.neutral6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // Open repository page if available
                if (pkg.repositoryUrl != null)
                  Tooltip(
                    message:
                        'Open repository in web browser (${pkg.repositoryUrl})',
                    child: InkWell(
                      onTap: () => onOpenUrl(pkg.repositoryUrl!),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: const AppIcon(
                          AppSvgIcon.arrowSquareOutDuotone,
                          size: 14,
                          color: AppColors.neutral6,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 26),
              ],
            ),
          ),
        ),

        // Expanded Cross-Project Matrix Subtable
        if (isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.neutral13.withValues(alpha: 0.6),
              border: const Border(
                top: BorderSide(color: AppColors.neutral11, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description if available
                if (pkg.description != null && pkg.description!.isNotEmpty) ...[
                  Tooltip(
                    message: 'Package description from registry',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: ShapeDecoration(
                        color: AppColors.neutral12,
                        shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.neutral10),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppIcon(
                            AppSvgIcon.chat,
                            size: 14,
                            color: AppColors.primaryBase,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              pkg.description!,
                              style: AppTypography.caption(
                                color: AppColors.neutral4,
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Subtable Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.neutral11,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Project',
                          style: AppTypography.tagline(
                            color: AppColors.neutral6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Manifest',
                          style: AppTypography.tagline(
                            color: AppColors.neutral6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Current Version',
                          style: AppTypography.tagline(
                            color: AppColors.neutral6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 80),
                    ],
                  ),
                ),

                // Subtable project rows
                ...pkg.usages.map((usage) {
                  final upgradeCmd = generateUpgradeCommand(
                    pkg.ecosystem,
                    pkg.name,
                    usage.isDev,
                  );

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.neutral11,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Project Name & Path
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Tooltip(
                                message: 'Project: ${usage.projectName}',
                                child: Text(
                                  usage.projectName,
                                  style: AppTypography.body(
                                    color: AppColors.neutral4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Tooltip(
                                message: 'Project directory: ${usage.projectPath}',
                                child: Text(
                                  usage.projectPath,
                                  style: AppTypography.tagline(
                                    color: AppColors.neutral6,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Manifest
                        Expanded(
                          flex: 3,
                          child: Tooltip(
                            message: 'Manifest file: ${usage.manifestRelativePath}',
                            child: Text(
                              usage.manifestRelativePath,
                              style: AppTypography.caption(
                                color: AppColors.neutral4,
                              ),
                            ),
                          ),
                        ),

                        // Current Version
                        Expanded(
                          flex: 2,
                          child: Tooltip(
                            message: 'Declared constraint: ${usage.currentConstraint}',
                            child: Text(
                              usage.currentConstraint,
                              style: AppTypography.caption(
                                color: AppColors.neutral4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        // Upgrade action
                        Tooltip(
                          message:
                              'Click to copy upgrade command for this project ($upgradeCmd)',
                          child: InkWell(
                            onTap: () => onCopy(
                              upgradeCmd,
                              'Copied: $upgradeCmd',
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.neutral10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const AppIcon(
                                    AppSvgIcon.terminal,
                                    size: 11,
                                    color: AppColors.primaryBase,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Upgrade',
                                    style: AppTypography.tagline(
                                      color: AppColors.primaryBase,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    ),
  );
}