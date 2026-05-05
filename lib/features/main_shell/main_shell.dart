import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/breakpoints.dart';
import '../../config/theme.dart';
import '../../core/widgets/momento_logo.dart';

/// Adaptive nav scaffold for the 5 primary tabs.
///
///   * `< Breakpoints.tablet` (mobile)  → bottom navigation with the
///     centre Ō badge denoting My Moments (matches the original design
///     export, frame5).
///   * `≥ Breakpoints.tablet` (tablet+)  → vertical `NavigationRail` on
///     the left. Collapsed (icon-only) at 720–1080, **extended** (icon +
///     label) at ≥1080. The Ō badge moves to the rail's `leading` slot
///     as pure branding; My Moments gets a regular icon there so the
///     rail visually balances.
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _Destination('Discover', Icons.explore_outlined, Icons.explore_rounded),
    _Destination('Map', Icons.map_outlined, Icons.map_rounded),
    // My Moments — gets a stroke / filled bookmark in the rail; the
    // centre-Ō treatment lives only in the bottom nav where the badge
    // doubles as branding.
    _Destination(
      'My Moments',
      Icons.bookmark_outline_rounded,
      Icons.bookmark_rounded,
    ),
    _Destination('Create', Icons.add_circle_outline_rounded,
        Icons.add_circle_rounded),
    _Destination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _onTap(int i) =>
      navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: navigationShell,
        bottomNavigationBar: _BottomNav(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTap,
        ),
      );
    }

    // Tablet + desktop — side rail.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _SideRail(
            currentIndex: navigationShell.currentIndex,
            onTap: _onTap,
            extended: context.isDesktop,
            destinations: _destinations,
          ),
          const VerticalDivider(width: 1, color: AppColors.divider),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.currentIndex,
    required this.onTap,
    required this.extended,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool extended;
  final List<_Destination> destinations;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: NavigationRail(
        backgroundColor: AppColors.background,
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        extended: extended,
        labelType: extended ? null : NavigationRailLabelType.none,
        minWidth: 80,
        minExtendedWidth: 220,
        leading: Padding(
          padding: EdgeInsets.fromLTRB(
            extended ? 16 : 0,
            AppSpacing.md,
            extended ? 16 : 0,
            AppSpacing.lg,
          ),
          child: extended
              ? const MomentoLogo()
              : const OBadge(size: 36, filled: false),
        ),
        selectedIconTheme:
            const IconThemeData(color: AppColors.primary, size: 24),
        unselectedIconTheme:
            const IconThemeData(color: AppColors.secondaryText, size: 24),
        selectedLabelTextStyle: AppText.labelMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle:
            AppText.labelMedium.copyWith(color: AppColors.secondaryText),
        useIndicator: true,
        indicatorColor: AppColors.primary.withValues(alpha: 0.10),
        destinations: [
          for (final d in destinations)
            NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: Text(d.label),
            ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  // Bottom nav keeps the original frame5 design — Ō badge in the centre,
  // four flanking icon-buttons. We don't reuse `MainShell._destinations`
  // because that list uses a regular icon for My Moments to suit the
  // vertical rail; the bottom-nav variant uses the badge instead.
  static const _icons = [
    (Icons.explore_outlined, Icons.explore_rounded),
    (Icons.map_outlined, Icons.map_rounded),
    (null, null), // centre Ō badge — handled by _CentreBadge
    (Icons.add_circle_outline_rounded, Icons.add_circle_rounded),
    (Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_icons.length, (i) {
          if (i == 2) {
            return _CentreBadge(
              active: currentIndex == 2,
              onTap: () => onTap(2),
            );
          }
          final active = currentIndex == i;
          final icon = active ? _icons[i].$2! : _icons[i].$1!;
          return IconButton(
            icon: Icon(icon, size: 26),
            color: active ? AppColors.primary : AppColors.secondaryText,
            onPressed: () => onTap(i),
          );
        }),
      ),
    );
  }
}

class _CentreBadge extends StatelessWidget {
  const _CentreBadge({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: OBadge(size: 48, filled: active),
    );
  }
}

/// Generic placeholder for screens that will be implemented in later phases.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MomentoLogo(),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: AppText.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: AppText.bodyMedium
                    .copyWith(color: AppColors.secondaryText),
              ),
              const Spacer(),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.construction_outlined,
                          size: 48,
                          color:
                              AppColors.primary.withValues(alpha: 0.7)),
                      const SizedBox(height: AppSpacing.md),
                      Text('Coming in a later phase',
                          style: AppText.titleMedium),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
