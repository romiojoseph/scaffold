import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/fs_node.dart';
import '../../services/scanner_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import 'totals_summary.dart';

class PieSliceEntry {
  const PieSliceEntry({
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

class FileTypeDistributionCard extends StatefulWidget {
  const FileTypeDistributionCard({
    super.key,
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
  State<FileTypeDistributionCard> createState() =>
      _FileTypeDistributionCardState();
}

class _FileTypeDistributionCardState extends State<FileTypeDistributionCard> {
  int? _hoveredIndex;
  int? _selectedIndex;

  List<PieSliceEntry> _buildSlices() {
    final entries =
        widget.extensionCounts.entries
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      return PieSliceEntry(
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
                  child: PieChartView(
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
                child: PieLegend(
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
            buildTotalsSummary(
              totals: widget.scanTotals!,
              includedFiles: widget.totalFiles,
              includedBytes: widget.includedBytes,
            ),
          ],
        ],
      ),
    );
  }
}

class PieChartView extends StatefulWidget {
  const PieChartView({
    super.key,
    required this.slices,
    required this.totalCount,
    required this.hoveredIndex,
    required this.selectedIndex,
    required this.onHoverChanged,
    required this.onSelectedChanged,
  });

  final List<PieSliceEntry> slices;
  final int totalCount;
  final int? hoveredIndex;
  final int? selectedIndex;
  final ValueChanged<int?> onHoverChanged;
  final ValueChanged<int?> onSelectedChanged;

  @override
  State<PieChartView> createState() => _PieChartViewState();
}

class _PieChartViewState extends State<PieChartView>
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
                    painter: PiePainter(
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

class PiePainter extends CustomPainter {
  PiePainter({
    required this.slices,
    required this.totalCount,
    required this.progress,
    required this.intensity,
    this.hoveredIndex,
    this.selectedIndex,
  });

  final List<PieSliceEntry> slices;
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
  bool shouldRepaint(PiePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.intensity != intensity ||
      oldDelegate.hoveredIndex != hoveredIndex ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.slices != slices ||
      oldDelegate.totalCount != totalCount;
}

class PieLegend extends StatelessWidget {
  const PieLegend({
    super.key,
    required this.slices,
    required this.totalCount,
    required this.hoveredIndex,
    required this.selectedIndex,
    required this.onHoverChanged,
    required this.onSelectedChanged,
  });

  final List<PieSliceEntry> slices;
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