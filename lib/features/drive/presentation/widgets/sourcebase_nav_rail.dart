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
      minWidth: 78,
      minExtendedWidth: 188,
      useIndicator: true,
      groupAlignment: -0.82,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      backgroundColor: AppColors.page,
      indicatorColor: AppColors.selectedBlue,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.blue,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      selectedIconTheme: const IconThemeData(
        color: AppColors.blue,
        size: 26,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.muted,
        size: 25,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.psychology_outlined),
          selectedIcon: Icon(Icons.psychology),
          label: Text('Merkez'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: Text('Drive'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.compost_outlined),
          selectedIcon: Icon(Icons.compost),
          label: Text('BaseForce'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.science_outlined),
          selectedIcon: Icon(Icons.science),
          label: Text('SourceLab'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Profil'),
        ),
      ],
    );
  }
}
