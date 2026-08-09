import 'package:flutter/material.dart';
import '../models/fs_node.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/format_utils.dart';
import 'viewers/file_viewer_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/icon_mapping_service.dart';
import 'common/app_icon.dart';
import 'common/app_button.dart';

class NodeDetailPanel extends StatelessWidget {
  final FsNode? selectedNode;
  final VoidCallback onClose;

  const NodeDetailPanel({
    super.key,
    required this.selectedNode,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedNode == null) return const SizedBox.shrink();

    final node = selectedNode!;
    final isDir = node.isDirectory;

    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: AppColors.neutral11,
        border: Border(left: BorderSide(color: AppColors.neutral10, width: 1)),
      ),
      child: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.neutral12,
              border: Border(
                bottom: BorderSide(color: AppColors.neutral10, width: 1),
              ),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/mapping/${isDir ? IconMappingConfig.instance.folderIcon : IconMappingConfig.instance.getIconForExtension(node.extension)}',
                  width: 28,
                  height: 28,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        style: AppTypography.heading6(
                          color: AppColors.neutral4,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isDir
                            ? 'Directory'
                            : (node.extension.isEmpty
                                  ? 'File'
                                  : '${node.extension.toUpperCase()} File'),
                        style: AppTypography.caption(color: AppColors.neutral6),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const AppIcon(
                    AppSvgIcon.xBold,
                    color: AppColors.neutral6,
                    size: 18,
                  ),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          // Content metadata
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview stats cards
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard(
                          title: isDir ? 'Total Size' : 'File Size',
                          value: node.sizeFormatted.isEmpty
                              ? FsNode.formatBytes(node.size)
                              : node.sizeFormatted,
                          svgIcon: AppSvgIcon.hardDrives,
                          color: AppColors.successBase,
                        ),
                      ),
                      if (!isDir && node.lineCount > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _infoCard(
                            title: 'Lines of Code',
                            value: FormatUtils.formatNumber(node.lineCount),
                            svgIcon: AppSvgIcon.code,
                            color: AppColors.warningBase,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // General properties
                  Text(
                    'PROPERTIES',
                    style: AppTypography.tagline(
                      color: AppColors.neutral6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _detailBox([
                    _detailItem('Type', node.type),
                    _detailItem(
                      'Extension',
                      node.extension.isEmpty ? 'None' : node.extension,
                    ),
                    if (node.children != null && isDir)
                      _detailItem(
                        'Item Count',
                        '${FormatUtils.formatNumber(node.children!.length)} items',
                      ),
                  ]),

                  const SizedBox(height: AppSpacing.md),

                  // Full Path section
                  Text(
                    'LOCATION',
                    style: AppTypography.tagline(
                      color: AppColors.neutral6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: ShapeDecoration(
                      color: AppColors.neutral13,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: AppColors.neutral11),
                      ),
                    ),
                    child: SelectableText(
                      node.path,
                      style: AppTypography.caption(color: AppColors.neutral3),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Timestamps section
                  Text(
                    'TIMESTAMPS',
                    style: AppTypography.tagline(
                      color: AppColors.neutral6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _detailBox([
                    _detailItem(
                      'Last Modified',
                      FormatUtils.formatDateTimeIso12h(node.lastModified),
                    ),
                    _detailItem(
                      'Last Accessed',
                      FormatUtils.formatDateTimeIso12h(node.lastAccessed),
                    ),
                    _detailItem(
                      'Created',
                      FormatUtils.formatDateTimeIso12h(node.created),
                    ),
                  ]),

                  if (!isDir && node.lineCount > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'LINE ANALYSIS',
                      style: AppTypography.tagline(
                        color: AppColors.neutral6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _detailBox([
                      _detailItem(
                        'Code Lines',
                        FormatUtils.formatNumber(node.codeLineCount),
                      ),
                      _detailItem(
                        'Comment Lines',
                        FormatUtils.formatNumber(node.commentLineCount),
                      ),
                      _detailItem(
                        'Blank Lines',
                        FormatUtils.formatNumber(node.blankLineCount),
                      ),
                    ]),
                  ],

                  if (!isDir && node.extension.toLowerCase() == '.json') ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Open Interactive JSON Viewer',
                      svgIcon: AppSvgIcon.fileCode,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.medium,
                      fullWidth: true,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FileViewerPage(node: node),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String value,
    required AppSvgIcon svgIcon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ShapeDecoration(
        color: AppColors.neutral13,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.neutral11),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(svgIcon, size: 14, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    title,
                    style: AppTypography.caption(color: AppColors.neutral6),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.subtitle(
              color: AppColors.neutral3,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBox(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ShapeDecoration(
        color: AppColors.neutral13,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.neutral11),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption(color: AppColors.neutral6)),
          Text(
            value,
            style: AppTypography.caption(
              color: AppColors.neutral3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
