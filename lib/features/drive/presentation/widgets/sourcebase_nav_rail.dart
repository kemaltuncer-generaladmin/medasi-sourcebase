import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SourceBaseNavRail extends StatelessWidget {
  const SourceBaseNavRail({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.extended = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onChanged,
      extended: extended,
      minWidth: 70,
      minExtendedWidth: 168,
      useIndicator: true,
      groupAlignment: -0.82,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      backgroundColor: AppColors.clinicalSurface,
      indicatorColor: AppColors.clinicalActiveBg,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.clinicalActive,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      selectedIconTheme: const IconThemeData(
        color: AppColors.clinicalActive,
        size: 25,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.muted,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.muted,
        size: 24,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: Icon(Icons.chat_bubble_rounded),
          label: Text('Sohbet'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.folder_open_outlined),
          selectedIcon: Icon(Icons.folder_open),
          label: Text('Drive'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.layers_outlined),
          selectedIcon: Icon(Icons.layers_rounded),
          label: Text('BaseForce'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.science_outlined),
          selectedIcon: Icon(Icons.science_rounded),
          label: Text('SourceLab'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Profil'),
        ),
      ],
    );
  }
}
