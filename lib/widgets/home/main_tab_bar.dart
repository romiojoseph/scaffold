import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../common/app_icon.dart';

Widget appMainTabBar(TabController tabController) {
  return AnimatedBuilder(
    animation: tabController,
    builder: (context, _) {
      return TabBar(
        controller: tabController,
        indicatorColor: AppColors.primaryBase,
        labelColor: AppColors.primaryBase,
        unselectedLabelColor: AppColors.neutral6,
        dividerColor: AppColors.neutral11,
        // Add these two properties
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        tabs: [
          Tab(
            icon: AppIcon(
              AppSvgIcon.treeStructure,
              size: 18,
              color: tabController.index == 0
                  ? AppColors.primaryBase
                  : AppColors.neutral6,
            ),
            text: 'Tree View',
          ),
          Tab(
            icon: AppIcon(
              AppSvgIcon.code,
              size: 18,
              color: tabController.index == 1
                  ? AppColors.primaryBase
                  : AppColors.neutral6,
            ),
            text: 'ASCII Output',
          ),
          Tab(
            icon: AppIcon(
              AppSvgIcon.presentationChart,
              size: 18,
              color: tabController.index == 2
                  ? AppColors.primaryBase
                  : AppColors.neutral6,
            ),
            text: 'Statistics',
          ),
          Tab(
            icon: AppIcon(
              AppSvgIcon.gitCommitDuotone,
              size: 18,
              color: tabController.index == 3
                  ? AppColors.primaryBase
                  : AppColors.neutral6,
            ),
            text: 'Git History',
          ),
          Tab(
            icon: AppIcon(
              AppSvgIcon.packageDuotone,
              size: 18,
              color: tabController.index == 4
                  ? AppColors.primaryBase
                  : AppColors.neutral6,
            ),
            text: 'Dependencies',
          ),
        ],
      );
    },
  );
}
