import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import '../../core/models/momento.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/responsive_content.dart';
import '../../core/widgets/momento_logo.dart';
import '../../core/widgets/section_tabs.dart';
import '../../core/widgets/slide_up_route.dart';
import '../momento_detail/momento_detail_screen.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveContent(
          maxWidth: 1080,
          padding: EdgeInsets.zero,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onClose: () => context.go('/profile')),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg),
                children: [
                  SectionTabs(
                    labels: const [
                      'Momentos',
                      'Users',
                      'Audit log',
                      'Stats',
                    ],
                    activeIndex: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            Expanded(
              child: switch (_tab) {
                0 => const _AllMomentosTab(),
                1 => const _AllUsersTab(),
                2 => const _AuditLogTab(),
                _ => const _StatsTab(),
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MomentoLogo(),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: AppColors.primaryText,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: AppColors.primary, size: 26),
              const SizedBox(width: AppSpacing.sm),
              Text('Admin panel', style: AppText.headlineMedium),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tab 1: All Momentos
// ─────────────────────────────────────────────────────────────────────────
class _AllMomentosTab extends ConsumerWidget {
  const _AllMomentosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMomentos = ref.watch(adminAllMomentosProvider);
    return asyncMomentos.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Could not load momentos.\n$e',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: AppColors.error)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_outlined,
            text: 'No momentos in the project yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _AdminMomentoRow(momento: items[i]),
        );
      },
    );
  }
}

class _AdminMomentoRow extends ConsumerWidget {
  const _AdminMomentoRow({required this.momento});
  final Momento momento;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('MMM d, y · h:mm a');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: CachedNetworkImage(
              imageUrl: momento.heroImage,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.surface),
              errorWidget: (_, _, _) => Container(color: AppColors.surface),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(momento.title,
                    style: AppText.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${momento.organizerName} · ${dateFmt.format(momento.startDateTime)}',
                  style: AppText.labelSmall
                      .copyWith(color: AppColors.secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _StatusPill(active: !momento.isExpired),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.secondaryText,
            onPressed: () => Navigator.of(context).push(
              slideUpRoute(MomentoDetailScreen(momento: momento)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.error,
            onPressed: () => _confirmDelete(context, ref, momento),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Momento m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Delete this momento?', style: AppText.titleMedium),
        content: Text(
          '"${m.title}" will be permanently removed. This cannot be undone.',
          style: AppText.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: AppText.labelLarge
                    .copyWith(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: AppText.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    final actor = ref.read(authStateChangesProvider).value;
    try {
      // Log first so a failed delete still leaves an attempt trail. The
      // log entry is small and the rule rejects it cheaply if the caller
      // turns out not to be an admin.
      if (actor != null) {
        await ref.read(auditLogRepositoryProvider).log(
              actor: actor,
              action: 'momento.delete',
              targetType: 'momento',
              targetId: m.id,
              before: {
                'title': m.title,
                'organizer_id': m.organizerId,
              },
            );
      }
      await ref.read(momentoRepositoryProvider).deleteMomento(m.id);
      messenger.showSnackBar(SnackBar(content: Text('Deleted "${m.title}"')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.hint,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        active ? 'Active' : 'Expired',
        style: AppText.labelSmall.copyWith(
          color: active ? AppColors.onPrimary : AppColors.secondaryText,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tab 2: All Users
// ─────────────────────────────────────────────────────────────────────────
class _AllUsersTab extends ConsumerWidget {
  const _AllUsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUsers = ref.watch(adminAllUsersProvider);
    return asyncUsers.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Could not load users.\n$e',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: AppColors.error)),
        ),
      ),
      data: (docs) {
        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.person_outline_rounded,
            text: 'No users have signed up yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _AdminUserRow(doc: docs[i]),
        );
      },
    );
  }
}

class _AdminUserRow extends ConsumerWidget {
  const _AdminUserRow({required this.doc});
  final DocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = (data['display_name'] as String?) ?? doc.id;
    final email = (data['email'] as String?) ?? '';
    final avatar = (data['avatar_url'] as String?) ?? '';
    final role = (data['role'] as String?) ?? 'user';
    final banned = (data['is_banned'] as bool?) ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: banned ? AppColors.error : AppColors.divider,
          width: banned ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipOval(
            child: avatar.isEmpty
                ? Container(
                    width: 40,
                    height: 40,
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: Icon(Icons.person_outline_rounded,
                        color: AppColors.secondaryText),
                  )
                : CachedNetworkImage(
                    imageUrl: avatar,
                    width: 40,
                    height: 40,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          style: AppText.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (banned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius:
                              BorderRadius.circular(AppRadii.full),
                        ),
                        child: Text('BANNED',
                            style: AppText.labelSmall.copyWith(
                              color: AppColors.onError,
                              fontSize: 9,
                              letterSpacing: 0.6,
                            )),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(email,
                    style: AppText.labelSmall
                        .copyWith(color: AppColors.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _RoleDropdown(uid: doc.id, current: role, displayName: name),
          IconButton(
            tooltip: banned ? 'Unban' : 'Ban',
            icon: Icon(
              banned
                  ? Icons.lock_open_rounded
                  : Icons.block_rounded,
              color: banned ? AppColors.primary : AppColors.error,
              size: 20,
            ),
            onPressed: () =>
                _confirmBan(context, ref, doc.id, name, currentlyBanned: banned),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBan(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String displayName, {
    required bool currentlyBanned,
  }) async {
    final next = !currentlyBanned;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(next ? 'Ban this user?' : 'Unban this user?'),
        content: Text(
          next
              ? '$displayName will lose every write — they can\'t create or edit '
                  'momentos, follow, or update their profile. They keep read access.'
              : '$displayName will get write access back.',
          style: AppText.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: AppText.labelLarge
                    .copyWith(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(next ? 'Ban' : 'Unban',
                style: AppText.labelLarge.copyWith(
                  color: next ? AppColors.error : AppColors.primary,
                )),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    final actor = ref.read(authStateChangesProvider).value;
    try {
      if (actor != null) {
        await ref.read(auditLogRepositoryProvider).log(
              actor: actor,
              action: next ? 'user.ban' : 'user.unban',
              targetType: 'user',
              targetId: uid,
              before: {'is_banned': currentlyBanned},
              after: {'is_banned': next},
            );
      }
      await ref.read(userRepositoryProvider).setBanned(uid, next);
      messenger.showSnackBar(SnackBar(
          content: Text(
              next ? 'Banned $displayName' : 'Unbanned $displayName')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }
}

class _RoleDropdown extends ConsumerWidget {
  const _RoleDropdown({
    required this.uid,
    required this.current,
    required this.displayName,
  });

  final String uid;
  final String current;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: AppColors.primaryText),
          style: AppText.labelMedium,
          dropdownColor: AppColors.background,
          items: const [
            DropdownMenuItem(value: 'user', child: Text('user')),
            DropdownMenuItem(value: 'organisor', child: Text('organisor')),
            DropdownMenuItem(value: 'admin', child: Text('admin')),
          ],
          onChanged: (v) => v == null || v == current
              ? null
              : _confirmChange(context, ref, v),
        ),
      ),
    );
  }

  Future<void> _confirmChange(
      BuildContext context, WidgetRef ref, String next) async {
    final isHighStakes = next == 'admin' || current == 'admin';
    if (isHighStakes) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(next == 'admin'
              ? 'Promote to admin?'
              : 'Remove admin privileges?'),
          content: Text(
            next == 'admin'
                ? '$displayName will gain full read/write access to every '
                    'momento and user. Only do this for trusted operators.'
                : '$displayName will lose admin privileges and become "$next".',
            style: AppText.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: AppText.labelLarge
                      .copyWith(color: AppColors.secondaryText)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Confirm',
                  style: AppText.labelLarge
                      .copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final actor = ref.read(authStateChangesProvider).value;
    try {
      if (actor != null) {
        await ref.read(auditLogRepositoryProvider).log(
              actor: actor,
              action: 'user.role_change',
              targetType: 'user',
              targetId: uid,
              before: {'role': current},
              after: {'role': next},
            );
      }
      await ref.read(userRepositoryProvider).setRole(uid, next);
      messenger.showSnackBar(
        SnackBar(content: Text('$displayName → $next')),
      );
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Role change failed: $e')));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tab 3: Audit log
// ─────────────────────────────────────────────────────────────────────────
class _AuditLogTab extends ConsumerWidget {
  const _AuditLogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLog = ref.watch(adminAuditLogProvider);
    return asyncLog.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Could not load audit log.\n$e',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: AppColors.error)),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const _EmptyState(
            icon: Icons.history_rounded,
            text: 'No admin actions logged yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _AuditEntryRow(doc: entries[i]),
        );
      },
    );
  }
}

class _AuditEntryRow extends StatelessWidget {
  const _AuditEntryRow({required this.doc});
  final DocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() ?? const <String, dynamic>{};
    final actor = (data['actor_email'] as String?) ?? 'unknown';
    final action = (data['action'] as String?) ?? '?';
    final targetType = (data['target_type'] as String?) ?? '?';
    final targetId = (data['target_id'] as String?) ?? '?';
    final ts = (data['created_at'] as Timestamp?)?.toDate();
    final before = data['before'] as Map?;
    final after = data['after'] as Map?;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(action),
                  color: _colorFor(action), size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _humanize(action),
                  style: AppText.labelMedium.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (ts != null)
                Text(
                  DateFormat('MMM d · HH:mm').format(ts),
                  style: AppText.labelSmall
                      .copyWith(color: AppColors.secondaryText),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'by $actor',
            style: AppText.bodySmall
                .copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 2),
          Text(
            'target: $targetType/$targetId',
            style: AppText.labelSmall.copyWith(
              color: AppColors.secondaryText,
              fontFamily: 'monospace',
            ),
          ),
          if (before != null || after != null) ...[
            const SizedBox(height: 6),
            Text(
              _diffSummary(before, after),
              style: AppText.labelSmall
                  .copyWith(color: AppColors.primaryText),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String action) {
    if (action.startsWith('momento.')) return Icons.event_note_outlined;
    if (action == 'user.ban') return Icons.block_rounded;
    if (action == 'user.unban') return Icons.lock_open_rounded;
    if (action == 'user.role_change') return Icons.shield_outlined;
    return Icons.history_rounded;
  }

  Color _colorFor(String action) {
    if (action == 'momento.delete' || action == 'user.ban') {
      return AppColors.error;
    }
    return AppColors.primary;
  }

  String _humanize(String action) {
    switch (action) {
      case 'momento.delete':
        return 'Deleted momento';
      case 'user.role_change':
        return 'Changed role';
      case 'user.ban':
        return 'Banned user';
      case 'user.unban':
        return 'Unbanned user';
      default:
        return action;
    }
  }

  String _diffSummary(Map? before, Map? after) {
    if (before == null && after == null) return '';
    final keys = <String>{
      ...?before?.keys.cast<String>(),
      ...?after?.keys.cast<String>(),
    };
    return keys
        .map((k) => '$k: ${before?[k] ?? '∅'} → ${after?[k] ?? '∅'}')
        .join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tab 4: Stats
// ─────────────────────────────────────────────────────────────────────────
class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMomentos = ref.watch(adminAllMomentosProvider);
    final asyncUsers = ref.watch(adminAllUsersProvider);

    final momentos = asyncMomentos.value ?? const [];
    final users = asyncUsers.value ?? const [];

    final activeMomentos = momentos.where((m) => !m.isExpired).length;
    int admins = 0, organisors = 0, plainUsers = 0;
    for (final d in users) {
      final r = (d.data()?['role'] as String?) ?? 'user';
      if (r == 'admin') admins++;
      else if (r == 'organisor') organisors++;
      else plainUsers++;
    }
    final totalViews =
        momentos.fold<int>(0, (sum, m) => sum + m.viewCount);
    final totalLikes =
        momentos.fold<int>(0, (sum, m) => sum + m.likeCount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        _StatTile(
          label: 'Momentos',
          value: '${momentos.length}',
          subtitle: '$activeMomentos active',
        ),
        const SizedBox(height: AppSpacing.md),
        _StatTile(
          label: 'Users',
          value: '${users.length}',
          subtitle:
              '$admins admin · $organisors organisor · $plainUsers user',
        ),
        const SizedBox(height: AppSpacing.md),
        _StatTile(
          label: 'Total views',
          value: _compact(totalViews),
        ),
        const SizedBox(height: AppSpacing.md),
        _StatTile(
          label: 'Total likes',
          value: _compact(totalLikes),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: MomentoButton(
            label: 'Refresh',
            icon: Icons.refresh_rounded,
            size: MomentoButtonSize.small,
            onPressed: () {
              ref.invalidate(adminAllMomentosProvider);
              ref.invalidate(adminAllUsersProvider);
            },
          ),
        ),
      ],
    );
  }

  String _compact(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppText.labelSmall
                        .copyWith(color: AppColors.secondaryText)),
                const SizedBox(height: 4),
                Text(value, style: AppText.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: AppText.bodySmall
                          .copyWith(color: AppColors.secondaryText)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 56,
                color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.md),
            Text(text,
                textAlign: TextAlign.center,
                style: AppText.titleMedium),
          ],
        ),
      ),
    );
  }
}
