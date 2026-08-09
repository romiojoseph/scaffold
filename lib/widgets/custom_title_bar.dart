import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'common/app_icon.dart';
import 'common/app_button.dart';

class CustomTitleBar extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onFileOpenPressed;
  final VoidCallback? onComparePressed;
  final VoidCallback? onExportPressed;
  final VoidCallback? onOpenTerminalPressed;
  final VoidCallback? onOpenExplorerPressed;
  final bool hasResults;

  const CustomTitleBar({
    super.key,
    this.title = 'Scaffold',
    this.onMenuPressed,
    this.onSettingsPressed,
    this.onFileOpenPressed,
    this.onComparePressed,
    this.onExportPressed,
    this.onOpenTerminalPressed,
    this.onOpenExplorerPressed,
    this.hasResults = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: AppColors.neutral4,
      mouseOver: AppColors.neutral10,
      mouseDown: AppColors.neutral9,
      iconMouseOver: AppColors.neutral0,
      iconMouseDown: AppColors.neutral0,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: AppColors.neutral4,
      mouseOver: AppColors.dangerBase,
      mouseDown: AppColors.dangerBase,
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    return Container(
      height: 38,
      color: AppColors.neutral13,
      child: WindowTitleBarBox(
        child: Row(
          children: [
            if (onMenuPressed != null)
              IconButton(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 38),
                icon: const AppIcon(
                  AppSvgIcon.menuBold,
                  size: 18,
                  color: AppColors.neutral4,
                ),
                onPressed: onMenuPressed,
                tooltip: 'Recent History',
              ),
            const SizedBox(width: AppSpacing.md),
            Text(
              title,
              style: AppTypography.subtitle(
                color: AppColors.neutral4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Action items directly in top bar
            if (onSettingsPressed != null) ...[
              AppButton(
                label: 'Settings',
                svgIcon: AppSvgIcon.gearSix,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: onSettingsPressed,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: 'Open JSON',
                svgIcon: AppSvgIcon.fileCode,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: onFileOpenPressed,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: 'Compare Diff',
                svgIcon: AppSvgIcon.presentationChart,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: hasResults ? onComparePressed : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: 'Export JSON',
                svgIcon: AppSvgIcon.download,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: hasResults ? onExportPressed : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: 'Explorer',
                svgIcon: AppSvgIcon.folderOpen,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: onOpenExplorerPressed,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: 'Terminal',
                svgIcon: AppSvgIcon.terminal,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: onOpenTerminalPressed,
              ),
            ],
            Expanded(child: MoveWindow()),
            Row(
              children: [
                MinimizeWindowButton(colors: buttonColors),
                MaximizeWindowButton(colors: buttonColors),
                CloseWindowButton(colors: closeButtonColors),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
