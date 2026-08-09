import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/fs_node.dart';
import '../services/export_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'common/app_icon.dart';
import 'common/app_button.dart';
import 'common/app_text_field.dart';

class ExportDialog extends StatefulWidget {
  final String rootPath;
  final List<String> excludedPatterns;
  final List<FsNode> structure;

  const ExportDialog({
    super.key,
    required this.rootPath,
    required this.excludedPatterns,
    required this.structure,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final TextEditingController _pathController = TextEditingController();
  bool _isSaving = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    final folderName = widget.rootPath
        .split(Platform.pathSeparator)
        .where((s) => s.isNotEmpty)
        .last;
    final defaultFileName = '${folderName}Structure.json';
    getApplicationDocumentsDirectory().then((dir) {
      if (mounted) {
        setState(() {
          _pathController.text = p.join(dir.path, defaultFileName);
        });
      }
    });
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _browseSavePath() async {
    final result = await FilePicker.saveFile(
      dialogTitle: 'Select JSON Export Path',
      fileName: p.basename(_pathController.text),
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null) {
      _pathController.text = result;
    }
  }

  Future<void> _doExport() async {
    setState(() {
      _isSaving = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final file = await ExportService.exportToJson(
        rootPath: widget.rootPath,
        excludedPatterns: widget.excludedPatterns,
        structure: widget.structure,
        outputPath: _pathController.text,
      );

      setState(() {
        _isSaving = false;
        _statusMessage = 'Saved JSON successfully to: ${file.path}';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
        _statusMessage = 'Error saving JSON: $e';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.neutral11,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Export Structure to JSON',
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
            const SizedBox(height: AppSpacing.md),
            Text(
              'Specify destination JSON file path:',
              style: AppTypography.body(color: AppColors.neutral4),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _pathController,
              size: AppInputSize.medium,
              hintText: 'Specify destination JSON file path',
              svgPrefixIcon: AppSvgIcon.folderOpen,
              onPrefixTap: _browseSavePath,
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _statusMessage!,
                style: AppTypography.caption(
                  color: _isError
                      ? AppColors.dangerBase
                      : AppColors.successBase,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.medium,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: _isSaving ? 'Exporting...' : 'Export JSON',
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.medium,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _doExport,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
