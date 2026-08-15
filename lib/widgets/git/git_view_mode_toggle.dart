import 'package:flutter/material.dart';
import '../common/app_icon.dart';
import '../common/app_segmented_control.dart';

Widget gitViewModeToggle({
  required bool isTableView,
  required ValueChanged<bool> onTableViewChanged,
}) {
  return AppSegmentedControl<bool>(
    selectedValue: isTableView,
    onValueChanged: onTableViewChanged,
    items: const [
      AppSegmentedItem<bool>(
        value: false,
        label: 'Cards',
        svgIcon: AppSvgIcon.menuBold,
        tooltip: 'Accordion Cards View',
      ),
      AppSegmentedItem<bool>(
        value: true,
        label: 'Table',
        svgIcon: AppSvgIcon.listNumbers,
        tooltip: 'Table View',
      ),
    ],
  );
}
