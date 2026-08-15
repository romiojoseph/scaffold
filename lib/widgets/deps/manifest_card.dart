import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/dependency_info.dart';
import '../../services/icon_mapping_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';
import 'dependency_row.dart';

Widget manifestCard({
  required ManifestFile manifest,
  required String relPath,
  required bool Function(String key) isExpanded,
  required ValueChanged<String> onToggle,
  required void Function(String text, String message) onCopy,
  required void Function(String url) onOpenUrl,
  required String Function(DateTime?) formatRelativeDate,
}) {
  final batchCommand = manifest.batchUpgradeCommand;
  final ecoIconSvg = IconMappingConfig.instance.getIconForExtension(
    manifest.ecosystem.defaultExtension,
  );

  return Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
    decoration: ShapeDecoration(
      color: AppColors.neutral13,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.neutral11, width: 1.5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Manifest Card Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: ShapeDecoration(
            color: AppColors.neutral12,
            shape: const ContinuousRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              side: BorderSide(color: AppColors.neutral11, width: 1),
            ),
          ),
          child: Row(
            children: [
              Tooltip(
                message: 'Manifest file: $relPath',
                child: SvgPicture.asset(
                  'assets/mapping/$ecoIconSvg',
                  width: 20,
                  height: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Tooltip(
                message: '${manifest.ecosystem.label} package ecosystem',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      manifest.ecosystem.label,
                      style: AppTypography.body(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Tooltip(
                  message: 'Relative manifest path: $relPath',
                  child: Text(
                    relPath,
                    style: AppTypography.body(
                      color: AppColors.neutral4,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (manifest.vulnerableCount > 0)
                Tooltip(
                  message:
                      '${manifest.vulnerableCount} packages in this manifest have reported security vulnerabilities',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBase.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${manifest.vulnerableCount} vulnerable',
                      style: AppTypography.caption(
                        color: AppColors.dangerBase,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              if (manifest.outdatedCount > 0) ...[
                Tooltip(
                  message:
                      '${manifest.outdatedCount} packages in this manifest can be upgraded to newer versions',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.warningBase.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${manifest.outdatedCount} outdated',
                      style: AppTypography.caption(
                        color: AppColors.warningBase,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (batchCommand.isNotEmpty)
                  Tooltip(
                    message:
                        'Copy terminal command to upgrade all outdated packages at once:\n$batchCommand',
                    child: InkWell(
                      onTap: () => onCopy(
                        batchCommand,
                        'Copied upgrade command to clipboard',
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBase.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(
                              AppSvgIcon.terminal,
                              size: 12,
                              color: AppColors.primaryBase,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Copy Upgrade Command',
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
              Tooltip(
                message:
                    'Total of ${manifest.totalDependencies} dependencies declared in this file',
                child: Text(
                  '${manifest.totalDependencies} ${manifest.totalDependencies == 1 ? 'pkg' : 'pkgs'}',
                  style: AppTypography.caption(color: AppColors.neutral6),
                ),
              ),
            ],
          ),
        ),

        // Packages Table Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 8,
          ),
          color: AppColors.neutral13.withValues(alpha: 0.5),
          child: Row(
            children: [
              const SizedBox(width: 24), // accordion chevron space
              Expanded(
                flex: 4,
                child: Text(
                  'Package',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Current',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Latest / Status',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Published',
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

        // Dependencies rows
        ...List.generate(manifest.dependencies.length, (index) {
          final dep = manifest.dependencies[index];
          return dependencyRow(
            dep: dep,
            isEven: index % 2 == 0,
            isExpanded: isExpanded('${dep.manifestPath}:${dep.name}'),
            onToggle: () => onToggle('${dep.manifestPath}:${dep.name}'),
            onCopy: onCopy,
            onOpenUrl: onOpenUrl,
            formatRelativeDate: formatRelativeDate,
          );
        }),
      ],
    ),
  );
}
