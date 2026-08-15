import 'package:flutter/material.dart';
import '../../models/dependency_info.dart';
import '../../services/global_dependency_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'global_package_row.dart';

Widget globalMatrixContainer({
  required List<GlobalPackageGroup> packages,
  required bool Function(GlobalPackageGroup pkg) isExpanded,
  required ValueChanged<GlobalPackageGroup> onToggle,
  required void Function(String text, String message) onCopy,
  required void Function(String url) onOpenUrl,
  required String Function(Ecosystem ecosystem, String packageName, bool isDev)
  generateUpgradeCommand,
}) {
  return Container(
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
        // Table Header
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
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: Text(
                  'Package / Ecosystem',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Used In Projects',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Cross-Project Versions / Status',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Latest Version',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 26),
            ],
          ),
        ),

        // Package Rows
        ...List.generate(packages.length, (index) {
          final pkg = packages[index];
          return globalPackageRow(
            pkg: pkg,
            isEven: index % 2 == 0,
            isExpanded: isExpanded(pkg),
            onToggle: () => onToggle(pkg),
            onCopy: onCopy,
            onOpenUrl: onOpenUrl,
            generateUpgradeCommand: generateUpgradeCommand,
          );
        }),
      ],
    ),
  );
}
