import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_icon.dart';

class AppSegmentedItem<T> {
  final T value;
  final String label;
  final AppSvgIcon? svgIcon;
  final String? tooltip;

  const AppSegmentedItem({
    required this.value,
    required this.label,
    this.svgIcon,
    this.tooltip,
  });
}

class AppSegmentedControl<T> extends StatelessWidget {
  final T selectedValue;
  final List<AppSegmentedItem<T>> items;
  final ValueChanged<T> onValueChanged;

  const AppSegmentedControl({
    super.key,
    required this.selectedValue,
    required this.items,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.neutral12,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.neutral11, width: 2),
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isSelected = item.value == selectedValue;
          Widget button = InkWell(
            onTap: () => onValueChanged(item.value),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBase.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(
                        color: AppColors.primaryBase.withValues(alpha: 0.1),
                        width: 2,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.svgIcon != null) ...[
                    AppIcon(
                      item.svgIcon!,
                      size: 13,
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.neutral6,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    item.label,
                    style: AppTypography.label(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.neutral6,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );

          if (item.tooltip != null && item.tooltip!.isNotEmpty) {
            button = Tooltip(
              message: item.tooltip!,
              child: button,
            );
          }

          return button;
        }).toList(),
      ),
    );
  }
}
