import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/export_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';
import '../common/app_toast.dart';
import 'json_node.dart';

Widget jsonTreeRow({
  required BuildContext context,
  required JsonNode node,
  required bool isExpanded,
  required bool isCurrentMatch,
  required String query,
  required VoidCallback onToggle,
}) {
  final keyStyle = GoogleFonts.googleSansCode(
    color: const Color(0xFF9CDCFE), // VS Code Light Blue for keys
    fontWeight: FontWeight.w500,
    fontSize: AppTypography.bodySize,
  );
  final countStyle = GoogleFonts.googleSansCode(
    color: AppColors.neutral5,
    fontSize: AppTypography.bodySize,
    fontWeight: FontWeight.w500,
  );
  final valueStyle = GoogleFonts.googleSansCode(
    color: node.valueColor ?? AppColors.neutral6,
    fontSize: AppTypography.bodySize,
    fontWeight: FontWeight.w500,
  );
  final keyLabel = node.keyLabel;

  return InkWell(
    onTap: node.isContainer ? onToggle : null,
    borderRadius: BorderRadius.circular(4),
    hoverColor: AppColors.neutral10.withValues(alpha: 0.5),
    child: Container(
      height: 28,
      decoration: BoxDecoration(
        color: isCurrentMatch
            ? AppColors.primaryDark.withValues(alpha: 0.4)
            : null,
        borderRadius: BorderRadius.circular(4),
        border: isCurrentMatch
            ? Border.all(color: AppColors.primaryBase, width: 1)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tree depth guide lines & indent
          ...List.generate(
            node.depth,
            (i) => Container(
              width: 18,
              alignment: Alignment.centerLeft,
              child: Container(
                width: 1,
                height: 20,
                color: AppColors.neutral9.withValues(alpha: 0.3),
              ),
            ),
          ),
          SizedBox(
            width: 20,
            height: 20,
            child: node.isContainer
                ? Center(
                    child: AppIcon(
                      isExpanded
                          ? AppSvgIcon.caretDownBold
                          : AppSvgIcon.caretRightBold,
                      color: AppColors.neutral5,
                      size: 14,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (keyLabel != null)
            Flexible(
              fit: FlexFit.loose,
              child: GestureDetector(
                onTap: () {
                  final keyToCopy = node.rawKey ?? keyLabel;
                  ExportService.copyToClipboard(keyToCopy);
                  AppToast.showSuccess(context, 'Copied key: "$keyToCopy"');
                },
                child: Text.rich(
                  TextSpan(
                    children: jsonHighlightSpans(keyLabel, keyStyle, query),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (node.isContainer) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: AppColors.neutral10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.neutral9.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                node.type == NodeType.map
                    ? '${node.childCount} items'
                    : '[${node.childCount}]',
                style: countStyle,
              ),
            ),
          ] else
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final val = node.rawValue;
                  final valToCopy = val is String ? val : (node.valueLabel ?? '');
                  ExportService.copyToClipboard(valToCopy);
                  AppToast.showSuccess(context, 'Copied value: "$valToCopy"');
                },
                child: Text.rich(
                  TextSpan(
                    children: jsonHighlightSpans(
                      node.valueLabel!,
                      valueStyle,
                      query,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

List<InlineSpan> jsonHighlightSpans(String text, TextStyle base, String query) {
  if (query.isEmpty) return [TextSpan(text: text, style: base)];
  final lower = text.toLowerCase();
  final spans = <InlineSpan>[];
  var start = 0;
  int index;
  while ((index = lower.indexOf(query, start)) != -1) {
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: base));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: base.copyWith(
          backgroundColor: AppColors.primaryBase,
          color: AppColors.neutral13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    start = index + query.length;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: base));
  }
  return spans;
}