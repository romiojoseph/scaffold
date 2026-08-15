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

enum CommitActivityMode {
  monthly('Months'),
  hourly('Time of Day');

  final String label;
  const CommitActivityMode(this.label);
}

class _ActivityBucket {
  final String shortLabel;
  final String fullLabel;
  int commitCount = 0;
  int additions = 0;
  int deletions = 0;
  final Set<String> authors = {};

  _ActivityBucket({required this.shortLabel, required this.fullLabel});
}

class CommitActivityChart extends StatefulWidget {
  final List<GitCommit> commits;

  const CommitActivityChart({super.key, required this.commits});

  @override
  State<CommitActivityChart> createState() => _CommitActivityChartState();
}

class _CommitActivityChartState extends State<CommitActivityChart> {
  late int _selectedYear;
  CommitActivityMode _mode = CommitActivityMode.monthly;
  int? _hoveredIndex;
  Offset? _hoverPosition;

  List<_ActivityBucket> _buckets = [];
  int _chartMax = 1;
  int _totalYearCommits = 0;
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
  void didUpdateWidget(covariant CommitActivityChart oldWidget) {
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
    if (_mode == CommitActivityMode.monthly) {
      final buckets = List.generate(
        12,
        (i) => _ActivityBucket(
          shortLabel: _monthShortNames[i],
          fullLabel: '${_fullMonthNames[i]} $_selectedYear',
        ),
      );

      for (final commit in widget.commits) {
        final localDate = commit.date.toLocal();
        if (localDate.year == _selectedYear) {
          final monthIndex = localDate.month - 1;
          if (monthIndex >= 0 && monthIndex < 12) {
            buckets[monthIndex].commitCount++;
            buckets[monthIndex].additions += commit.totalAdditions;
            buckets[monthIndex].deletions += commit.totalDeletions;
            buckets[monthIndex].authors.add(commit.author);
          }
        }
      }
      _buckets = buckets;
    } else {
      // 24-hour time of day
      final buckets = List.generate(24, (i) {
        final hour12 = i == 0 ? 12 : (i > 12 ? i - 12 : i);
        final ampm = i < 12 ? 'a' : 'p';
        final endHour = (i + 1) % 24;
        final endHour12 = endHour == 0
            ? 12
            : (endHour > 12 ? endHour - 12 : endHour);
        final endAmpm = endHour < 12 ? 'AM' : 'PM';
        final startAmpm = i < 12 ? 'AM' : 'PM';

        return _ActivityBucket(
          shortLabel: '$hour12$ampm',
          fullLabel: '$hour12:00 $startAmpm - $endHour12:00 $endAmpm',
        );
      });

      for (final commit in widget.commits) {
        final localDate = commit.date.toLocal();
        if (localDate.year == _selectedYear) {
          final hour = localDate.hour;
          if (hour >= 0 && hour < 24) {
            buckets[hour].commitCount++;
            buckets[hour].additions += commit.totalAdditions;
            buckets[hour].deletions += commit.totalDeletions;
            buckets[hour].authors.add(commit.author);
          }
        }
      }
      _buckets = buckets;
    }

    int maxCount = 0;
    int totalCommits = 0;
    for (final b in _buckets) {
      maxCount = math.max(maxCount, b.commitCount);
      totalCommits += b.commitCount;
    }
    _chartMax = maxCount == 0 ? 1 : maxCount;
    _totalYearCommits = totalCommits;
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
          // Header with Title, Year Tabs, and View Toggle
          Row(
            children: [
              Text(
                'Commit Activity',
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
                  color: AppColors.primaryBase.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${FormatUtils.formatNumber(_totalYearCommits)} commits in $_selectedYear',
                  style: AppTypography.body(
                    color: AppColors.primaryBase,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),

              // Mode Toggle (Monthly / Hourly)
              AppSegmentedControl<CommitActivityMode>(
                selectedValue: _mode,
                onValueChanged: (mode) => setState(() {
                  _mode = mode;
                  _hoveredIndex = null;
                  _hoverPosition = null;
                  _recalculateBuckets();
                }),
                items: CommitActivityMode.values.map((mode) {
                  return AppSegmentedItem<CommitActivityMode>(
                    value: mode,
                    label: mode.label,
                  );
                }).toList(),
              ),
              const SizedBox(width: AppSpacing.md),

              // Year Tabs
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

          // Main Chart Plot Area
          LayoutBuilder(
            builder: (context, constraints) {
              const yAxisWidth = 44.0;
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
                        // Fixed Y-Axis Labels
                        SizedBox(
                          width: yAxisWidth,
                          height: 256,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                FormatUtils.formatCompactNumber(_chartMax),
                                style: AppTypography.tagline(
                                  color: AppColors.neutral6,
                                ),
                              ),
                              Text(
                                FormatUtils.formatCompactNumber(
                                  (_chartMax * 0.66).round(),
                                ),
                                style: AppTypography.tagline(
                                  color: AppColors.neutral7,
                                ),
                              ),
                              Text(
                                FormatUtils.formatCompactNumber(
                                  (_chartMax * 0.33).round(),
                                ),
                                style: AppTypography.tagline(
                                  color: AppColors.neutral7,
                                ),
                              ),
                              Text(
                                '0',
                                style: AppTypography.tagline(
                                  color: AppColors.neutral7,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Plot Area (Bars + X Labels strictly grouped in each column)
                        Expanded(
                          child: Column(
                            children: [
                              // Bars + Grid Area
                              SizedBox(
                                height: 256,
                                child: Stack(
                                  children: [
                                    // Background Grid Lines
                                    Positioned.fill(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: List.generate(4, (i) {
                                          return Container(
                                            height: 1,
                                            color: i == 3
                                                ? AppColors.neutral8
                                                : AppColors.neutral11
                                                      .withValues(alpha: 0.6),
                                          );
                                        }),
                                      ),
                                    ),

                                    // Aligned Bars Row
                                    Positioned.fill(
                                      child: Row(
                                        children: List.generate(_buckets.length, (
                                          index,
                                        ) {
                                          final bucket = _buckets[index];
                                          final isHovered =
                                              _hoveredIndex == index;
                                          final fraction =
                                              bucket.commitCount / _chartMax;
                                          final barHeight = (fraction * 174)
                                              .clamp(
                                                bucket.commitCount > 0
                                                    ? 4.0
                                                    : 0.0,
                                                174.0,
                                              );

                                          return Expanded(
                                            child: Align(
                                              alignment: Alignment.bottomCenter,
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 2,
                                                    ),
                                                width:
                                                    _mode ==
                                                        CommitActivityMode
                                                            .monthly
                                                    ? 32
                                                    : 14,
                                                height: barHeight,
                                                decoration: BoxDecoration(
                                                  color: isHovered
                                                      ? AppColors.primaryHover
                                                      : (bucket.commitCount > 0
                                                            ? AppColors
                                                                  .primaryBase
                                                            : AppColors
                                                                  .neutral11),
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(4),
                                                      ),
                                                  boxShadow: isHovered
                                                      ? [
                                                          BoxShadow(
                                                            color: AppColors
                                                                .primaryBase
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                            blurRadius: 10,
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
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppSpacing.sm),

                              // X-Axis Labels (Exact Column Alignment)
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
                                            ? AppColors.primaryBase
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

                    // Ultra-responsive Floating Popover Tooltip strictly near mouse
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
    _ActivityBucket bucket,
    Offset mousePos,
    double chartWidth,
  ) {
    return AppChartHoverTooltip(
      mousePosition: mousePos,
      chartWidth: chartWidth,
      title: bucket.fullLabel,
      titleIcon: AppSvgIcon.arrowCounterClockwise,
      titleIconColor: AppColors.primaryBase,
      items: [
        ChartTooltipItem(
          label: 'Commits',
          value: FormatUtils.formatNumber(bucket.commitCount),
          valueColor: AppColors.primaryBase,
        ),
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
      ],
    );
  }
}
