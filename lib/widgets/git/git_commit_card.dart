import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/git_commit.dart';
import '../../services/icon_mapping_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../common/app_button.dart';
import '../common/app_icon.dart';
import '../common/app_markdown_text.dart';
import 'git_file_status_badge.dart';

Widget gitCommitCard({
  required GitCommit commit,
  required bool isExpanded,
  required bool isFirst,
  required bool isLast,
  required int index,
  required VoidCallback onToggle,
  required void Function(String text, String message) onCopy,
  required void Function(String url) onOpenUrl,
}) {
  return Container(
    decoration: BoxDecoration(
      color: index % 2 == 0
          ? AppColors.neutral11.withValues(alpha: 0.5)
          : AppColors.neutral12.withValues(alpha: 0.2),
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(10) : Radius.zero,
        bottom: isLast && !isExpanded ? const Radius.circular(10) : Radius.zero,
      ),
      border: Border(
        top: isFirst
            ? const BorderSide(color: AppColors.neutral10)
            : BorderSide.none,
        left: const BorderSide(color: AppColors.neutral10),
        right: const BorderSide(color: AppColors.neutral10),
        bottom: BorderSide(
          color: AppColors.neutral10,
          width: isLast && !isExpanded ? 1 : 0.5,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header / Accordion trigger
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Caret
                AppIcon(
                  isExpanded
                      ? AppSvgIcon.caretDownBold
                      : AppSvgIcon.caretRightBold,
                  size: 16,
                  color: AppColors.primaryBase,
                ),
                const SizedBox(width: AppSpacing.sm),

                // Short Hash badge
                Tooltip(
                  message: 'Click to copy short hash (${commit.shortHash})',
                  child: InkWell(
                    onTap: () => onCopy(
                      commit.shortHash,
                      'Short hash copied to clipboard',
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neutral10,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.neutral9,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        commit.shortHash,
                        style: AppTypography.caption(
                          color: AppColors.primaryBase,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Message, author and relative time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (commit.isMerge) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              margin: const EdgeInsets.only(
                                right: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFA855F7,
                                ).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(
                                    0xFFA855F7,
                                  ).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                'Merge',
                                style: AppTypography.tagline(
                                  color: const Color(0xFFA855F7),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              commit.message,
                              style: AppTypography.subtitle(
                                color: AppColors.neutral4,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            commit.author,
                            style: AppTypography.body(
                              color: AppColors.neutral6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '•',
                            style: AppTypography.body(
                              color: AppColors.neutral7,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            commit.relativeDate,
                            style: AppTypography.body(
                              color: AppColors.neutral6,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '(${FormatUtils.formatDateTimeIso12h(commit.date)})',
                            style: AppTypography.label(
                              color: AppColors.neutral7,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Additions badge
                if (commit.totalAdditions > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.successBase.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${FormatUtils.formatNumber(commit.totalAdditions)}',
                      style: AppTypography.body(
                        color: AppColors.successBase,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(width: AppSpacing.xs),

                // Deletions badge
                if (commit.totalDeletions > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBase.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-${FormatUtils.formatNumber(commit.totalDeletions)}',
                      style: AppTypography.body(
                        color: AppColors.dangerBase,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(width: AppSpacing.xs),

                // Files count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neutral10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${commit.files.length} ${commit.files.length == 1 ? 'file' : 'files'}',
                    style: AppTypography.body(color: AppColors.neutral5),
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),

                // Commit remote link button if available
                if (commit.commitUrl != null)
                  Tooltip(
                    message: 'Open commit in browser',
                    child: InkWell(
                      onTap: () => onOpenUrl(commit.commitUrl!),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neutral10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const AppIcon(
                          AppSvgIcon.arrowSquareOutDuotone,
                          size: 14,
                          color: AppColors.primaryBase,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Expanded Details Section (Accordion Body)
        if (isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.neutral13,
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(10))
                  : BorderRadius.zero,
              border: const Border(
                top: BorderSide(color: AppColors.neutral10, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Single Unified Container for Details, Actions, Hash & Link
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: ShapeDecoration(
                    color: AppColors.neutral11,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: AppColors.neutral11),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Action Buttons
                      Row(
                        children: [
                          AppButton(
                            label: 'Copy Message',
                            svgIcon: AppSvgIcon.copy,
                            variant: AppButtonVariant.outline,
                            size: AppButtonSize.small,
                            foregroundColor: AppColors.primaryBase,
                            onPressed: () => onCopy(
                              commit.message,
                              'Commit message copied to clipboard',
                            ),
                          ),
                          if (commit.description != null &&
                              commit.description!.trim().isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.xs),
                            AppButton(
                              label: 'Copy Description',
                              svgIcon: AppSvgIcon.copy,
                              variant: AppButtonVariant.outline,
                              size: AppButtonSize.small,
                              foregroundColor: AppColors.primaryBase,
                              onPressed: () => onCopy(
                                commit.description!,
                                'Commit description copied to clipboard',
                              ),
                            ),
                          ],
                          if (commit.commitUrl != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            AppButton(
                              label: 'Copy Link',
                              svgIcon: AppSvgIcon.copy,
                              variant: AppButtonVariant.outline,
                              size: AppButtonSize.small,
                              foregroundColor: AppColors.primaryBase,
                              onPressed: () => onCopy(
                                commit.commitUrl!,
                                'Commit link copied to clipboard',
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Description text (if available) with Markdown support
                      if (commit.description != null &&
                          commit.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppMarkdownText(
                          text: commit.description!,
                          defaultColor: AppColors.neutral6,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Divider(
                          color: AppColors.neutral13,
                          height: 5,
                          thickness: 0.5,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ] else ...[
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      // Commit Hash row
                      Row(
                        children: [
                          Text(
                            'Commit: ',
                            style: AppTypography.body(
                              color: AppColors.neutral7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Flexible(
                            child: Tooltip(
                              message: 'Click to copy commit hash',
                              waitDuration: const Duration(milliseconds: 300),
                              child: InkWell(
                                onTap: () => onCopy(
                                  commit.hash,
                                  'Commit hash copied to clipboard',
                                ),
                                mouseCursor: SystemMouseCursors.click,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          commit.hash,
                                          style: AppTypography.body(
                                            color: AppColors.neutral3,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Remote Link row (if available)
                      if (commit.commitUrl != null) ...[
                        const SizedBox(height: AppSpacing.xs + 2),
                        Row(
                          children: [
                            Text(
                              'Remote Link: ',
                              style: AppTypography.body(
                                color: AppColors.neutral7,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Flexible(
                              child: Tooltip(
                                message: 'Click to open in browser',
                                waitDuration: const Duration(milliseconds: 300),
                                child: InkWell(
                                  onTap: () => onOpenUrl(commit.commitUrl!),
                                  mouseCursor: SystemMouseCursors.click,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      commit.commitUrl!,
                                      style: AppTypography.body(
                                        color: AppColors.primaryBase,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Changed Files Title
                Text(
                  'Changed Files (${commit.files.length})',
                  style: AppTypography.caption(
                    color: AppColors.neutral5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Files List
                if (commit.files.isEmpty)
                  Text(
                    'No file diff stats available for this commit.',
                    style: AppTypography.caption(color: AppColors.neutral7),
                  )
                else
                  ...commit.files.map((file) {
                    final iconSvg = IconMappingConfig.instance
                        .getIconForExtension(file.extension);

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neutral12,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.neutral11,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          gitFileStatusBadge(file.status),
                          const SizedBox(width: AppSpacing.sm),
                          SvgPicture.asset(
                            'assets/mapping/$iconSvg',
                            width: 16,
                            height: 16,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              file.path,
                              style: AppTypography.caption(
                                color: AppColors.neutral4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          if (file.isBinary)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs + 2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.neutral10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'BIN',
                                style: AppTypography.tagline(
                                  color: AppColors.neutral6,
                                ),
                              ),
                            )
                          else ...[
                            if (file.additions > 0)
                              Text(
                                '+${FormatUtils.formatNumber(file.additions)}',
                                style: AppTypography.caption(
                                  color: AppColors.successBase,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (file.additions > 0 && file.deletions > 0)
                              const SizedBox(width: AppSpacing.sm),
                            if (file.deletions > 0)
                              Text(
                                '-${FormatUtils.formatNumber(file.deletions)}',
                                style: AppTypography.caption(
                                  color: AppColors.dangerBase,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
      ],
    ),
  );
}
