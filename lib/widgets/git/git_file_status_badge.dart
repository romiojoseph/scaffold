import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

Widget gitFileStatusBadge(String status) {
  final String label;
  final Color color;
  final String tooltip;

  switch (status.toUpperCase()) {
    case 'A':
      label = 'A';
      color = AppColors.successBase;
      tooltip = 'Added';
      break;
    case 'D':
      label = 'D';
      color = AppColors.dangerBase;
      tooltip = 'Deleted';
      break;
    case 'R':
      label = 'R';
      color = const Color(0xFFA855F7);
      tooltip = 'Renamed';
      break;
    case 'C':
      label = 'C';
      color = const Color(0xFF06B6D4);
      tooltip = 'Copied';
      break;
    case 'T':
      label = 'T';
      color = AppColors.neutral5;
      tooltip = 'Type Changed';
      break;
    case 'M':
    default:
      label = 'M';
      color = AppColors.warningBase;
      tooltip = 'Modified';
      break;
  }

  return Tooltip(
    message: tooltip,
    child: Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.tagline(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}