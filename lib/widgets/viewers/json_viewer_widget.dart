import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/export_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_icon.dart';
import '../common/app_text_field.dart';

class JsonViewerWidget extends StatefulWidget {
  final String jsonContent;
  final Widget Function(
    BuildContext context,
    int visibleCount,
    int totalCount,
    VoidCallback expandAll,
    VoidCallback collapseAll,
    VoidCallback copyJson,
    bool skeletonMode,
    VoidCallback toggleSkeleton,
    VoidCallback copySkeleton,
    bool copiedSkeleton,
    bool isAllExpanded,
    VoidCallback toggleExpandCollapse,
  )?
  headerActions;

  const JsonViewerWidget({
    super.key,
    required this.jsonContent,
    this.headerActions,
  });

  @override
  State<JsonViewerWidget> createState() => _JsonViewerWidgetState();
}

enum _NodeType { map, list, primitive }

class _JsonNode {
  _JsonNode({
    required this.id,
    required this.parentId,
    required this.depth,
    required this.type,
    required this.keyLabel,
    this.rawKey,
    this.valueLabel,
    this.rawValue,
    this.valueColor,
    this.childCount = 0,
  });

  final int id;
  final int parentId;
  final int depth;
  final _NodeType type;
  final String? keyLabel;
  final String? rawKey;
  final String? valueLabel;
  final dynamic rawValue;
  final Color? valueColor;
  final int childCount;

  bool get isContainer => type != _NodeType.primitive;
}

/// Runs in a background isolate so large files don't block the UI thread.
List<_JsonNode> _flattenJson(String content) {
  // jsonDecode in Dart preserves key insertion order of JSON objects.
  final root = jsonDecode(content);
  final nodes = <_JsonNode>[];
  var id = 0;

  void visit(dynamic value, String? key, int parentId, int depth) {
    final nodeId = id++;
    if (depth > 128) {
      nodes.add(
        _JsonNode(
          id: nodeId,
          parentId: parentId,
          depth: depth,
          type: _NodeType.primitive,
          keyLabel: key,
          rawKey: key,
          valueLabel: '... (Max recursion depth reached)',
          rawValue: '... (Max recursion depth reached)',
          valueColor: AppColors.warningBase,
        ),
      );
      return;
    }
    if (value is Map) {
      nodes.add(
        _JsonNode(
          id: nodeId,
          parentId: parentId,
          depth: depth,
          type: _NodeType.map,
          keyLabel: _keyLabel(key),
          rawKey: key,
          childCount: value.length,
        ),
      );
      for (final entry in value.entries) {
        visit(entry.value, entry.key.toString(), nodeId, depth + 1);
      }
    } else if (value is List) {
      nodes.add(
        _JsonNode(
          id: nodeId,
          parentId: parentId,
          depth: depth,
          type: _NodeType.list,
          keyLabel: _keyLabel(key),
          rawKey: key,
          childCount: value.length,
        ),
      );
      for (var i = 0; i < value.length; i++) {
        visit(value[i], '[$i]', nodeId, depth + 1);
      }
    } else {
      nodes.add(
        _JsonNode(
          id: nodeId,
          parentId: parentId,
          depth: depth,
          type: _NodeType.primitive,
          keyLabel: _keyLabel(key),
          rawKey: key,
          valueLabel: _formatPrimitive(value),
          rawValue: value,
          valueColor: _primitiveColor(value),
        ),
      );
    }
  }

  visit(root, null, -1, 0);
  return nodes;
}

/// Builds a skeleton (schema-shape) of a JSON value, stripping actual values.
/// Runs in an isolate via compute() — must be a top-level function.
dynamic _buildSkeleton(dynamic value) {
  if (value == null) return null;
  if (value is String) return 'string';
  if (value is int) return 0;
  if (value is double) return 0.0;
  if (value is bool) return true;
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key: _buildSkeleton(entry.value),
    };
  }
  if (value is List) {
    if (value.isEmpty) return <dynamic>[];
    return [_buildSkeleton(value[0])];
  }
  return null;
}

/// Top-level function for compute(): parses + skeletonizes + re-encodes.
String _computeSkeletonJson(String content) {
  final root = jsonDecode(content);
  final skeleton = _buildSkeleton(root);
  return const JsonEncoder.withIndent('  ').convert(skeleton);
}

String? _keyLabel(String? key) {
  if (key == null) return null;
  return key.startsWith('[') ? '$key: ' : '"$key": ';
}

String _formatPrimitive(dynamic value) {
  if (value == null) return 'null';
  if (value is String) return '"$value"';
  return '$value';
}

Color _primitiveColor(dynamic value) {
  if (value == null) {
    return const Color(0xFF569CD6); // VS Code Blue for null
  }
  if (value is String) {
    return const Color(0xFFCE9178); // VS Code Terracotta Red/Orange for Strings
  }
  if (value is num) {
    return const Color(0xFFB5CEA8); // VS Code Mint Green for Numbers
  }
  if (value is bool) {
    return const Color(0xFF569CD6); // VS Code Blue for Booleans
  }
  return AppColors.neutral6;
}

class _JsonViewerWidgetState extends State<JsonViewerWidget> {
  static const double _defaultRowHeight = 24;
  static const int _autoCollapseThreshold = 2000;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, double> _rowHeights = {};

  List<_JsonNode> _nodes = const [];
  Map<int, _JsonNode> _byId = const {};
  String? _error;
  bool _isLoading = false;
  int _parseGeneration = 0;
  final Set<int> _collapsed = {};
  bool _wasAutoCollapsed = false;

  String _query = '';
  List<int> _matches = const [];
  int _matchIndex = -1;

  // Skeleton mode state
  bool _skeletonMode = false;
  String? _skeletonJson;
  bool _copiedSkeleton = false;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant JsonViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jsonContent != widget.jsonContent) {
      _collapsed.clear();
      _rowHeights.clear();
      _searchController.clear();
      _query = '';
      _matches = const [];
      _matchIndex = -1;
      // Reset skeleton state when content changes
      _skeletonJson = null;
      _skeletonMode = false;
      _parse();
    }
  }

  @override
  void dispose() {
    _parseGeneration++;
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    await _parseContent(widget.jsonContent);
  }

  Future<void> _parseContent(String content) async {
    final generation = ++_parseGeneration;
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Empty JSON content';
        _nodes = const [];
        _byId = const {};
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _nodes = const [];
      _byId = const {};
    });
    try {
      final nodes = await compute(_flattenJson, trimmed);
      if (!mounted || generation != _parseGeneration) return;

      // For large files, auto-collapse everything beyond depth 0 so the viewer
      // opens fast and doesn't render hundreds of thousands of rows at once.
      // The user can expand individual nodes or use Expand All from the header.
      final autoCollapsed = <int>{};
      if (nodes.length > _autoCollapseThreshold) {
        for (final n in nodes) {
          if (n.isContainer && n.depth > 0) {
            autoCollapsed.add(n.id);
          }
        }
      }

      setState(() {
        _nodes = nodes;
        _byId = {for (final n in nodes) n.id: n};
        _wasAutoCollapsed = autoCollapsed.isNotEmpty;
        _collapsed
          ..clear()
          ..addAll(autoCollapsed);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _parseGeneration) return;
      setState(() {
        _nodes = const [];
        _byId = const {};
        _isLoading = false;
        _error = 'Invalid JSON syntax: $e';
      });
    }
  }

  /// Returns the skeleton JSON string, computing it lazily on first call.
  Future<String> _getSkeletonJson() async {
    if (_skeletonJson != null) return _skeletonJson!;
    final result = await compute(_computeSkeletonJson, widget.jsonContent.trim());
    _skeletonJson = result;
    return result;
  }

  Future<void> _toggleSkeleton() async {
    final next = !_skeletonMode;
    // Pre-compute skeleton before switching (uses compute() for large files)
    final skeletonJson = next ? await _getSkeletonJson() : null;

    // Reset view state the same way didUpdateWidget does
    _collapsed.clear();
    _rowHeights.clear();
    _searchController.clear();
    _query = '';
    _matches = const [];
    _matchIndex = -1;

    setState(() {
      _skeletonMode = next;
    });

    if (next) {
      await _parseContent(skeletonJson!);
    } else {
      await _parseContent(widget.jsonContent);
    }
  }

  Future<void> _copySkeleton() async {
    final json = await _getSkeletonJson();
    ExportService.copyToClipboard(json);
    setState(() => _copiedSkeleton = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiedSkeleton = false);
  }

  List<_JsonNode> _visibleNodes() {
    final visible = <_JsonNode>[];
    final collapsedDepths = <int>[];

    for (final node in _nodes) {
      // Pop any collapsed depth thresholds that we've exited out of
      while (collapsedDepths.isNotEmpty && node.depth <= collapsedDepths.last) {
        collapsedDepths.removeLast();
      }

      // If we are currently inside any collapsed subtree, skip this node
      if (collapsedDepths.isNotEmpty) {
        continue;
      }

      visible.add(node);

      // If this container node is collapsed, push its depth to stack
      if (node.isContainer && _collapsed.contains(node.id)) {
        collapsedDepths.add(node.depth);
      }
    }

    return visible;
  }

  void _toggle(_JsonNode node) {
    setState(() {
      if (_collapsed.contains(node.id)) {
        _collapsed.remove(node.id);
      } else {
        _collapsed.add(node.id);
      }
    });
  }

  // ---- Search ----

  void _onQueryChanged(String raw) {
    final query = raw.trim().toLowerCase();
    setState(() {
      _query = query;
      _matches = const [];
      _matchIndex = -1;
      if (query.isNotEmpty) {
        _matches = [
          for (final node in _nodes)
            if (_nodeMatches(node, query)) node.id,
        ];
        if (_matches.isNotEmpty) _matchIndex = 0;
      }
    });
    if (_matchIndex >= 0) _goto(_matchIndex);
  }

  bool _nodeMatches(_JsonNode node, String query) {
    final key = node.keyLabel;
    if (key != null && key.toLowerCase().contains(query)) return true;
    final value = node.valueLabel;
    return value != null && value.toLowerCase().contains(query);
  }

  void _nextMatch() {
    if (_matches.isEmpty) return;
    _goto((_matchIndex + 1) % _matches.length);
  }

  void _prevMatch() {
    if (_matches.isEmpty) return;
    _goto((_matchIndex - 1 + _matches.length) % _matches.length);
  }

  void _goto(int index) {
    setState(() {
      _matchIndex = index;
      _expandAncestors(_matches[index]);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrentMatch());
  }

  void _expandAncestors(int nodeId) {
    var parentId = _byId[nodeId]?.parentId;
    while (parentId != null && parentId != -1) {
      _collapsed.remove(parentId);
      parentId = _byId[parentId]?.parentId;
    }
  }

  double _offsetOf(int nodeId) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return 0;
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += _rowHeights[_nodes[i].id] ?? _defaultRowHeight;
    }
    return offset;
  }

  void _jumpToCurrentMatch() {
    if (!_scrollController.hasClients || _matchIndex < 0) return;
    final position = _scrollController.position;
    final target = (_offsetOf(_matches[_matchIndex]) - 8).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon(
                AppSvgIcon.xBold,
                color: AppColors.dangerBase,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTypography.body(color: AppColors.dangerBase),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              _skeletonMode ? 'Building skeleton...' : 'Parsing JSON...',
              style: const TextStyle(color: AppColors.neutral6),
            ),
          ],
        ),
      );
    }

    final visible = _visibleNodes();
    final isAllExpanded = _collapsed.isEmpty;

    return Column(
      children: [
        if (widget.headerActions != null)
          widget.headerActions!(
            context,
            visible.length,
            _nodes.length,
            () => setState(_collapsed.clear),
            () => setState(
              () => _collapsed.addAll(
                _nodes.where((n) => n.isContainer).map((n) => n.id),
              ),
            ),
            () => ExportService.copyToClipboard(widget.jsonContent),
            _skeletonMode,
            _toggleSkeleton,
            _copySkeleton,
            _copiedSkeleton,
            isAllExpanded,
            () => setState(() {
              if (isAllExpanded) {
                _collapsed.addAll(
                  _nodes.where((n) => n.isContainer).map((n) => n.id),
                );
              } else {
                _collapsed.clear();
              }
            }),
          ),
        if (_skeletonMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            color: AppColors.neutral10,
            child: Row(
              children: [
                const AppIcon(
                  AppSvgIcon.treeStructure,
                  size: 14,
                  color: AppColors.neutral5,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Skeleton mode — showing JSON structure with placeholder values.',
                  style: AppTypography.caption(color: AppColors.neutral5),
                ),
                const Spacer(),
                InkWell(
                  onTap: _toggleSkeleton,
                  child: const AppIcon(AppSvgIcon.xBold, size: 12, color: AppColors.neutral6),
                ),
              ],
            ),
          ),
        if (_wasAutoCollapsed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            color: AppColors.neutral10,
            child: Row(
              children: [
                Text(
                  'Large file — nested nodes auto-collapsed. Use Expand All or click nodes to explore.',
                  style: AppTypography.caption(color: AppColors.neutral6),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _wasAutoCollapsed = false),
                  child: const AppIcon(
                    AppSvgIcon.xBold,
                    size: 12,
                    color: AppColors.neutral6,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: AppColors.neutral11,
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _searchController,
                  hintText: 'Search keys and values...',
                  svgPrefixIcon: AppSvgIcon.magnifyingGlass,
                  size: AppInputSize.small,
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) => _nextMatch(),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const AppIcon(
                            AppSvgIcon.xBold,
                            size: 14,
                            color: AppColors.neutral6,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null,
                ),
              ),
              if (_query.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${_matchIndex + 1}/${_matches.length}',
                  style: AppTypography.caption(
                    color: _matches.isEmpty
                        ? AppColors.dangerBase
                        : AppColors.neutral6,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  icon: const AppIcon(
                    AppSvgIcon.caretRightBold,
                    size: 16,
                    color: AppColors.neutral0,
                  ),
                  onPressed: _matches.isEmpty ? null : _prevMatch,
                  tooltip: 'Previous match',
                ),
                IconButton(
                  icon: const AppIcon(
                    AppSvgIcon.caretDownBold,
                    size: 16,
                    color: AppColors.neutral0,
                  ),
                  onPressed: _matches.isEmpty ? null : _nextMatch,
                  tooltip: 'Next match',
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: AppColors.neutral12,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectionArea(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: visible.length,
                itemExtent: 28,
                itemBuilder: (context, index) => _buildRow(visible[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(_JsonNode node) {
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
    final isCurrentMatch = _matchIndex >= 0 && node.id == _matches[_matchIndex];

    return InkWell(
      onTap: node.isContainer ? () => _toggle(node) : null,
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
                        _collapsed.contains(node.id)
                            ? AppSvgIcon.caretRightBold
                            : AppSvgIcon.caretDownBold,
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied key: "$keyToCopy"'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        width: 260,
                      ),
                    );
                  },
                  child: Text.rich(
                    TextSpan(children: _highlightSpans(keyLabel, keyStyle)),
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
                  node.type == _NodeType.map
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied value: "$valToCopy"'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        width: 260,
                      ),
                    );
                  },
                  child: Text.rich(
                    TextSpan(
                      children: _highlightSpans(node.valueLabel!, valueStyle),
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

  List<InlineSpan> _highlightSpans(String text, TextStyle base) {
    if (_query.isEmpty) return [TextSpan(text: text, style: base)];
    final lower = text.toLowerCase();
    final query = _query;
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
}
