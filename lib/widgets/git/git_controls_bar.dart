import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_button.dart';
import '../common/app_icon.dart';
import '../common/app_text_field.dart';
import 'git_sort_option.dart';

Widget gitControlsBar({
  required TextEditingController searchController,
  required String filter,
  required ValueChanged<String> onFilterChanged,
  required GitSortOption sortOption,
  required ValueChanged<GitSortOption> onSortChanged,
  required VoidCallback onRefresh,
}) {
  return Row(
    children: [
      Expanded(
        child: AppTextField(
          controller: searchController,
          hintText: 'Search by commit message, hash, author, or file...',
          svgPrefixIcon: AppSvgIcon.magnifyingGlass,
          size: AppInputSize.medium,
          onChanged: (val) => onFilterChanged(val.trim().toLowerCase()),
          suffixIcon: filter.isNotEmpty
              ? IconButton(
                  icon: const AppIcon(
                    AppSvgIcon.xBold,
                    size: 14,
                    color: AppColors.neutral6,
                  ),
                  onPressed: () {
                    searchController.clear();
                    onFilterChanged('');
                  },
                )
              : null,
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      PopupMenuButton<GitSortOption>(
        tooltip: 'Sort Commits',
        color: AppColors.neutral11,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.neutral10),
        ),
        initialValue: sortOption,
        onSelected: onSortChanged,
        itemBuilder: (context) => GitSortOption.values.map((option) {
          final isSelected = option == sortOption;
          return PopupMenuItem<GitSortOption>(
            value: option,
            child: Row(
              children: [
                AppIcon(
                  isSelected
                      ? AppSvgIcon.checkBold
                      : AppSvgIcon.funnelSimpleBold,
                  size: 16,
                  color: isSelected
                      ? AppColors.primaryBase
                      : AppColors.neutral6,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  option.label,
                  style: AppTypography.body(
                    color: isSelected
                        ? AppColors.primaryBase
                        : AppColors.neutral2,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: ShapeDecoration(
            color: AppColors.neutral12,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.neutral11, width: 2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(
                AppSvgIcon.listNumbers,
                size: 14,
                color: AppColors.neutral4,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                sortOption.label,
                style: AppTypography.body(
                  color: AppColors.neutral4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const AppIcon(
                AppSvgIcon.caretDownBold,
                size: 12,
                color: AppColors.neutral6,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      AppButton(
        label: 'Refresh',
        svgIcon: AppSvgIcon.arrowCounterClockwise,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.medium,
        onPressed: onRefresh,
      ),
    ],
  );
}
