import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'common/app_icon.dart';
import 'common/app_button.dart';
import 'common/app_text_field.dart';

class HeaderBar extends StatelessWidget {
  final TextEditingController pathController;
  final bool isScanning;
  final VoidCallback onScanPressed;
  final VoidCallback? onCancelPressed;

  const HeaderBar({
    super.key,
    required this.pathController,
    required this.isScanning,
    required this.onScanPressed,
    this.onCancelPressed,
  });

  Future<void> _pickDirectory() async {
    final selectedDir = await FilePicker.getDirectoryPath();
    if (selectedDir != null) {
      pathController.text = selectedDir;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.neutral13,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral12, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: pathController,
              hintText: 'Enter or click folder icon to browse path (e.g. E:\\dev\\project)',
              svgPrefixIcon: AppSvgIcon.folderOpen,
              onPrefixTap: _pickDirectory,
              size: AppInputSize.medium,
              onSubmitted: (_) => isScanning ? null : onScanPressed(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isScanning) ...[
            AppButton(
              label: 'Cancel Scan',
              svgIcon: AppSvgIcon.xBold,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.medium,
              onPressed: onCancelPressed,
            ),
          ] else ...[
            AppButton(
              label: 'Scan Directory',
              svgIcon: AppSvgIcon.scan,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.medium,
              onPressed: onScanPressed,
            ),
          ],
        ],
      ),
    );
  }
}
