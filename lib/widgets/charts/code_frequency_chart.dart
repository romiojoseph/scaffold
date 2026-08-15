import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/git_commit.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../common/app_chart_hover_tooltip.dart';
import '../common/app_icon.dart';
import '../common/app_segmented_control.dart';

class _FrequencyBucket {
  final String shortLabel;
  final String fullLabel;
  int additions = 0;
  int deletions = 0;
  int commits = 0;
  final Set<String> authors = {};

  _FrequencyBucket({required this.shortLabel, required this.fullLabel});

  int get net => additions - deletions;
}

class CodeFrequencyChart extends StatefulWidget {
  final List<GitCommit> commits;

  const CodeFrequencyChart({super.key, required this.commits});

  @override
  State<CodeFrequencyChart> createState() => _CodeFrequencyChartState();
}

class _CodeFrequencyChartState extends State<CodeFrequencyChart> {
  late int _selectedYear;
  int? _hoveredIndex;
  Offset? _hoverPosition;

  List<_FrequencyBucket> _buckets = [];
  int _chartMax = 1;
  int _totalYearAdditions = 0;
  int _totalYearDeletions = 0;
  List<int> _yearsList = [];

  static const List<String> _monthShortNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _fullMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _computeYears();
    _selectedYear = _yearsList.isNotEmpty
        ? _yearsList.first
        : DateTime.now().year;
    _recalculateBuckets();
  }

  @override
  void didUpdateWidget(covariant CodeFrequencyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commits != widget.commits) {
      _computeYears();
      if (!_yearsList.contains(_selectedYear) && _yearsList.isNotEmpty) {
        _selectedYear = _yearsList.first;
      }
      _recalculateBuckets();
    }
  }

  void _computeYears() {
    final yearSet = <int>{};
    for (final c in widget.commits) {
      yearSet.add(c.date.toLocal().year);
    }
    if (yearSet.isEmpty) {
      yearSet.add(DateTime.now().year);
    }
    _yearsList = yearSet.toList()..sort((a, b) => b.compareTo(a));
  }

  void _recalculateBuckets() {
    final buckets = List.generate(
      12,
      (i) => _FrequencyBucket(
        shortLabel: _monthShortNames[i],
        fullLabel: '${_fullMonthNames[i]} $_selectedYear',
      ),
    );

    for (final commit in widget.commits) {
      final localDate = commit.date.toLocal();
      if (localDate.year == _selectedYear) {
        final monthIndex = localDate.month - 1;
        if (monthIndex >= 0 && monthIndex < 12) {
          buckets[monthIndex].commits++;
          buckets[monthIndex].additions += commit.totalAdditions;
          buckets[monthIndex].deletions += commit.totalDeletions;
          buckets[monthIndex].authors.add(commit.author);
        }
      }
    }
    _buckets = buckets;

    int maxAdditions = 0;
    int maxDeletions = 0;
    int totalAdds = 0;
    int totalDels = 0;

    for (final b in buckets) {
      maxAdditions = math.max(maxAdditions, b.additions);
      maxDeletions = math.max(maxDeletions, b.deletions);
      totalAdds += b.additions;
      totalDels += b.deletions;
    }

    final globalMax = math.max(maxAdditions, maxDeletions);
    _chartMax = globalMax == 0 ? 1 : globalMax;
    _totalYearAdditions = totalAdds;
    _totalYearDeletions = totalDels;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ShapeDecoration(
        color: AppColors.neutral13,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.neutral11),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Code Frequency',
                style: AppTypography.heading6(
                  color: AppColors.neutral5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successBase.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '+${FormatUtils.formatNumber(_totalYearAdditions)}',
                  style: AppTypography.body(
                    color: AppColors.successBase,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerBase.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '-${FormatUtils.formatNumber(_totalYearDeletions)}',
                  style: AppTypography.body(
                    color: AppColors.dangerBase,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),

              // Year Selector Tabs
              AppSegmentedControl<int>(
                selectedValue: _selectedYear,
                onValueChanged: (year) => setState(() {
                  _selectedYear = year;
                  _hoveredIndex = null;
                  _hoverPosition = null;
                  _recalculateBuckets();
                }),
                items: _yearsList.map((year) {
                  return AppSegmentedItem<int>(value: year, label: '$year');
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Main Bi-Directional Chart
          LayoutBuilder(
            builder: (context, constraints) {
              const yAxisWidth = 44.0;
              const plotHeight = 256.0;
              const halfHeight = plotHeight / 2;
              final plotWidth = constraints.maxWidth - yAxisWidth;
              final columnWidth = plotWidth / _buckets.length;

              return MouseRegion(
                onExit: (_) => setState(() {
                  _hoveredIndex = null;
                  _hoverPosition = null;
                }),
                onHover: (event) {
                  final localX = event.localPosition.dx;
                  if (localX >= yAxisWidth && localX <= constraints.maxWidth) {
                    final idx = ((localX - yAxisWidth) / columnWidth)
                        .floor()
                        .clamp(0, _buckets.length - 1);
                    setState(() {
                      _hoveredIndex = idx;
                      _hoverPosition = event.localPosition;
                    });
                  } else {
                    setState(() {
                      _hoveredIndex = null;
                      _hoverPosition = null;
                    });
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fixed Y-Axis Labels (+max, 0, -max)
                        SizedBox(
                          width: yAxisWidth,
                          height: plotHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+${FormatUtils.formatCompactNumber(_chartMax)}',
                                style: AppTypography.tagline(
                                  color: AppColors.successBase,
                                ),
                              ),
                              Text(
                                '0',
                                style: AppTypography.tagline(
                                  color: AppColors.neutral7,
                                ),
                              ),
                              Text(
                                '-${FormatUtils.formatCompactNumber(_chartMax)}',
                                style: AppTypography.tagline(
                                  color: AppColors.dangerBase,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Plot Area (Additions above, Deletions below, X-labels aligned)
                        Expanded(
                          child: Column(
                            children: [
                              // Bi-directional bars area
                              SizedBox(
                                height: plotHeight,
                                child: Stack(
                                  children: [
                                    // Top Guide Line
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 1,
                                        color: AppColors.neutral11.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),

                                    // Center Zero Baseline
                                    Positioned(
                                      top: halfHeight - 0.75,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 1.5,
                                        color: AppColors.neutral8,
                                      ),
                                    ),

                                    // Bottom Guide Line
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 1,
                                        color: AppColors.neutral11.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),

                                    // Month Columns
                                    Positioned.fill(
                                      child: Row(
                                        children: List.generate(_buckets.length, (
                                          index,
                                        ) {
                                          final bucket = _buckets[index];
                                          final isHovered =
                                              _hoveredIndex == index;

                                          final addFraction =
                                              bucket.additions / _chartMax;
                                          final addBarHeight =
                                              (addFraction * halfHeight).clamp(
                                                bucket.additions > 0
                                                    ? 3.0
                                                    : 0.0,
                                                halfHeight,
                                              );

                                          final delFraction =
                                              bucket.deletions / _chartMax;
                                          final delBarHeight =
                                              (delFraction * halfHeight).clamp(
                                                bucket.deletions > 0
                                                    ? 3.0
                                                    : 0.0,
                                                halfHeight,
                                              );

                                          return Expanded(
                                            child: Column(
                                              children: [
                                                // Top Half (Additions)
                                                SizedBox(
                                                  height: halfHeight,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.bottomCenter,
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                          ),
                                                      width: 24,
                                                      height: addBarHeight,
                                                      decoration: BoxDecoration(
                                                        color: isHovered
                                                            ? AppColors
                                                                  .successHover
                                                            : (bucket.additions >
                                                                      0
                                                                  ? AppColors
                                                                        .successBase
                                                                  : Colors
                                                                        .transparent),
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    3,
                                                                  ),
                                                            ),
                                                        boxShadow:
                                                            isHovered &&
                                                                bucket.additions >
                                                                    0
                                                            ? [
                                                                BoxShadow(
                                                                  color: AppColors
                                                                      .successBase
                                                                      .withValues(
                                                                        alpha:
                                                                            0.5,
                                                                      ),
                                                                  blurRadius:
                                                                      10,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        -2,
                                                                      ),
                                                                ),
                                                              ]
                                                            : null,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // Bottom Half (Deletions)
                                                SizedBox(
                                                  height: halfHeight,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.topCenter,
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                          ),
                                                      width: 24,
                                                      height: delBarHeight,
                                                      decoration: BoxDecoration(
                                                        color: isHovered
                                                            ? AppColors
                                                                  .dangerHover
                                                            : (bucket.deletions >
                                                                      0
                                                                  ? AppColors
                                                                        .dangerBase
                                                                  : Colors
                                                                        .transparent),
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              bottom:
                                                                  Radius.circular(
                                                                    3,
                                                                  ),
                                                            ),
                                                        boxShadow:
                                                            isHovered &&
                                                                bucket.deletions >
                                                                    0
                                                            ? [
                                                                BoxShadow(
                                                                  color: AppColors
                                                                      .dangerBase
                                                                      .withValues(
                                                                        alpha:
                                                                            0.5,
                                                                      ),
                                                                  blurRadius:
                                                                      10,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        2,
                                                                      ),
                                                                ),
                                                              ]
                                                            : null,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppSpacing.sm),

                              // X-Axis Month Labels (Exact Column Alignment)
                              Row(
                                children: List.generate(_buckets.length, (
                                  index,
                                ) {
                                  final bucket = _buckets[index];
                                  final isHovered = _hoveredIndex == index;

                                  return Expanded(
                                    child: Text(
                                      bucket.shortLabel,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.tagline(
                                        color: isHovered
                                            ? AppColors.neutral0
                                            : AppColors.neutral6,
                                        fontWeight: isHovered
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Ultra-responsive Floating Popover Tooltip near Cursor
                    if (_hoveredIndex != null && _hoverPosition != null)
                      _buildMouseNearTooltip(
                        _buckets[_hoveredIndex!],
                        _hoverPosition!,
                        constraints.maxWidth,
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMouseNearTooltip(
    _FrequencyBucket bucket,
    Offset mousePos,
    double chartWidth,
  ) {
    final net = bucket.net;
    final netPrefix = net > 0 ? '+' : '';
    final netColor = net > 0
        ? AppColors.successBase
        : (net < 0 ? AppColors.dangerBase : AppColors.neutral6);

    return AppChartHoverTooltip(
      mousePosition: mousePos,
      chartWidth: chartWidth,
      title: bucket.fullLabel,
      titleIcon: AppSvgIcon.code,
      titleIconColor: AppColors.successBase,
      items: [
        ChartTooltipItem(
          label: 'Additions',
          value: '+${FormatUtils.formatNumber(bucket.additions)}',
          valueColor: AppColors.successBase,
        ),
        ChartTooltipItem(
          label: 'Deletions',
          value: '-${FormatUtils.formatNumber(bucket.deletions)}',
          valueColor: AppColors.dangerBase,
        ),
        ChartTooltipItem(
          label: 'Net Change',
          value: '$netPrefix${FormatUtils.formatNumber(net)}',
          valueColor: netColor,
        ),
        ChartTooltipItem(
          label: 'Commits',
          value: FormatUtils.formatNumber(bucket.commits),
          valueColor: AppColors.primaryBase,
        ),
      ],
    );
  }
}
