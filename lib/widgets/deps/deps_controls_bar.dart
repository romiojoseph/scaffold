import 'package:flutter/material.dart';
import '../../models/dependency_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_button.dart';
import '../common/app_icon.dart';
import '../common/app_segmented_control.dart';
import '../common/app_text_field.dart';

Widget depsControlsBar({
  required TextEditingController searchController,
  required String searchFilter,
  required ValueChanged<String> onFilterChanged,
  required bool showOutdatedOnly,
  required VoidCallback onOutdatedToggled,
  required bool showVulnerableOnly,
  required VoidCallback onVulnerableToggled,
  required bool isChecking,
  required VoidCallback? onCheckUpdates,
}) {
  return Row(
    children: [
      Expanded(
        child: AppTextField(
          controller: searchController,
          hintText: 'Search packages, manifests, or descriptions...',
          svgPrefixIcon: AppSvgIcon.magnifyingGlass,
          size: AppInputSize.medium,
          onChanged: (val) => onFilterChanged(val.trim().toLowerCase()),
          suffixIcon: searchFilter.isNotEmpty
              ? Tooltip(
                  message: 'Clear search filter',
                  child: IconButton(
                    icon: const AppIcon(
                      AppSvgIcon.xBold,
                      size: 14,
                      color: AppColors.neutral6,
                    ),
                    onPressed: () {
                      searchController.clear();
                      onFilterChanged('');
                    },
                  ),
                )
              : null,
        ),
      ),
      const SizedBox(width: AppSpacing.md),

      // Outdated only Toggle Button (Medium Size with toggleLeft / toggleRight)
      Tooltip(
        message: showOutdatedOnly
            ? 'Showing only outdated packages (Click to show all)'
            : 'Filter to show only packages that have newer versions available in registries',
        child: InkWell(
          onTap: onOutdatedToggled,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: ShapeDecoration(
              color: showOutdatedOnly
                  ? AppColors.warningBase.withValues(alpha: 0.18)
                  : AppColors.neutral12,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: showOutdatedOnly
                      ? AppColors.warningBase.withValues(alpha: 0.5)
                      : AppColors.neutral11,
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  showOutdatedOnly
                      ? AppSvgIcon.toggleRight
                      : AppSvgIcon.toggleLeft,
                  size: 18,
                  color: showOutdatedOnly
                      ? AppColors.warningBase
                      : AppColors.neutral6,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Outdated',
                  style: AppTypography.body(
                    color: showOutdatedOnly
                        ? AppColors.warningBase
                        : AppColors.neutral4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),

      // Vulnerable only Toggle Button (Medium Size with toggleLeft / toggleRight)
      Tooltip(
        message: showVulnerableOnly
            ? 'Showing only vulnerable packages (Click to show all)'
            : 'Filter to show only packages with known security advisories (CVEs)',
        child: InkWell(
          onTap: onVulnerableToggled,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: ShapeDecoration(
              color: showVulnerableOnly
                  ? AppColors.dangerBase.withValues(alpha: 0.18)
                  : AppColors.neutral12,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: showVulnerableOnly
                      ? AppColors.dangerBase.withValues(alpha: 0.5)
                      : AppColors.neutral11,
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  showVulnerableOnly
                      ? AppSvgIcon.toggleRight
                      : AppSvgIcon.toggleLeft,
                  size: 18,
                  color: showVulnerableOnly
                      ? AppColors.dangerBase
                      : AppColors.neutral6,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Vulnerable',
                  style: AppTypography.body(
                    color: showVulnerableOnly
                        ? AppColors.dangerBase
                        : AppColors.neutral4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.md),

      // Check / Refresh Action (Medium Size)
      Tooltip(
        message: isChecking
            ? 'Currently checking remote registries...'
            : 'Query registries to check for package updates and security advisories',
        child: AppButton(
          label: isChecking ? 'Checking...' : 'Check Updates',
          svgIcon: AppSvgIcon.arrowCounterClockwise,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.medium,
          isLoading: isChecking,
          onPressed: onCheckUpdates,
        ),
      ),
    ],
  );
}

Widget depsEcosystemChips({
  required List<ManifestFile> manifests,
  required Ecosystem? selectedEcosystemFilter,
  required ValueChanged<Ecosystem?> onEcosystemSelected,
}) {
  final activeEcosystems = Ecosystem.values
      .where((eco) => manifests.any((m) => m.ecosystem == eco))
      .toList();

  final items = <AppSegmentedItem<Ecosystem?>>[
    AppSegmentedItem<Ecosystem?>(
      value: null,
      label: 'All Ecosystems (${manifests.length})',
      tooltip: 'Show dependencies from all package ecosystems (${manifests.length} manifests)',
    ),
    ...activeEcosystems.map((eco) {
      final count = manifests.where((m) => m.ecosystem == eco).length;
      return AppSegmentedItem<Ecosystem?>(
        value: eco,
        label: '${eco.label} ($count)',
        tooltip: 'Filter to ${eco.label} packages ($count manifests detected)',
      );
    }),
  ];

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: AppSegmentedControl<Ecosystem?>(
      selectedValue: selectedEcosystemFilter,
      items: items,
      onValueChanged: onEcosystemSelected,
    ),
  );
}