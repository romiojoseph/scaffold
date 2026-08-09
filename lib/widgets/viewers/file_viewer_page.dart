import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/fs_node.dart';
import '../../services/icon_mapping_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../custom_title_bar.dart';
import 'json_viewer_widget.dart';
import '../common/app_button.dart';
import '../common/app_icon.dart';

class FileViewerPage extends StatelessWidget {
  final FsNode node;

  const FileViewerPage({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final isJson = node.extension.toLowerCase() == '.json';

    return Scaffold(
      backgroundColor: AppColors.neutral12,
      body: Column(
        children: [
          CustomTitleBar(title: 'Scaffold - ${node.name}'),
          Expanded(
            child: FutureBuilder<String>(
              future: () async {
                final f = File(node.path);
                final stat = await f.stat();
                const maxBytes = 30 * 1024 * 1024; // 30 MB limit
                if (stat.size > maxBytes) {
                  throw Exception(
                    'File is too large to preview (${FsNode.formatBytes(stat.size)}). Max limit: 30 MB.',
                  );
                }
                return f.readAsString();
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Text(
                      'Error reading file: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.dangerBase),
                    ),
                  );
                }

                if (isJson) {
                  return JsonViewerWidget(
                    jsonContent: snapshot.data!,
                    headerActions:
                        (
                          context,
                          visibleCount,
                          totalCount,
                          expandAll,
                          collapseAll,
                          copyJson,
                          skeletonMode,
                          toggleSkeleton,
                          copySkeleton,
                          copiedSkeleton,
                          isAllExpanded,
                          toggleExpandCollapse,
                        ) {
                          return Container(
                            height: 52,
                            color: AppColors.neutral11,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const AppIcon(
                                    AppSvgIcon.arrowLeftBold,
                                    color: AppColors.neutral0,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  tooltip: 'Back',
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                SvgPicture.asset(
                                  'assets/mapping/${IconMappingConfig.instance.getIconForExtension(node.extension)}',
                                  width: 40,
                                  height: 40,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              node.name,
                                              style: AppTypography.heading6(
                                                color: AppColors.neutral3,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            '($visibleCount of $totalCount nodes)',
                                            style: AppTypography.body(
                                              color: AppColors.neutral6,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${node.path} (${node.sizeFormatted})',
                                        style: AppTypography.body(
                                          color: AppColors.neutral6,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: toggleExpandCollapse,
                                  icon: AppIcon(
                                    isAllExpanded
                                        ? AppSvgIcon.caretRightBold
                                        : AppSvgIcon.caretDownBold,
                                    size: 14,
                                    color: AppColors.primaryBase,
                                  ),
                                  label: Text(
                                    isAllExpanded ? 'Collapse All' : 'Expand All',
                                    style: const TextStyle(color: AppColors.infoBase),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppButton(
                                  label: 'Skeleton',
                                  svgIcon: skeletonMode
                                      ? AppSvgIcon.checkSquareFill
                                      : AppSvgIcon.squareDuotone,
                                  variant: skeletonMode
                                      ? AppButtonVariant.primary
                                      : AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  onPressed: toggleSkeleton,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppButton(
                                  label: 'Copy Skeleton',
                                  svgIcon: copiedSkeleton
                                      ? AppSvgIcon.checkBold
                                      : AppSvgIcon.copy,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  onPressed: copySkeleton,
                                ),
                              ],
                            ),
                          );
                        },
                  );
                }

                return Column(
                  children: [
                    Container(
                      height: 52,
                      color: AppColors.neutral11,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const AppIcon(
                              AppSvgIcon.arrowLeftBold,
                              color: AppColors.neutral0,
                              size: 20,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Back',
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          SvgPicture.asset(
                            'assets/mapping/${IconMappingConfig.instance.getIconForExtension(node.extension)}',
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  node.name,
                                  style: AppTypography.heading6(
                                    color: AppColors.neutral0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${node.path} (${node.sizeFormatted})',
                                  style: AppTypography.caption(
                                    color: AppColors.neutral6,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: SelectableText(
                          snapshot.data!,
                          style: const TextStyle(
                            color: AppColors.neutral0,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
