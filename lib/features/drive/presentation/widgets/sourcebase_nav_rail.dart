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
    return Container(
      color: AppColors.page,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(
            right: BorderSide(color: AppColors.line, width: 1),
          ),
        ),
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onChanged,
          labelType: extended
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.selectedBlue,
          selectedLabelTextStyle: const TextStyle(
            color: AppColors.blue,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelTextStyle: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          selectedIconTheme: const IconThemeData(
            color: AppColors.blue,
            size: 26,
          ),
          unselectedIconTheme: const IconThemeData(
            color: AppColors.muted,
            size: 24,
          ),
          minWidth: 72,
          minExtendedWidth: 200,
          groupAlignment: 0,
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
        ),
      ),
    );
  }
}
