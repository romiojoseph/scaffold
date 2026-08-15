import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_stats.dart';
import '../models/fs_node.dart';
import '../services/tokenizer_registry.dart';
import '../services/bpe_tokenizer.dart';
import '../services/scanner_service.dart';
import '../models/thresholds_config.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import 'common/app_toast.dart';
import 'stats/language_breakdown_table.dart';
import 'stats/language_stats.dart';
import 'stats/line_composition_bar.dart';
import 'stats/stats_copy_bar.dart';
import 'stats/stats_metric_cards.dart';
import 'stats/stats_pie_chart.dart';

class StatsView extends StatefulWidget {
  final ScanStats stats;
  final List<FsNode> nodes;
  final ThresholdsConfig thresholdsConfig;
  final TokenizerRegistry tokenizerRegistry;
  final ScanTotals? scanTotals;
  final String rootPath;

  const StatsView({
    super.key,
    required this.stats,
    required this.nodes,
    required this.thresholdsConfig,
    required this.tokenizerRegistry,
    this.scanTotals,
    this.rootPath = '',
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
  static final Map<String, int> _tokenCache = {};


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
            : mapLanguage(node.extension);

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
        statsMetricCards(
          stats: widget.stats,
          totalTokens: totalTokens,
          isLoadingTokenizer: _isLoadingTokenizer,
        ),

        // 2. Line Composition Distribution Bar
        lineCompositionBar(
          totalCode: totalCode,
          totalComments: totalComments,
          totalBlanks: totalBlanks,
          totalAllLines: totalAllLines,
        ),

        const SizedBox(height: AppSpacing.xxxl),

        // 3. Language & Code Line Table Section
        statsCopyBar(
          isCopied: _isCopied,
          onCopyPressed: () {
            final mdTable = _generateMarkdownTable(sortedLanguages);
            Clipboard.setData(ClipboardData(text: mdTable));
            setState(() => _isCopied = true);
            _copyResetTimer?.cancel();
            _copyResetTimer = Timer(const Duration(seconds: 2), () {
              if (mounted) setState(() => _isCopied = false);
            });
            AppToast.showSuccess(
              context,
              'Statistics copied to clipboard as Markdown table!',
            );
          },
          languageCount: sortedLanguages.length,
        ),
        const SizedBox(height: AppSpacing.md),

        languageBreakdownTable(
          context: context,
          sortedLanguages: sortedLanguages,
          expandedLanguages: _expandedLanguages,
          onToggleLanguage: (lang) {
            setState(() {
              if (_expandedLanguages.contains(lang)) {
                _expandedLanguages.remove(lang);
              } else {
                _expandedLanguages.add(lang);
              }
            });
          },
          estimateFileTokens: _estimateFileTokens,
          getRelativePath: _getRelativePath,
          thresholdsConfig: widget.thresholdsConfig,
          rootPath: widget.rootPath,
        ),

        const SizedBox(height: AppSpacing.xxxl),

        // 4. File Type Distribution Pie Chart
        FileTypeDistributionCard(
          extensionCounts: widget.stats.extensionCounts,
          extensionSizes: widget.stats.extensionSizes,
          totalFiles: widget.stats.totalFiles,
          includedBytes: widget.stats.totalBytes,
          scanTotals: widget.scanTotals,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }
}
