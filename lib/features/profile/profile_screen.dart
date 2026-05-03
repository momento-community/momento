import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../config/env.dart';
import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import '../../core/mock/mock_momentos.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/momento_card.dart';
import '../../core/widgets/momento_logo.dart';
import '../../core/widgets/section_tabs.dart';
import '../../core/widgets/slide_up_route.dart';
import '../momento_detail/momento_detail_screen.dart';
import '../my_moments/my_moments_providers.dart' show myOrganisedMomentosProvider, myLikedMomentosProvider;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).value;
    final organised = ref.watch(myOrganisedMomentosProvider);
    final liked = ref.watch(myLikedMomentosProvider);
    final freemiumUsed = ref.watch(freemiumUsedProvider);
    final progress =
        (freemiumUsed / Env.freemiumLimit).clamp(0.0, 1.0).toDouble();

    final tabItems = _tab == 0 ? organised : liked;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  children: [
                    const MomentoLogo(),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined,
                          size: 22),
                      color: AppColors.primaryText,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: Divider(color: AppColors.divider, height: 1)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    _AvatarRing(url: user?.photoURL),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      user?.displayName ?? _emailToName(user?.email),
                      style: AppText.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Berlin · Curator & Coffee Enthusiast',
                      style: AppText.bodySmall
                          .copyWith(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StatsRow(
                      momentos: organised.length,
                      liked: liked.length,
                      followers: 1244,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MomentoButton(
                      label: 'Edit Profile',
                      size: MomentoButtonSize.small,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: _FreemiumCard(used: freemiumUsed, progress: progress),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg),
                child: SectionTabs(
                  labels: const ['My Momentos', 'Liked'],
                  activeIndex: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Divider(color: AppColors.divider, height: 1))),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childCount: tabItems.length,
                itemBuilder: (_, i) {
                  final m = tabItems[i];
                  final h = 130.0 + ((m.id.hashCode % 5) * 22);
                  return MomentoCard(
                    momento: m,
                    imageHeight: h,
                    onTap: () => Navigator.of(context).push(
                      slideUpRoute(MomentoDetailScreen(momento: m)),
                    ),
                  );
                },
              ),
            ),
            if (kDebugMode)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  child: _DevSeedButton(),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      await ref
                          .read(authRepositoryProvider)
                          .signOut();
                      if (context.mounted) {
                        GoRouter.of(context).go('/auth');
                      }
                    },
                    child: Text(
                      'Logout',
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.error,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emailToName(String? email) {
    if (email == null) return 'Momento member';
    final local = email.split('@').first;
    if (local.isEmpty) return 'Momento member';
    return local
        .split(RegExp(r'[._-]'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider, width: 2),
      ),
      child: ClipOval(
        child: url == null
            ? Container(
                color: AppColors.surface,
                alignment: Alignment.center,
                child: Icon(Icons.person_outline_rounded,
                    color: AppColors.primary, size: 36),
              )
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppColors.surface),
                errorWidget: (_, _, _) =>
                    Container(color: AppColors.surface),
              ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.momentos,
    required this.liked,
    required this.followers,
  });

  final int momentos;
  final int liked;
  final int followers;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(value: '$momentos', label: 'Momentos'),
        const _VDivider(),
        _StatItem(value: '$liked', label: 'Liked'),
        const _VDivider(),
        _StatItem(
          value: followers >= 1000
              ? '${(followers / 1000).toStringAsFixed(1)}k'
              : '$followers',
          label: 'Followers',
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppText.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: AppText.labelSmall
                .copyWith(color: AppColors.secondaryText)),
      ],
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 24, color: AppColors.divider);
}

class _DevSeedButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DevSeedButton> createState() => _DevSeedButtonState();
}

class _DevSeedButtonState extends ConsumerState<_DevSeedButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEV TOOLS',
              style: AppText.labelSmall
                  .copyWith(color: AppColors.secondaryText)),
          const SizedBox(height: AppSpacing.sm),
          MomentoButton(
            label: _busy ? 'Seeding…' : 'Seed dev Momentos',
            icon: Icons.data_array_rounded,
            size: MomentoButtonSize.small,
            onPressed: _busy ? null : _seed,
          ),
        ],
      ),
    );
  }

  Future<void> _seed() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(momentoRepositoryProvider);
      final userDoc = ref.read(currentUserDocProvider).value?.data();
      final n = await repo.seedDevMomentos(
        mocks: mockMomentos,
        organizerUid: user.uid,
        organizerName: (userDoc?['display_name'] as String?) ??
            user.displayName ??
            user.email ??
            'Organizer',
        organizerAvatarUrl:
            (userDoc?['avatar_url'] as String?) ?? user.photoURL ?? '',
      );
      messenger.showSnackBar(SnackBar(content: Text('Seeded $n Momentos')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Seed failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _FreemiumCard extends StatelessWidget {
  const _FreemiumCard({required this.used, required this.progress});
  final int used;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Free Momentos',
                  style: AppText.labelMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$used of ${Env.freemiumLimit} used',
                  style: AppText.labelSmall
                      .copyWith(color: AppColors.secondaryText)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'After ${Env.freemiumLimit}, each Momento costs '
            '€${Env.pricePerDayEur.toStringAsFixed(0)}/day to promote.',
            style: AppText.labelSmall
                .copyWith(color: AppColors.secondaryText, height: 1.4),
          ),
        ],
      ),
    );
  }
}
