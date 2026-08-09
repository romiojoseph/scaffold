import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/fs_node.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'viewers/file_viewer_page.dart';

import 'package:flutter_svg/flutter_svg.dart';
import '../services/icon_mapping_service.dart';

import 'common/app_icon.dart';
import 'common/app_text_field.dart';

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

  @override
  Widget build(BuildContext context) {
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: widget.nodes
                .where((n) => _nodeMatchesFilter(n, _filter))
                .map((node) => _buildNodeTile(node, 0))
                .toList(),
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

  String _relativePath(String fullPath) {
    final root = widget.rootPath;
    if (fullPath == root) return '.';
    if (fullPath.startsWith(root)) {
      var rel = fullPath.substring(root.length);
      while (rel.startsWith('/') || rel.startsWith('\\')) {
        rel = rel.substring(1);
      }
      return rel;
    }
    return fullPath;
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Copied to clipboard',
            style: AppTypography.body(color: AppColors.neutral0),
          ),
          backgroundColor: AppColors.primaryBase,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _openFolder(BuildContext context, String path) {
    try {
      Process.run('explorer.exe', [path]);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open folder',
            style: AppTypography.body(color: AppColors.neutral0),
          ),
          backgroundColor: AppColors.dangerBase,
        ),
      );
    }
  }

  Future<void> _openTerminal(BuildContext context, String path) async {
    try {
      final targetDir = FileSystemEntity.isDirectorySync(path)
          ? path
          : File(path).parent.path;
      final canonicalPath = await Directory(targetDir).resolveSymbolicLinks();
      final terminalExe = await _findTerminal();
      await Process.start(terminalExe, [
        '-d',
        canonicalPath,
      ], workingDirectory: canonicalPath);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open terminal',
              style: AppTypography.body(color: AppColors.neutral0),
            ),
            backgroundColor: AppColors.dangerBase,
          ),
        );
      }
    }
  }

  Future<String> _findTerminal() async {
    final which = await Process.run('where', ['wt.exe']);
    if (which.exitCode == 0) {
      final lines = which.stdout.toString().trim().split('\n');
      if (lines.isNotEmpty) return lines.first.trim();
    }
    return 'cmd.exe';
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required AppSvgIcon icon,
    required String label,
  }) {
    return PopupMenuItem<String>(
      value: value,
      padding: EdgeInsets.zero,
      child: _PopupMenuItemTile(icon: icon, label: label),
    );
  }

  void _showNodeContextMenu(
    BuildContext context,
    Offset globalPosition,
    FsNode node,
  ) {
    final isDir = node.isDirectory;
    final relativePath = _relativePath(node.path);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        if (isDir)
          _buildPopupMenuItem(
            value: 'open',
            icon: AppSvgIcon.folderOpen,
            label: 'Open Folder Here',
          ),
        _buildPopupMenuItem(
          value: 'openTerminal',
          icon: AppSvgIcon.code,
          label: isDir ? 'Open Terminal Here' : 'Open Terminal in Folder',
        ),
        _buildPopupMenuItem(
          value: 'copyName',
          icon: AppSvgIcon.copy,
          label: isDir ? 'Copy Folder Name' : 'Copy File Name',
        ),
        _buildPopupMenuItem(
          value: 'copyPath',
          icon: AppSvgIcon.copy,
          label: 'Copy Path',
        ),
        _buildPopupMenuItem(
          value: 'copyRelative',
          icon: AppSvgIcon.copy,
          label: 'Copy Relative Path',
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'open':
          _openFolder(context, node.path);
        case 'openTerminal':
          _openTerminal(context, node.path);
        case 'copyName':
          _copyToClipboard(context, node.name);
        case 'copyPath':
          _copyToClipboard(context, node.path);
        case 'copyRelative':
          _copyToClipboard(context, relativePath);
      }
    });
  }

  Widget _buildNodeTile(FsNode node, int depth) {
    final matchesFilter =
        _filter.isEmpty || node.name.toLowerCase().contains(_filter);

    if (node.isDirectory) {
      final children = node.children ?? [];
      final filteredChildren = children
          .where((c) => _nodeMatchesFilter(c, _filter))
          .toList();
      final folderSvg = IconMappingConfig.instance.folderIcon;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
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
          ),
          if (node.isExpanded)
            ...filteredChildren.map(
              (child) => _buildNodeTile(child, depth + 1),
            ),
        ],
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

class _PopupMenuItemTile extends StatefulWidget {
  final AppSvgIcon icon;
  final String label;

  const _PopupMenuItemTile({required this.icon, required this.label});

  @override
  State<_PopupMenuItemTile> createState() => _PopupMenuItemTileState();
}

class _PopupMenuItemTileState extends State<_PopupMenuItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.primaryBase.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            AppIcon(
              widget.icon,
              size: 16,
              color: _isHovered ? AppColors.primaryBase : AppColors.neutral4,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              widget.label,
              style: AppTypography.body(
                color: _isHovered ? AppColors.primaryBase : AppColors.neutral2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
