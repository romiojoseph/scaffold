import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/fs_node.dart';
import '../../services/scanner_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';

Widget buildTotalsSummary({
  required ScanTotals totals,
  required int includedFiles,
  required int includedBytes,
}) {
  final excludedFiles = math.max(0, totals.files - includedFiles);
  final excludedBytes = math.max(0, totals.bytes - includedBytes);
  final diskFiles = math.max(includedFiles, totals.files);
  final diskBytes = math.max(includedBytes, totals.bytes);

  double shareOf(int count) =>
      diskFiles > 0 ? (count / diskFiles * 100) : 0.0;

  return Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.neutral12.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          child: Row(
            children: [
              const SizedBox(width: 10),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Scan Summary (exclusions applied)',
                  style: AppTypography.label(
                    color: AppColors.neutral7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  'Files',
                  textAlign: TextAlign.right,
                  style: AppTypography.label(
                    color: AppColors.neutral7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 80,
                child: Text(
                  'Size',
                  textAlign: TextAlign.right,
                  style: AppTypography.label(
                    color: AppColors.neutral7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 65,
                child: Text(
                  'Share',
                  textAlign: TextAlign.right,
                  style: AppTypography.label(
                    color: AppColors.neutral7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        buildTotalsRow(
          dotColor: AppColors.successBase,
          label: 'Included',
          files: includedFiles,
          bytes: includedBytes,
          share: shareOf(includedFiles),
          shareColor: AppColors.successBase,
        ),
        buildTotalsRow(
          dotColor: AppColors.warningBase,
          label: 'Excluded',
          files: excludedFiles,
          bytes: excludedBytes,
          share: shareOf(excludedFiles),
          shareColor: AppColors.warningBase,
        ),
        Container(
          margin: const EdgeInsets.only(top: AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.neutral10, width: 1),
            ),
          ),
          child: buildTotalsRow(
            dotColor: AppColors.neutral4,
            label: 'Total on disk',
            files: diskFiles,
            bytes: diskBytes,
            share: 100,
            shareColor: AppColors.neutral4,
            emphasized: true,
          ),
        ),
      ],
    ),
  );
}

Widget buildTotalsRow({
  required Color dotColor,
  required String label,
  required int files,
  required int bytes,
  required double share,
  required Color shareColor,
  bool emphasized = false,
}) {
  final labelStyle = AppTypography.body(
    color: emphasized ? AppColors.neutral3 : AppColors.neutral3,
    fontWeight: emphasized ? FontWeight.w500 : FontWeight.w500,
  );
  final valueStyle = AppTypography.body(
    color: emphasized ? AppColors.neutral3 : AppColors.neutral5,
    fontWeight: emphasized ? FontWeight.w500 : FontWeight.w500,
  );

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: labelStyle)),
        SizedBox(
          width: 100,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${FormatUtils.formatNumber(files)} ${files == 1 ? 'file' : 'files'}',
              textAlign: TextAlign.right,
              style: valueStyle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 80,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              FsNode.formatBytes(bytes),
              textAlign: TextAlign.right,
              style: valueStyle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 65,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${share.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: AppTypography.caption(
                color: shareColor,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}