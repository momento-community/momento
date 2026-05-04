import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/env.dart';
import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import '../../core/models/momento.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/momento_card.dart';
import '../../core/widgets/slide_up_route.dart';
import '../discover/discover_providers.dart';
import '../organizer/organizer_detail_screen.dart';

class MomentoDetailScreen extends ConsumerStatefulWidget {
  const MomentoDetailScreen({super.key, required this.momento});
  final Momento momento;

  @override
  ConsumerState<MomentoDetailScreen> createState() =>
      _MomentoDetailScreenState();
}

class _MomentoDetailScreenState extends ConsumerState<MomentoDetailScreen> {
  bool _expanded = false;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    // Bump view count on first open, but only when the viewer isn't the
    // organizer themselves — self-views shouldn't pad the analytics.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Env.useMockData) return;
      final uid = ref.read(authStateChangesProvider).value?.uid;
      if (uid != null && uid != widget.momento.organizerId) {
        ref
            .read(momentoRepositoryProvider)
            .incrementViewCount(widget.momento.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.momento;
    final all = ref.watch(allMomentosProvider);
    final related =
        all.where((x) => x.id != m.id && x.isActive).take(6).toList();
    final uid = ref.watch(authStateChangesProvider).value?.uid;
    final isAdmin = ref.watch(isAdminProvider);
    final showAnalytics = isAdmin || (uid != null && uid == m.organizerId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 700) Navigator.pop(context);
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: false,
                  expandedHeight: 380,
                  backgroundColor: AppColors.background,
                  surfaceTintColor: AppColors.background,
                  automaticallyImplyLeading: false,
                  leading: const SizedBox.shrink(),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _Hero(image: m.heroImage),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    transform: Matrix4.translationValues(0, -24, 0),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadii.lg)),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title, style: AppText.headlineMedium),
                        const SizedBox(height: AppSpacing.md),
                        _MetaRow(
                          icon: Icons.calendar_today_outlined,
                          text: _formatDateRange(m),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MetaRow(
                          icon: Icons.location_on_outlined,
                          text: m.locationAddress,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _OrganizerCard(momento: m),
                        const SizedBox(height: AppSpacing.lg),
                        _Description(
                          text: m.description,
                          expanded: _expanded,
                          onToggle: () =>
                              setState(() => _expanded = !_expanded),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(
                            color: AppColors.divider, height: 1),
                        const SizedBox(height: AppSpacing.md),
                        _ActionRow(
                          momento: m,
                          liked: _liked,
                          onLike: () => setState(() => _liked = !_liked),
                        ),
                        if (showAnalytics) ...[
                          const SizedBox(height: AppSpacing.md),
                          const Divider(
                              color: AppColors.divider, height: 1),
                          const SizedBox(height: AppSpacing.md),
                          _AnalyticsCard(momento: m, isAdminView: isAdmin),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        const Divider(
                            color: AppColors.divider, height: 1),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'More Momentos near you',
                          style: AppText.labelLarge
                              .copyWith(color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 220,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: related.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: AppSpacing.md),
                            itemBuilder: (_, i) => SizedBox(
                              width: 160,
                              child: MomentoCard(
                                momento: related[i],
                                imageHeight: 130,
                                onTap: () =>
                                    Navigator.of(context).pushReplacement(
                                  slideUpRoute(MomentoDetailScreen(
                                      momento: related[i])),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Floating back button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: AppSpacing.md,
              child: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            // Sticky bottom CTA
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyReserveBar(momento: m),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(Momento m) {
    final dateFmt = DateFormat('EEE, MMM d');
    final timeFmt = DateFormat('h:mm a');
    final sameDay = m.startDateTime.day == m.endDateTime.day &&
        m.startDateTime.month == m.endDateTime.month;
    if (sameDay) {
      return '${dateFmt.format(m.startDateTime)} • '
          '${timeFmt.format(m.startDateTime)} – '
          '${timeFmt.format(m.endDateTime)}';
    }
    return '${dateFmt.format(m.startDateTime)} – '
        '${dateFmt.format(m.endDateTime)}';
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.image});
  final String image;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: image,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: AppColors.surface),
          errorWidget: (_, _, _) => Container(color: AppColors.surface),
        ),
        // subtle bottom fade so the rounded card edge is visible
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 60,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.background.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.primaryText, size: 20),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryText),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(text, style: AppText.bodyMedium)),
      ],
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  const _OrganizerCard({required this.momento});
  final Momento momento;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => momento.pushOrganizerDetail(context),
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: momento.organizerAvatarUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.divider),
              errorWidget: (_, _, _) => Container(color: AppColors.divider),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  momento.organizerName,
                  style: AppText.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${momento.likeCount} likes',
                  style: AppText.labelSmall
                      .copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          MomentoButton(
            label: 'Follow',
            size: MomentoButtonSize.small,
            onPressed: () {},
          ),
        ],
      ),
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final showToggle = text.length > 140;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded ? null : 4,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppText.bodyMedium.copyWith(height: 1.6),
        ),
        if (showToggle) ...[
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              expanded ? 'Show less' : 'Read more',
              style: AppText.labelLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.momento,
    required this.liked,
    required this.onLike,
  });

  final Momento momento;
  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Action(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: 'Like',
          activeColor: liked ? AppColors.primary : null,
          onTap: onLike,
        ),
        _Action(
          icon: Icons.visibility_outlined,
          label: '${momento.viewCount}',
        ),
        if (momento.eventWebsiteUrl != null)
          _Action(
            icon: Icons.language_rounded,
            label: 'Web',
            onTap: () => _open(momento.eventWebsiteUrl!),
          ),
        if (momento.instagramPostUrl != null)
          _Action(
            icon: Icons.alternate_email_rounded,
            label: 'IG',
            onTap: () => _open(momento.instagramPostUrl!),
          ),
        if (momento.eventbriteUrl != null || momento.otherTicketUrl != null)
          _Action(
            icon: Icons.confirmation_number_outlined,
            label: 'Tickets',
            onTap: () => _open(
                momento.eventbriteUrl ?? momento.otherTicketUrl ?? ''),
          ),
        _Action(
          icon: Icons.share_outlined,
          label: 'Share',
        ),
      ],
    );
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    this.onTap,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primaryText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppText.labelSmall
                  .copyWith(color: AppColors.secondaryText, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Analytics card visible only to the organizer of this momento and to
/// admins. v1 surfaces existing counters; reservations + follower delta
/// arrive when paid Momentos and a richer follow-stream land.
class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.momento, required this.isAdminView});
  final Momento momento;
  final bool isAdminView;

  @override
  Widget build(BuildContext context) {
    final views = momento.viewCount;
    final likes = momento.likeCount;
    final likeRate = views == 0 ? null : likes / views;
    final timing = _timingLabel(momento);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
              Icon(
                isAdminView
                    ? Icons.shield_outlined
                    : Icons.bar_chart_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isAdminView ? 'ADMIN VIEW' : 'YOUR ANALYTICS',
                style: AppText.labelSmall.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Stat(label: 'Views', value: _compact(views)),
              _StatDivider(),
              _Stat(label: 'Likes', value: _compact(likes)),
              _StatDivider(),
              _Stat(
                label: 'Like rate',
                value: likeRate == null
                    ? '—'
                    : '${(likeRate * 100).toStringAsFixed(0)}%',
              ),
              _StatDivider(),
              _Stat(label: 'Timing', value: timing),
            ],
          ),
        ],
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  static String _timingLabel(Momento m) {
    final now = DateTime.now();
    if (now.isBefore(m.startDateTime)) {
      final delta = m.startDateTime.difference(now);
      if (delta.inDays >= 1) return 'in ${delta.inDays}d';
      if (delta.inHours >= 1) return 'in ${delta.inHours}h';
      return 'in ${delta.inMinutes}m';
    }
    if (now.isBefore(m.endDateTime)) return 'Live';
    final delta = now.difference(m.endDateTime);
    if (delta.inDays >= 1) return '${delta.inDays}d ago';
    if (delta.inHours >= 1) return '${delta.inHours}h ago';
    return 'just ended';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppText.titleMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: AppText.labelSmall
                  .copyWith(color: AppColors.secondaryText)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.divider);
}

class _StickyReserveBar extends StatelessWidget {
  const _StickyReserveBar({required this.momento});
  final Momento momento;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Free Entry',
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                'Registration required',
                style: AppText.labelSmall
                    .copyWith(color: AppColors.secondaryText, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: MomentoButton(
              label: 'Reserve Spot',
              variant: MomentoButtonVariant.primary,
              size: MomentoButtonSize.large,
              fullWidth: true,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}
