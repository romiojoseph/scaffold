import 'package:flutter/material.dart';
import '../../models/dependency_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../common/app_icon.dart';
import 'dependency_status_widget.dart';

Widget dependencyRow({
  required DependencyItem dep,
  required bool isEven,
  required bool isExpanded,
  required VoidCallback onToggle,
  required void Function(String text, String message) onCopy,
  required void Function(String url) onOpenUrl,
  required String Function(DateTime?) formatRelativeDate,
}) {
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
        // Main Collapsible Row
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                // Caret Icon styled consistently with git_commit_card
                Tooltip(
                  message: isExpanded
                      ? 'Click to collapse package details'
                      : 'Click to expand package details, security notes, and repository links',
                  child: AppIcon(
                    isExpanded
                        ? AppSvgIcon.caretDownBold
                        : AppSvgIcon.caretRightBold,
                    size: 16,
                    color: AppColors.primaryBase,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Package name + Dev badge + CVE warning icon
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Package: ${dep.name}',
                        child: Text(
                          dep.name,
                          style: AppTypography.body(
                            color: AppColors.neutral4,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dep.isDev) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Tooltip(
                          message:
                              'Development dependency (used only during development and testing)',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.neutral10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'dev',
                              style: AppTypography.tagline(
                                color: AppColors.neutral6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (dep.hasVulnerabilities) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Tooltip(
                          message:
                              'Security Advisory (${dep.vulnerabilityIds.length} CVEs):\n${dep.vulnerabilityIds.join(", ")}\n${dep.vulnerabilitySummary ?? ""}',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBase.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppIcon(
                                  AppSvgIcon.radioactiveFill,
                                  size: 16,
                                  color: AppColors.dangerBase,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'CVE',
                                  style: AppTypography.caption(
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

                // Current Version constraint
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message:
                        'Declared version constraint in manifest: ${dep.currentConstraint}',
                    child: Text(
                      dep.currentConstraint,
                      style: AppTypography.caption(
                        color: AppColors.neutral5,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Status & Latest Version
                Expanded(flex: 4, child: dependencyStatusWidget(dep)),

                // Published Date / Staleness
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: dep.latestPublishedAt != null
                        ? 'Latest release published: ${FormatUtils.formatDateTimeIso12h(dep.latestPublishedAt!)}'
                        : 'Release publish date unknown',
                    child: Text(
                      formatRelativeDate(dep.latestPublishedAt),
                      style: AppTypography.caption(
                        color: AppColors.neutral6,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Action buttons (Copy CLI Command + Copy constraint + open URL)
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message:
                            'Copy CLI upgrade command to clipboard (${dep.cliUpgradeCommand})',
                        child: InkWell(
                          onTap: () => onCopy(
                            dep.cliUpgradeCommand,
                            'Copied: ${dep.cliUpgradeCommand}',
                          ),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: const AppIcon(
                              AppSvgIcon.terminal,
                              size: 14,
                              color: AppColors.neutral6,
                            ),
                          ),
                        ),
                      ),
                      if (dep.latestVersion != null)
                        Tooltip(
                          message:
                              'Copy version constraint (^${dep.latestVersion}) to clipboard',
                          child: InkWell(
                            onTap: () => onCopy(
                              '^${dep.latestVersion}',
                              'Copied ^${dep.latestVersion} to clipboard',
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: const AppIcon(
                                AppSvgIcon.copy,
                                size: 14,
                                color: AppColors.neutral6,
                              ),
                            ),
                          ),
                        ),
                      if (dep.packageUrl != null)
                        Tooltip(
                          message:
                              'Open package page in web browser (${dep.packageUrl})',
                          child: InkWell(
                            onTap: () => onOpenUrl(dep.packageUrl!),
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
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded Accordion Details Panel
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
                // Release Description / Message Box
                if (dep.description != null && dep.description!.isNotEmpty) ...[
                  Tooltip(
                    message: 'Package description from registry',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
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
                              dep.description!,
                              style: AppTypography.caption(
                                color: AppColors.neutral4,
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Security Advisory Detail Block if CVEs exist
                if (dep.hasVulnerabilities) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: ShapeDecoration(
                      color: AppColors.dangerBase.withValues(alpha: 0.1),
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: AppColors.dangerBase.withValues(alpha: 0.16),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppIcon(
                              AppSvgIcon.shieldWarningFill,
                              size: 18,
                              color: AppColors.dangerBase,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Security Vulnerability Advisories (${dep.vulnerabilityIds.length}):',
                              style: AppTypography.body(
                                color: AppColors.dangerLight.withValues(
                                  alpha: 0.8,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dep.vulnerabilityIds.join(', '),
                          style: AppTypography.caption(
                            color: AppColors.dangerLight.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (dep.vulnerabilitySummary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            dep.vulnerabilitySummary!,
                            style: AppTypography.caption(
                              color: AppColors.dangerLight.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Links, License, and Upgrade Command Bar
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // License Badge
                    if (dep.license != null && dep.license!.isNotEmpty)
                      Tooltip(
                        message: 'Open source license: ${dep.license}',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neutral10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'License: ${dep.license}',
                            style: AppTypography.tagline(
                              color: AppColors.neutral5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                    // Repository Link Button
                    if (dep.repositoryUrl != null)
                      Tooltip(
                        message:
                            'Open repository in browser (${dep.repositoryUrl})',
                        child: InkWell(
                          onTap: () => onOpenUrl(dep.repositoryUrl!),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBase.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppIcon(
                                  AppSvgIcon.code,
                                  size: 12,
                                  color: AppColors.primaryBase,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Repository',
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

                    // Changelog Link Button
                    if (dep.changelogUrl != null)
                      Tooltip(
                        message:
                            'Open changelog / release notes in browser (${dep.changelogUrl})',
                        child: InkWell(
                          onTap: () => onOpenUrl(dep.changelogUrl!),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.infoBase.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppIcon(
                                  AppSvgIcon.listNumbers,
                                  size: 12,
                                  color: AppColors.infoBase,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Changelog / Release Notes',
                                  style: AppTypography.tagline(
                                    color: AppColors.infoBase,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // CLI Command Copy snippet
                    Tooltip(
                      message:
                          'Click to copy upgrade command (${dep.cliUpgradeCommand})',
                      child: InkWell(
                        onTap: () => onCopy(
                          dep.cliUpgradeCommand,
                          'Copied: ${dep.cliUpgradeCommand}',
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neutral11,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.neutral10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppIcon(
                                AppSvgIcon.terminal,
                                size: 12,
                                color: AppColors.neutral6,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dep.cliUpgradeCommand,
                                style: AppTypography.tagline(
                                  color: AppColors.neutral4,
                                  fontWeight: FontWeight.w500,
                                ).copyWith(fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
