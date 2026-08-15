import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// A lightweight, clean Markdown renderer for commit descriptions, release notes, and messages.
/// Supports:
/// - Bold (`**bold**` or `__bold__`)
/// - Italics (`*italic*` or `_italic_`)
/// - Bold + Italic (`***text***`)
/// - Inline code (`` `code` ``)
/// - Strikethrough (`~~text~~`)
/// - Unordered Lists (`- `, `* `, `+ `, `• `)
/// - Ordered Lists (`1. `, `2. `, `1) `, etc.)
/// - Headings (`# `, `## `, `### `)
class AppMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? defaultColor;
  final double lineSpacing;

  const AppMarkdownText({
    super.key,
    required this.text,
    this.style,
    this.defaultColor,
    this.lineSpacing = AppSpacing.xs,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = (style ?? AppTypography.body()).copyWith(
      color: defaultColor ?? AppColors.neutral3,
      height: 1.45,
    );

    final lines = text.split('\n');
    final blockWidgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        if (i < lines.length - 1 && lines[i + 1].trim().isNotEmpty) {
          blockWidgets.add(SizedBox(height: lineSpacing));
        }
        continue;
      }

      // Check for Headings
      if (trimmed.startsWith('### ')) {
        final content = trimmed.substring(4);
        blockWidgets.add(
          Padding(
            padding: EdgeInsets.only(top: lineSpacing, bottom: lineSpacing / 2),
            child: SelectableText.rich(
              TextSpan(
                children: _parseInlineSpans(
                  content,
                  baseStyle.copyWith(
                    fontSize: (baseStyle.fontSize ?? 14) + 1,
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutral3,
                  ),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('## ')) {
        final content = trimmed.substring(3);
        blockWidgets.add(
          Padding(
            padding: EdgeInsets.only(top: lineSpacing, bottom: lineSpacing / 2),
            child: SelectableText.rich(
              TextSpan(
                children: _parseInlineSpans(
                  content,
                  baseStyle.copyWith(
                    fontSize: (baseStyle.fontSize ?? 14) + 2,
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutral3,
                  ),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('# ')) {
        final content = trimmed.substring(2);
        blockWidgets.add(
          Padding(
            padding: EdgeInsets.only(top: lineSpacing, bottom: lineSpacing / 2),
            child: SelectableText.rich(
              TextSpan(
                children: _parseInlineSpans(
                  content,
                  baseStyle.copyWith(
                    fontSize: (baseStyle.fontSize ?? 14) + 4,
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutral3,
                  ),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      // Check for Unordered List (ul: -, *, +, •)
      final ulMatch = RegExp(r'^(\s*)([-*+•])\s+(.*)$').firstMatch(rawLine);
      if (ulMatch != null) {
        final indentLevel = (ulMatch.group(1)?.length ?? 0) ~/ 2;
        final content = ulMatch.group(3) ?? '';

        blockWidgets.add(
          Padding(
            padding: EdgeInsets.only(
              left: indentLevel * AppSpacing.md + AppSpacing.xs,
              bottom: 3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7, right: AppSpacing.sm),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBase,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: SelectableText.rich(
                    TextSpan(children: _parseInlineSpans(content, baseStyle)),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Check for Ordered List (ol: 1., 1), 2., etc.)
      final olMatch = RegExp(r'^(\s*)(\d+)[\.\)]\s+(.*)$').firstMatch(rawLine);
      if (olMatch != null) {
        final indentLevel = (olMatch.group(1)?.length ?? 0) ~/ 2;
        final numberStr = olMatch.group(2) ?? '1';
        final content = olMatch.group(3) ?? '';

        blockWidgets.add(
          Padding(
            padding: EdgeInsets.only(
              left: indentLevel * AppSpacing.md + AppSpacing.xs,
              bottom: 3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '$numberStr.',
                    style: baseStyle.copyWith(
                      color: AppColors.primaryBase,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText.rich(
                    TextSpan(children: _parseInlineSpans(content, baseStyle)),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Regular Paragraph Line
      blockWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: SelectableText.rich(
            TextSpan(children: _parseInlineSpans(rawLine, baseStyle)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blockWidgets,
    );
  }

  /// Parses inline markdown formatting (bold, italic, code, strikethrough).
  static List<InlineSpan> _parseInlineSpans(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];

    // Regex pattern matching:
    // 1. `inline code`
    // 2. ***bold italic*** or ___bold italic___
    // 3. **bold** or __bold__
    // 4. *italic* or _italic_
    // 5. ~~strikethrough~~
    final regex = RegExp(
      r'(`([^`]+)`)'
      r'|(\*\*\*([^*]+)\*\*\*|___([^_]+)___)'
      r'|(\*\*([^*]+)\*\*|__([^_]+)__)'
      r'|(\*([^*]+)\*|_([^_]+)_)'
      r'|(~~([^~]+)~~)',
    );

    int currentIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final fullMatch = match.group(0)!;

      // 1. Inline Code: `code`
      if (fullMatch.startsWith('`') && fullMatch.endsWith('`')) {
        final codeContent = match.group(2) ?? '';
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.neutral10,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.neutral9, width: 0.5),
              ),
              child: Text(
                codeContent,
                style: baseStyle.copyWith(
                  fontFamily: 'monospace',
                  fontSize: (baseStyle.fontSize ?? 14) * 0.9,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ),
        );
      }
      // 2. Bold + Italic: ***text*** or ___text___
      else if (fullMatch.startsWith('***') || fullMatch.startsWith('___')) {
        final content = match.group(4) ?? match.group(5) ?? '';
        spans.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: AppColors.neutral3,
            ),
          ),
        );
      }
      // 3. Bold: **text** or __text__
      else if (fullMatch.startsWith('**') || fullMatch.startsWith('__')) {
        final content = match.group(7) ?? match.group(8) ?? '';
        spans.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.neutral3,
            ),
          ),
        );
      }
      // 4. Italic: *text* or _text_
      else if (fullMatch.startsWith('*') || fullMatch.startsWith('_')) {
        final content = match.group(10) ?? match.group(11) ?? '';
        spans.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.neutral3,
            ),
          ),
        );
      }
      // 5. Strikethrough: ~~text~~
      else if (fullMatch.startsWith('~~')) {
        final content = match.group(13) ?? '';
        spans.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(
              decoration: TextDecoration.lineThrough,
              color: AppColors.neutral6,
            ),
          ),
        );
      }

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: baseStyle));
    }

    return spans;
  }
}
