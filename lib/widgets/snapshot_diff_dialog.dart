import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/fs_node.dart';
import '../models/snapshot_diff.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'common/app_icon.dart';
import 'common/app_button.dart';

class SnapshotDiffDialog extends StatefulWidget {
  final List<FsNode> currentNodes;

  const SnapshotDiffDialog({super.key, required this.currentNodes});

  @override
  State<SnapshotDiffDialog> createState() => _SnapshotDiffDialogState();
}

class _SnapshotDiffDialogState extends State<SnapshotDiffDialog> {
  String? _baselinePath;
  List<DiffNode>? _diffResults;
  bool _isLoading = false;
  String? _error;

  Future<void> _pickBaselineJson() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select Baseline JSON Snapshot',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      setState(() {
        _baselinePath = filePath;
        _isLoading = true;
        _error = null;
      });

      try {
        final content = await File(filePath).readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final rawStructure = json['Structure'] as List<dynamic>? ?? [];

        final baselineNodes = rawStructure
            .map((e) => _parseJsonNode(e))
            .toList();
        final diffs = SnapshotDiff.compareTrees(
          baselineNodes,
          widget.currentNodes,
        );

        setState(() {
          _diffResults = diffs;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _error = 'Failed to load baseline JSON: $e';
          _isLoading = false;
        });
      }
    }
  }

  FsNode _parseJsonNode(Map<String, dynamic> json) {
    final isDir = json['Type'] == 'Directory';
    final children = (json['Children'] as List<dynamic>?)
        ?.map((c) => _parseJsonNode(c as Map<String, dynamic>))
        .toList();

    return FsNode(
      name: json['Name'] ?? '',
      type: isDir ? 'Directory' : 'File',
      path: json['Path'] ?? '',
      size: json['Size'] ?? 0,
      sizeFormatted: json['SizeFormatted'] ?? '',
      extension: json['Extension'] ?? '',
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.neutral11,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        height: 650,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Directory Snapshot Diff',
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
                    size: 18,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Select a previously exported structure JSON to compare changes',
              style: AppTypography.body(color: AppColors.neutral6),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _baselinePath ?? 'No baseline snapshot selected',
                    style: AppTypography.body(
                      color: _baselinePath != null
                          ? AppColors.neutral0
                          : AppColors.neutral6,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: 'Select Baseline JSON',
                  svgIcon: AppSvgIcon.fileCode,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: _pickBaselineJson,
                ),
              ],
            ),
            const Divider(color: AppColors.neutral10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.dangerBase),
                      ),
                    )
                  : _diffResults == null
                  ? Center(
                      child: Text(
                        'Load a JSON snapshot to view differences',
                        style: AppTypography.body(color: AppColors.neutral7),
                      ),
                    )
                  : _diffResults!.where((n) => _hasAnyDiff(n)).isEmpty
                  ? Center(
                      child: Text(
                        'No differences found! Directories are identical.',
                        style: AppTypography.body(color: AppColors.successBase),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _diffResults!
                          .where((n) => _hasAnyDiff(n))
                          .length,
                      itemBuilder: (context, index) {
                        final filtered = _diffResults!
                            .where((n) => _hasAnyDiff(n))
                            .toList();
                        return _buildDiffTile(filtered[index], 0);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasAnyDiff(DiffNode node) {
    if (node.diffType != DiffType.unchanged) return true;
    if (node.children != null) {
      return node.children!.any((c) => _hasAnyDiff(c));
    }
    return false;
  }

  Widget _buildDiffTile(DiffNode node, int depth) {
    if (!_hasAnyDiff(node)) return const SizedBox.shrink();

    Color color;
    AppSvgIcon svgIcon;
    String badge;

    switch (node.diffType) {
      case DiffType.added:
        color = AppColors.successBase;
        svgIcon = AppSvgIcon.checkCircleFill;
        badge = '+ ADDED';
        break;
      case DiffType.removed:
        color = AppColors.dangerBase;
        svgIcon = AppSvgIcon.xBold;
        badge = '- DELETED';
        break;
      case DiffType.modified:
        color = AppColors.warningBase;
        svgIcon = AppSvgIcon.gearSix;
        badge = '~ MODIFIED';
        break;
      case DiffType.unchanged:
        color = AppColors.neutral6;
        svgIcon = AppSvgIcon.checkCircleFill;
        badge = 'UNCHANGED';
        break;
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * AppSpacing.lg, top: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(svgIcon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                node.name,
                style: AppTypography.body(
                  color: AppColors.neutral3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: AppTypography.tagline(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (node.details.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  node.details,
                  style: AppTypography.caption(color: AppColors.neutral6),
                ),
              ],
            ],
          ),
          if (node.children != null)
            ...node.children!
                .where((c) => _hasAnyDiff(c))
                .map((child) => _buildDiffTile(child, depth + 1)),
        ],
      ),
    );
  }
}
