import 'package:flutter/material.dart';
import '../../models/fs_node.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';

Widget hashStatCards({
  required int totalFiles,
  required int totalSizeBytes,
  required int hashedCount,
}) {
  return Row(
    children: [
      _buildCard(
        icon: AppSvgIcon.filesFill,
        color: AppColors.primaryBase,
        title: '$totalFiles',
        subtitle: 'Selected Files',
      ),
      const SizedBox(width: AppSpacing.md),
      _buildCard(
        icon: AppSvgIcon.hardDrivesFill,
        color: AppColors.infoBase,
        title: FsNode.formatBytes(totalSizeBytes),
        subtitle: 'Total Size',
      ),
      const SizedBox(width: AppSpacing.md),
      _buildCard(
        icon: AppSvgIcon.passwordFill,
        color: AppColors.successBase,
        title: '$hashedCount / $totalFiles',
        subtitle: 'Hashed Files',
      ),
    ],
  );
}

Widget _buildCard({
  required AppSvgIcon icon,
  required Color color,
  required String title,
  required String subtitle,
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
            child: AppIcon(icon, size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: AppTypography.caption(color: AppColors.neutral6),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
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
