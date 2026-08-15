import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/fs_node.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/clipboard_utils.dart';
import '../viewers/file_viewer_page.dart';
import 'app_icon.dart';
import 'app_toast.dart';

class NodeContextMenu {
  NodeContextMenu._();

  static String relativePath(String fullPath, String rootPath) {
    if (fullPath == rootPath) return '.';
    if (fullPath.startsWith(rootPath)) {
      var rel = fullPath.substring(rootPath.length);
      while (rel.startsWith('/') || rel.startsWith('\\')) {
        rel = rel.substring(1);
      }
      return rel;
    }
    return fullPath;
  }

  static void _copyToClipboard(BuildContext context, String text, String message) async {
    final success = await ClipboardUtils.copy(text);
    if (!context.mounted) return;
    if (success) {
      AppToast.showSuccess(context, message);
    } else {
      AppToast.showError(context, 'Failed to copy to clipboard');
    }
  }

  static void _openFolderOrExplorer(BuildContext context, String path, bool isDir) {
    try {
      if (Platform.isWindows) {
        if (isDir) {
          Process.run('explorer.exe', [path]);
        } else {
          Process.run('explorer.exe', ['/select,', path]);
        }
      } else if (Platform.isMacOS) {
        Process.run('open', [isDir ? path : File(path).parent.path]);
      } else {
        Process.run('xdg-open', [isDir ? path : File(path).parent.path]);
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.showError(context, 'Could not open File Explorer');
      }
    }
  }

  static Future<void> _openTerminal(BuildContext context, String path) async {
    try {
      final targetDir = FileSystemEntity.isDirectorySync(path)
          ? path
          : File(path).parent.path;
      final canonicalPath = await Directory(targetDir).resolveSymbolicLinks();
      final terminalExe = await _findTerminal();
      await Process.start(
        terminalExe,
        ['-d', canonicalPath],
        workingDirectory: canonicalPath,
      );
    } catch (_) {
      if (context.mounted) {
        AppToast.showError(context, 'Could not open terminal');
      }
    }
  }

  static Future<String> _findTerminal() async {
    try {
      final which = await Process.run('where', ['wt.exe']);
      if (which.exitCode == 0) {
        final lines = which.stdout.toString().trim().split('\n');
        if (lines.isNotEmpty) return lines.first.trim();
      }
    } catch (_) {}
    return 'cmd.exe';
  }

  static void _openFileViewer(BuildContext context, FsNode node) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FileViewerPage(node: node)),
    );
  }

  static PopupMenuItem<String> _buildMenuItem({
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

  /// Displays the standardized right-click context menu for an FsNode.
  static Future<void> show({
    required BuildContext context,
    required Offset globalPosition,
    required FsNode node,
    required String rootPath,
  }) async {
    final isDir = node.isDirectory;
    final relPath = relativePath(node.path, rootPath);

    final selected = await showMenu<String>(
      context: context,
      color: AppColors.neutral11,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.neutral10),
      ),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        if (!isDir)
          _buildMenuItem(
            value: 'viewFile',
            icon: AppSvgIcon.fileCode,
            label: 'View File Content',
          ),
        _buildMenuItem(
          value: 'openExplorer',
          icon: AppSvgIcon.folderOpen,
          label: isDir ? 'Open Folder in Explorer' : 'Reveal in File Explorer',
        ),
        _buildMenuItem(
          value: 'openTerminal',
          icon: AppSvgIcon.terminal,
          label: isDir ? 'Open Terminal Here' : 'Open Terminal in Folder',
        ),
        const PopupMenuDivider(height: 1),
        _buildMenuItem(
          value: 'copyName',
          icon: AppSvgIcon.copy,
          label: isDir ? 'Copy Folder Name' : 'Copy File Name',
        ),
        _buildMenuItem(
          value: 'copyPath',
          icon: AppSvgIcon.copy,
          label: 'Copy Full Path',
        ),
        _buildMenuItem(
          value: 'copyRelative',
          icon: AppSvgIcon.copy,
          label: 'Copy Relative Path',
        ),
      ],
    );

    if (selected == null || !context.mounted) return;

    switch (selected) {
      case 'viewFile':
        _openFileViewer(context, node);
        break;
      case 'openExplorer':
        _openFolderOrExplorer(context, node.path, isDir);
        break;
      case 'openTerminal':
        _openTerminal(context, node.path);
        break;
      case 'copyName':
        _copyToClipboard(context, node.name, 'Copied name to clipboard');
        break;
      case 'copyPath':
        _copyToClipboard(context, node.path, 'Copied full path to clipboard');
        break;
      case 'copyRelative':
        _copyToClipboard(context, relPath, 'Copied relative path to clipboard');
        break;
    }
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
          vertical: AppSpacing.sm + 2,
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
              size: 15,
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
