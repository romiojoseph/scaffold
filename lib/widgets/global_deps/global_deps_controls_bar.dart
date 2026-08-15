import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';
import '../common/app_text_field.dart';

Widget globalDepsControlsBar({
  required TextEditingController searchController,
  required String searchFilter,
  required ValueChanged<String> onFilterChanged,
  required bool showDivergentOnly,
  required VoidCallback onDivergentToggled,
  required bool showOutdatedOnly,
  required VoidCallback onOutdatedToggled,
  required bool showVulnerableOnly,
  required VoidCallback onVulnerableToggled,
}) {
  return Row(
    children: [
      Expanded(
        child: AppTextField(
          controller: searchController,
          hintText:
              'Search across all packages, projects, or descriptions...',
          svgPrefixIcon: AppSvgIcon.magnifyingGlass,
          size: AppInputSize.medium,
          onChanged: (val) => onFilterChanged(val.trim().toLowerCase()),
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
      const SizedBox(width: AppSpacing.md),

      // Mismatch Only Toggle
      _globalToggle(
        label: 'Version Mismatch',
        active: showDivergentOnly,
        activeColor: AppColors.warningBase,
        onTap: onDivergentToggled,
      ),
      const SizedBox(width: AppSpacing.sm),

      // Outdated Only Toggle
      _globalToggle(
        label: 'Outdated',
        active: showOutdatedOnly,
        activeColor: AppColors.warningBase,
        onTap: onOutdatedToggled,
      ),
      const SizedBox(width: AppSpacing.sm),

      // Vulnerable Only Toggle
      _globalToggle(
        label: 'Vulnerable',
        active: showVulnerableOnly,
        activeColor: AppColors.dangerBase,
        onTap: onVulnerableToggled,
      ),
    ],
  );
}

Widget _globalToggle({
  required String label,
  required bool active,
  required Color activeColor,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: ShapeDecoration(
        color: active
            ? activeColor.withValues(alpha: 0.18)
            : AppColors.neutral12,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: active
                ? activeColor.withValues(alpha: 0.5)
                : AppColors.neutral11,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            active ? AppSvgIcon.toggleRight : AppSvgIcon.toggleLeft,
            size: 18,
            color: active ? activeColor : AppColors.neutral6,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.body(
              color: active ? activeColor : AppColors.neutral4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}