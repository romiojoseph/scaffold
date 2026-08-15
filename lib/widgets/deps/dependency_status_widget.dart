import 'package:flutter/material.dart';
import '../../models/dependency_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';

Widget dependencyStatusWidget(DependencyItem dep) {
  switch (dep.status) {
    case DependencyStatus.checking:
      return Tooltip(
        message: 'Querying remote package registry for latest metadata...',
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.neutral6),
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              'Checking registry...',
              style: AppTypography.tagline(
                color: AppColors.neutral6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

    case DependencyStatus.outdated:
      return Tooltip(
        message:
            'Newer version v${dep.latestVersion} available (current constraint: ${dep.currentConstraint})',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningBase.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(
                    AppSvgIcon.arrowUpFill,
                    size: 10,
                    color: AppColors.warningBase,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'v${dep.latestVersion}',
                    style: AppTypography.caption(
                      color: AppColors.warningBase,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

    case DependencyStatus.upToDate:
      return Tooltip(
        message:
            'Up to date! Latest available release is v${dep.latestVersion ?? "latest"}',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.successBase.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(
                    AppSvgIcon.checkBold,
                    size: 10,
                    color: AppColors.successBase,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'v${dep.latestVersion ?? 'latest'}',
                    style: AppTypography.caption(
                      color: AppColors.successBase,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

    case DependencyStatus.error:
      return Tooltip(
        message: 'Registry error: ${dep.errorMessage ?? "Package not found"}',
        child: Text(
          dep.errorMessage ?? 'Not found in registry',
          style: AppTypography.tagline(
            color: AppColors.dangerBase,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );

    case DependencyStatus.idle:
      return Tooltip(
        message: 'Pending background registry version check',
        child: Text(
          'Pending check',
          style: AppTypography.tagline(
            color: AppColors.neutral7,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
  }
}
