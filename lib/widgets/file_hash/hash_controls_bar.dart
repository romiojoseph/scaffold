import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_button.dart';
import '../common/app_icon.dart';
import '../common/app_text_field.dart';

Widget hashControlsBar({
  required TextEditingController searchController,
  required String searchFilter,
  required ValueChanged<String> onFilterChanged,
  required VoidCallback onAddFiles,
  required VoidCallback onClearAll,
  required VoidCallback? onExportCsv,
  required VoidCallback? onExportJson,
  required bool excludeFilePathOnExport,
  required VoidCallback onToggleExcludeFilePath,
  required bool isHashing,
  required bool hasResults,
}) {
  return Row(
    children: [
      // Search Input using AppTextField
      Expanded(
        child: AppTextField(
          controller: searchController,
          hintText: 'Filter by filename or hash...',
          svgPrefixIcon: AppSvgIcon.magnifyingGlass,
          size: AppInputSize.medium,
          onChanged: onFilterChanged,
          suffixIcon: searchFilter.isNotEmpty
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
      const SizedBox(width: AppSpacing.lg),

      // Add Files Button
      AppButton(
        label: 'Add Files',
        svgIcon: AppSvgIcon.fileCode,
        variant: AppButtonVariant.primary,
        size: AppButtonSize.medium,
        isLoading: isHashing,
        onPressed: isHashing ? null : onAddFiles,
      ),
      const SizedBox(width: AppSpacing.lg),

      // Exclude File Path on Export Toggle Button (Matches Outdated/Vulnerable style)
      Tooltip(
        message: excludeFilePathOnExport
            ? 'File path will NOT be included in export (Click to include)'
            : 'Exclude full file path from CSV/JSON export',
        child: InkWell(
          onTap: onToggleExcludeFilePath,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: ShapeDecoration(
              color: excludeFilePathOnExport
                  ? AppColors.primaryBase.withValues(alpha: 0.18)
                  : AppColors.neutral12,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: excludeFilePathOnExport
                      ? AppColors.primaryBase.withValues(alpha: 0.5)
                      : AppColors.neutral11,
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  excludeFilePathOnExport
                      ? AppSvgIcon.toggleRight
                      : AppSvgIcon.toggleLeft,
                  size: 18,
                  color: excludeFilePathOnExport
                      ? AppColors.primaryBase
                      : AppColors.neutral6,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Exclude Path',
                  style: AppTypography.body(
                    color: excludeFilePathOnExport
                        ? AppColors.primaryBase
                        : AppColors.neutral4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.lg),

      // Export CSV
      AppButton(
        label: 'Export CSV',
        svgIcon: AppSvgIcon.download,
        variant: AppButtonVariant.ghost,
        size: AppButtonSize.medium,
        onPressed: hasResults && !isHashing ? onExportCsv : null,
      ),
      const SizedBox(width: AppSpacing.lg),

      // Export JSON
      AppButton(
        label: 'Export JSON',
        svgIcon: AppSvgIcon.download,
        variant: AppButtonVariant.ghost,
        size: AppButtonSize.medium,
        onPressed: hasResults && !isHashing ? onExportJson : null,
      ),
      const SizedBox(width: AppSpacing.lg),

      // Clear All Button
      AppButton(
        label: 'Clear All',
        svgIcon: AppSvgIcon.trash,
        variant: AppButtonVariant.ghost,
        size: AppButtonSize.medium,
        onPressed: hasResults && !isHashing ? onClearAll : null,
      ),
    ],
  );
}
