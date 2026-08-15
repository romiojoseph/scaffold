import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/fs_node.dart';
import '../../models/thresholds_config.dart';
import '../../services/icon_mapping_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../common/app_icon.dart';
import '../common/node_context_menu.dart';
import '../viewers/file_viewer_page.dart';
import 'language_stats.dart';

Widget languageBreakdownTable({
  required BuildContext context,
  required List<LanguageStats> sortedLanguages,
  required Set<String> expandedLanguages,
  required ValueChanged<String> onToggleLanguage,
  required int Function(FsNode file) estimateFileTokens,
  required String Function(String fullPath) getRelativePath,
  required ThresholdsConfig thresholdsConfig,
  required String rootPath,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header Row
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.neutral10.withValues(alpha: 0.64),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                'Language',
                style: AppTypography.body(
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral0,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Files',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral0,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Total Lines',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral0,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Code',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontWeight: FontWeight.bold,
                  color: AppColors.successBase,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Comments',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontWeight: FontWeight.bold,
                  color: AppColors.infoBase,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Blanks',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral6,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Est. Tokens',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBase,
                ),
              ),
            ),
          ],
        ),
      ),

      if (sortedLanguages.isEmpty)
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.neutral11,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(10),
            ),
            border: Border.all(color: AppColors.neutral10),
          ),
          child: Center(
            child: Text(
              'No code files detected in this directory.',
              style: AppTypography.body(color: AppColors.neutral6),
            ),
          ),
        )
      else
        ...List.generate(sortedLanguages.length, (index) {
          final group = sortedLanguages[index];
          final isExpanded = expandedLanguages.contains(group.language);
          final isLast = index == sortedLanguages.length - 1;

          return Container(
            decoration: BoxDecoration(
              color: index % 2 == 0
                  ? AppColors.neutral11.withValues(alpha: 0.5)
                  : AppColors.neutral12.withValues(alpha: 0.2),
              borderRadius: isLast && !isExpanded
                  ? const BorderRadius.vertical(bottom: Radius.circular(10))
                  : BorderRadius.zero,
              border: Border(
                left: const BorderSide(color: AppColors.neutral10),
                right: const BorderSide(color: AppColors.neutral10),
                bottom: BorderSide(
                  color: AppColors.neutral10,
                  width: isLast && !isExpanded ? 1 : 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => onToggleLanguage(group.language),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              AppIcon(
                                isExpanded
                                    ? AppSvgIcon.caretDownBold
                                    : AppSvgIcon.caretRightBold,
                                size: 16,
                                color: AppColors.primaryBase,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  group.language,
                                  style: AppTypography.body(
                                    color: AppColors.neutral3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            FormatUtils.formatNumber(group.files.length),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              color: AppColors.neutral3,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            FormatUtils.formatNumber(group.lines),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              color: AppColors.neutral0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            FormatUtils.formatNumber(group.code),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              color: AppColors.successBase,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            FormatUtils.formatNumber(group.comments),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              color: AppColors.infoBase,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            FormatUtils.formatNumber(group.blanks),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              color: AppColors.neutral6,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            FormatUtils.formatNumber(
                              group.files.fold<int>(
                                0,
                                (sum, file) =>
                                    sum + estimateFileTokens(file),
                              ),
                            ),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              color: AppColors.primaryBase,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  Container(
                    color: AppColors.neutral13,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: group.files.map((file) {
                        final iconSvg = IconMappingConfig.instance
                            .getIconForExtension(file.extension);
                        final threshold = thresholdsConfig
                            .getThreshold(file.extension);
                        final isExceeded = file.lineCount > threshold;
                        final excessPercent = isExceeded
                            ? ((file.lineCount - threshold) / threshold * 100)
                                  .toStringAsFixed(0)
                            : null;

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FileViewerPage(node: file),
                              ),
                            );
                          },
                          onSecondaryTapDown: (details) =>
                              NodeContextMenu.show(
                                context: context,
                                globalPosition: details.globalPosition,
                                node: file,
                                rootPath: rootPath,
                              ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isExceeded
                                  ? AppColors.dangerBase.withValues(
                                      alpha: 0.12,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 18),
                                    child: Row(
                                      children: [
                                        SvgPicture.asset(
                                          'assets/mapping/$iconSvg',
                                          width: 14,
                                          height: 14,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                file.name,
                                                style: AppTypography.subtitle(
                                                  color: isExceeded
                                                      ? AppColors.dangerBase
                                                      : AppColors.neutral4,
                                                  fontWeight: isExceeded
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                getRelativePath(file.path),
                                                style: AppTypography.label(
                                                  color: AppColors.neutral7,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isExceeded) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.dangerBase
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: AppColors.dangerBase
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Text(
                                              '+$excessPercent% over limit ($threshold)',
                                              style: AppTypography.caption(
                                                color: AppColors.dangerHover,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '1',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.neutral6,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(file.lineCount),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: isExceeded
                                          ? AppColors.dangerBase
                                          : AppColors.neutral4,
                                      fontWeight: isExceeded
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(
                                      file.codeLineCount,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.successBase,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(
                                      file.commentLineCount,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.infoBase,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(
                                      file.blankLineCount,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.neutral6,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(
                                      estimateFileTokens(file),
                                    ),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.primaryBase,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }),
    ],
  );
}