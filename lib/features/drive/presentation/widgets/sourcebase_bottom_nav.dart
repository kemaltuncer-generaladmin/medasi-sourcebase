import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SourceBaseBottomNav extends StatelessWidget {
  const SourceBaseBottomNav({
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const double navHeight = 58;
  static const double navTopGap = 8;
  static const double contentBuffer = 18;
  static const double contentTailGuard = 12;
  static const double minBottomSafeArea = 10;

  static double safeAreaBottom(BuildContext context) {
    return math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      minBottomSafeArea,
    );
  }

  static double bottomOffset(BuildContext context) {
    return safeAreaBottom(context) + navTopGap;
  }

  static double contentBottomPadding(BuildContext context) {
    return bottomOffset(context) + navHeight + contentBuffer;
  }

  static double scrollEndPadding(BuildContext context) {
    return contentBottomPadding(context) + contentTailGuard;
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      _BottomItem(
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        'Sohbet',
      ),
      _BottomItem(Icons.folder_open_outlined, Icons.folder_open, 'Drive'),
      _BottomItem(Icons.layers_outlined, Icons.layers_rounded, 'BaseForce'),
      _BottomItem(Icons.science_outlined, Icons.science_rounded, 'SourceLab'),
      _BottomItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
    ];
    final width = MediaQuery.sizeOf(context).width;
    final showAllLabels = width >= 390;

    return Positioned(
      left: 10,
      right: 10,
      bottom: bottomOffset(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            height: navHeight,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.clinicalSurface.withValues(alpha: .98),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.clinicalBorder),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B1F33).withValues(alpha: .08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _BottomNavButton(
                      item: items[index],
                      selected: selectedIndex == index,
                      showLabel: showAllLabels || selectedIndex == index,
                      onTap: () => onChanged(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem {
  const _BottomItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final _BottomItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.clinicalActiveBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: selected
                  ? Border.all(
                      color: AppColors.clinicalActive.withValues(alpha: .12),
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? AppColors.clinicalActive : AppColors.muted,
                  size: selected ? 20 : 19,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: showLabel
                      ? Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? AppColors.clinicalActive
                                    : AppColors.muted,
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                height: 1,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
