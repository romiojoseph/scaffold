import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/scan_stats.dart';
import '../models/fs_node.dart';
import '../services/icon_mapping_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/format_utils.dart';
import '../models/thresholds_config.dart';
import '../services/tokenizer_registry.dart';
import '../services/bpe_tokenizer.dart';
import '../services/scanner_service.dart';
import 'common/app_icon.dart';
import 'common/app_button.dart';

class LanguageStats {
  final String language;
  final List<FsNode> files;
  int lines = 0;
  int code = 0;
  int comments = 0;
  int blanks = 0;
  int bytes = 0;

  LanguageStats({required this.language, List<FsNode>? files})
    : files = files ?? [];
}

class StatsView extends StatefulWidget {
  final ScanStats stats;
  final List<FsNode> nodes;
  final ThresholdsConfig thresholdsConfig;
  final TokenizerRegistry tokenizerRegistry;
  final ScanTotals? scanTotals;

  const StatsView({
    super.key,
    required this.stats,
    required this.nodes,
    required this.thresholdsConfig,
    required this.tokenizerRegistry,
    this.scanTotals,
  });

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  final Set<String> _expandedLanguages = {};
  bool _isCopied = false;
  Timer? _copyResetTimer;
  BpeTokenizer? _loadedTokenizer;
  bool _isLoadingTokenizer = false;
  final Map<String, int> _tokenCache = {};

  String _mapLanguage(String ext) {
    switch (ext.toLowerCase()) {
      case '.dart':
        return 'Dart';
      case '.cpp':
      case '.cc':
      case '.cxx':
        return 'C++';
      case '.h':
      case '.hpp':
        return 'C Header';
      case '.c':
        return 'C';
      case '.js':
      case '.mjs':
      case '.cjs':
        return 'JavaScript';
      case '.ts':
        return 'TypeScript';
      case '.jsx':
        return 'JSX';
      case '.tsx':
        return 'TSX';
      case '.json':
        return 'JSON';
      case '.html':
      case '.htm':
        return 'HTML';
      case '.css':
      case '.scss':
      case '.less':
        return 'CSS';
      case '.yaml':
      case '.yml':
        return 'YAML';
      case '.md':
      case '.markdown':
        return 'Markdown';
      case '.py':
        return 'Python';
      case '.rs':
        return 'Rust';
      case '.go':
        return 'Go';
      case '.java':
        return 'Java';
      case '.cs':
        return 'C#';
      case '.kt':
        return 'Kotlin';
      case '.swift':
        return 'Swift';
      case '.sh':
      case '.ps1':
      case '.bat':
        return 'Shell Script';
      case '.xml':
        return 'XML';
      case 'cmakelists.txt':
      default:
        return ext.isEmpty
            ? 'Plain Text'
            : ext.toUpperCase().replaceAll('.', '');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTokenizer();
  }

  Future<void> _loadTokenizer() async {
    setState(() {
      _isLoadingTokenizer = true;
    });
    final tokenizer = await widget.tokenizerRegistry.getTokenizer();
    if (mounted) {
      setState(() {
        _loadedTokenizer = tokenizer;
        _isLoadingTokenizer = false;
      });
      _prefetchAllTokens();
    }
  }

  Future<void> _prefetchAllTokens() async {
    if (_loadedTokenizer == null) return;
    final breakdown = _buildLanguageBreakdown();
    final allFiles = <FsNode>[];
    for (final group in breakdown.values) {
      allFiles.addAll(group.files);
    }

    int processedSinceLastRedraw = 0;
    for (final file in allFiles) {
      if (!mounted) break;
      if (_tokenCache.containsKey(file.path)) continue;

      // Skip non-text or massive binary files > 2MB
      if (file.size > 2 * 1024 * 1024) {
        _tokenCache[file.path] = 0;
        continue;
      }

      try {
        final text = await File(file.path).readAsString();
        final count = _loadedTokenizer!.countTokens(text);
        _tokenCache[file.path] = count;
      } catch (_) {
        _tokenCache[file.path] = 0;
      }

      processedSinceLastRedraw++;
      // Batch redraw every 20 files so UI thread doesn't choke on 1000s of setState calls
      if (processedSinceLastRedraw >= 20) {
        processedSinceLastRedraw = 0;
        if (mounted) setState(() {});
        await Future.delayed(
          Duration.zero,
        ); // Give UI thread room to render frame
      }
    }
    if (mounted) setState(() {});
  }

  int _estimateFileTokens(FsNode file) {
    if (_tokenCache.containsKey(file.path)) {
      return _tokenCache[file.path]!;
    }
    return 0;
  }

  String _getRelativePath(String fullPath) {
    if (widget.nodes.isEmpty) return fullPath;
    final rootPath = widget.nodes.first.path;
    final parentDir = rootPath.substring(
      0,
      rootPath.lastIndexOf(RegExp(r'[/\\]')),
    );
    if (fullPath.startsWith(parentDir)) {
      var rel = fullPath.substring(parentDir.length);
      if (rel.startsWith('/') || rel.startsWith('\\')) {
        rel = rel.substring(1);
      }
      return rel;
    }
    return fullPath;
  }

  String _generateMarkdownTable(List<LanguageStats> sortedLanguages) {
    final sb = StringBuffer();

    sb.writeln(
      '| Language / File | Files | Lines | Code | Comments | Blanks | Est. Tokens |',
    );
    sb.writeln('| :--- | :---: | :---: | :---: | :---: | :---: | :---: |');

    int totalFiles = 0;
    int totalLines = 0;
    int totalCode = 0;
    int totalComments = 0;
    int totalBlanks = 0;
    int grandTotalTokens = 0;

    for (final group in sortedLanguages) {
      totalFiles += group.files.length;
      totalLines += group.lines;
      totalCode += group.code;
      totalComments += group.comments;
      totalBlanks += group.blanks;

      int groupTokens = 0;
      for (final file in group.files) {
        groupTokens += _estimateFileTokens(file);
      }
      grandTotalTokens += groupTokens;

      sb.writeln(
        '| **${group.language}** | **${group.files.length}** | **${FormatUtils.formatNumber(group.lines)}** | **${FormatUtils.formatNumber(group.code)}** | **${FormatUtils.formatNumber(group.comments)}** | **${FormatUtils.formatNumber(group.blanks)}** | **${FormatUtils.formatNumber(groupTokens)}** |',
      );

      for (final file in group.files) {
        final relPath = _getRelativePath(file.path);
        final fileTokens = _estimateFileTokens(file);
        sb.writeln(
          '| &nbsp;&nbsp;&nbsp;&nbsp;`$relPath` | 1 | ${FormatUtils.formatNumber(file.lineCount)} | ${FormatUtils.formatNumber(file.codeLineCount)} | ${FormatUtils.formatNumber(file.commentLineCount)} | ${FormatUtils.formatNumber(file.blankLineCount)} | ${FormatUtils.formatNumber(fileTokens)} |',
        );
      }
    }

    sb.writeln(
      '| **Total** | **$totalFiles** | **${FormatUtils.formatNumber(totalLines)}** | **${FormatUtils.formatNumber(totalCode)}** | **${FormatUtils.formatNumber(totalComments)}** | **${FormatUtils.formatNumber(totalBlanks)}** | **${FormatUtils.formatNumber(grandTotalTokens)}** |',
    );

    return sb.toString();
  }

  Map<String, LanguageStats> _buildLanguageBreakdown() {
    final map = <String, LanguageStats>{};

    void recurse(FsNode node) {
      if (node.isDirectory) {
        if (node.children != null) {
          for (final child in node.children!) {
            recurse(child);
          }
        }
      } else {
        if (node.lineCount == 0 &&
            node.codeLineCount == 0 &&
            node.blankLineCount == 0) {
          return;
        }

        final lang = node.name.toLowerCase() == 'cmakelists.txt'
            ? 'CMake'
            : _mapLanguage(node.extension);

        final group = map.putIfAbsent(
          lang,
          () => LanguageStats(language: lang),
        );
        group.files.add(node);
        group.lines += node.lineCount;
        group.code += node.codeLineCount;
        group.comments += node.commentLineCount;
        group.blanks += node.blankLineCount;
        group.bytes += node.size;
      }
    }

    for (final node in widget.nodes) {
      recurse(node);
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final languageMap = _buildLanguageBreakdown();
    final sortedLanguages = languageMap.values.toList()
      ..sort((a, b) => b.lines.compareTo(a.lines));

    final int totalCode = widget.stats.totalCodeLines;
    final int totalComments = widget.stats.totalCommentLines;
    final int totalBlanks = widget.stats.totalBlankLines;
    final int totalAllLines = widget.stats.totalLines;

    int totalTokens = 0;
    for (final group in sortedLanguages) {
      for (final file in group.files) {
        totalTokens += _estimateFileTokens(file);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 1. Metric Overview Cards
        Row(
          children: [
            _buildStatCard(
              svgIcon: AppSvgIcon.file,
              label: 'Total Files',
              value: FormatUtils.formatNumber(widget.stats.totalFiles),
              color: AppColors.infoBase,
            ),
            const SizedBox(width: AppSpacing.md),
            _buildStatCard(
              svgIcon: AppSvgIcon.folderOpen,
              label: 'Total Directories',
              value: FormatUtils.formatNumber(widget.stats.totalDirectories),
              color: AppColors.primaryBase,
            ),
            const SizedBox(width: AppSpacing.md),
            _buildStatCard(
              svgIcon: AppSvgIcon.code,
              label: 'Lines of Code',
              value: FormatUtils.formatNumber(widget.stats.totalLines),
              color: AppColors.warningBase,
            ),
            const SizedBox(width: AppSpacing.md),
            _buildStatCard(
              svgIcon: AppSvgIcon.hardDrives,
              label: 'Total Size',
              value: widget.stats.formattedTotalSize,
              color: AppColors.successBase,
            ),
            const SizedBox(width: AppSpacing.md),
            _buildStatCard(
              svgIcon: AppSvgIcon.sparkleDuotone,
              label: 'Est. Tokens',
              value: _isLoadingTokenizer
                  ? '...'
                  : FormatUtils.formatNumber(totalTokens),
              color: AppColors.primaryBase,
            ),
          ],
        ),

        // 2. Line Composition Distribution Bar
        if (totalAllLines > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: ShapeDecoration(
              color: AppColors.neutral13,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: AppColors.neutral11),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Line Composition',
                      style: AppTypography.heading6(
                        color: AppColors.neutral5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total: ${FormatUtils.formatNumber(totalAllLines)} lines',
                      style: AppTypography.caption(color: AppColors.neutral6),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        if (totalCode > 0)
                          Expanded(
                            flex: totalCode,
                            child: Container(color: AppColors.successBase),
                          ),
                        if (totalComments > 0)
                          Expanded(
                            flex: totalComments,
                            child: Container(color: AppColors.infoBase),
                          ),
                        if (totalBlanks > 0)
                          Expanded(
                            flex: totalBlanks,
                            child: Container(color: AppColors.neutral7),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(
                      color: AppColors.successBase,
                      label: 'Code Lines',
                      value: FormatUtils.formatNumber(totalCode),
                      percentage: totalAllLines > 0
                          ? (totalCode / totalAllLines * 100).toStringAsFixed(1)
                          : '0',
                    ),
                    _buildLegendItem(
                      color: AppColors.infoBase,
                      label: 'Comments',
                      value: FormatUtils.formatNumber(totalComments),
                      percentage: totalAllLines > 0
                          ? (totalComments / totalAllLines * 100)
                                .toStringAsFixed(1)
                          : '0',
                    ),
                    _buildLegendItem(
                      color: AppColors.neutral7,
                      label: 'Blank Lines',
                      value: FormatUtils.formatNumber(totalBlanks),
                      percentage: totalAllLines > 0
                          ? (totalBlanks / totalAllLines * 100).toStringAsFixed(
                              1,
                            )
                          : '0',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xxxl),

        // 3. Language & Code Line Table Section
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Language Breakdown',
                      style: AppTypography.heading6(
                        color: AppColors.neutral5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppButton(
                      label: _isCopied ? 'Copied' : 'Copy Markdown Table',
                      svgIcon: _isCopied
                          ? AppSvgIcon.checkBold
                          : AppSvgIcon.copy,
                      variant: AppButtonVariant.text,
                      size: AppButtonSize.small,
                      foregroundColor: _isCopied
                          ? AppColors.successBase
                          : AppColors.primaryBase,
                      onPressed: () {
                        final mdTable = _generateMarkdownTable(sortedLanguages);
                        Clipboard.setData(ClipboardData(text: mdTable));
                        setState(() => _isCopied = true);
                        _copyResetTimer?.cancel();
                        _copyResetTimer = Timer(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _isCopied = false);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Statistics copied to clipboard as Markdown table!',
                            ),
                            backgroundColor: AppColors.primaryBase,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Token counts are estimated using the included tokenizer configuration. Actual token counts may vary depending on the target LLM's model configuration.",
                  style: AppTypography.caption(color: AppColors.neutral7),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${sortedLanguages.length} Languages Detected',
              style: AppTypography.caption(color: AppColors.neutral6),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Header Row
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.neutral10.withValues(alpha: 0.64),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Language',
                  style: AppTypography.body(
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral0,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Files',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral0,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total Lines',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral0,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Code',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    fontWeight: FontWeight.bold,
                    color: AppColors.successBase,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Comments',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    fontWeight: FontWeight.bold,
                    color: AppColors.infoBase,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Blanks',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral6,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Est. Tokens',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBase,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (sortedLanguages.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.neutral11,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
              border: Border.all(color: AppColors.neutral10),
            ),
            child: Center(
              child: Text(
                'No code files detected in this directory.',
                style: AppTypography.body(color: AppColors.neutral6),
              ),
            ),
          )
        else
          ...List.generate(sortedLanguages.length, (index) {
            final group = sortedLanguages[index];
            final isExpanded = _expandedLanguages.contains(group.language);
            final isLast = index == sortedLanguages.length - 1;

            return Container(
              decoration: BoxDecoration(
                color: index % 2 == 0
                    ? AppColors.neutral11.withValues(alpha: 0.5)
                    : AppColors.neutral12.withValues(alpha: 0.2),
                borderRadius: isLast && !isExpanded
                    ? const BorderRadius.vertical(bottom: Radius.circular(10))
                    : BorderRadius.zero,
                border: Border(
                  left: const BorderSide(color: AppColors.neutral10),
                  right: const BorderSide(color: AppColors.neutral10),
                  bottom: BorderSide(
                    color: AppColors.neutral10,
                    width: isLast && !isExpanded ? 1 : 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedLanguages.remove(group.language);
                        } else {
                          _expandedLanguages.add(group.language);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                AppIcon(
                                  isExpanded
                                      ? AppSvgIcon.caretDownBold
                                      : AppSvgIcon.caretRightBold,
                                  size: 16,
                                  color: AppColors.primaryBase,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    group.language,
                                    style: AppTypography.body(
                                      color: AppColors.neutral3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              FormatUtils.formatNumber(group.files.length),
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                color: AppColors.neutral3,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              FormatUtils.formatNumber(group.lines),
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                color: AppColors.neutral0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              FormatUtils.formatNumber(group.code),
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                color: AppColors.successBase,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              FormatUtils.formatNumber(group.comments),
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                color: AppColors.infoBase,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              FormatUtils.formatNumber(group.blanks),
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                color: AppColors.neutral6,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              FormatUtils.formatNumber(
                                group.files.fold<int>(
                                  0,
                                  (sum, file) =>
                                      sum + _estimateFileTokens(file),
                                ),
                              ),
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                color: AppColors.primaryBase,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    Container(
                      color: AppColors.neutral13,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        children: group.files.map((file) {
                          final iconSvg = IconMappingConfig.instance
                              .getIconForExtension(file.extension);
                          final threshold = widget.thresholdsConfig
                              .getThreshold(file.extension);
                          final isExceeded = file.lineCount > threshold;
                          final excessPercent = isExceeded
                              ? ((file.lineCount - threshold) / threshold * 100)
                                    .toStringAsFixed(0)
                              : null;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isExceeded
                                  ? AppColors.dangerBase.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 18),
                                    child: Row(
                                      children: [
                                        SvgPicture.asset(
                                          'assets/mapping/$iconSvg',
                                          width: 14,
                                          height: 14,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                file.name,
                                                style: AppTypography.subtitle(
                                                  color: isExceeded
                                                      ? AppColors.dangerBase
                                                      : AppColors.neutral4,
                                                  fontWeight: isExceeded
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                _getRelativePath(file.path),
                                                style: AppTypography.label(
                                                  color: AppColors.neutral7,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isExceeded) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.dangerBase
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: AppColors.dangerBase
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Text(
                                              '+$excessPercent% over limit ($threshold)',
                                              style: AppTypography.caption(
                                                color: AppColors.dangerHover,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '1',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.neutral6,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(file.lineCount),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: isExceeded
                                          ? AppColors.dangerBase
                                          : AppColors.neutral4,
                                      fontWeight: isExceeded
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(
                                      file.codeLineCount,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.successBase,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(
                                      file.commentLineCount,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.infoBase,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(
                                      file.blankLineCount,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.neutral6,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    FormatUtils.formatNumber(
                                      _estimateFileTokens(file),
                                    ),
                                    textAlign: TextAlign.center,
                                    style: AppTypography.subtitle(
                                      color: AppColors.primaryBase,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          }),

        const SizedBox(height: AppSpacing.xxxl),

        // 4. File Type Distribution Pie Chart
        _FileTypeDistributionCard(
          extensionCounts: widget.stats.extensionCounts,
          extensionSizes: widget.stats.extensionSizes,
          totalFiles: widget.stats.totalFiles,
          includedBytes: widget.stats.totalBytes,
          scanTotals: widget.scanTotals,
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String value,
    required String percentage,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: ',
          style: AppTypography.caption(color: AppColors.neutral5),
        ),
        Text(
          '$value ($percentage%)',
          style: AppTypography.caption(
            color: AppColors.neutral0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required AppSvgIcon svgIcon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: ShapeDecoration(
          color: AppColors.neutral13,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.neutral11),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppIcon(svgIcon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption(color: AppColors.neutral6),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.heading6(color: AppColors.neutral0),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }
}

class _PieSliceEntry {
  const _PieSliceEntry({
    required this.label,
    required this.count,
    required this.sizeBytes,
    required this.color,
  });

  final String label;
  final int count;
  final int sizeBytes;
  final Color color;
}

const List<Color> _piePalette = [
  Color(0xFF4DA6FF),
  Color(0xFF22C55E),
  Color(0xFFA78BFA),
  Color(0xFFF59E0B),
  Color(0xFF22D3EE),
  Color(0xFFF43F5E),
  Color(0xFFFB923C),
  Color(0xFF4CD68A),
  Color(0xFFA5B4FC),
  Color(0xFFE879F9),
  Color(0xFFFACC15),
  Color(0xFF60A5FA),
  Color(0xFF2DD4BF),
  Color(0xFFF87171),
  Color(0xFFC084FC),
  Color(0xFF94A3B8),
];

Color _sliceColor(int index) {
  if (index < _piePalette.length) return _piePalette[index];
  final base = HSLColor.fromColor(_piePalette[index % _piePalette.length]);
  final shift = (index ~/ _piePalette.length) * 18;
  return base
      .withHue((base.hue + shift) % 360)
      .withLightness((base.lightness + 0.08).clamp(0.35, 0.8))
      .toColor();
}

class _FileTypeDistributionCard extends StatefulWidget {
  const _FileTypeDistributionCard({
    required this.extensionCounts,
    required this.extensionSizes,
    required this.totalFiles,
    required this.includedBytes,
    required this.scanTotals,
  });

  final Map<String, int> extensionCounts;
  final Map<String, int> extensionSizes;
  final int totalFiles;
  final int includedBytes;
  final ScanTotals? scanTotals;

  @override
  State<_FileTypeDistributionCard> createState() =>
      _FileTypeDistributionCardState();
}

class _FileTypeDistributionCardState extends State<_FileTypeDistributionCard> {
  int? _hoveredIndex;
  int? _selectedIndex;

  List<_PieSliceEntry> _buildSlices() {
    final entries =
        widget.extensionCounts.entries
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      return _PieSliceEntry(
        label: entry.key == 'No Ext' ? 'No extension' : entry.key,
        count: entry.value,
        sizeBytes: widget.extensionSizes[entry.key] ?? 0,
        color: _sliceColor(index),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final slices = _buildSlices();
    if (slices.isEmpty) return const SizedBox.shrink();

    final activeIndex = _selectedIndex ?? _hoveredIndex;
    final activeSlice = activeIndex != null ? slices[activeIndex] : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: ShapeDecoration(
        color: AppColors.neutral13,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.neutral11, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'File Type Distribution',
                style: AppTypography.heading6(
                  color: AppColors.neutral5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${slices.length} file types',
                style: AppTypography.caption(color: AppColors.neutral6),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Center(
                  child: _PieChartView(
                    slices: slices,
                    totalCount: widget.totalFiles,
                    hoveredIndex: _hoveredIndex,
                    selectedIndex: _selectedIndex,
                    onHoverChanged: (index) =>
                        setState(() => _hoveredIndex = index),
                    onSelectedChanged: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(
                flex: 4,
                child: _PieLegend(
                  slices: slices,
                  totalCount: widget.totalFiles,
                  hoveredIndex: _hoveredIndex,
                  selectedIndex: _selectedIndex,
                  onHoverChanged: (index) =>
                      setState(() => _hoveredIndex = index),
                  onSelectedChanged: (index) =>
                      setState(() => _selectedIndex = index),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.neutral12.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: activeSlice == null
                ? Text(
                    '${FormatUtils.formatNumber(widget.totalFiles)} files across ${slices.length} file types',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption(color: AppColors.neutral6),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: activeSlice.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        activeSlice.label,
                        style: AppTypography.caption(
                          color: AppColors.neutral0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        '${FormatUtils.formatNumber(activeSlice.count)} ${activeSlice.count == 1 ? 'file' : 'files'}',
                        style: AppTypography.caption(color: AppColors.neutral5),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        FsNode.formatBytes(activeSlice.sizeBytes),
                        style: AppTypography.caption(
                          color: AppColors.neutral5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        '${(activeSlice.count / widget.totalFiles * 100).toStringAsFixed(1)}%',
                        style: AppTypography.caption(
                          color: activeSlice.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
          if (widget.scanTotals != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildTotalsSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalsSummary() {
    final totals = widget.scanTotals!;
    final includedFiles = widget.totalFiles;
    final includedBytes = widget.includedBytes;
    final excludedFiles = math.max(0, totals.files - includedFiles);
    final excludedBytes = math.max(0, totals.bytes - includedBytes);
    final diskFiles = math.max(includedFiles, totals.files);
    final diskBytes = math.max(includedBytes, totals.bytes);

    double shareOf(int count) =>
        diskFiles > 0 ? (count / diskFiles * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutral12.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Scan Summary (exclusions applied)',
                    style: AppTypography.label(
                      color: AppColors.neutral7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Files',
                    textAlign: TextAlign.right,
                    style: AppTypography.label(
                      color: AppColors.neutral7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Size',
                    textAlign: TextAlign.right,
                    style: AppTypography.label(
                      color: AppColors.neutral7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 65,
                  child: Text(
                    'Share',
                    textAlign: TextAlign.right,
                    style: AppTypography.label(
                      color: AppColors.neutral7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildTotalsRow(
            dotColor: AppColors.successBase,
            label: 'Included',
            files: includedFiles,
            bytes: includedBytes,
            share: shareOf(includedFiles),
            shareColor: AppColors.successBase,
          ),
          _buildTotalsRow(
            dotColor: AppColors.warningBase,
            label: 'Excluded',
            files: excludedFiles,
            bytes: excludedBytes,
            share: shareOf(excludedFiles),
            shareColor: AppColors.warningBase,
          ),
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.neutral10, width: 1),
              ),
            ),
            child: _buildTotalsRow(
              dotColor: AppColors.neutral4,
              label: 'Total on disk',
              files: diskFiles,
              bytes: diskBytes,
              share: 100,
              shareColor: AppColors.neutral4,
              emphasized: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsRow({
    required Color dotColor,
    required String label,
    required int files,
    required int bytes,
    required double share,
    required Color shareColor,
    bool emphasized = false,
  }) {
    final labelStyle = AppTypography.body(
      color: emphasized ? AppColors.neutral3 : AppColors.neutral3,
      fontWeight: emphasized ? FontWeight.w500 : FontWeight.w500,
    );
    final valueStyle = AppTypography.body(
      color: emphasized ? AppColors.neutral3 : AppColors.neutral5,
      fontWeight: emphasized ? FontWeight.w500 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: labelStyle)),
          SizedBox(
            width: 100,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${FormatUtils.formatNumber(files)} ${files == 1 ? 'file' : 'files'}',
                textAlign: TextAlign.right,
                style: valueStyle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 80,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                FsNode.formatBytes(bytes),
                textAlign: TextAlign.right,
                style: valueStyle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 65,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${share.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: AppTypography.caption(
                  color: shareColor,
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartView extends StatefulWidget {
  const _PieChartView({
    required this.slices,
    required this.totalCount,
    required this.hoveredIndex,
    required this.selectedIndex,
    required this.onHoverChanged,
    required this.onSelectedChanged,
  });

  final List<_PieSliceEntry> slices;
  final int totalCount;
  final int? hoveredIndex;
  final int? selectedIndex;
  final ValueChanged<int?> onHoverChanged;
  final ValueChanged<int?> onSelectedChanged;

  @override
  State<_PieChartView> createState() => _PieChartViewState();
}

class _PieChartViewState extends State<_PieChartView>
    with SingleTickerProviderStateMixin {
  static const double _chartSize = 340;

  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _hitTest(Offset position, double size) {
    final center = Offset(size / 2, size / 2);
    final delta = position - center;
    if (delta.distance > size / 2) return null;

    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    var accumulated = 0.0;
    for (var i = 0; i < widget.slices.length; i++) {
      final sweep = (widget.slices[i].count / widget.totalCount) * 2 * math.pi;
      if (angle >= accumulated && angle < accumulated + sweep) return i;
      accumulated += sweep;
    }
    return widget.slices.isEmpty ? null : widget.slices.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _chartSize;
        final size = math.min(_chartSize, maxWidth);

        return SizedBox(
          width: size,
          height: size,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onHover: (event) {
              final index = _hitTest(event.localPosition, size);
              if (index != widget.hoveredIndex) widget.onHoverChanged(index);
            },
            onExit: (_) {
              if (widget.hoveredIndex != null) widget.onHoverChanged(null);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final index = _hitTest(details.localPosition, size);
                widget.onSelectedChanged(
                  widget.selectedIndex == index ? null : index,
                );
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end:
                      widget.hoveredIndex != null ||
                          widget.selectedIndex != null
                      ? 1
                      : 0,
                ),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (context, intensity, _) => AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) => CustomPaint(
                    painter: _PiePainter(
                      slices: widget.slices,
                      totalCount: widget.totalCount,
                      progress: _progress.value,
                      hoveredIndex: widget.hoveredIndex,
                      selectedIndex: widget.selectedIndex,
                      intensity: intensity,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.slices,
    required this.totalCount,
    required this.progress,
    required this.intensity,
    this.hoveredIndex,
    this.selectedIndex,
  });

  final List<_PieSliceEntry> slices;
  final int totalCount;
  final double progress;
  final double intensity;
  final int? hoveredIndex;
  final int? selectedIndex;

  static const double _gap = 0.015;
  static const double _hoverExplode = 5;
  static const double _selectedExplode = 10;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty || totalCount <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    var startAngle = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final fullSweep = (slice.count / totalCount) * 2 * math.pi;

      final t = ((progress * slices.length) - i).clamp(0.0, 1.0);
      final currentFullSweep = fullSweep * Curves.easeOutCubic.transform(t);

      if (currentFullSweep > 0) {
        final drawSweep = currentFullSweep > _gap * 2
            ? currentFullSweep - _gap
            : currentFullSweep;
        final isHovered = hoveredIndex == i;
        final isSelected = selectedIndex == i;

        var drawCenter = center;
        if (isHovered || isSelected) {
          final explode =
              (isSelected ? _selectedExplode : _hoverExplode) * intensity;
          if (explode > 0) {
            final midAngle = startAngle + drawSweep / 2;
            drawCenter =
                center +
                Offset(math.cos(midAngle), math.sin(midAngle)) * explode;
          }
        }

        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = (isHovered || isSelected)
              ? Color.lerp(slice.color, Colors.white, 0.14 * intensity)!
              : slice.color;

        canvas.drawArc(
          Rect.fromCircle(center: drawCenter, radius: radius),
          startAngle,
          drawSweep,
          true,
          paint,
        );
      }

      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.intensity != intensity ||
      oldDelegate.hoveredIndex != hoveredIndex ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.slices != slices ||
      oldDelegate.totalCount != totalCount;
}

class _PieLegend extends StatelessWidget {
  const _PieLegend({
    required this.slices,
    required this.totalCount,
    required this.hoveredIndex,
    required this.selectedIndex,
    required this.onHoverChanged,
    required this.onSelectedChanged,
  });

  final List<_PieSliceEntry> slices;
  final int totalCount;
  final int? hoveredIndex;
  final int? selectedIndex;
  final ValueChanged<int?> onHoverChanged;
  final ValueChanged<int?> onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 340),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'File Type',
                      style: AppTypography.label(
                        color: AppColors.neutral7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Files',
                      textAlign: TextAlign.right,
                      style: AppTypography.label(
                        color: AppColors.neutral7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Size',
                      textAlign: TextAlign.right,
                      style: AppTypography.label(
                        color: AppColors.neutral7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 65,
                    child: Text(
                      'Share',
                      textAlign: TextAlign.right,
                      style: AppTypography.label(
                        color: AppColors.neutral7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < slices.length; i++)
              _buildLegendItem(context, i),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, int index) {
    final slice = slices[index];
    final isActive = hoveredIndex == index || selectedIndex == index;
    final isSelected = selectedIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(index),
      onExit: (_) => onHoverChanged(null),
      child: GestureDetector(
        onTap: () => onSelectedChanged(isSelected ? null : index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? slice.color.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: slice.color.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: slice.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  slice.label,
                  style: AppTypography.body(
                    color: isActive ? AppColors.neutral0 : AppColors.neutral3,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 100,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${FormatUtils.formatNumber(slice.count)} ${slice.count == 1 ? 'file' : 'files'}',
                    textAlign: TextAlign.right,
                    style: AppTypography.caption(
                      color: AppColors.neutral3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 80,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    FsNode.formatBytes(slice.sizeBytes),
                    textAlign: TextAlign.right,
                    style: AppTypography.caption(
                      color: AppColors.neutral5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 65,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(slice.count / totalCount * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: AppTypography.caption(
                      color: isActive ? slice.color : AppColors.neutral6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
