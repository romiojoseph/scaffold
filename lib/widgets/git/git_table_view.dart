import 'package:flutter/material.dart';
import '../../models/git_commit.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../common/app_icon.dart';

Widget gitTableView({
  required List<GitCommit> commits,
  required void Function(String text, String message) onCopy,
  required void Function(String url) onOpenUrl,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.neutral12,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.neutral10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: const BoxDecoration(
            color: AppColors.neutral11,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(color: AppColors.neutral10)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '#',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 85,
                child: Text(
                  'Commit',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'Message',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Author',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  'Date',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  'Lines',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'Files',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 32),
            ],
          ),
        ),

        // Table Rows
        ...List.generate(commits.length, (index) {
          final commit = commits[index];
          final isEven = index % 2 == 0;

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isEven
                  ? AppColors.neutral12.withValues(alpha: 0.3)
                  : AppColors.neutral11.withValues(alpha: 0.2),
              border: const Border(
                bottom: BorderSide(color: AppColors.neutral11, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // # (Index)
                SizedBox(
                  width: 36,
                  child: Text(
                    '${index + 1}',
                    style: AppTypography.caption(color: AppColors.neutral7),
                  ),
                ),

                // Short Commit Hash badge
                SizedBox(
                  width: 85,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Tooltip(
                      message: 'Click to copy short hash (${commit.shortHash})',
                      child: InkWell(
                        onTap: () => onCopy(
                          commit.shortHash,
                          'Copied commit ${commit.shortHash} to clipboard',
                        ),
                        borderRadius: BorderRadius.circular(4),
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
                  ),
                ),

                // Message
                Expanded(
                  flex: 5,
                  child: Tooltip(
                    message:
                        commit.description != null &&
                            commit.description!.isNotEmpty
                        ? '${commit.message}\n\n${commit.description}'
                        : commit.message,
                    child: Row(
                      children: [
                        if (commit.isMerge) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFA855F7,
                              ).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(3),
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
                            style: AppTypography.body(
                              color: AppColors.neutral4,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Author
                Expanded(
                  flex: 3,
                  child: Text(
                    commit.author,
                    style: AppTypography.body(color: AppColors.neutral6),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Date
                SizedBox(
                  width: 110,
                  child: Tooltip(
                    message: commit.date.toLocal().toString().split('.').first,
                    child: Text(
                      commit.relativeDate,
                      style: AppTypography.body(color: AppColors.neutral6),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Lines (+additions -deletions)
                SizedBox(
                  width: 110,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (commit.totalAdditions > 0)
                        Text(
                          '+${FormatUtils.formatNumber(commit.totalAdditions)}',
                          style: AppTypography.body(
                            color: AppColors.successBase,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (commit.totalAdditions > 0 &&
                          commit.totalDeletions > 0)
                        const SizedBox(width: AppSpacing.sm),
                      if (commit.totalDeletions > 0)
                        Text(
                          '-${FormatUtils.formatNumber(commit.totalDeletions)}',
                          style: AppTypography.body(
                            color: AppColors.dangerBase,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (commit.totalAdditions == 0 &&
                          commit.totalDeletions == 0)
                        Text(
                          '0',
                          style: AppTypography.body(color: AppColors.neutral7),
                        ),
                    ],
                  ),
                ),

                // Files Count
                SizedBox(
                  width: 70,
                  child: Text(
                    '${commit.files.length} ${commit.files.length == 1 ? 'file' : 'files'}',
                    style: AppTypography.caption(color: AppColors.neutral6),
                  ),
                ),

                // Actions (Remote link)
                SizedBox(
                  width: 32,
                  child: commit.commitUrl != null
                      ? Tooltip(
                          message: 'Open commit on remote',
                          child: InkWell(
                            onTap: () => onOpenUrl(commit.commitUrl!),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const AppIcon(
                                AppSvgIcon.arrowSquareOutDuotone,
                                size: 14,
                                color: AppColors.neutral6,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}
