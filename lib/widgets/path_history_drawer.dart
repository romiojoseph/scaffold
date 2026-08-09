import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

import 'common/app_icon.dart';

class PathHistoryDrawer extends StatelessWidget {
  final List<String> paths;
  final ValueChanged<String> onPathTap;
  final ValueChanged<int> onPathRemove;

  const PathHistoryDrawer({
    super.key,
    required this.paths,
    required this.onPathTap,
    required this.onPathRemove,
  });

  static bool isDriveRoot(String rawPath) {
    var p = rawPath.trim().replaceAll('/', r'\');
    while (p.endsWith(r'\') && p.length > 3) {
      p = p.substring(0, p.length - 1);
    }
    return p.length == 2 && p[1] == ':';
  }

  static String folderName(String rawPath) {
    var p = rawPath.trim().replaceAll('/', r'\');
    while (p.endsWith(r'\') && p.length > 3) {
      p = p.substring(0, p.length - 1);
    }
    if (p.length == 2 && p[1] == ':') {
      return '$p\\';
    }
    if (p.length == 3 && p[1] == ':' && p[2] == r'\') {
      return p;
    }
    final sep = p.lastIndexOf(r'\');
    if (sep == -1 || sep == p.length - 1) return p;
    return p.substring(sep + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.neutral11,
      width: 320,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Recent Paths',
                    style: AppTypography.heading5(
                      color: AppColors.neutral3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const AppIcon(
                      AppSvgIcon.xBold,
                      color: AppColors.neutral6,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.neutral10, height: 1),
            Expanded(
              child: paths.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'No paths scanned yet.\nScan a directory and it will\nappear here.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body(color: AppColors.neutral7),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: paths.length,
                      itemBuilder: (context, index) {
                        final path = paths[index];
                        final name = folderName(path);
                        return _HistoryItem(
                          name: name,
                          fullPath: path,
                          onTap: () {
                            Navigator.of(context).pop();
                            onPathTap(path);
                          },
                          onRemove: () => onPathRemove(index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatefulWidget {
  final String name;
  final String fullPath;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _HistoryItem({
    required this.name,
    required this.fullPath,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_HistoryItem> createState() => _HistoryItemState();
}

class _HistoryItemState extends State<_HistoryItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs / 2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.neutral10 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: AppTypography.subtitle(color: AppColors.neutral0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.fullPath,
                      style: AppTypography.caption(color: AppColors.neutral6),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_hovered)
                IconButton(
                  icon: const AppIcon(
                    AppSvgIcon.xBold,
                    color: AppColors.neutral5,
                    size: 18,
                  ),
                  onPressed: widget.onRemove,
                  tooltip: 'Remove',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
