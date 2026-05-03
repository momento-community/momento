import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/widgets/momento_logo.dart';

/// Bottom-nav scaffold shared by the 5 primary tabs.
/// Centre Ō badge denotes the My Moments tab (per design — frame5).
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: _BottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _icons = [
    (Icons.explore_outlined, Icons.explore_rounded),
    (Icons.map_outlined, Icons.map_rounded),
    (null, null), // centre Ō badge
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
