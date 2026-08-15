import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/fs_node.dart';
import '../../services/file_crypto_service.dart';
import '../../services/icon_mapping_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';

Widget hashTable({
  required List<FileHashResult> results,
  required Set<String> pendingFilePaths,
  required void Function(String text, String message) onCopy,
  required void Function(String filePath) onRemove,
}) {
  if (results.isEmpty && pendingFilePaths.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: ShapeDecoration(
        color: AppColors.neutral13,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.neutral11, width: 1.5),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const AppIcon(
              AppSvgIcon.fileCode,
              size: 40,
              color: AppColors.neutral8,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No files selected for hashing.',
              style: AppTypography.body(color: AppColors.neutral5),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Click "Add Files" above to compute SHA-256 and SHA-512 hashes.',
              style: AppTypography.caption(color: AppColors.neutral7),
            ),
          ],
        ),
      ),
    );
  }

  return Container(
    decoration: ShapeDecoration(
      color: AppColors.neutral13,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.neutral11, width: 1.5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: ShapeDecoration(
            color: AppColors.neutral12,
            shape: const ContinuousRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              side: BorderSide(color: AppColors.neutral11, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'File Name',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Size',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'SHA-256',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'SHA-512',
                  style: AppTypography.tagline(
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(
                width: 60,
                child: Text(
                  'Actions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.neutral6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Result Rows
        ...List.generate(results.length, (index) {
          final r = results[index];
          final isEven = index % 2 == 0;
          final ext = r.fileName.contains('.')
              ? '.${r.fileName.split('.').last}'
              : '';
          final iconSvg = IconMappingConfig.instance.getIconForExtension(ext);

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isEven
                  ? AppColors.neutral12.withValues(alpha: 0.35)
                  : AppColors.neutral11.withValues(alpha: 0.15),
              border: const Border(
                bottom: BorderSide(color: AppColors.neutral11, width: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Name with mapping SVG icon
                Expanded(
                  flex: 4,
                  child: Tooltip(
                    message: r.filePath,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: SvgPicture.asset(
                            'assets/mapping/$iconSvg',
                            width: 16,
                            height: 16,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.fileName,
                                style: AppTypography.body(
                                  color: AppColors.neutral4,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.filePath,
                                style: AppTypography.label(
                                  color: AppColors.neutral7,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Size
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      FsNode.formatBytes(r.fileSizeBytes),
                      style: AppTypography.caption(color: AppColors.neutral5),
                    ),
                  ),
                ),

                // SHA-256 (Click to copy, clean without separate copy icon)
                Expanded(
                  flex: 5,
                  child: _buildClickableHashField(
                    hash: r.sha256,
                    algorithm: 'SHA-256',
                    onCopy: onCopy,
                  ),
                ),

                // SHA-512 (Click to copy, clean without separate copy icon)
                Expanded(
                  flex: 5,
                  child: _buildClickableHashField(
                    hash: r.sha512,
                    algorithm: 'SHA-512',
                    onCopy: onCopy,
                  ),
                ),

                // Actions: Copy all hashes & Delete
                SizedBox(
                  width: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: 'Copy all hashes as JSON (${r.fileName})',
                        child: InkWell(
                          onTap: () => onCopy(
                            r.toJson().toString(),
                            'All hashes copied for ${r.fileName}',
                          ),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: const AppIcon(
                              AppSvgIcon.copy,
                              size: 14,
                              color: AppColors.neutral6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Tooltip(
                        message: 'Remove from list',
                        child: InkWell(
                          onTap: () => onRemove(r.filePath),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: const AppIcon(
                              AppSvgIcon.trash,
                              size: 14,
                              color: AppColors.dangerBase,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        // Pending Rows
        ...pendingFilePaths.map((p) {
          final fileName = p.split(RegExp(r'[/\\]')).last;
          final ext = fileName.contains('.')
              ? '.${fileName.split('.').last}'
              : '';
          final iconSvg = IconMappingConfig.instance.getIconForExtension(ext);

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.neutral11, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryBase,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      SvgPicture.asset(
                        'assets/mapping/$iconSvg',
                        width: 14,
                        height: 14,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          fileName,
                          style: AppTypography.body(color: AppColors.neutral5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '-',
                    style: AppTypography.caption(color: AppColors.neutral7),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Computing SHA-256...',
                    style: AppTypography.caption(color: AppColors.neutral6),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Computing SHA-512...',
                    style: AppTypography.caption(color: AppColors.neutral6),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Center(
                    child: Tooltip(
                      message: 'Cancel / Remove',
                      child: InkWell(
                        onTap: () => onRemove(p),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: const AppIcon(
                            AppSvgIcon.xBold,
                            size: 14,
                            color: AppColors.neutral6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

Widget _buildClickableHashField({
  required String hash,
  required String algorithm,
  required void Function(String text, String message) onCopy,
}) {
  return Tooltip(
    message: 'Click to copy $algorithm ($hash)',
    child: InkWell(
      onTap: () => onCopy(hash, '$algorithm copied to clipboard!'),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: SelectableText(
          hash,
          onTap: () => onCopy(hash, '$algorithm copied to clipboard!'),
          style: GoogleFonts.googleSansCode(
            fontSize: 13,
            height: 1.5,
            color: AppColors.primaryBase,
          ),
        ),
      ),
    ),
  );
}
