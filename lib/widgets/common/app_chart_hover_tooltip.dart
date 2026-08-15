import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_icon.dart';

class ChartTooltipItem {
  final String label;
  final String value;
  final Color valueColor;

  const ChartTooltipItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });
}

class AppChartHoverTooltip extends StatelessWidget {
  final Offset mousePosition;
  final double chartWidth;
  final String title;
  final AppSvgIcon titleIcon;
  final Color titleIconColor;
  final List<ChartTooltipItem> items;
  final double tooltipWidth;

  const AppChartHoverTooltip({
    super.key,
    required this.mousePosition,
    required this.chartWidth,
    required this.title,
    this.titleIcon = AppSvgIcon.sparkleDuotone,
    this.titleIconColor = AppColors.primaryBase,
    required this.items,
    this.tooltipWidth = 240.0,
  });

  @override
  Widget build(BuildContext context) {
    final left = (mousePosition.dx - (tooltipWidth / 2))
        .clamp(10.0, math.max(10.0, chartWidth - tooltipWidth - 10.0))
        .toDouble();
    final top = mousePosition.dy < 130
        ? (mousePosition.dy + 16.0)
        : (mousePosition.dy - 135.0);

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: ShapeDecoration(
            color: AppColors.neutral12,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.neutral11, width: 1.5),
            ),
            shadows: [
              BoxShadow(
                color: AppColors.neutral13.withValues(alpha: 0.85),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.body(
                        color: AppColors.neutral4,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Divider(color: AppColors.neutral10, height: 1),
              const SizedBox(height: AppSpacing.xs),
              ...items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: AppTypography.body(color: AppColors.neutral6),
                      ),
                      Text(
                        item.value,
                        style: AppTypography.body(
                          color: item.valueColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
