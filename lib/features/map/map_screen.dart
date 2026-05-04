import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/models/momento.dart';
import '../../core/widgets/responsive_content.dart';
import '../../core/widgets/slide_up_route.dart';
import '../discover/discover_providers.dart';
import '../filter/filter_bottom_sheet.dart';
import '../momento_detail/momento_detail_screen.dart';

/// Default camera target — central Brussels. Used when the feed is empty so
/// the map still renders at a sensible zoom instead of (0, 0).
const _kBrusselsCenter = LatLng(50.8503, 4.3517);
const double _kInitialZoom = 12;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Momento? _selected;
  GoogleMapController? _controller;

  /// Build a marker per Momento. Tapping a marker selects it and animates the
  /// camera to its location. We keyframe `MarkerId(momento.id)` so widget
  /// rebuilds reuse the same marker instance.
  Set<Marker> _markersFor(List<Momento> feed) {
    return feed
        .where((m) => m.locationLat != 0 || m.locationLng != 0)
        .map(
          (m) => Marker(
            markerId: MarkerId(m.id),
            position: LatLng(m.locationLat, m.locationLng),
            onTap: () {
              setState(() => _selected = m);
              _controller?.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(m.locationLat, m.locationLng),
                ),
              );
            },
          ),
        )
        .toSet();
  }

  CameraPosition _initialCameraFor(List<Momento> feed) {
    if (feed.isEmpty) {
      return const CameraPosition(target: _kBrusselsCenter, zoom: _kInitialZoom);
    }
    final first = feed.first;
    return CameraPosition(
      target: LatLng(first.locationLat, first.locationLng),
      zoom: _kInitialZoom,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(discoverFeedProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraFor(feed),
            markers: _markersFor(feed),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onMapCreated: (c) => _controller = c,
            onTap: (_) => setState(() => _selected = null),
          ),
          // Top chrome — map fills the viewport (intentional), but the
          // search + filter chrome sits inside a 720 column so on desktop
          // it's centered, not stretched edge to edge.
          SafeArea(
            bottom: false,
            child: ResponsiveContent(
              maxWidth: 720,
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
                child: ResponsiveContent(
                  maxWidth: 560,
                  padding: const EdgeInsets.all(AppSpacing.md),
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
