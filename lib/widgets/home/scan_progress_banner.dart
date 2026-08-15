import 'package:flutter/material.dart';
import '../../services/scanner_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

int scanStageNumber(ScanStage stage) {
  switch (stage) {
    case ScanStage.initializing:
      return 1;
    case ScanStage.readingExclusions:
      return 2;
    case ScanStage.analyzingCode:
      return 3;
    case ScanStage.scanningFiles:
      return 4;
    case ScanStage.processingResults:
      return 5;
  }
}

Widget scanProgressBanner(ScanProgress? progress) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm + 2,
    ),
    decoration: const BoxDecoration(
      color: AppColors.neutral12,
      border: Border(
        bottom: BorderSide(color: AppColors.neutral11),
      ),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primaryBase,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs + 2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryBase.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            progress != null
                ? 'Stage ${scanStageNumber(progress.stage)}/5'
                : 'SCANNING',
            style: AppTypography.tagline(
              color: AppColors.primaryBase,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            progress?.message ?? 'Scanning directory in progress...',
            style: AppTypography.caption(
              color: AppColors.neutral3,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}