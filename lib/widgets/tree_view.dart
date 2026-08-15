import 'package:flutter/material.dart';
import '../models/fs_node.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'viewers/file_viewer_page.dart';

import 'package:flutter_svg/flutter_svg.dart';
import '../services/icon_mapping_service.dart';

import 'common/app_icon.dart';
import 'common/app_text_field.dart';
import 'common/node_context_menu.dart';

class DirectoryTreeView extends StatefulWidget {
  final List<FsNode> nodes;
  final String rootPath;
  final Function(FsNode) onNodeTap;

  const DirectoryTreeView({
    super.key,
    required this.nodes,
    required this.rootPath,
    required this.onNodeTap,
  });

  @override
  State<DirectoryTreeView> createState() => _DirectoryTreeViewState();
}

class _DirectoryTreeViewState extends State<DirectoryTreeView> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<({FsNode node, int depth})> _getFlattenedVisibleNodes() {
    final list = <({FsNode node, int depth})>[];

    void addNode(FsNode node, int depth) {
      if (!_nodeMatchesFilter(node, _filter)) return;
      list.add((node: node, depth: depth));

      if (node.isDirectory && node.isExpanded && node.children != null) {
        for (final child in node.children!) {
          addNode(child, depth + 1);
        }
      }
    }

    for (final root in widget.nodes) {
      addNode(root, 0);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visibleNodes = _getFlattenedVisibleNodes();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppTextField(
            controller: _searchController,
            hintText: 'Filter nodes...',
            svgPrefixIcon: AppSvgIcon.magnifyingGlass,
            size: AppInputSize.small,
            onChanged: (val) =>
                setState(() => _filter = val.trim().toLowerCase()),
            suffixIcon: _filter.isNotEmpty
                ? IconButton(
                    icon: const AppIcon(
                      AppSvgIcon.xBold,
                      size: 14,
                      color: AppColors.neutral6,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _filter = '');
                    },
                  )
                : null,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: visibleNodes.length,
            itemBuilder: (context, index) {
              final item = visibleNodes[index];
              return _buildNodeTile(item.node, item.depth);
            },
          ),
        ),
      ],
    );
  }

  bool _nodeMatchesFilter(FsNode node, String query) {
    if (query.isNotEmpty && !node.name.toLowerCase().contains(query)) {
      if (!node.isDirectory) return false;
    }
    if (node.isDirectory && node.children != null) {
      if (query.isEmpty) return true;
      return node.children!.any((c) => _nodeMatchesFilter(c, query));
    }
    return true;
  }

  void _showNodeContextMenu(
    BuildContext context,
    Offset globalPosition,
    FsNode node,
  ) {
    NodeContextMenu.show(
      context: context,
      globalPosition: globalPosition,
      node: node,
      rootPath: widget.rootPath,
    );
  }

  Widget _buildNodeTile(FsNode node, int depth) {
    final matchesFilter =
        _filter.isEmpty || node.name.toLowerCase().contains(_filter);

    if (node.isDirectory) {
      final children = node.children ?? [];
      final folderSvg = IconMappingConfig.instance.folderIcon;

      return InkWell(
        onTap: () {
          setState(() {
            node.isExpanded = !node.isExpanded;
          });
          widget.onNodeTap(node);
        },
        onSecondaryTapDown: (details) =>
            _showNodeContextMenu(context, details.globalPosition, node),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.only(
            left: depth * AppSpacing.lg,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
            right: AppSpacing.sm,
          ),
          child: Row(
            children: [
              AppIcon(
                node.isExpanded
                    ? AppSvgIcon.caretDownBold
                    : AppSvgIcon.caretRightBold,
                size: 16,
                color: AppColors.neutral6,
              ),
              const SizedBox(width: AppSpacing.xs),
              SvgPicture.asset(
                'assets/mapping/$folderSvg',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  node.name,
                  style: AppTypography.body(
                    color: matchesFilter
                        ? AppColors.neutral3
                        : AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neutral10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${children.length}',
                  style: AppTypography.tagline(color: AppColors.neutral6),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        onTap: () {
          widget.onNodeTap(node);
          if (node.extension.toLowerCase() == '.json') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FileViewerPage(node: node)),
            );
          }
        },
        onSecondaryTapDown: (details) =>
            _showNodeContextMenu(context, details.globalPosition, node),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.only(
            left: depth * AppSpacing.lg + 22.0,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
            right: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _getFileIcon(node.extension),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  node.name,
                  style: AppTypography.body(
                    color: matchesFilter
                        ? AppColors.neutral4
                        : AppColors.neutral7,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                node.sizeFormatted,
                style: AppTypography.caption(color: AppColors.neutral7),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _getFileIcon(String ext) {
    final iconFile = IconMappingConfig.instance.getIconForExtension(ext);
    return SvgPicture.asset('assets/mapping/$iconFile', width: 18, height: 18);
  }
}

