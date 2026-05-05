import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/env.dart';
import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import '../../core/repositories/organisor_requests_repository.dart';
import '../../core/seeds/demo_seed.dart';
import '../../core/widgets/follow_button.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/momento_card.dart';
import '../../core/widgets/momento_logo.dart';
import '../../core/widgets/responsive_content.dart';
import '../../core/widgets/section_tabs.dart';
import '../../core/widgets/slide_up_route.dart';
import '../discover/discover_providers.dart' show allMomentosProvider;
import '../momento_detail/momento_detail_screen.dart';
import '../my_moments/my_moments_providers.dart' show myOrganisedMomentosProvider, myLikedMomentosProvider;

/// Unified profile surface — both the bottom-nav "/profile" tab (self) and
/// the deep-link `/u/:id` route (any user) render the same widget.
///
/// `userId == null` means "current signed-in user". Pass an explicit id when
/// deep-linking. When the explicit id matches the signed-in uid we still
/// render in self mode so the inline-edit / freemium / logout chrome shows
/// up — convenient for sharing your own URL without losing affordances.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).value;
    final isSelf = widget.userId == null || widget.userId == user?.uid;
    if (!isSelf) {
      return _OtherProfileBody(userId: widget.userId!);
    }
    final userDocData =
        ref.watch(currentUserDocProvider).value?.data() ?? const {};
    final organised = ref.watch(myOrganisedMomentosProvider);
    final liked = ref.watch(myLikedMomentosProvider);
    final freemiumUsed = ref.watch(freemiumUsedProvider);
    // Real follower count (organisors get followed; for non-organisors this
    // is simply 0 — still cheap, one count() read).
    final followers = user == null
        ? 0
        : ref.watch(followerCountProvider(user.uid)).value ?? 0;
    final progress =
        (freemiumUsed / Env.freemiumLimit).clamp(0.0, 1.0).toDouble();

    final tabItems = _tab == 0 ? organised : liked;

    // Profile fields — Firestore is the source of truth. Auth fields are
    // a fallback for the brief window before `ensureUserDoc` lands the doc.
    final displayName = (userDocData['display_name'] as String?)?.trim();
    final bio = (userDocData['bio'] as String?)?.trim() ?? '';
    final city = (userDocData['location_city'] as String?)?.trim() ?? '';
    final avatarUrl = (userDocData['avatar_url'] as String?)?.trim();
    final effectiveName = (displayName?.isNotEmpty ?? false)
        ? displayName!
        : (user?.displayName ?? _emailToName(user?.email));
    final effectiveAvatar = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? avatarUrl
        : user?.photoURL;
    final canEdit = user != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ResponsiveContent(
          maxWidth: 720,
          padding: EdgeInsets.zero,
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
                    _AvatarRing(
                      url: effectiveAvatar,
                      canEdit: canEdit,
                      onTap: canEdit ? _pickAvatar : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _InlineEditableText(
                      text: effectiveName,
                      style: AppText.headlineSmall,
                      enabled: canEdit,
                      onTap: () => _editField(
                        title: 'Display name',
                        initial: effectiveName,
                        maxLength: 60,
                        onSave: (next) =>
                            _patchProfile({'display_name': next.trim()}),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _InlineEditableText(
                      text: city.isEmpty ? 'Add your city' : city,
                      style: AppText.bodySmall.copyWith(
                          color: city.isEmpty
                              ? AppColors.hint
                              : AppColors.secondaryText),
                      enabled: canEdit,
                      onTap: () => _editField(
                        title: 'City',
                        initial: city,
                        maxLength: 60,
                        hint: 'e.g. Berlin',
                        onSave: (next) =>
                            _patchProfile({'location_city': next.trim()}),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _InlineEditableText(
                      text: bio.isEmpty ? 'Add a short bio' : bio,
                      style: AppText.bodySmall.copyWith(
                          color: bio.isEmpty
                              ? AppColors.hint
                              : AppColors.secondaryText),
                      enabled: canEdit,
                      maxLines: 3,
                      onTap: () => _editField(
                        title: 'Bio',
                        initial: bio,
                        maxLength: 160,
                        maxLines: 4,
                        hint: 'Curator & coffee enthusiast',
                        onSave: (next) =>
                            _patchProfile({'bio': next.trim()}),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StatsRow(
                      momentos: organised.length,
                      liked: liked.length,
                      followers: followers,
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
                child: _RoleCard(),
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
                  // "Created Momentos" = Momentos this user is the organizer
                  // of. "Liked" = Momentos they tapped the heart on. Two
                  // disjoint sets — labels are explicit so the contrast is
                  // unmistakable.
                  labels: const ['Created Momentos', 'Liked'],
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

  // ──────────────────────────────────────────────────────────────────
  // Inline-edit + avatar helpers
  // ──────────────────────────────────────────────────────────────────

  Future<void> _editField({
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
    int maxLines = 1,
    int? maxLength,
    String? hint,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(title, style: AppText.titleMedium),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppText.labelLarge
                    .copyWith(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('Save',
                style: AppText.labelLarge
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    if (result == initial) return;
    await onSave(result);
  }

  Future<void> _patchProfile(Map<String, Object?> patch) async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(userRepositoryProvider).updateProfile(user.uid, patch);
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _pickAvatar() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;
    final picker = ImagePicker();
    final messenger = ScaffoldMessenger.of(context);
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref.read(storageRepositoryProvider).uploadAvatar(
            uid: user.uid,
            bytes: bytes,
            contentType: picked.mimeType ?? 'image/jpeg',
          );
      await ref
          .read(userRepositoryProvider)
          .updateProfile(user.uid, {'avatar_url': url});
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }
}

/// Tappable text-with-pencil affordance. Falls back to the plain text when
/// disabled (signed out) so layout stays identical.
class _InlineEditableText extends StatelessWidget {
  const _InlineEditableText({
    required this.text,
    required this.style,
    required this.enabled,
    required this.onTap,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle style;
  final bool enabled;
  final VoidCallback onTap;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final body = Text(
      text,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (!enabled) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: body),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined,
                size: 14, color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({this.url, this.canEdit = false, this.onTap});
  final String? url;
  final bool canEdit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Container(
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

    if (!canEdit) return ring;

    // Camera badge bottom-right marks the avatar as tappable.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          children: [
            Positioned.fill(child: ring),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 1),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 14,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
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
        _StatItem(value: '$momentos', label: 'Created'),
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
  int _done = 0;
  int _total = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final progress = _total == 0 ? 0.0 : _done / _total;
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            isAdmin
                ? 'Seeds organisor + plain-user docs and momentos with cover '
                    'photos in Firebase Storage. Admin only.'
                : 'Seeding requires the admin role.',
            style: AppText.labelSmall
                .copyWith(color: AppColors.secondaryText, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          MomentoButton(
            label: _busy
                ? 'Seeding $_done/$_total…'
                : 'Seed demo data',
            icon: Icons.data_array_rounded,
            size: MomentoButtonSize.small,
            onPressed: (_busy || !isAdmin) ? null : _seed,
          ),
          if (_busy && _total > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.full),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.divider,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _seed() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;
    setState(() {
      _busy = true;
      _done = 0;
      _total = 0;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final seed = DemoSeed(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );
      final result = await seed.run(
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Seeded $result')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Seed failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _done = 0;
          _total = 0;
        });
      }
    }
  }
}

class _RoleCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends ConsumerState<_RoleCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);

    if (role == 'admin') {
      return _RoleBanner(
        accent: AppColors.primary,
        icon: Icons.shield_outlined,
        title: 'Admin',
        subtitle: 'You have full read/write access. Be deliberate.',
        action: MomentoButton(
          label: 'Open admin panel',
          icon: Icons.dashboard_outlined,
          size: MomentoButtonSize.small,
          onPressed: () => GoRouter.of(context).go('/admin'),
        ),
      );
    }

    if (role == 'organisor') {
      return _RoleBanner(
        accent: AppColors.primary,
        icon: Icons.local_florist_outlined,
        title: "You're an organisor",
        subtitle: 'Create Momentos and see analytics on each one.',
        action: TextButton(
          onPressed: _busy ? null : _stopHosting,
          child: Text(
            'Stop hosting',
            style: AppText.labelSmall.copyWith(
              color: AppColors.secondaryText,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }

    // Default: role == 'user'. Three sub-states keyed off the user's
    // own `organisor_requests/{uid}` doc:
    //
    //   - none           → "Want to host? Request access" CTA
    //   - pending        → disabled "Application under review" banner
    //   - rejected       → "Not approved" + reason + "Try again" CTA
    final myReq = ref.watch(myOrganisorRequestProvider).value;
    if (myReq == null) {
      return _RoleBanner(
        accent: AppColors.primary,
        icon: Icons.add_rounded,
        title: 'Want to host?',
        subtitle:
            "Send an organisor request — admins review and approve.",
        action: MomentoButton(
          label: _busy ? 'Sending…' : 'Request to host',
          variant: MomentoButtonVariant.primary,
          size: MomentoButtonSize.small,
          onPressed: _busy ? null : _submitRequest,
        ),
      );
    }
    if (myReq.status == OrganisorRequestStatus.pending) {
      return _RoleBanner(
        accent: AppColors.primary,
        icon: Icons.hourglass_empty_rounded,
        title: 'Application under review',
        subtitle: "We'll let you know as soon as an admin decides.",
        action: const SizedBox.shrink(),
      );
    }
    if (myReq.status == OrganisorRequestStatus.rejected) {
      return _RoleBanner(
        accent: AppColors.error,
        icon: Icons.cancel_outlined,
        title: 'Application not approved',
        subtitle: (myReq.decidedReason?.trim().isNotEmpty ?? false)
            ? 'Reason: ${myReq.decidedReason}'
            : "Feel free to apply again when you're ready.",
        action: MomentoButton(
          label: _busy ? 'Sending…' : 'Try again',
          size: MomentoButtonSize.small,
          onPressed: _busy ? null : _submitRequest,
        ),
      );
    }
    // Approved status would normally have already flipped role to
    // organisor — but if there's a brief lag where the request says
    // approved before the user doc updates, fall through to the same
    // pending-style chrome (avoids flashing the request CTA back).
    return _RoleBanner(
      accent: AppColors.primary,
      icon: Icons.check_circle_outline_rounded,
      title: 'Approved',
      subtitle: 'Setting things up…',
      action: const SizedBox.shrink(),
    );
  }

  Future<void> _submitRequest() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;
    final userDocData =
        ref.read(currentUserDocProvider).value?.data() ?? const {};
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(organisorRequestsRepositoryProvider).submit(
            uid: user.uid,
            userEmail: user.email ?? '',
            userDisplayName:
                (userDocData['display_name'] as String?)?.trim().isNotEmpty ==
                        true
                    ? (userDocData['display_name'] as String).trim()
                    : (user.displayName ??
                        user.email?.split('@').first ??
                        'Member'),
            userAvatarUrl: (userDocData['avatar_url'] as String?) ??
                user.photoURL,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Request sent — an admin will review.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopHosting() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .updateProfile(user.uid, {'role': 'user'});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Demote failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RoleBanner extends StatelessWidget {
  const _RoleBanner({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.titleSmall
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppText.bodySmall
                        .copyWith(color: AppColors.secondaryText)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          action,
        ],
      ),
    );
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

/// Read-only "viewing someone else's profile" body. Reads the user's live
/// `users/{uid}` doc (so name/avatar are always fresh, never the stale
/// denormalised snapshot baked into individual Momentos). Renders a
/// compact header + Follow + Message and the user's active Momentos.
class _OtherProfileBody extends ConsumerWidget {
  const _OtherProfileBody({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use `.value` not `.when` — in mock-data builds the unauthenticated
    // Firestore read errors (rules require signed-in for user docs), and
    // in production a transient blip shouldn't blank the screen. Falling
    // back to the denormalised organizer fields baked into a hosted
    // Momento keeps the page useful in either case.
    final data = ref.watch(userDocByIdProvider(userId)).value?.data();
    final all = ref.watch(allMomentosProvider);
    final hosted =
        all.where((m) => m.organizerId == userId && m.isActive).toList();
    final followers = ref.watch(followerCountProvider(userId)).value ?? 0;

    final fallback = hosted.isNotEmpty ? hosted.first : null;
    final name = ((data?['display_name'] as String?)?.trim().isNotEmpty ?? false)
        ? (data!['display_name'] as String).trim()
        : (fallback?.organizerName ?? 'Profile');
    final avatar = ((data?['avatar_url'] as String?)?.trim().isNotEmpty ?? false)
        ? (data!['avatar_url'] as String).trim()
        : (fallback?.organizerAvatarUrl ?? '');
    final city = (data?['location_city'] as String?)?.trim() ?? '';
    final bio = (data?['bio'] as String?)?.trim() ?? '';

    return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: ResponsiveContent(
              maxWidth: 1080,
              padding: EdgeInsets.zero,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        0,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppColors.primaryText,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              shape: const CircleBorder(),
                            ),
                            onPressed: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.pop(context);
                              } else {
                                GoRouter.of(context).go('/discover');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        children: [
                          _AvatarRing(url: avatar.isEmpty ? null : avatar),
                          const SizedBox(height: AppSpacing.md),
                          Text(name, style: AppText.headlineSmall),
                          if (city.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              city,
                              style: AppText.bodySmall
                                  .copyWith(color: AppColors.secondaryText),
                            ),
                          ],
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              bio,
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodySmall
                                  .copyWith(color: AppColors.secondaryText),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${hosted.length} active Momento'
                            "${hosted.length == 1 ? '' : 's'} · "
                            '$followers follower'
                            "${followers == 1 ? '' : 's'}",
                            style: AppText.labelSmall
                                .copyWith(color: AppColors.secondaryText),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FollowButton(organizerId: userId),
                              const SizedBox(width: AppSpacing.sm),
                              MomentoButton(
                                label: 'Message',
                                size: MomentoButtonSize.small,
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: Divider(color: AppColors.divider, height: 1)),
                  if (hosted.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _OtherEmptyState(name: name),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childCount: hosted.length,
                        itemBuilder: (_, i) {
                          final m = hosted[i];
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
                ],
              ),
            ),
          ),
        );
  }
}

class _OtherEmptyState extends StatelessWidget {
  const _OtherEmptyState({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined,
                size: 56, color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.md),
            Text('$name has no active Momentos right now',
                textAlign: TextAlign.center, style: AppText.titleMedium),
          ],
        ),
      ),
    );
  }
}

