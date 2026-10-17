import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import '../../core/theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// NaadyantraNavBar
//
// Premium bottom navigation using SalomonBottomBar (Aurélien Salomon pattern).
// Themed to NAADYANTRA brand: animated pill indicator in Burnt Orange,
// warm ivory surface, JetBrains Mono labels.
//
// Replaces the generic Material 3 NavigationBar.
// Preserves exact same 5-tab layout and index semantics.
// ──────────────────────────────────────────────────────────────────────────────

class NaadyantraNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const NaadyantraNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final barBg = isDark ? const Color(0xF5181716) : AppColors.pureWhite;
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.warmStone;
    final selectedColor = isDark
        ? AppColors.burntOrange
        : AppColors.darkBurntOrange;
    final unselectedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.warmGraphite;

    return Container(
      decoration: BoxDecoration(
        color: barBg,
        border: Border(top: BorderSide(color: dividerColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SalomonBottomBar(
          currentIndex: selectedIndex,
          onTap: (i) {
            HapticFeedback.selectionClick();
            onDestinationSelected(i);
          },
          backgroundColor: barBg,
          selectedItemColor: selectedColor,
          unselectedItemColor: unselectedColor,
          selectedColorOpacity: 0.0, // we use itemShape for indicator
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          items: [
            SalomonBottomBarItem(
              icon: const Icon(Icons.dashboard_outlined, size: 22),
              activeIcon: const Icon(Icons.dashboard_rounded, size: 22),
              title: _NavLabel('Overview', selectedColor),
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
            ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.hub_outlined, size: 22),
              activeIcon: const Icon(Icons.hub_rounded, size: 22),
              title: _NavLabel('Devices', selectedColor),
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
            ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.sensors_outlined, size: 22),
              activeIcon: const Icon(Icons.sensors_rounded, size: 22),
              title: _NavLabel('Inspect', selectedColor),
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
            ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.history_outlined, size: 22),
              activeIcon: const Icon(Icons.history_rounded, size: 22),
              title: _NavLabel('Sessions', selectedColor),
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
            ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.tune_outlined, size: 22),
              activeIcon: const Icon(Icons.tune_rounded, size: 22),
              title: _NavLabel('Settings', selectedColor),
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _NavLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.3,
      ),
    );
  }
}
