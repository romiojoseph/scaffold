import 'package:flutter/material.dart';
import '../../models/dependency_info.dart';
import '../../services/global_dependency_service.dart';
import '../common/app_segmented_control.dart';

Widget globalDepsEcosystemChips({
  required List<GlobalPackageGroup> packages,
  required Ecosystem? selectedEcosystem,
  required ValueChanged<Ecosystem?> onEcosystemSelected,
}) {
  final activeEcosystems = Ecosystem.values
      .where((eco) => packages.any((p) => p.ecosystem == eco))
      .toList();

  final items = <AppSegmentedItem<Ecosystem?>>[
    AppSegmentedItem<Ecosystem?>(
      value: null,
      label: 'All Ecosystems (${packages.length})',
    ),
    ...activeEcosystems.map((eco) {
      final count = packages.where((p) => p.ecosystem == eco).length;
      return AppSegmentedItem<Ecosystem?>(
        value: eco,
        label: '${eco.label} ($count)',
      );
    }),
  ];

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: AppSegmentedControl<Ecosystem?>(
      selectedValue: selectedEcosystem,
      items: items,
      onValueChanged: onEcosystemSelected,
    ),
  );
}