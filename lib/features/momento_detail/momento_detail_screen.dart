import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/env.dart';
import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import '../../core/models/momento.dart';
import '../../core/models/momento_category.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/follow_button.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/momento_card.dart';
import '../../core/widgets/responsive_content.dart';
import '../../core/widgets/slide_up_route.dart';
import '../discover/discover_providers.dart';
import '../organizer/organizer_detail_screen.dart';

class MomentoDetailScreen extends ConsumerStatefulWidget {
  const MomentoDetailScreen({super.key, required this.momento, this.onClose});

  final Momento momento;

  /// When provided, the screen is rendered in **embedded mode** — used
  /// by the Phase 3 two-pane Discover layout. The back/close button calls
  /// this callback instead of `Navigator.pop`, and the swipe-down-to-
  /// dismiss gesture is disabled (the parent owns the close affordance).
  final VoidCallback? onClose;

  @override
  ConsumerState<MomentoDetailScreen> createState() =>
      _MomentoDetailScreenState();
}

class _MomentoDetailScreenState extends ConsumerState<MomentoDetailScreen> {
  bool _expanded = false;

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
    // Watch the live doc so inline edits land instantly. Fall back to the
    // seed momento until the first snapshot arrives (and on USE_MOCK_DATA
    // builds where the watcher just yields the static fixture).
    final live = ref.watch(momentoByIdProvider(widget.momento.id));
    final m = live.value ?? widget.momento;

    final all = ref.watch(allMomentosProvider);
    final related =
        all.where((x) => x.id != m.id && x.isActive).take(6).toList();
    final uid = ref.watch(authStateChangesProvider).value?.uid;
    final isAdmin = ref.watch(isAdminProvider);
    final canEdit = canEditMomento(ref, m);
    final showAnalytics = isAdmin || (uid != null && uid == m.organizerId);

    final embedded = widget.onClose != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        // Swipe-down-to-dismiss only in slide-up modal mode. In embedded
        // mode the parent (right pane) owns the close affordance.
        onVerticalDragEnd: embedded
            ? null
            : (details) {
                if ((details.primaryVelocity ?? 0) > 700) {
                  Navigator.pop(context);
                }
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
                    background: _Hero(
                      momento: m,
                      canEdit: canEdit,
                      onEditPhoto: () => _editPhoto(m),
                    ),
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
                    // Hero stays full-bleed (decorative); the body text +
                    // analytics sit in a 720 column for readability.
                    child: ResponsiveContent(
                      maxWidth: 720,
                      padding: EdgeInsets.zero,
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _EditableField(
                          enabled: canEdit,
                          onTap: () => _editTitle(m),
                          child: Text(m.title, style: AppText.headlineMedium),
                        ),
                        if (canEdit) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _CategoryChipRow(
                            category: m.category,
                            onTap: () => _editCategory(m),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _EditableField(
                          enabled: canEdit,
                          onTap: () => _editDates(m),
                          child: _MetaRow(
                            icon: Icons.calendar_today_outlined,
                            text: _formatDateRange(m),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _EditableField(
                          enabled: canEdit,
                          onTap: () => _editLocation(m),
                          child: _MetaRow(
                            icon: Icons.location_on_outlined,
                            text: m.locationAddress,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _OrganizerCard(momento: m),
                        const SizedBox(height: AppSpacing.lg),
                        _EditableField(
                          enabled: canEdit,
                          onTap: () => _editDescription(m),
                          child: _Description(
                            text: m.description,
                            expanded: _expanded,
                            onToggle: () =>
                                setState(() => _expanded = !_expanded),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(
                            color: AppColors.divider, height: 1),
                        const SizedBox(height: AppSpacing.md),
                        _ActionRow(momento: m, onShare: () => _share(m)),
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
                ),
              ],
            ),
            // Floating back / close button. In embedded (two-pane) mode
            // we anchor it top-right and use a close icon; in slide-up
            // mode it stays top-left as a back arrow.
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: embedded ? null : AppSpacing.md,
              right: embedded ? AppSpacing.md : null,
              child: _CircleIconButton(
                icon: embedded
                    ? Icons.close_rounded
                    : Icons.arrow_back_rounded,
                onTap: embedded
                    ? widget.onClose!
                    : () => _back(context),
              ),
            ),
            // Top-right action menu — share for everyone, delete for
            // owner+admin. In embedded mode the close button is already
            // at top-right, so we shift the menu inward.
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: embedded ? AppSpacing.md + 56 : AppSpacing.md,
              child: _CircleIconButton(
                icon: Icons.more_horiz_rounded,
                onTap: () => _openMenu(m, canEdit),
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

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      // Deep-link entry point — no nav stack to pop. Send them home.
      context.go('/discover');
    }
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

  // ──────────────────────────────────────────────────────────────────
  // Inline edit handlers
  // ──────────────────────────────────────────────────────────────────

  Future<void> _editTitle(Momento m) async {
    final next = await _promptText(
      title: 'Edit title',
      initial: m.title,
      maxLength: 120,
    );
    if (next == null || next.trim() == m.title) return;
    await _patch(m, {'title': next.trim()});
  }

  Future<void> _editDescription(Momento m) async {
    final next = await _promptText(
      title: 'Edit description',
      initial: m.description,
      maxLines: 8,
    );
    if (next == null || next == m.description) return;
    await _patch(m, {'description': next});
  }

  Future<void> _editCategory(Momento m) async {
    final next = await showModalBottomSheet<MomentoCategory>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pick a category', style: AppText.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final c in MomentoCategory.values)
                    CategoryChip(
                      label: c.displayName,
                      selected: c == m.category,
                      onTap: () => Navigator.pop(context, c),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (next == null || next == m.category) return;
    await _patch(m, {'category': next.id});
  }

  Future<void> _editDates(Momento m) async {
    final start = await _pickDateTime(
      context: context,
      initial: m.startDateTime,
    );
    if (start == null) return;
    if (!mounted) return;
    final end = await _pickDateTime(
      context: context,
      initial: m.endDateTime.isAfter(start)
          ? m.endDateTime
          : start.add(const Duration(hours: 2)),
      first: start,
      last: start.add(Duration(days: Env.maxMomentoDurationDays)),
    );
    if (end == null) return;
    if (!end.isAfter(start)) return;
    final durationDays = ((end.difference(start)).inHours / 24)
        .ceil()
        .clamp(1, Env.maxMomentoDurationDays);
    await _patch(m, {
      'start_datetime': Timestamp.fromDate(start),
      'end_datetime': Timestamp.fromDate(end),
      'expires_at': Timestamp.fromDate(end),
      'duration_days': durationDays,
    });
  }

  Future<void> _editLocation(Momento m) async {
    final picked = await showModalBottomSheet<_LocationChoice>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (_) => const _LocationPicker(),
    );
    if (picked == null) return;
    final geo = GeoFirePoint(GeoPoint(picked.lat, picked.lng));
    await _patch(m, {
      'location_address': picked.address,
      'location_city': picked.city,
      'location_geopoint': GeoPoint(picked.lat, picked.lng),
      'location_geohash': geo.geohash,
    });
  }

  Future<void> _editPhoto(Momento m) async {
    final picker = ImagePicker();
    final messenger = ScaffoldMessenger.of(context);
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 88,
    );
    if (picked == null) return;
    try {
      await ref.read(momentoRepositoryProvider).updateMomento(
        id: m.id,
        organizerUid: m.organizerId,
        coverPhoto: picked,
      );
      await _maybeAuditAdminEdit(m, fields: const {'images': '[updated]'});
      messenger.showSnackBar(
        const SnackBar(content: Text('Photo updated')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _patch(Momento m, Map<String, Object?> fields) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(momentoRepositoryProvider).updateMomento(
            id: m.id,
            organizerUid: m.organizerId,
            fields: fields,
          );
      await _maybeAuditAdminEdit(m, fields: fields);
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  /// Audit log entry whenever an admin edits a Momento that isn't theirs.
  /// Self-edits don't go in the log — same convention as deletes.
  Future<void> _maybeAuditAdminEdit(
    Momento m, {
    required Map<String, Object?> fields,
  }) async {
    final actor = ref.read(authStateChangesProvider).value;
    final isAdmin = ref.read(isAdminProvider);
    if (actor == null || !isAdmin) return;
    if (actor.uid == m.organizerId) return;
    try {
      await ref.read(auditLogRepositoryProvider).log(
            actor: actor,
            action: 'momento.edit',
            targetType: 'momento',
            targetId: m.id,
            after: fields.map((k, v) => MapEntry(k, v?.toString() ?? '')),
          );
    } catch (_) {
      // Best-effort; the edit already landed.
    }
  }

  Future<String?> _promptText({
    required String title,
    required String initial,
    int maxLines = 1,
    int? maxLength,
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
                style:
                    AppText.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<DateTime?> _pickDateTime({
    required BuildContext context,
    required DateTime initial,
    DateTime? first,
    DateTime? last,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime.now().subtract(const Duration(days: 1)),
      lastDate: last ?? DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ──────────────────────────────────────────────────────────────────
  // Top-right menu
  // ──────────────────────────────────────────────────────────────────

  Future<void> _openMenu(Momento m, bool canEdit) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (sheet) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined,
                  color: AppColors.primaryText),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(sheet);
                _share(m);
              },
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.image_outlined,
                    color: AppColors.primaryText),
                title: const Text('Replace photo'),
                onTap: () {
                  Navigator.pop(sheet);
                  _editPhoto(m);
                },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                title: const Text('Delete Momento',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(sheet);
                  _confirmDelete(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(Momento m) async {
    final url = '${_shareOrigin()}/#/momento/${m.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied: $url')),
    );
  }

  /// On web, mirror the current browser origin so dev/staging copies the
  /// right host. Off-web we hardcode the production domain.
  String _shareOrigin() {
    if (kIsWeb) {
      final base = Uri.base;
      return '${base.scheme}://${base.host}'
          '${base.hasPort && base.port != 80 && base.port != 443 ? ':${base.port}' : ''}';
    }
    return 'https://${Env.domain}';
  }

  Future<void> _confirmDelete(Momento m) async {
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
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final actor = ref.read(authStateChangesProvider).value;
    final isAdmin = ref.read(isAdminProvider);
    try {
      // Audit-log admin deletes of someone else's momento. Owner self-deletes
      // don't carry the same compliance weight.
      if (actor != null && isAdmin && actor.uid != m.organizerId) {
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
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Deleted "${m.title}"')));
      // Pop / clear selection / route home as appropriate.
      if (widget.onClose != null) {
        widget.onClose!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      } else {
        context.go('/discover');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.momento,
    required this.canEdit,
    required this.onEditPhoto,
  });
  final Momento momento;
  final bool canEdit;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: momento.heroImage,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: AppColors.surface),
          errorWidget: (_, _, _) => Container(color: AppColors.surface),
        ),
        if (canEdit)
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _PillButton(
              icon: Icons.image_outlined,
              label: 'Edit photo',
              onTap: onEditPhoto,
            ),
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

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.full),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primaryText),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.labelMedium
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
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

/// Wraps a child with a tappable affordance that's only active for the
/// owner / admin. Adds a subtle pencil glyph at the trailing edge so the
/// "this is editable" hint is discoverable without owning real estate when
/// the user is just reading.
class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: child),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.edit_outlined,
                size: 16, color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _CategoryChipRow extends StatelessWidget {
  const _CategoryChipRow({required this.category, required this.onTap});
  final MomentoCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.displayName,
                style: AppText.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.edit_outlined,
                size: 14, color: AppColors.secondaryText),
          ],
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
          FollowButton(organizerId: momento.organizerId),
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

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.momento, required this.onShare});

  final Momento momento;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateChangesProvider).value;
    final liked = me != null && momento.likedBy.contains(me.uid);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Action(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: '${momento.likeCount}',
          activeColor: liked ? AppColors.error : null,
          onTap: me == null
              ? null
              : () => ref
                  .read(momentoRepositoryProvider)
                  .toggleLike(momento.id, me.uid),
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
          onTap: onShare,
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
      // Bar background spans full viewport; inner row caps at 560 so the
      // CTA doesn't stretch ear-to-ear on desktop.
      child: ResponsiveContent(
        maxWidth: 560,
        padding: EdgeInsets.zero,
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
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Location picker (mock fixture mirrors CreateScreen — until real
// geocoding lands the choice is from a small canned list).
// ──────────────────────────────────────────────────────────────────────

class _LocationChoice {
  const _LocationChoice({
    required this.address,
    required this.city,
    required this.lat,
    required this.lng,
  });
  final String address;
  final String city;
  final double lat;
  final double lng;
}

class _LocationPicker extends StatelessWidget {
  const _LocationPicker();

  static const List<_LocationChoice> _options = [
    _LocationChoice(
      address: 'Tiergarten — entrance Brandenburger Tor',
      city: 'Berlin',
      lat: 52.5163,
      lng: 13.3777,
    ),
    _LocationChoice(
      address: '124 Creative District, Warehouse B',
      city: 'Berlin',
      lat: 52.5074,
      lng: 13.4408,
    ),
    _LocationChoice(
      address: 'Old Square',
      city: 'Berlin',
      lat: 52.5170,
      lng: 13.4060,
    ),
    _LocationChoice(
      address: 'Cellar Bar, Friedrichstraße 12',
      city: 'Berlin',
      lat: 52.5208,
      lng: 13.3878,
    ),
    _LocationChoice(
      address: 'Rooftop, Mitte',
      city: 'Berlin',
      lat: 52.5246,
      lng: 13.4031,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick a location (mock)', style: AppText.titleMedium),
            const SizedBox(height: AppSpacing.md),
            for (final o in _options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined,
                    color: AppColors.primary),
                title: Text(o.address),
                onTap: () => Navigator.pop(context, o),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Map picker arrives with Google Maps in Phase 3 polish.',
              style: AppText.labelSmall
                  .copyWith(color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

