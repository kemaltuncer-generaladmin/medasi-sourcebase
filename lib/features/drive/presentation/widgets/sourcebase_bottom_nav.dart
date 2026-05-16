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

  @override
  Widget build(BuildContext context) {
    const items = [
      _BottomItem(Icons.psychology_outlined, 'Merkezi AI'),
      _BottomItem(Icons.folder_rounded, 'Drive Ekranı'),
      _BottomItem(Icons.layers_rounded, 'BaseForce'),
      _BottomItem(Icons.science_outlined, 'SourceLab'),
      _BottomItem(Icons.manage_accounts_outlined, 'Profil ve Ayarlar'),
    ];

    return Positioned(
      left: 14,
      right: 14,
      bottom: 10,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF214379).withValues(alpha: .13),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
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
  const _BottomItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BottomItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 78,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.selectedBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: selected ? AppColors.blue : const Color(0xFF6C7892),
                  size: 30,
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? AppColors.blue
                          : const Color(0xFF56637E),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
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
