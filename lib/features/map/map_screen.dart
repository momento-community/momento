import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/models/momento.dart';
import '../../core/widgets/slide_up_route.dart';
import '../discover/discover_providers.dart';
import '../filter/filter_bottom_sheet.dart';
import '../momento_detail/momento_detail_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Momento? _selected;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(discoverFeedProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _MapBackground(),
          // Markers — fake positions for now (TODO Phase 4: real GeoPoints with
          // GoogleMap once the platform API keys land via --dart-define).
          ...feed.take(8).toList().asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            final dx = ((i * 0.17) - 0.4).clamp(-0.85, 0.85);
            final dy = (((i + 1) * 0.13) - 0.5).clamp(-0.7, 0.6);
            return Align(
              alignment: Alignment(dx, dy),
              child: _MapMarker(
                selected: _selected?.id == m.id,
                onTap: () => setState(() => _selected = m),
              ),
            );
          }),
          // Top chrome
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _SearchBar(),
                  const SizedBox(height: AppSpacing.md),
                  _ChromeRow(
                    onFilters: () => showFilterBottomSheet(context),
                    onToggleGrid: () => GoRouter.of(context).go('/discover'),
                  ),
                ],
              ),
            ),
          ),
          // Bottom compact card
          if (_selected != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: _CompactCard(
                    momento: _selected!,
                    onClose: () => setState(() => _selected = null),
                    onTap: () => Navigator.of(context).push(
                      slideUpRoute(MomentoDetailScreen(momento: _selected!)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapBackground extends StatelessWidget {
  const _MapBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              Colors.white,
              AppColors.surface.withValues(alpha: 0.6),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 28.0 : 22.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.background, width: 3),
          boxShadow: AppShadows.md,
        ),
        alignment: Alignment.center,
        child: Container(
          width: size * 0.28,
          height: size * 0.28,
          decoration: const BoxDecoration(
            color: AppColors.onPrimary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              color: AppColors.secondaryText, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Search location…',
              style: AppText.bodyMedium
                  .copyWith(color: AppColors.secondaryText),
            ),
          ),
          const Icon(Icons.mic_none_rounded,
              color: AppColors.secondaryText, size: 20),
        ],
      ),
    );
  }
}

class _ChromeRow extends StatelessWidget {
  const _ChromeRow({required this.onFilters, required this.onToggleGrid});

  final VoidCallback onFilters;
  final VoidCallback onToggleGrid;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Pill(
          icon: Icons.tune_rounded,
          label: 'Filters',
          onTap: onFilters,
        ),
        _MapGridToggle(onToggle: onToggleGrid),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.full),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primaryText),
              const SizedBox(width: 6),
              Text(label, style: AppText.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapGridToggle extends StatelessWidget {
  const _MapGridToggle({required this.onToggle});
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          _Segment(icon: Icons.map_rounded, label: 'Map', active: true),
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: const _Segment(
                icon: Icons.grid_view_rounded, label: 'Grid', active: false),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(
      {required this.icon, required this.label, required this.active});

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: active ? AppColors.onPrimary : AppColors.primaryText,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.labelMedium.copyWith(
              color: active ? AppColors.onPrimary : AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({
    required this.momento,
    required this.onClose,
    required this.onTap,
  });

  final Momento momento;
  final VoidCallback onClose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.lg,
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: CachedNetworkImage(
                  imageUrl: momento.heroImage,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: AppColors.surface),
                  errorWidget: (_, _, _) =>
                      Container(color: AppColors.surface),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text(
                        momento.category.badge,
                        style: AppText.labelSmall.copyWith(
                            color: AppColors.onSecondary, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(momento.title,
                        style: AppText.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEE · h:mm a')
                          .format(momento.startDateTime),
                      style: AppText.labelSmall
                          .copyWith(color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.secondaryText,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
